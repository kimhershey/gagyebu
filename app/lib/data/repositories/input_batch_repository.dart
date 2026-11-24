import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/ids.dart';
import '../../domain/enums.dart';
import '../db/database.dart';
import 'ledger_repository.dart';

/// 묶음에 넣을 한 건.
sealed class BatchEntry {
  const BatchEntry();
}

/// 새 거래를 만든다.
class BatchCreate extends BatchEntry {
  const BatchCreate(this.input);

  final TransactionInput input;
}

/// 이미 있는 거래를 취소로 표시한다(승인취소 문자의 원 거래).
class BatchCancel extends BatchEntry {
  const BatchCancel(this.txId);

  final String txId;
}

/// `input_batch_items.kind`의 값.
abstract final class BatchItemKind {
  /// 묶음이 만든 거래.
  static const created = 'created';

  /// 묶음이 취소 처리한 원 거래.
  static const canceled = 'canceled';
}

/// 저장한 묶음.
class SavedBatch {
  const SavedBatch({
    required this.batchId,
    required this.createdIds,
    required this.canceledIds,
  });

  final String batchId;

  /// 묶음이 만든 거래의 ID(넣은 순서).
  final List<String> createdIds;

  /// 묶음이 취소로 표시한 원 거래의 ID.
  final List<String> canceledIds;

  int get itemCount => createdIds.length + canceledIds.length;
}

/// 되돌린 결과.
class UndoResult {
  const UndoResult({required this.undone, required this.kept});

  /// 되돌린 건수(지운 거래 + 취소를 푼 거래).
  final int undone;

  /// 저장한 뒤에 고쳐서 남겨 둔 건수.
  final int kept;
}

/// 이미 되돌린 묶음을 또 되돌리려 했다.
class BatchAlreadyUndone implements Exception {
  const BatchAlreadyUndone(this.batchId);

  final String batchId;

  @override
  String toString() => '이미 되돌린 묶음이다: $batchId';
}

/// 묶음이 건드린 거래 한 건과 그 거래의 지금 모습.
class BatchItemView {
  const BatchItemView({required this.item, required this.transaction});

  final InputBatchItemRow item;

  /// 지금의 거래. 흔적 없이 지워졌으면 null이다.
  final TransactionView? transaction;

  /// 지워져서 더는 내역에 없는지.
  bool get isGone => transaction == null || transaction!.row.deletedAt != null;

  /// 저장한 뒤에 고쳤는지. 고친 거래는 되돌리기가 건드리지 않는다.
  bool get isEdited =>
      !isGone && transaction!.row.clientUpdatedAt != item.stamp;
}

/// 입력창 · 이미지 입력 · 가져오기로 저장한 묶음의 기록과 되돌리기(`docs/SPEC.md` 7.7).
///
/// 거래를 쓰는 일은 [LedgerRepository]에 맡긴다(대기열에 올리는 것까지 거기서 한다).
/// 여기서는 그 호출들을 한 트랜잭션으로 묶고, 무엇을 건드렸는지를 기기에만 있는 표
/// `input_batches` · `input_batch_items`에 적는다. 이 두 표는 동기화하지 않는다.
class InputBatchRepository {
  InputBatchRepository(this.ledger, {String Function()? idGenerator})
    : _newId = idGenerator ?? newRowId;

  final LedgerRepository ledger;
  final String Function() _newId;

  AppDatabase get db => ledger.db;

  /// 기록을 보관하는 날 수.
  static const retentionDays = 90;

  /// [entries]를 한 트랜잭션으로 저장하고 작업 기록을 남긴다.
  ///
  /// 중간에 한 건이라도 실패하면 거래도, 대기열도, 기록도 남지 않는다.
  Future<SavedBatch> saveBatch(
    String ledgerId,
    List<BatchEntry> entries, {
    required TxSource source,
  }) async {
    if (entries.isEmpty) throw ArgumentError('저장할 건이 없습니다');
    final saved = await db.transaction(() async {
      final batchId = _newId();
      final created = <String>[];
      final canceled = <String>[];
      for (final entry in entries) {
        switch (entry) {
          case BatchCreate(:final input):
            final id = await ledger.addTransaction(ledgerId, input);
            await _recordItem(batchId, id, BatchItemKind.created);
            created.add(id);
            // 사용자가 확인한 분류를 상대방의 규칙으로 기억한다.
            final party = input.counterparty?.trim() ?? '';
            final categoryId = input.categoryId;
            if (input.type != TxType.transfer &&
                party.isNotEmpty &&
                categoryId != null) {
              await ledger.rememberCategory(ledgerId, party, categoryId);
            }
          case BatchCancel(:final txId):
            // 같은 원 거래를 가리키는 취소 문자가 두 번 들어와도 한 번만 적는다.
            if (canceled.contains(txId)) continue;
            await ledger.setCanceled(txId, canceled: true);
            await _recordItem(batchId, txId, BatchItemKind.canceled);
            canceled.add(txId);
        }
      }
      await db
          .into(db.inputBatches)
          .insert(
            InputBatchesCompanion.insert(
              id: batchId,
              ledgerId: ledgerId,
              createdAt: ledger.outbox.now(),
              source: source,
              itemCount: created.length + canceled.length,
            ),
          );
      return SavedBatch(
        batchId: batchId,
        createdIds: created,
        canceledIds: canceled,
      );
    });
    // 묶음을 저장할 때마다 오래된 기록을 치운다. 따로 도는 정리 작업이 없어도 쌓이지 않는다.
    await purgeExpired(ledgerId);
    return saved;
  }

