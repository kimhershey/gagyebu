import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/local_date.dart';
import '../../domain/enums.dart';
import '../../domain/month_period.dart';
import '../../domain/month_summary.dart';
import '../db/database.dart';
import 'budget_repository.dart';
import 'ledger_repository.dart';

/// 홈과 통계가 쓰는 집계 가운데 기본 집계(`LedgerRepository.monthSummary`)에 없는 것:
/// 고정 지출, 예산 대비, 여러 달의 추이, 확인 필요 건수, 수입 쪽의 내용
/// (`docs/SPEC.md` 7.9 · 7.10).
///
/// 읽기만 한다. 숫자는 모두 SQL이 센다.
class SummaryRepository {
  SummaryRepository(this.ledger);

  final LedgerRepository ledger;

  AppDatabase get db => ledger.db;

  /// 집계에 드는 거래: 그 가계부, 그 기간, 지우지도 취소하지도 않은 것.
  static const _scope = '''
    ledger_id = ?1 AND occurred_on >= ?2 AND occurred_on < ?3
    AND deleted_at IS NULL AND canceled_at IS NULL
  ''';

  List<Variable> _vars(
    String ledgerId,
    LocalDate from,
    LocalDate toExclusive,
  ) => [
    Variable.withString(ledgerId),
    Variable.withString(from.toString()),
    Variable.withString(toExclusive.toString()),
  ];

  /// 고정 지출: 반복 거래가 만든(출처가 `recurring`인) 지출의 합.
  Future<int> fixedExpense(String ledgerId, MonthPeriod period) async {
    final row = await db
        .customSelect(
          '''
          SELECT COALESCE(SUM(amount), 0) AS total
          FROM transactions
          WHERE $_scope AND type = 'expense' AND source = ?4
          ''',
          variables: [
            ..._vars(ledgerId, period.start, period.endExclusive),
            Variable.withString(TxSource.recurring.code),
          ],
        )
        .getSingle();
    return row.read<int>('total');
  }

  /// 그 달의 전체 예산(원). 정하지 않았으면 null. 행이 겹치면 나중에 고친 것을 쓴다.
  Future<int?> totalBudgetAmount(String ledgerId, MonthPeriod period) async {
    final row =
        await (db.select(db.budgets)
              ..where(
                (b) =>
                    b.ledgerId.equals(ledgerId) &
                    b.month.equals(period.key) &
                    b.categoryId.isNull() &
                    b.deletedAt.isNull(),
              )
              ..orderBy([(b) => OrderingTerm.desc(b.clientUpdatedAt)])
              ..limit(1))
            .getSingleOrNull();
    return row?.amount;
  }

  /// 고정 지출과 예산 대비까지 채운 한 달 집계. 월별 요약(`toStatsJson`)의 입력이다.
  Future<MonthSummary> monthSummary(
    String ledgerId,
    MonthPeriod period, {
    required LocalDate today,
  }) async {
    final base = await ledger.monthSummary(ledgerId, period, today: today);
    final budget = await totalBudgetAmount(ledgerId, period);
    return base.withExtras(
      fixedExpense: await fixedExpense(ledgerId, period),
      budget: budget == null
          ? null
          : MonthBudget(amount: budget, spent: base.expense),
    );
  }

  /// [period]까지 [count]달의 수입 · 지출 합계. 오래된 달부터 준다.
  Future<List<MonthTotal>> monthlyTotals(
    String ledgerId,
    MonthPeriod period, {
    int count = 6,
  }) async {
    final periods = <MonthPeriod>[period];
    while (periods.length < count) {
      periods.insert(0, periods.first.previous);
    }
    // 날짜별로 한 번에 읽어 기간에 나눠 담는다. 월 시작일이 1일이 아니면 기간이 달력의
    // 달과 어긋나서 SQL에서 달로 묶을 수 없다.
    final rows = await db.customSelect(
      '''
          SELECT occurred_on, type, SUM(amount) AS total
          FROM transactions
          WHERE $_scope AND type <> 'transfer'
          GROUP BY occurred_on, type
          ''',
      variables: _vars(ledgerId, periods.first.start, period.endExclusive),
    ).get();
    final income = List<int>.filled(periods.length, 0);
    final expense = List<int>.filled(periods.length, 0);
    for (final row in rows) {
      final day = LocalDate.parse(row.read<String>('occurred_on'));
      final index = periods.indexWhere((p) => p.contains(day));
      if (index < 0) continue;
      final total = row.read<int>('total');
      if (row.read<String>('type') == TxType.income.code) {
        income[index] += total;
      } else {
        expense[index] += total;
      }
    }
    return [
      for (var i = 0; i < periods.length; i++)
        MonthTotal(period: periods[i], income: income[i], expense: expense[i]),
    ];
  }

