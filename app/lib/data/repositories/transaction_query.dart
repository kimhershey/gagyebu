import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/local_date.dart';
import '../../domain/enums.dart';
import 'ledger_repository.dart';

/// 내역 화면의 필터(`docs/SPEC.md` 7.3). 검색어와 함께 건다.
///
/// 비어 있는 집합은 "가리지 않는다"는 뜻이다. 취소한 거래는 [includeCanceled]를 켜야
/// 보인다(집계에서 빠지는 거래라 평소에는 숨긴다).
class TransactionFilter {
  const TransactionFilter({
    this.types = const {},
    this.categoryIds = const {},
    this.accountIds = const {},
    this.minAmount,
    this.maxAmount,
    this.needsReviewOnly = false,
    this.includeCanceled = false,
  });

  /// [categoryIds]에 넣으면 "분류 없음"(분류를 정하지 않은 수입 · 지출)을 뜻하는 값.
  /// 주소로도 쓴다: `/transactions?category=none`.
  static const noCategory = 'none';

  final Set<TxType> types;

  /// 분류 ID. 대분류를 고르면 그 아래 소분류의 거래도 함께 나온다.
  final Set<String> categoryIds;

  /// 자산 ID. 이체는 보내는 쪽이든 받는 쪽이든 걸린다.
  final Set<String> accountIds;

  /// 금액 범위(양 끝 포함).
  final int? minAmount;
  final int? maxAmount;

  final bool needsReviewOnly;
  final bool includeCanceled;

  /// 아무것도 걸지 않았는지.
  bool get isEmpty => activeCount == 0;

  /// 걸린 조건의 수(칩의 수와 같다).
  int get activeCount =>
      types.length +
      categoryIds.length +
      accountIds.length +
      (minAmount != null || maxAmount != null ? 1 : 0) +
      (needsReviewOnly ? 1 : 0) +
      (includeCanceled ? 1 : 0);

  /// 금액 범위는 null로 되돌릴 수 있어야 해서 함수로 받는다.
  TransactionFilter copyWith({
    Set<TxType>? types,
    Set<String>? categoryIds,
    Set<String>? accountIds,
    int? Function()? minAmount,
    int? Function()? maxAmount,
    bool? needsReviewOnly,
    bool? includeCanceled,
  }) => TransactionFilter(
    types: types ?? this.types,
    categoryIds: categoryIds ?? this.categoryIds,
    accountIds: accountIds ?? this.accountIds,
    minAmount: minAmount == null ? this.minAmount : minAmount(),
    maxAmount: maxAmount == null ? this.maxAmount : maxAmount(),
    needsReviewOnly: needsReviewOnly ?? this.needsReviewOnly,
    includeCanceled: includeCanceled ?? this.includeCanceled,
  );

  @override
  bool operator ==(Object other) =>
      other is TransactionFilter &&
      _sameSet(other.types, types) &&
      _sameSet(other.categoryIds, categoryIds) &&
      _sameSet(other.accountIds, accountIds) &&
      other.minAmount == minAmount &&
      other.maxAmount == maxAmount &&
      other.needsReviewOnly == needsReviewOnly &&
      other.includeCanceled == includeCanceled;

  @override
  int get hashCode => Object.hash(
    Object.hashAllUnordered(types),
    Object.hashAllUnordered(categoryIds),
    Object.hashAllUnordered(accountIds),
    minAmount,
    maxAmount,
    needsReviewOnly,
    includeCanceled,
  );

  @override
  String toString() =>
      'TransactionFilter(types: $types, categories: $categoryIds, '
      'accounts: $accountIds, amount: $minAmount…$maxAmount, '
      'review: $needsReviewOnly, canceled: $includeCanceled)';
}

bool _sameSet<T>(Set<T> a, Set<T> b) =>
    a.length == b.length && a.containsAll(b);

