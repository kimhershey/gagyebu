import 'package:drift/drift.dart';

import '../../ai/query/ledger_query.dart';
import '../../core/local_date.dart';
import '../../domain/enums.dart';
import 'ledger_repository.dart';

/// 조회의 답(`docs/SPEC.md` 7.15). 숫자는 모두 SQL이 센다.
class QueryResult {
  const QueryResult({
    required this.query,
    required this.count,
    required this.total,
    required this.averageDays,
    required this.rows,
  });

  /// 적용한 조건.
  final LedgerQuery query;

  /// 조건에 맞는 거래 수. 취소한 거래와 지운 거래는 세지 않는다.
  final int count;

  /// 금액의 합(원). 종류를 가리지 않은 조회에서는 수입 · 지출 · 이체가 섞인 값이라
  /// 화면에 보이지 않는다.
  final int total;

  /// '하루 평균'을 나눈 날 수. 기간 가운데 오늘까지 지난 날이다.
  final int averageDays;

  /// 조건에 맞는 거래. 최근 순으로 [runQuery]의 `listLimit`건까지.
  final List<TransactionView> rows;

  bool get isEmpty => count == 0;

  /// 평균(원). 조건이 '하루 평균'이면 날 수로, 아니면 건수로 나눈다.
  int get average {
    final divisor = query.perDay ? averageDays : count;
    return divisor <= 0 ? 0 : (total / divisor).round();
  }

  /// 목록에 다 담지 못한 건수.
  int get hiddenCount => count - rows.length;
}

/// [query]를 실행한다.
///
/// 조건은 drift의 조회 식으로만 건다. 값은 모두 매개변수로 들어가고, 문장이나 모델의
/// 답이 SQL 글자가 되는 일은 없다.
///
/// [today]를 주면 '하루 평균'을 기간 전체가 아니라 오늘까지 지난 날로 나눈다.
Future<QueryResult> runQuery(
  LedgerRepository repository,
  String ledgerId,
  LedgerQuery query, {
  LocalDate? today,
  int listLimit = 50,
}) async {
  final db = repository.db;
  final t = db.ledgerTransactions;
  final a = db.accounts;
  final toA = db.alias(db.accounts, 'to_account');
  final c = db.categories;

  QueryResult empty() => QueryResult(
    query: query,
    count: 0,
    total: 0,
    averageDays: _elapsedDays(query.range, today),
    rows: const [],
  );

  var condition =
      t.ledgerId.equals(ledgerId) &
      t.deletedAt.isNull() &
      t.canceledAt.isNull() &
      t.occurredOn.isBiggerOrEqualValue(query.range.from.toString()) &
      t.occurredOn.isSmallerThanValue(query.range.toExclusive.toString());

  final type = query.type;
  if (type != null) condition = condition & t.type.equalsValue(type);

  final categoryName = query.category;
  if (categoryName != null) {
    final all = await repository.categories(ledgerId);
    final wanted = categoryName.trim().toLowerCase();
    final ids = <String>{
      for (final row in all)
        if (row.name.trim().toLowerCase() == wanted &&
            (type == null || row.kind.code == type.code))
          row.id,
    };
    // 대분류를 물으면 그 아래 소분류의 거래도 센다.
    ids.addAll([
      for (final row in all)
        if (row.parentId != null && ids.contains(row.parentId)) row.id,
    ]);
    if (ids.isEmpty) return empty();
    condition = condition & t.categoryId.isIn(ids);
  }

  final party = query.party?.trim() ?? '';
  if (party.isNotEmpty) {
    final like = '%${_escapeLike(party)}%';
    condition =
        condition &
        (t.receiver.like(like, escapeChar: r'\') |
            t.sender.like(like, escapeChar: r'\') |
            t.memo.like(like, escapeChar: r'\'));
  }

  final countColumn = t.id.count();
  final sumColumn = t.amount.sum();
  final totals =
      await (db.selectOnly(t)
            ..addColumns([countColumn, sumColumn])
            ..where(condition))
          .getSingle();
  final count = totals.read(countColumn) ?? 0;
  if (count == 0) return empty();

  final rows =
      await (db.select(t).join([
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
            ])
            ..limit(listLimit))
          .get();

  return QueryResult(
    query: query,
    count: count,
    total: totals.read(sumColumn) ?? 0,
    averageDays: _elapsedDays(query.range, today),
    rows: [
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

/// 기간 가운데 오늘까지 지난 날 수(1 이상).
int _elapsedDays(DateRange range, LocalDate? today) {
  var end = range.toExclusive;
  if (today != null && today.addDays(1) < end) end = today.addDays(1);
  final days = end.differenceInDays(range.from);
  return days < 1 ? 1 : days;
}

String _escapeLike(String text) =>
    text.replaceAll(r'\', r'\\').replaceAll('%', r'\%').replaceAll('_', r'\_');

/// 조회 조건의 종류를 화면의 말로.
String queryTypeLabel(TxType type) => switch (type) {
  TxType.expense => '지출',
  TxType.income => '수입',
  TxType.transfer => '이체',
};