  /// 거래가 바뀔 때마다 [monthlyTotals]를 다시 흘려보낸다.
  Stream<List<MonthTotal>> watchMonthlyTotals(
    String ledgerId,
    MonthPeriod period, {
    int count = 6,
  }) => _onTransactionChange().asyncMap(
    (_) => monthlyTotals(ledgerId, period, count: count),
  );

  /// 그 달의 수입 쪽 내용: 합계, 분류별 합계, 날짜별 합계, 보낸 곳 상위 5, 큰 수입 5.
  Future<FlowBreakdown> incomeBreakdown(
    String ledgerId,
    MonthPeriod period,
  ) async {
    final vars = _vars(ledgerId, period.start, period.endExclusive);

    final categoryRows = await db.customSelect('''
          SELECT t.category_id AS category_id, c.name AS name, SUM(t.amount) AS total
          FROM transactions t
          LEFT JOIN categories c ON c.id = t.category_id
          WHERE t.ledger_id = ?1 AND t.occurred_on >= ?2 AND t.occurred_on < ?3
            AND t.deleted_at IS NULL AND t.canceled_at IS NULL AND t.type = 'income'
          GROUP BY t.category_id
          ORDER BY total DESC
          ''', variables: vars).get();

    final partyRows = await db.customSelect('''
          SELECT sender AS name, SUM(amount) AS total, COUNT(*) AS n
          FROM transactions
          WHERE $_scope AND type = 'income' AND sender IS NOT NULL AND sender <> ''
          GROUP BY sender
          ORDER BY total DESC, n DESC
          LIMIT 5
          ''', variables: vars).get();

    final largestRows = await db.customSelect('''
          SELECT id, occurred_on, amount,
                 COALESCE(NULLIF(sender, ''), NULLIF(memo, ''), '') AS name
          FROM transactions
          WHERE $_scope AND type = 'income'
          ORDER BY amount DESC, occurred_on DESC
          LIMIT 5
          ''', variables: vars).get();

    final dailyRows = await db.customSelect('''
          SELECT occurred_on, SUM(amount) AS total
          FROM transactions
          WHERE $_scope AND type = 'income'
          GROUP BY occurred_on
          ''', variables: vars).get();
    final daily = {
      for (final row in dailyRows)
        LocalDate.parse(row.read<String>('occurred_on')): row.read<int>(
          'total',
        ),
    };

    return FlowBreakdown(
      period: period,
      total: daily.values.fold<int>(0, (sum, v) => sum + v),
      byCategory: [
        for (final row in categoryRows)
          CategoryTotal(
            categoryId: row.read<String?>('category_id'),
            name: row.read<String?>('name') ?? '분류 없음',
            amount: row.read<int>('total'),
          ),
      ],
      daily: daily,
      topCounterparties: [
        for (final row in partyRows)
          CounterpartyTotal(
            name: row.read<String>('name'),
            amount: row.read<int>('total'),
            count: row.read<int>('n'),
          ),
      ],
      largest: [
        for (final row in largestRows)
          LargeExpense(
            transactionId: row.read<String>('id'),
            date: LocalDate.parse(row.read<String>('occurred_on')),
            name: row.read<String>('name'),
            amount: row.read<int>('amount'),
          ),
      ],
    );
  }

  /// 거래나 분류가 바뀔 때마다 [incomeBreakdown]을 다시 흘려보낸다.
  Stream<FlowBreakdown> watchIncomeBreakdown(
    String ledgerId,
    MonthPeriod period,
  ) =>
      _onTransactionChange().asyncMap((_) => incomeBreakdown(ledgerId, period));