/// [from] 이상 [toExclusive] 미만의 거래 가운데 [filter]와 [search]에 맞는 것을 최근 순으로.
///
/// `LedgerRepository.watchTransactions`와 같은 모양으로 돌려주되 조건만 더 건다.
Stream<List<TransactionView>> watchFilteredTransactions(
  LedgerRepository repository,
  String ledgerId, {
  required LocalDate from,
  required LocalDate toExclusive,
  TransactionFilter filter = const TransactionFilter(),
  String? search,
}) {
  final db = repository.db;
  final t = db.ledgerTransactions;
  final a = db.accounts;
  final toA = db.alias(db.accounts, 'to_account');
  final c = db.categories;

  var condition =
      t.ledgerId.equals(ledgerId) &
      t.deletedAt.isNull() &
      t.occurredOn.isBiggerOrEqualValue(from.toString()) &
      t.occurredOn.isSmallerThanValue(toExclusive.toString());

  final term = search?.trim() ?? '';
  if (term.isNotEmpty) {
    final like = '%${_escapeLike(term)}%';
    condition =
        condition &
        (t.sender.like(like, escapeChar: r'\') |
            t.receiver.like(like, escapeChar: r'\') |
            t.memo.like(like, escapeChar: r'\') |
            c.name.like(like, escapeChar: r'\'));
  }

  if (filter.types.isNotEmpty) {
    condition = condition & t.type.isInValues(filter.types);
  }

  if (filter.categoryIds.isNotEmpty) {
    final ids = filter.categoryIds
        .where((id) => id != TransactionFilter.noCategory)
        .toList();
    Expression<bool>? byCategory;
    if (ids.isNotEmpty) {
      // 대분류를 고르면 소분류의 거래도 나오게, 고른 분류와 그 아래 분류를 함께 찾는다.
      final family = db.alias(db.categories, 'filter_category');
      final familyIds = db.selectOnly(family)
        ..addColumns([family.id])
        ..where(family.id.isIn(ids) | family.parentId.isIn(ids));
      byCategory = t.categoryId.isInQuery(familyIds);
    }
    if (filter.categoryIds.contains(TransactionFilter.noCategory)) {
      // 이체에는 분류가 없지만 "분류 없음"으로 치지 않는다.
      final none =
          t.categoryId.isNull() & t.type.equalsValue(TxType.transfer).not();
      byCategory = byCategory == null ? none : byCategory | none;
    }
    condition = condition & byCategory!;
  }

  if (filter.accountIds.isNotEmpty) {
    condition =
        condition &
        (t.accountId.isIn(filter.accountIds) |
            t.toAccountId.isIn(filter.accountIds));
  }

  final min = filter.minAmount;
  if (min != null) {
    condition = condition & t.amount.isBiggerOrEqualValue(min);
  }
  final max = filter.maxAmount;
  if (max != null) {
    condition = condition & t.amount.isSmallerOrEqualValue(max);
  }

  if (filter.needsReviewOnly) {
    condition = condition & t.status.equalsValue(TxStatus.needsReview);
  }
  if (!filter.includeCanceled) {
    condition = condition & t.canceledAt.isNull();
  }

  final query =
      db.select(t).join([
          leftOuterJoin(a, a.id.equalsExp(t.accountId)),
          leftOuterJoin(toA, toA.id.equalsExp(t.toAccountId)),
          leftOuterJoin(c, c.id.equalsExp(t.categoryId)),
        ])
        ..where(condition)
        ..orderBy([
          OrderingTerm.desc(t.occurredOn),
          OrderingTerm(
            expression: t.occurredTime,
            mode: OrderingMode.desc,
            nulls: NullsOrder.last,
          ),
          OrderingTerm.desc(t.id),
        ]);

  return query.watch().map(
    (rows) => [
      for (final row in rows)
        TransactionView(
          row: row.readTable(t),
          accountName: row.readTableOrNull(a)?.name ?? '(지워진 자산)',
          toAccountName: row.readTableOrNull(toA)?.name,
          categoryName: row.readTableOrNull(c)?.name,
        ),
    ],
  );
}

String _escapeLike(String text) =>
    text.replaceAll(r'\', r'\\').replaceAll('%', r'\%').replaceAll('_', r'\_');

/// 하루의 수입과 지출 합계.
class DayTotal {
  const DayTotal({this.income = 0, this.expense = 0});

  final int income;
  final int expense;

  @override
  bool operator ==(Object other) =>
      other is DayTotal && other.income == income && other.expense == expense;

  @override
  int get hashCode => Object.hash(income, expense);

  @override
  String toString() => 'DayTotal(+$income, -$expense)';
}

/// 달력의 날짜 칸에 적을 날짜별 합계. 취소한 거래와 이체는 뺀다.
Map<LocalDate, DayTotal> dailyTotals(Iterable<TransactionView> transactions) {
  final totals = <LocalDate, DayTotal>{};
  for (final view in transactions) {
    final row = view.row;
    if (view.isCanceled || row.type == TxType.transfer) continue;
    final day = totals[row.occurredOn] ?? const DayTotal();
    totals[row.occurredOn] = row.type == TxType.income
        ? DayTotal(income: day.income + row.amount, expense: day.expense)
        : DayTotal(income: day.income, expense: day.expense + row.amount);
  }
  return totals;
}

/// 내역 화면에 걸린 필터.
class TransactionFilterController extends Notifier<TransactionFilter> {
  @override
  TransactionFilter build() => const TransactionFilter();

  void set(TransactionFilter filter) => state = filter;

  void clear() => state = const TransactionFilter();
}

final transactionFilterProvider =
    NotifierProvider<TransactionFilterController, TransactionFilter>(
      TransactionFilterController.new,
    );

/// 내역을 보는 방식.
enum TransactionViewMode { list, calendar }

class TransactionViewModeController extends Notifier<TransactionViewMode> {
  @override
  TransactionViewMode build() => TransactionViewMode.list;

  void set(TransactionViewMode mode) => state = mode;
}

final transactionViewModeProvider =
    NotifierProvider<TransactionViewModeController, TransactionViewMode>(
      TransactionViewModeController.new,
    );

/// 달력에서 고른 날짜. 고르지 않았으면 null이다.
class CalendarDayController extends Notifier<LocalDate?> {
  @override
  LocalDate? build() => null;

  void set(LocalDate? day) => state = day;
}

final calendarDayProvider = NotifierProvider<CalendarDayController, LocalDate?>(
  CalendarDayController.new,
);

/// 달력에서 거래를 보여 줄 날. 고른 날이 보고 있는 달에 들면 그날이고, 아니면 오늘이다
/// (오늘도 그 달 밖이면 없다).
final shownCalendarDayProvider = Provider<LocalDate?>((ref) {
  final period = ref.watch(selectedPeriodProvider);
  final picked = ref.watch(calendarDayProvider);
  if (picked != null && period.contains(picked)) return picked;
  final today = ref.watch(todayProvider);
  return period.contains(today) ? today : null;
});

/// 보고 있는 달의 거래에 필터와 검색어를 건 것. 목록과 달력이 함께 쓴다.
final filteredTransactionsProvider = StreamProvider<List<TransactionView>>((
  ref,
) {
  final period = ref.watch(selectedPeriodProvider);
  return watchFilteredTransactions(
    ref.watch(repositoryProvider),
    ref.watch(ledgerIdProvider),
    from: period.start,
    toExclusive: period.endExclusive,
    filter: ref.watch(transactionFilterProvider),
    search: ref.watch(searchQueryProvider),
  );
});
