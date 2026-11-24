import 'package:drift/drift.dart' show OrderingTerm;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gagyebu/core/local_date.dart';
import 'package:gagyebu/data/db/database.dart';
import 'package:gagyebu/data/repositories/conflict_repository.dart';
import 'package:gagyebu/data/repositories/ledger_repository.dart';
import 'package:gagyebu/domain/enums.dart';

void main() {
  final now = DateTime.utc(2026, 11, 17, 3);
  late AppDatabase db;
  late LedgerRepository ledger;
  late ConflictRepository conflicts;
  late String ledgerId;
  late String cash;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    ledger = LedgerRepository(db, clock: () => now);
    conflicts = ConflictRepository(db, ledger, clock: () => now);
    ledgerId = await ledger.ensureLocalLedger();
    cash = (await ledger.accounts(ledgerId)).single.id;
  });
  tearDown(() => db.close());

  Future<int> record({
    String table = 'transactions',
    required String rowId,
    required Map<String, Object?> loser,
    String side = 'local',
    DateTime? at,
  }) => db
      .into(db.syncConflicts)
      .insert(
        SyncConflictsCompanion.insert(
          ledgerId: ledgerId,
          targetTable: table,
          rowId: rowId,
          loser: loser,
          loserSide: side,
          detectedAt: at ?? now,
        ),
      );

  Future<String> addLunch({int amount = 8000, String party = '김밥천국'}) =>
      ledger.addTransaction(
        ledgerId,
        TransactionInput(
          type: TxType.expense,
          occurredOn: LocalDate(2026, 11, 16),
          amount: amount,
          accountId: cash,
          counterparty: party,
        ),
      );

  /// 기기가 올리다 진 값(push용 JSON)의 꼴.
  Map<String, Object?> localLoser({int amount = 12000, String? memo}) => {
    'type': 'expense',
    'occurred_on': '2026-11-15',
    'occurred_time': '12:30',
    'amount': amount,
    'currency': null,
    'original_amount': null,
    'account_id': cash,
    'to_account_id': null,
    'sender': '현금',
    'receiver': '김밥천국 본점',
    'category_id': null,
    'memo': memo,
    'tags': <String>[],
    'installment_months': null,
    'balance_after': null,
    'canceled_at': null,
    'source': 'manual',
    'ai_model': null,
    'status': 'confirmed',
    'dedup_key': '2026-11-15|$amount|김밥천국본점',
  };

  Future<List<SyncConflictRow>> stored() => (db.select(
    db.syncConflicts,
  )..orderBy([(c) => OrderingTerm.asc(c.seq)])).get();

  group('정리', () {
    test('30일이 지난 기록을 지운다', () async {
      await record(
        rowId: 'old',
        loser: {'deleted': true},
        at: now.subtract(const Duration(days: 31)),
      );
      await record(
        rowId: 'edge',
        loser: {'deleted': true},
        at: now.subtract(const Duration(days: 29, hours: 23)),
      );
      await record(rowId: 'new', loser: {'deleted': true});

      expect(await conflicts.pruneConflicts(), 1);
      expect([for (final c in await stored()) c.rowId], ['edge', 'new']);
    });

    test('200건을 넘으면 오래된 것부터 지운다', () async {
      for (var i = 0; i < 205; i++) {
        await record(rowId: 'row-$i', loser: {'deleted': true});
      }
      expect(await conflicts.pruneConflicts(), 5);
      final left = await stored();
      expect(left, hasLength(ConflictRepository.maxCount));
      expect(left.first.rowId, 'row-5');
      expect(left.last.rowId, 'row-204');
      // 다시 돌려도 더 지우지 않는다.
      expect(await conflicts.pruneConflicts(), 0);
    });
  });

  group('조회', () {
    test('진 값과 지금 값이 다른 칸만 알려 준다', () async {
      final id = await addLunch();
      await record(
        rowId: id,
        loser: localLoser(memo: '둘이서'),
      );

      final view = (await conflicts.watchConflicts(ledgerId).first).single;
      expect(view.localLost, isTrue);
      expect(view.canRestore, isTrue);
      expect(view.loserIsDeletion, isFalse);
      final changed = {for (final f in view.changed) f.column: f};
      expect(
        changed.keys,
        unorderedEquals([
          'occurred_on',
          'occurred_time',
          'amount',
          'receiver',
          'memo',
        ]),
      );
      expect(changed['amount']!.loser, 12000);
      expect(changed['amount']!.current, 8000);
      expect(changed['receiver']!.current, '김밥천국');
    });

    test('서버가 준 행(시각에 초가 붙는다)도 같은 표기로 견준다', () async {
      final id = await addLunch();
      await ledger.updateTransaction(
        id,
        TransactionInput(
          type: TxType.expense,
          occurredOn: LocalDate(2026, 11, 16),
          occurredTime: '12:30',
          amount: 8000,
          accountId: cash,
          counterparty: '김밥천국',
        ),
      );
      await record(
        rowId: id,
        side: 'remote',
        loser: {
          ...localLoser(amount: 8000),
          'id': id,
          'ledger_id': ledgerId,
          'occurred_on': '2026-11-16',
          'occurred_time': '12:30:00',
          'receiver': '김밥천국',
          'version': 3,
          'server_seq': 40,
          'client_updated_at': '2026-11-16T03:00:00+00:00',
          'created_at': '2026-11-16T03:00:00+00:00',
          'updated_at': '2026-11-16T03:00:00+00:00',
          'deleted_at': null,
          'counterparty': '김밥천국',
        },
      );

      final view = (await conflicts.watchConflicts(ledgerId).first).single;
      expect(view.localLost, isFalse);
      expect(view.changed, isEmpty);
    });

    test('다른 가계부의 기록은 주지 않고, 거래가 아닌 표는 되살릴 수 없다고 알린다', () async {
      await record(
        table: 'accounts',
        rowId: cash,
        loser: {'name': '지갑', 'kind': 'cash'},
      );
      await db
          .into(db.syncConflicts)
          .insert(
            SyncConflictsCompanion.insert(
              ledgerId: 'other-ledger',
              targetTable: 'transactions',
              rowId: 'x',
              loser: {'deleted': true},
              loserSide: 'local',
              detectedAt: now,
            ),
          );

      final view = (await conflicts.watchConflicts(ledgerId).first).single;
      expect(view.row.targetTable, 'accounts');
      expect(view.canRestore, isFalse);
      expect(view.changed.single.column, 'name');
      expect(view.changed.single.current, '현금');
    });

    test('기기의 삭제가 졌으면 삭제였다고 알린다', () async {
      final id = await addLunch();
      await record(rowId: id, loser: {'deleted': true});
      final view = (await conflicts.watchConflicts(ledgerId).first).single;
      expect(view.loserIsDeletion, isTrue);
      expect(view.changed, isEmpty);
      expect(view.current, isNotNull);
    });
  });

  group('되살리기', () {
    test('진 값으로 거래를 다시 쓰고 대기열에 올린 뒤 기록을 지운다', () async {
      final id = await addLunch();
      // 서버에 올라간 적이 있는 행으로 만든다.
      await db.customStatement(
        'UPDATE transactions SET version = 4 WHERE id = ?',
        [id],
      );
      await db.delete(db.outbox).go();
      final seq = await record(
        rowId: id,
        loser: localLoser(memo: '둘이서'),
      );
      final conflict = (await stored()).single;
      expect(conflict.seq, seq);

      await conflicts.restore(conflict);

      final tx = (await ledger.transactionById(id))!;
      expect(tx.amount, 12000);
      expect(tx.occurredOn, LocalDate(2026, 11, 15));
      expect(tx.occurredTime, '12:30');
      expect(tx.receiver, '김밥천국 본점');
      expect(tx.memo, '둘이서');
      final queued = (await db.select(db.outbox).get()).single;
      expect(queued.targetTable, 'transactions');
      expect(queued.rowId, id);
      expect(queued.op, 'upsert');
      expect(queued.baseVersion, 4);
      expect(await stored(), isEmpty);
    });

    test('지워져 있는 거래는 삭제 표시를 풀고 되살린다', () async {
      final id = await addLunch();
      await db.customStatement(
        'UPDATE transactions SET version = 4 WHERE id = ?',
        [id],
      );
      await ledger.deleteTransaction(id);
      expect((await ledger.transactionById(id))!.deletedAt, isNotNull);
      await record(rowId: id, loser: localLoser());

      await conflicts.restore((await stored()).single);

      final tx = (await ledger.transactionById(id))!;
      expect(tx.deletedAt, isNull);
      expect(tx.amount, 12000);
      final queued = (await db.select(db.outbox).get()).single;
      expect(queued.op, 'upsert');
    });

    test('기기에 없는 거래는 같은 ID로 다시 만든다', () async {
      await record(rowId: 'gone-row', loser: localLoser());
      await conflicts.restore((await stored()).single);
      final tx = (await ledger.transactionById('gone-row'))!;
      expect(tx.ledgerId, ledgerId);
      expect(tx.amount, 12000);
    });

    test('서버가 준 행에서도 되살린다(시각의 초를 뗀다)', () async {
      final id = await addLunch();
      await record(
        rowId: id,
        side: 'remote',
        loser: {
          ...localLoser(),
          'id': id,
          'ledger_id': ledgerId,
          'occurred_time': '08:05:00',
          'version': 2,
          'deleted_at': null,
        },
      );
      await conflicts.restore((await stored()).single);
      expect((await ledger.transactionById(id))!.occurredTime, '08:05');
    });

    test('진 쪽이 삭제였으면 그 거래를 다시 지운다', () async {
      final id = await addLunch();
      await record(rowId: id, loser: {'deleted': true});
      await conflicts.restore((await stored()).single);
      // 서버에 올라간 적 없는 행이라 흔적 없이 지워진다.
      expect(await ledger.transactionById(id), isNull);
      expect(await stored(), isEmpty);
    });

    test('거래가 아닌 표의 기록은 되살리지 않고 남긴다', () async {
      await record(table: 'accounts', rowId: cash, loser: {'name': '지갑'});
      await expectLater(
        conflicts.restore((await stored()).single),
        throwsUnsupportedError,
      );
      expect(await stored(), hasLength(1));
    });

    test('쓰던 자산이 지워졌으면 되살리지 못하고, 아무것도 바꾸지 않는다', () async {
      final id = await addLunch();
      await db.delete(db.outbox).go();
      await record(
        rowId: id,
        loser: {...localLoser(), 'account_id': 'no-such-account'},
      );
      await expectLater(
        conflicts.restore((await stored()).single),
        throwsArgumentError,
      );
      expect((await ledger.transactionById(id))!.amount, 8000);
      expect(await db.select(db.outbox).get(), isEmpty);
      expect(await stored(), hasLength(1));
    });

    test('꼭 있어야 하는 값이 빠진 기록은 읽지 못한다고 알린다', () {
      expect(
        () => ConflictRepository.transactionInputFromLoser({
          'type': 'expense',
          'amount': 1000,
        }),
        throwsFormatException,
      );
    });
  });

  test('기록 한 건을 지워도 거래는 그대로다', () async {
    final id = await addLunch();
    final seq = await record(rowId: id, loser: localLoser());
    await conflicts.deleteConflict(seq);
    expect(await stored(), isEmpty);
    expect((await ledger.transactionById(id))!.amount, 8000);
  });
}
