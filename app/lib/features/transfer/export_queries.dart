import 'package:drift/drift.dart';

import '../../core/local_date.dart';
import '../../data/repositories/ledger_repository.dart';

/// 내보내기가 쓰는 조회. 저장소(`LedgerRepository`)를 고치지 않고 여기서 더한다.
extension ExportQueries on LedgerRepository {
  /// [from] 이상 [toExclusive] 미만의 거래를 오래된 것부터 한 번 읽는다.
  ///
  /// 저장소의 `watchTransactions`는 바뀔 때마다 다시 흘려보내는 흐름이다. 파일로 한 번
  /// 적을 때는 그때의 내용만 있으면 되므로 따로 읽는다.
  Future<List<TransactionView>> transactionsBetween(
    String ledgerId, {
    required LocalDate from,
    required LocalDate toExclusive,
  }) async {
    final t = db.ledgerTransactions;
    final a = db.accounts;
    final toA = db.alias(db.accounts, 'to_account');
    final c = db.categories;
    final query =
        db.select(t).join([
            leftOuterJoin(a, a.id.equalsExp(t.accountId)),
            leftOuterJoin(toA, toA.id.equalsExp(t.toAccountId)),
            leftOuterJoin(c, c.id.equalsExp(t.categoryId)),
          ])
          ..where(
            t.ledgerId.equals(ledgerId) &
                t.deletedAt.isNull() &
                t.occurredOn.isBiggerOrEqualValue(from.toString()) &
                t.occurredOn.isSmallerThanValue(toExclusive.toString()),
          )
          ..orderBy([
            OrderingTerm.asc(t.occurredOn),
            OrderingTerm(
              expression: t.occurredTime,
              mode: OrderingMode.asc,
              nulls: NullsOrder.first,
            ),
            OrderingTerm.asc(t.id),
          ]);
    final rows = await query.get();
    return [
      for (final row in rows)
        TransactionView(
          row: row.readTable(t),
          accountName: row.readTableOrNull(a)?.name ?? '(지워진 자산)',
          toAccountName: row.readTableOrNull(toA)?.name,
          categoryName: row.readTableOrNull(c)?.name,
        ),
    ];
  }
}