  /// 그 달의 '확인 필요' 거래 수. 취소한 거래도 확인이 남았으면 센다(내역에 보이므로).
  Stream<int> watchNeedsReviewCount(String ledgerId, MonthPeriod period) => db
      .customSelect(
        '''
        SELECT COUNT(*) AS n
        FROM transactions
        WHERE ledger_id = ?1 AND occurred_on >= ?2 AND occurred_on < ?3
          AND deleted_at IS NULL AND status = ?4
        ''',
        variables: [
          ..._vars(ledgerId, period.start, period.endExclusive),
          Variable.withString(TxStatus.needsReview.code),
        ],
        readsFrom: {db.ledgerTransactions},
      )
      .watchSingle()
      .map((row) => row.read<int>('n'));

  /// 거래나 분류가 바뀌면 값을 하나 흘려보낸다. 처음에도 한 번 보낸다.
  Stream<void> _onTransactionChange() => db
      .customSelect(
        'SELECT COUNT(*) AS n FROM transactions',
        readsFrom: {db.ledgerTransactions, db.categories},
      )
      .watch();
}

final summaryRepositoryProvider = Provider<SummaryRepository>(
  (ref) => SummaryRepository(ref.watch(repositoryProvider)),
);

/// 고정 지출과 예산 대비까지 채운 [period]의 집계. 총평을 만드는 쪽이
/// `toStatsJson()`의 입력으로 쓴다.
final monthStatsProvider = FutureProvider.family<MonthSummary, MonthPeriod>(
  (ref, period) => ref
      .watch(summaryRepositoryProvider)
      .monthSummary(
        ref.watch(ledgerIdProvider),
        period,
        today: ref.watch(todayProvider),
      ),
);

/// 보고 있는 달의 '확인 필요' 거래 수.
final needsReviewCountProvider = StreamProvider<int>(
  (ref) => ref
      .watch(summaryRepositoryProvider)
      .watchNeedsReviewCount(
        ref.watch(ledgerIdProvider),
        ref.watch(selectedPeriodProvider),
      ),
);

/// 보고 있는 달의 전체 예산(원). 정하지 않았으면 null.
final totalBudgetAmountProvider = StreamProvider<int?>((ref) {
  final period = ref.watch(selectedPeriodProvider);
  return ref
      .watch(budgetRepositoryProvider)
      .watchBudgets(ref.watch(ledgerIdProvider), period.key)
      .map((rows) {
        for (final row in rows) {
          if (row.categoryId == null) return row.amount;
        }
        return null;
      });
});

/// 보고 있는 달의 전체 예산과 쓴 돈. 전체 예산을 정하지 않았으면 null.
///
/// 설계서 7.9의 `budgetProgressProvider`에 해당한다. 예산 화면이 같은 이름의 제공자를
/// 둘 수 있어 이름을 달리했다.
final totalBudgetProgressProvider = Provider<AsyncValue<MonthBudget?>>((ref) {
  final amount = ref.watch(totalBudgetAmountProvider);
  final summary = ref.watch(monthSummaryProvider);
  // 예산과 집계가 모두 온 뒤에 값을 낸다. 한쪽만으로는 막대를 그릴 수 없다.
  if (amount.hasError) {
    return AsyncValue.error(amount.error!, amount.stackTrace!);
  }
  if (!amount.hasValue) return const AsyncValue.loading();
  final budget = amount.value;
  if (budget == null) return const AsyncValue.data(null);
  final spent = summary.value?.expense;
  if (spent == null) {
    return summary.hasError
        ? AsyncValue.error(summary.error!, summary.stackTrace!)
        : const AsyncValue.loading();
  }
  return AsyncValue.data(MonthBudget(amount: budget, spent: spent));
});

/// 보고 있는 달까지 최근 여섯 달의 수입 · 지출.
final monthTrendProvider = StreamProvider<List<MonthTotal>>(
  (ref) => ref
      .watch(summaryRepositoryProvider)
      .watchMonthlyTotals(
        ref.watch(ledgerIdProvider),
        ref.watch(selectedPeriodProvider),
      ),
);

/// 보고 있는 달의 수입 쪽 내용.
final incomeBreakdownProvider = StreamProvider<FlowBreakdown>(
  (ref) => ref
      .watch(summaryRepositoryProvider)
      .watchIncomeBreakdown(
        ref.watch(ledgerIdProvider),
        ref.watch(selectedPeriodProvider),
      ),
);