  /// 묶음이 건드린 거래를 적는다. 그때의 `client_updated_at`을 함께 적어, 나중에 그 뒤로
  /// 고쳤는지를 가린다.
  Future<void> _recordItem(String batchId, String txId, String kind) async {
    final row = await ledger.transactionById(txId);
    await db
        .into(db.inputBatchItems)
        .insert(
          InputBatchItemsCompanion.insert(
            batchId: batchId,
            txId: txId,
            kind: kind,
            stamp: row!.clientUpdatedAt,
          ),
        );
  }

  /// 묶음 목록(최근 순).
  Stream<List<InputBatchRow>> watchBatches(String ledgerId) =>
      (db.select(db.inputBatches)
            ..where((b) => b.ledgerId.equals(ledgerId))
            ..orderBy([
              (b) => OrderingTerm.desc(b.createdAt),
              (b) => OrderingTerm.desc(b.id),
            ]))
          .watch();

  Future<InputBatchRow?> batchById(String batchId) => (db.select(
    db.inputBatches,
  )..where((b) => b.id.equals(batchId))).getSingleOrNull();

  /// 아직 되돌리지 않은 가장 최근 묶음. 없으면 null.
  Future<InputBatchRow?> lastUndoable(String ledgerId) =>
      (db.select(db.inputBatches)
            ..where((b) => b.ledgerId.equals(ledgerId) & b.undoneAt.isNull())
            ..orderBy([
              (b) => OrderingTerm.desc(b.createdAt),
              (b) => OrderingTerm.desc(b.id),
            ])
            ..limit(1))
          .getSingleOrNull();

  /// 묶음이 건드린 거래와 그 거래의 지금 모습.
  Stream<List<BatchItemView>> watchBatchItems(String batchId) {
    final i = db.inputBatchItems;
    final t = db.ledgerTransactions;
    final a = db.accounts;
    final toA = db.alias(db.accounts, 'to_account');
    final c = db.categories;
    final query =
        db.select(i).join([
            leftOuterJoin(t, t.id.equalsExp(i.txId)),
            leftOuterJoin(a, a.id.equalsExp(t.accountId)),
            leftOuterJoin(toA, toA.id.equalsExp(t.toAccountId)),
            leftOuterJoin(c, c.id.equalsExp(t.categoryId)),
          ])
          ..where(i.batchId.equals(batchId))
          // 거래 ID는 만든 순서대로 커진다.
          ..orderBy([OrderingTerm.asc(i.txId)]);
    return query.watch().map(
      (rows) => [
        for (final row in rows)
          BatchItemView(
            item: row.readTable(i),
            transaction: switch (row.readTableOrNull(t)) {
              null => null,
              final tx => TransactionView(
                row: tx,
                accountName: row.readTableOrNull(a)?.name ?? '(지워진 자산)',
                toAccountName: row.readTableOrNull(toA)?.name,
                categoryName: row.readTableOrNull(c)?.name,
              ),
            },
          ),
      ],
    );
  }

  /// 묶음을 되돌린다.
  ///
  /// - 묶음이 만든 거래 가운데 저장한 뒤에 고치지 않은 것(`client_updated_at`이 그때 적어
  ///   둔 값과 같은 것)을 지운다. 고친 거래는 남긴다.
  /// - 묶음이 취소로 표시한 원 거래는 아직 취소 상태면 취소를 푼다.
  /// - 이미 지워진 거래는 세지 않는다.
  ///
  /// 지우고 푸는 일은 평소의 쓰기와 같아서 대기열에 올라가 다른 기기에도 전해진다.
  /// 한 번 되돌린 묶음을 다시 되돌리려 하면 [BatchAlreadyUndone]을 던진다.
  Future<UndoResult> undo(String batchId) => db.transaction(() async {
    final batch = await batchById(batchId);
    if (batch == null) throw StateError('없는 묶음입니다: $batchId');
    if (batch.undoneAt != null) throw BatchAlreadyUndone(batchId);

    final items = await (db.select(
      db.inputBatchItems,
    )..where((i) => i.batchId.equals(batchId))).get();
    var undone = 0;
    var kept = 0;
    for (final item in items) {
      final row = await ledger.transactionById(item.txId);
      if (row == null || row.deletedAt != null) continue;
      if (item.kind == BatchItemKind.canceled) {
        if (row.canceledAt == null) continue;
        await ledger.setCanceled(row.id, canceled: false);
        undone++;
      } else if (row.clientUpdatedAt == item.stamp) {
        await ledger.deleteTransaction(row.id);
        undone++;
      } else {
        kept++;
      }
    }
    await (db.update(db.inputBatches)..where((b) => b.id.equals(batchId)))
        .write(InputBatchesCompanion(undoneAt: Value(ledger.outbox.now())));
    return UndoResult(undone: undone, kept: kept);
  });

  /// [retentionDays]일이 지난 기록을 지운다. 거래는 건드리지 않는다. 지운 묶음 수를 준다.
  Future<int> purgeExpired(String ledgerId) => db.transaction(() async {
    final cutoff = ledger.outbox
        .now()
        .subtract(const Duration(days: retentionDays))
        .toIso8601String();
    final old =
        await (db.select(db.inputBatches)..where(
              (b) =>
                  b.ledgerId.equals(ledgerId) &
                  b.createdAt.isSmallerThanValue(cutoff),
            ))
            .get();
    if (old.isEmpty) return 0;
    final ids = [for (final b in old) b.id];
    await (db.delete(
      db.inputBatchItems,
    )..where((i) => i.batchId.isIn(ids))).go();
    await (db.delete(db.inputBatches)..where((b) => b.id.isIn(ids))).go();
    return ids.length;
  });
}

final inputBatchRepositoryProvider = Provider<InputBatchRepository>(
  (ref) => InputBatchRepository(ref.watch(repositoryProvider)),
);
