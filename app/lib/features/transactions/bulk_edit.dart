import '../../data/db/database.dart';
import '../../data/repositories/ledger_repository.dart';
import '../../domain/enums.dart';

/// 저장된 거래 [row]를 다시 저장할 입력값으로 옮긴다. 바꿀 것만 인자로 준다.
///
/// 분류는 "분류 없음"(null)으로도 바꿀 수 있어야 해서 함수로 받는다.
TransactionInput inputFromRow(
  TxRow row, {
  String? Function()? categoryId,
  String? accountId,
  TxStatus? status,
}) => TransactionInput(
  type: row.type,
  occurredOn: row.occurredOn,
  occurredTime: row.occurredTime,
  amount: row.amount,
  accountId: accountId ?? row.accountId,
  toAccountId: row.toAccountId,
  counterparty: switch (row.type) {
    TxType.expense => row.receiver,
    TxType.income => row.sender,
    TxType.transfer => null,
  },
  categoryId: categoryId == null ? row.categoryId : categoryId(),
  memo: row.memo,
  installmentMonths: row.installmentMonths,
  balanceAfter: row.balanceAfter,
  currency: row.currency,
  originalAmount: row.originalAmount,
  source: row.source,
  aiModel: row.aiModel,
  canceled: row.canceledAt != null,
  status: status ?? row.status,
);

/// 일괄 수정의 결과.
class BulkResult {
  const BulkResult({required this.done, required this.skipped});

  /// 바꾼 건수(이미 그 값이던 것도 센다).
  final int done;

  /// 바꿀 수 없어 그대로 둔 건수.
  final int skipped;
}

/// 고른 거래의 분류를 [category]로 바꾼다. null이면 "분류 없음"으로 바꾼다.
///
/// 이체에는 분류가 없고 지출 분류를 수입에 붙일 수 없으므로, 종류가 맞지 않는 거래는
/// 그대로 둔다. 행마다 한 건씩 저장한다(각각 대기열에 올라간다).
Future<BulkResult> bulkSetCategory(
  LedgerRepository repository,
  Iterable<TxRow> rows,
  CategoryRow? category,
) async {
  var done = 0, skipped = 0;
  for (final row in rows) {
    final fits = switch (row.type) {
      TxType.transfer => false,
      TxType.expense =>
        category == null || category.kind == CategoryKind.expense,
      TxType.income => category == null || category.kind == CategoryKind.income,
    };
    if (!fits) {
      skipped++;
      continue;
    }
    if (row.categoryId != category?.id) {
      await repository.updateTransaction(
        row.id,
        inputFromRow(row, categoryId: () => category?.id),
      );
    }
    done++;
  }
  return BulkResult(done: done, skipped: skipped);
}

/// 고른 거래의 자산을 [accountId]로 바꾼다. 이체는 보내는 자산을 바꾼다.
///
/// 받는 자산이 [accountId]인 이체는 같은 자산끼리의 이체가 되므로 그대로 둔다.
Future<BulkResult> bulkSetAccount(
  LedgerRepository repository,
  Iterable<TxRow> rows,
  String accountId,
) async {
  var done = 0, skipped = 0;
  for (final row in rows) {
    if (row.type == TxType.transfer && row.toAccountId == accountId) {
      skipped++;
      continue;
    }
    if (row.accountId != accountId) {
      await repository.updateTransaction(
        row.id,
        inputFromRow(row, accountId: accountId),
      );
    }
    done++;
  }
  return BulkResult(done: done, skipped: skipped);
}

/// 고른 거래 가운데 확인이 필요한 것을 확인한 것으로 바꾼다. 바꾼 건수를 돌려준다.
Future<int> bulkConfirm(
  LedgerRepository repository,
  Iterable<TxRow> rows,
) async {
  var done = 0;
  for (final row in rows) {
    if (row.status != TxStatus.needsReview) continue;
    await repository.updateTransaction(
      row.id,
      inputFromRow(row, status: TxStatus.confirmed),
    );
    done++;
  }
  return done;
}

/// 고른 거래를 지운다. 지운 건수를 돌려준다.
Future<int> bulkDelete(
  LedgerRepository repository,
  Iterable<TxRow> rows,
) async {
  var done = 0;
  for (final row in rows) {
    await repository.deleteTransaction(row.id);
    done++;
  }
  return done;
}
