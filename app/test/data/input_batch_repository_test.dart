import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gagyebu/core/local_date.dart';
import 'package:gagyebu/data/db/database.dart';
import 'package:gagyebu/data/repositories/input_batch_repository.dart';
import 'package:gagyebu/data/repositories/ledger_repository.dart';
import 'package:gagyebu/domain/enums.dart';

void main() {
  late AppDatabase db;
  late LedgerRepository ledger;
  late InputBatchRepository batches;
  late String ledgerId;
  late String cash;

  // 부를 때마다 1초씩 가는 시계. 저장한 뒤에 고친 거래는 `client_updated_at`이 달라진다.
  var now = DateTime.utc(2026, 11, 17, 3);
  DateTime tick() => now = now.add(const Duration(seconds: 1));

  setUp(() async {
    now = DateTime.utc(2026, 11, 17, 3);
    db = AppDatabase(NativeDatabase.memory());
    ledger = LedgerRepository(db, clock: tick);
    batches = InputBatchRepository(ledger);
    ledgerId = await ledger.ensureLocalLedger();
    cash = (await ledger.accounts(ledgerId)).first.id;
  });
  tearDown(() => db.close());

  TransactionInput expense(
    int amount,
    String party, {
    String? accountId,
    TxStatus status = TxStatus.confirmed,
  }) => TransactionInput(
    type: TxType.expense,
    occurredOn: LocalDate(2026, 11, 16),
    amount: amount,
    accountId: accountId ?? cash,
    counterparty: party,
    source: TxSource.paste,
    status: status,
  );

  Future<List<TxRow>> transactions() => (db.select(
    db.ledgerTransactions,
  )..orderBy([(t) => OrderingTerm.asc(t.id)])).get();

  Future<List<OutboxRow>> queued() => (db.select(
    db.outbox,
  )..where((o) => o.targetTable.equals('transactions'))).get();

  /// 서버에 올라간 것처럼 만든다: 판 번호를 올리고 대기열을 비운다.
  Future<void> markPushed() async {
    await db
        .update(db.ledgerTransactions)
        .write(const LedgerTransactionsCompanion(version: Value(1)));
    await db.delete(db.outbox).go();
  }

  group('saveBatch', () {
    test('거래를 만들고 묶음과 건마다의 기록을 남긴다', () async {
      final saved = await batches.saveBatch(ledgerId, [
        BatchCreate(expense(12500, '김밥천국')),
        BatchCreate(expense(4800, '스타벅스', status: TxStatus.needsReview)),
      ], source: TxSource.paste);

      final rows = await transactions();
      expect(rows.map((r) => r.amount), [12500, 4800]);
      expect(rows.map((r) => r.status), [
        TxStatus.confirmed,
        TxStatus.needsReview,
      ]);
      expect(saved.createdIds, rows.map((r) => r.id));
      expect(saved.itemCount, 2);

      final batch = (await batches.watchBatches(ledgerId).first).single;
      expect(batch.id, saved.batchId);
      expect(batch.source, TxSource.paste);
      expect(batch.itemCount, 2);
      expect(batch.undoneAt, isNull);

      final items = await db.select(db.inputBatchItems).get();
      expect(items, hasLength(2));
      for (final item in items) {
        expect(item.kind, BatchItemKind.created);
        final row = rows.firstWhere((r) => r.id == item.txId);
        expect(item.stamp, row.clientUpdatedAt);
      }
      // 만든 거래는 평소처럼 대기열에 올라간다.
      expect((await queued()).map((o) => o.op), ['upsert', 'upsert']);
    });

    test('중간에 실패하면 한 건도 남지 않는다', () async {
      await expectLater(
        batches.saveBatch(ledgerId, [
          BatchCreate(expense(12500, '김밥천국')),
          // 없는 자산이라 저장소가 받지 않는다.
          BatchCreate(expense(4800, '스타벅스', accountId: 'missing')),
          BatchCreate(expense(900, '편의점')),
        ], source: TxSource.paste),
        throwsArgumentError,
      );

      expect(await transactions(), isEmpty);
      expect(await queued(), isEmpty);
      expect(await db.select(db.inputBatches).get(), isEmpty);
      expect(await db.select(db.inputBatchItems).get(), isEmpty);
      // 분류 규칙도 남지 않는다.
      expect(await db.select(db.categoryRules).get(), isEmpty);
    });

    test('취소 처리 도중에 실패해도 원 거래는 그대로다', () async {
      final original = await ledger.addTransaction(
        ledgerId,
        expense(30000, '서점'),
      );
      await expectLater(
        batches.saveBatch(ledgerId, [
          BatchCancel(original),
          BatchCreate(expense(4800, '스타벅스', accountId: 'missing')),
        ], source: TxSource.paste),
        throwsArgumentError,
      );
      expect((await ledger.transactionById(original))!.canceledAt, isNull);
      expect(await db.select(db.inputBatches).get(), isEmpty);
    });

    test('빈 묶음은 받지 않는다', () {
      expect(
        batches.saveBatch(ledgerId, const [], source: TxSource.paste),
        throwsArgumentError,
      );
    });

    test('분류를 고른 건은 상대방의 분류 규칙으로 기억한다', () async {
      final food = (await ledger.categories(ledgerId))
          .firstWhere((c) => c.name == '식비')
          .id;
      await batches.saveBatch(ledgerId, [
        BatchCreate(
          TransactionInput(
            type: TxType.expense,
            occurredOn: LocalDate(2026, 11, 16),
            amount: 9000,
            accountId: cash,
            counterparty: '우리동네분식',
            categoryId: food,
            source: TxSource.nl,
          ),
        ),
      ], source: TxSource.nl);
      expect(await ledger.categoryForCounterparty(ledgerId, '우리동네분식'), food);
    });

    test('같은 원 거래를 가리키는 취소가 두 번 와도 한 번만 적는다', () async {
      final original = await ledger.addTransaction(
        ledgerId,
        expense(30000, '서점'),
      );
      final saved = await batches.saveBatch(ledgerId, [
        BatchCancel(original),
        BatchCancel(original),
      ], source: TxSource.paste);
      expect(saved.canceledIds, [original]);
      expect(saved.itemCount, 1);
      expect((await ledger.transactionById(original))!.canceledAt, isNotNull);
    });
  });

  group('undo', () {
    test('고치지 않은 것만 지우고, 고친 것은 남긴다', () async {
      final saved = await batches.saveBatch(ledgerId, [
        BatchCreate(expense(12500, '김밥천국')),
        BatchCreate(expense(4800, '스타벅스')),
        BatchCreate(expense(900, '편의점')),
      ], source: TxSource.paste);
      await markPushed();

      // 한 건을 저장한 뒤에 고친다.
      final editedId = saved.createdIds[1];
      await ledger.updateTransaction(editedId, expense(5300, '스타벅스'));

      final result = await batches.undo(saved.batchId);
      expect(result.undone, 2);
      expect(result.kept, 1);

      final rows = await transactions();
      expect(rows, hasLength(3));
      for (final row in rows) {
        expect(
          row.deletedAt == null,
          row.id == editedId,
          reason: '고친 거래만 남는다: ${row.receiver}',
        );
      }
      expect(rows.firstWhere((r) => r.id == editedId).amount, 5300);

      final batch = await batches.batchById(saved.batchId);
      expect(batch!.undoneAt, isNotNull);
    });

    test('되돌린 삭제는 대기열에 올라간다', () async {
      final saved = await batches.saveBatch(ledgerId, [
        BatchCreate(expense(12500, '김밥천국')),
        BatchCreate(expense(4800, '스타벅스')),
      ], source: TxSource.paste);
      await markPushed();
      expect(await queued(), isEmpty);

      await batches.undo(saved.batchId);

      final outbox = await queued();
      expect(outbox.map((o) => o.rowId).toSet(), saved.createdIds.toSet());
      expect(outbox.every((o) => o.op == 'delete'), isTrue);
      // 서버가 가진 판을 기준으로 지운다.
      expect(outbox.every((o) => o.baseVersion == 1), isTrue);
    });

    test('서버에 올라간 적 없는 거래는 흔적 없이 지운다', () async {
      final saved = await batches.saveBatch(ledgerId, [
        BatchCreate(expense(12500, '김밥천국')),
      ], source: TxSource.nl);

      final result = await batches.undo(saved.batchId);
      expect(result.undone, 1);
      expect(await transactions(), isEmpty);
      expect(await queued(), isEmpty);
      // 기록은 '되돌림'으로 남는다.
      final batch = (await batches.watchBatches(ledgerId).first).single;
      expect(batch.undoneAt, isNotNull);
      final items = await batches.watchBatchItems(saved.batchId).first;
      expect(items.single.isGone, isTrue);
    });

    test('묶음이 취소로 표시한 원 거래는 취소를 푼다', () async {
      final original = await ledger.addTransaction(
        ledgerId,
        expense(30000, '서점'),
      );
      await markPushed();

      final saved = await batches.saveBatch(ledgerId, [
        BatchCancel(original),
        BatchCreate(expense(4800, '스타벅스')),
      ], source: TxSource.paste);
      expect((await ledger.transactionById(original))!.canceledAt, isNotNull);
      final items = await db.select(db.inputBatchItems).get();
      expect(
        items.firstWhere((i) => i.txId == original).kind,
        BatchItemKind.canceled,
      );
      await db.delete(db.outbox).go();

      final result = await batches.undo(saved.batchId);
      expect(result.undone, 2);
      expect(result.kept, 0);

      final row = (await ledger.transactionById(original))!;
      expect(row.canceledAt, isNull);
      expect(row.deletedAt, isNull);
      // 취소를 푼 것도 다른 기기에 전해져야 한다.
      final outbox = await queued();
      expect(
        outbox.firstWhere((o) => o.rowId == original).op,
        'upsert',
        reason: '원 거래는 지우지 않고 고친다',
      );
    });

    test('사용자가 이미 취소를 푼 원 거래는 건드리지 않는다', () async {
      final original = await ledger.addTransaction(
        ledgerId,
        expense(30000, '서점'),
      );
      final saved = await batches.saveBatch(ledgerId, [
        BatchCancel(original),
      ], source: TxSource.paste);
      await ledger.setCanceled(original, canceled: false);
      final before = (await ledger.transactionById(original))!;

      final result = await batches.undo(saved.batchId);
      expect(result.undone, 0);
      expect(result.kept, 0);
      final after = (await ledger.transactionById(original))!;
      expect(after.clientUpdatedAt, before.clientUpdatedAt);
    });

    test('두 번 되돌리지 못한다', () async {
      final saved = await batches.saveBatch(ledgerId, [
        BatchCreate(expense(12500, '김밥천국')),
      ], source: TxSource.paste);
      await markPushed();
      await batches.undo(saved.batchId);
      final outboxAfterFirst = (await queued()).length;

      await expectLater(
        batches.undo(saved.batchId),
        throwsA(isA<BatchAlreadyUndone>()),
      );
      expect((await queued()).length, outboxAfterFirst);
      expect(await batches.lastUndoable(ledgerId), isNull);
    });

    test('없는 묶음은 되돌리지 못한다', () {
      expect(batches.undo('nope'), throwsStateError);
    });

    test('사용자가 이미 지운 거래는 세지 않는다', () async {
      final saved = await batches.saveBatch(ledgerId, [
        BatchCreate(expense(12500, '김밥천국')),
        BatchCreate(expense(4800, '스타벅스')),
      ], source: TxSource.paste);
      await markPushed();
      await ledger.deleteTransaction(saved.createdIds.first);

      final result = await batches.undo(saved.batchId);
      expect(result.undone, 1);
      expect(result.kept, 0);
    });
  });

  group('기록 보기', () {
    test('묶음은 최근 순이고, 마지막으로 되돌릴 수 있는 묶음을 찾는다', () async {
      final first = await batches.saveBatch(ledgerId, [
        BatchCreate(expense(1000, '가')),
      ], source: TxSource.nl);
      final second = await batches.saveBatch(ledgerId, [
        BatchCreate(expense(2000, '나')),
      ], source: TxSource.paste);

      final list = await batches.watchBatches(ledgerId).first;
      expect(list.map((b) => b.id), [second.batchId, first.batchId]);
      expect((await batches.lastUndoable(ledgerId))!.id, second.batchId);

      await batches.undo(second.batchId);
      expect((await batches.lastUndoable(ledgerId))!.id, first.batchId);
    });

    test('묶음의 거래를 지금 모습으로 보여 주고, 고친 건을 가린다', () async {
      final saved = await batches.saveBatch(ledgerId, [
        BatchCreate(expense(12500, '김밥천국')),
        BatchCreate(expense(4800, '스타벅스')),
      ], source: TxSource.paste);
      await ledger.updateTransaction(
        saved.createdIds[1],
        expense(5300, '스타벅스'),
      );

      final items = await batches.watchBatchItems(saved.batchId).first;
      expect(items.map((i) => i.transaction!.row.amount), [12500, 5300]);
      expect(items.map((i) => i.isEdited), [false, true]);
      expect(items.first.transaction!.accountName, '현금');
    });

    test('90일이 지난 기록은 지운다. 거래는 그대로 둔다', () async {
      final old = await batches.saveBatch(ledgerId, [
        BatchCreate(expense(1000, '가')),
      ], source: TxSource.nl);
      now = now.add(const Duration(days: 91));
      final recent = await batches.saveBatch(ledgerId, [
        BatchCreate(expense(2000, '나')),
      ], source: TxSource.nl);

      final list = await batches.watchBatches(ledgerId).first;
      expect(list.map((b) => b.id), [recent.batchId]);
      final items = await db.select(db.inputBatchItems).get();
      expect(items.map((i) => i.batchId).toSet(), {recent.batchId});
      expect(await batches.batchById(old.batchId), isNull);
      expect(await transactions(), hasLength(2));
    });
  });
}
