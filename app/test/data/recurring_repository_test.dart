import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gagyebu/core/local_date.dart';
import 'package:gagyebu/data/db/database.dart';
import 'package:gagyebu/data/repositories/ledger_repository.dart';
import 'package:gagyebu/data/repositories/recurring_repository.dart';
import 'package:gagyebu/domain/enums.dart';

void main() {
  late AppDatabase db;
  late LedgerRepository ledger;
  late RecurringRepository recurring;
  late String ledgerId;
  late String cash;
  late String rent;
  var now = DateTime.utc(2026, 11, 17, 3);

  setUp(() async {
    now = DateTime.utc(2026, 11, 17, 3);
    db = AppDatabase(NativeDatabase.memory());
    ledger = LedgerRepository(db, clock: () => now);
    recurring = RecurringRepository(ledger);
    ledgerId = await ledger.ensureLocalLedger();
    cash = (await ledger.accounts(ledgerId)).single.id;
    rent = (await ledger.categories(ledgerId))
        .firstWhere((c) => c.name == '주거·통신')
        .id;
  });
  tearDown(() => db.close());

  RecurringRuleInput input(
    String nextRunOn, {
    RecurringFrequency frequency = RecurringFrequency.monthly,
    int interval = 1,
    String? endOn,
    bool autoPost = false,
    bool isActive = true,
    int amount = 500000,
    TxType type = TxType.expense,
    String? toAccountId,
  }) => RecurringRuleInput(
    template: RecurringTemplate(
      type: type,
      amount: amount,
      accountId: cash,
      toAccountId: toAccountId,
      counterparty: '집주인',
      categoryId: rent,
      memo: '월세',
    ),
    frequency: frequency,
    intervalCount: interval,
    nextRunOn: LocalDate.parse(nextRunOn),
    endOn: endOn == null ? null : LocalDate.parse(endOn),
    autoPost: autoPost,
    isActive: isActive,
  );

  Future<RecurringRuleRow> rule(String id) =>
      (db.select(db.recurringRules)..where((r) => r.id.equals(id))).getSingle();

  Future<List<TxRow>> made() =>
      (db.select(db.ledgerTransactions)
            ..where((t) => t.deletedAt.isNull())
            ..orderBy([(t) => OrderingTerm.asc(t.occurredOn)]))
          .get();

  Future<List<String>> madeDates() async => [
    for (final tx in await made()) tx.occurredOn.toString(),
  ];

  Future<List<OutboxRow>> queued(String table) =>
      (db.select(db.outbox)..where((o) => o.targetTable.equals(table))).get();

  group('규칙의 추가 · 수정 · 삭제', () {
    test('틀을 7.13의 키로 저장하고 대기열에 올린다', () async {
      final id = await recurring.addRule(ledgerId, input('2026-11-25'));

      final saved = await rule(id);
      expect(saved.template, {
        'type': 'expense',
        'amount': 500000,
        'account_id': cash,
        'to_account_id': null,
        'counterparty': '집주인',
        'category_id': rent,
        'memo': '월세',
        'anchor_day': 25,
      });
      expect(saved.frequency, 'monthly');
      expect(saved.intervalCount, 1);
      expect(saved.nextRunOn, LocalDate(2026, 11, 25));
      expect(saved.autoPost, isFalse);
      expect(saved.isActive, isTrue);
      expect(saved.clientUpdatedAt, now);

      final entry = (await queued('recurring_rules')).single;
      expect(entry.rowId, id);
      expect(entry.op, 'upsert');
      expect(entry.baseVersion, 0);
      expect((await recurring.watchRules(ledgerId).first).single.id, id);
    });

    test('고치고 끄면 그 행의 판 번호로 올라간다', () async {
      final id = await recurring.addRule(ledgerId, input('2026-11-25'));
      await (db.update(db.recurringRules)..where((r) => r.id.equals(id))).write(
        const RecurringRulesCompanion(version: Value(5)),
      );
      await db.delete(db.outbox).go();

      now = DateTime.utc(2026, 11, 18);
      await recurring.updateRule(
        id,
        input(
          '2026-12-01',
          frequency: RecurringFrequency.weekly,
          interval: 2,
          endOn: '2027-06-30',
          autoPost: true,
          amount: 30000,
        ),
      );
      var saved = await rule(id);
      expect(saved.frequency, 'weekly');
      expect(saved.intervalCount, 2);
      expect(saved.nextRunOn, LocalDate(2026, 12, 1));
      expect(saved.endOn, LocalDate(2027, 6, 30));
      expect(saved.autoPost, isTrue);
      expect(saved.template['amount'], 30000);
      expect(saved.template.containsKey('anchor_day'), isFalse);
      expect(saved.clientUpdatedAt, now);
      expect((await queued('recurring_rules')).single.baseVersion, 5);

      await recurring.setActive(id, active: false);
      saved = await rule(id);
      expect(saved.isActive, isFalse);
      expect(await queued('recurring_rules'), hasLength(1));

      await recurring.deleteRule(id);
      expect((await rule(id)).deletedAt, isNotNull);
      expect((await queued('recurring_rules')).single.op, 'delete');
      expect(await recurring.rules(ledgerId), isEmpty);
    });

    test('금액 · 간격 · 이체의 받는 자산을 확인한다', () async {
      await expectLater(
        recurring.addRule(ledgerId, input('2026-11-25', amount: 0)),
        throwsArgumentError,
      );
      await expectLater(
        recurring.addRule(ledgerId, input('2026-11-25', interval: 0)),
        throwsArgumentError,
      );
      await expectLater(
        recurring.addRule(ledgerId, input('2026-11-25', type: TxType.transfer)),
        throwsArgumentError,
      );
      await expectLater(
        recurring.addRule(
          ledgerId,
          input('2026-11-25', type: TxType.transfer, toAccountId: cash),
        ),
        throwsArgumentError,
      );
      expect(await queued('recurring_rules'), isEmpty);
    });
  });

  group('runDue', () {
    test('밀린 날짜만큼 거래를 만들고 다음 날짜를 옮긴다', () async {
      final id = await recurring.addRule(ledgerId, input('2026-08-25'));
      await (db.update(db.recurringRules)..where((r) => r.id.equals(id))).write(
        const RecurringRulesCompanion(version: Value(2)),
      );
      await db.delete(db.outbox).go();

      final created = await recurring.runDue(ledgerId, LocalDate(2026, 11, 17));

      expect(created, 3);
      expect(await madeDates(), ['2026-08-25', '2026-09-25', '2026-10-25']);
      expect((await rule(id)).nextRunOn, LocalDate(2026, 11, 25));

      final tx = (await made()).first;
      expect(tx.id, RecurringRepository.transactionIdFor(id, tx.occurredOn));
      expect(tx.type, TxType.expense);
      expect(tx.amount, 500000);
      expect(tx.accountId, cash);
      expect(tx.receiver, '집주인');
      expect(tx.categoryId, rent);
      expect(tx.memo, '월세');
      expect(tx.source, TxSource.recurring);
      expect(tx.status, TxStatus.needsReview);

      expect(await queued('transactions'), hasLength(3));
      final ruleEntry = (await queued('recurring_rules')).single;
      expect(ruleEntry.op, 'upsert');
      expect(ruleEntry.baseVersion, 2);
    });

    test('다음 날짜가 오늘이면 만들고, 내일이면 만들지 않는다', () async {
      await recurring.addRule(ledgerId, input('2026-11-17'));
      await recurring.addRule(ledgerId, input('2026-11-18', amount: 1));
      expect(await recurring.runDue(ledgerId, LocalDate(2026, 11, 17)), 1);
      expect((await made()).single.amount, 500000);
    });

    test('자동 등록이면 확정된 거래로 만든다', () async {
      await recurring.addRule(ledgerId, input('2026-11-10', autoPost: true));
      await recurring.runDue(ledgerId, LocalDate(2026, 11, 17));
      final tx = (await made()).single;
      expect(tx.status, TxStatus.confirmed);
      expect(tx.source, TxSource.recurring);
    });

    test('두 번 돌려도 늘지 않는다', () async {
      final id = await recurring.addRule(ledgerId, input('2026-09-25'));
      expect(await recurring.runDue(ledgerId, LocalDate(2026, 11, 17)), 2);
      expect(await recurring.runDue(ledgerId, LocalDate(2026, 11, 17)), 0);
      expect(await made(), hasLength(2));

      // 다른 기기가 먼저 만든 뒤 규칙의 옛 날짜를 받은 경우: 같은 ID라 다시 만들지 않는다.
      await (db.update(db.recurringRules)..where((r) => r.id.equals(id))).write(
        RecurringRulesCompanion(nextRunOn: Value(LocalDate(2026, 9, 25))),
      );
      expect(await recurring.runDue(ledgerId, LocalDate(2026, 11, 17)), 0);
      expect(await made(), hasLength(2));
      expect((await rule(id)).nextRunOn, LocalDate(2026, 11, 25));
    });

    test('만든 거래를 지워도 다시 만들지 않는다', () async {
      final id = await recurring.addRule(ledgerId, input('2026-10-25'));
      await recurring.runDue(ledgerId, LocalDate(2026, 11, 17));
      final tx = (await made()).single;
      // 서버에 올라간 거래를 지운 경우(삭제 표시만 남는다).
      await (db.update(db.ledgerTransactions)..where((t) => t.id.equals(tx.id)))
          .write(const LedgerTransactionsCompanion(version: Value(1)));
      await ledger.deleteTransaction(tx.id);
      await (db.update(db.recurringRules)..where((r) => r.id.equals(id))).write(
        RecurringRulesCompanion(nextRunOn: Value(LocalDate(2026, 10, 25))),
      );

      expect(await recurring.runDue(ledgerId, LocalDate(2026, 11, 17)), 0);
      expect(await made(), isEmpty);
    });

    test('두 기기가 같은 날짜를 만들면 같은 ID가 된다', () async {
      const ruleId = '0193a5b0-0000-7000-8000-000000000001';
      final a = RecurringRepository.transactionIdFor(
        ruleId,
        LocalDate(2026, 11, 25),
      );
      final b = RecurringRepository.transactionIdFor(
        ruleId,
        LocalDate(2026, 11, 25),
      );
      expect(a, b);
      // 서버의 uuid 열에 들어가는 UUIDv5 꼴이다.
      expect(
        a,
        matches(
          RegExp(
            r'^[0-9a-f]{8}-[0-9a-f]{4}-5[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
          ),
        ),
      );
      // 이름 공간이 바뀌면 이미 만든 거래와 ID가 어긋난다. 값을 고정해 둔다.
      expect(a, '4d2be4c5-5e86-50e0-b265-52f2ab16f91c');
      expect(
        RecurringRepository.transactionIdFor(ruleId, LocalDate(2026, 12, 25)),
        isNot(a),
      );
      expect(
        RecurringRepository.transactionIdFor('other', LocalDate(2026, 11, 25)),
        isNot(a),
      );
    });

    test('매달 31일은 그 달의 마지막 날로 당기고, 긴 달에는 31일로 돌아간다', () async {
      final id = await recurring.addRule(ledgerId, input('2027-01-31'));
      expect(await recurring.runDue(ledgerId, LocalDate(2027, 5, 1)), 4);
      expect(await madeDates(), [
        '2027-01-31',
        '2027-02-28',
        '2027-03-31',
        '2027-04-30',
      ]);
      expect((await rule(id)).nextRunOn, LocalDate(2027, 5, 31));
    });

    test('매년 2월 29일은 평년에 28일로 당긴다', () async {
      final id = await recurring.addRule(
        ledgerId,
        input('2028-02-29', frequency: RecurringFrequency.yearly),
      );
      expect(await recurring.runDue(ledgerId, LocalDate(2032, 3, 1)), 5);
      expect(await madeDates(), [
        '2028-02-29',
        '2029-02-28',
        '2030-02-28',
        '2031-02-28',
        '2032-02-29',
      ]);
      expect((await rule(id)).nextRunOn, LocalDate(2033, 2, 28));
    });

    test('매주와 간격', () async {
      final id = await recurring.addRule(
        ledgerId,
        input('2026-10-20', frequency: RecurringFrequency.weekly, interval: 2),
      );
      expect(await recurring.runDue(ledgerId, LocalDate(2026, 11, 17)), 3);
      expect(await madeDates(), ['2026-10-20', '2026-11-03', '2026-11-17']);
      expect((await rule(id)).nextRunOn, LocalDate(2026, 12, 1));
    });

    test('한 번에 24건까지만 만들고 남은 것은 다음에 이어서 만든다', () async {
      // 매주 규칙을 30주 묵혔다.
      final start = LocalDate(2026, 11, 17).addDays(-7 * 29);
      final id = await recurring.addRule(
        ledgerId,
        input('$start', frequency: RecurringFrequency.weekly),
      );
      final today = LocalDate(2026, 11, 17);

      expect(await recurring.runDue(ledgerId, today), 24);
      expect(await made(), hasLength(24));
      expect((await rule(id)).nextRunOn, start.addDays(7 * 24));

      expect(await recurring.runDue(ledgerId, today), 6);
      expect(await made(), hasLength(30));
      expect((await rule(id)).nextRunOn, today.addDays(7));
      expect(await recurring.runDue(ledgerId, today), 0);
    });

    test('24건의 한도는 규칙을 모두 합친 수다', () async {
      final today = LocalDate(2026, 11, 17);
      for (var i = 0; i < 3; i++) {
        await recurring.addRule(
          ledgerId,
          input(
            '${today.addDays(-7 * 9 - i)}',
            frequency: RecurringFrequency.weekly,
            amount: 1000 + i,
          ),
        );
      }
      expect(await recurring.runDue(ledgerId, today), 24);
      expect(await recurring.runDue(ledgerId, today), 6);
      expect(await made(), hasLength(30));
    });

    test('끝나는 날 뒤로는 만들지 않는다', () async {
      final id = await recurring.addRule(
        ledgerId,
        input('2026-08-25', endOn: '2026-09-25'),
      );
      expect(await recurring.runDue(ledgerId, LocalDate(2026, 11, 17)), 2);
      expect(await madeDates(), ['2026-08-25', '2026-09-25']);
      expect((await rule(id)).nextRunOn, LocalDate(2026, 10, 25));
      expect(await recurring.runDue(ledgerId, LocalDate(2026, 12, 17)), 0);
    });

    test('꺼 둔 규칙과 지운 규칙은 돌지 않는다', () async {
      final off = await recurring.addRule(
        ledgerId,
        input('2026-10-25', isActive: false),
      );
      final gone = await recurring.addRule(ledgerId, input('2026-10-25'));
      await recurring.deleteRule(gone);
      expect(await recurring.runDue(ledgerId, LocalDate(2026, 11, 17)), 0);
      expect((await rule(off)).nextRunOn, LocalDate(2026, 10, 25));

      // 다시 켜면 밀린 것부터 만든다.
      await recurring.setActive(off, active: true);
      expect(await recurring.runDue(ledgerId, LocalDate(2026, 11, 17)), 1);
    });

    test('자산이 지워진 규칙은 건너뛰고 날짜를 그대로 둔다', () async {
      final bank = await ledger.addAccount(
        ledgerId: ledgerId,
        name: '통장',
        kind: AccountKind.bank,
      );
      final id = await recurring.addRule(
        ledgerId,
        RecurringRuleInput(
          template: RecurringTemplate(
            type: TxType.expense,
            amount: 9900,
            accountId: bank,
          ),
          frequency: RecurringFrequency.monthly,
          nextRunOn: LocalDate(2026, 10, 25),
        ),
      );
      await ledger.deleteAccount(bank);
      final ok = await recurring.addRule(ledgerId, input('2026-11-01'));

      expect(await recurring.runDue(ledgerId, LocalDate(2026, 11, 17)), 1);
      expect((await rule(id)).nextRunOn, LocalDate(2026, 10, 25));
      expect((await rule(ok)).nextRunOn, LocalDate(2026, 12, 1));
    });

    test('이체 규칙은 이체 거래를, 지워진 분류는 분류 없음으로 만든다', () async {
      final bank = await ledger.addAccount(
        ledgerId: ledgerId,
        name: '적금',
        kind: AccountKind.bank,
      );
      await recurring.addRule(
        ledgerId,
        input('2026-11-05', type: TxType.transfer, toAccountId: bank),
      );
      await recurring.addRule(ledgerId, input('2026-11-10', amount: 7000));
      await ledger.deleteCategory(rent);

      expect(await recurring.runDue(ledgerId, LocalDate(2026, 11, 17)), 2);
      final rows = await made();
      expect(rows[0].type, TxType.transfer);
      expect(rows[0].toAccountId, bank);
      expect(rows[0].categoryId, isNull);
      expect(rows[1].amount, 7000);
      expect(rows[1].categoryId, isNull);
    });
  });

  group('nextRecurrence', () {
    test('고른 날이 없으면 지금 날짜의 날을 쓴다', () {
      expect(
        nextRecurrence(LocalDate(2027, 1, 31), RecurringFrequency.monthly, 1),
        LocalDate(2027, 2, 28),
      );
      expect(
        nextRecurrence(LocalDate(2027, 2, 28), RecurringFrequency.monthly, 1),
        LocalDate(2027, 3, 28),
      );
      expect(
        nextRecurrence(
          LocalDate(2027, 2, 28),
          RecurringFrequency.monthly,
          1,
          anchorDay: 31,
        ),
        LocalDate(2027, 3, 31),
      );
      expect(
        nextRecurrence(LocalDate(2026, 11, 30), RecurringFrequency.monthly, 3),
        LocalDate(2027, 2, 28),
      );
    });
  });

  test('읽을 수 없는 틀은 null이고 규칙은 건너뛴다', () async {
    expect(RecurringTemplate.tryParse({'type': 'expense'}), isNull);
    expect(
      RecurringTemplate.tryParse({'amount': 1, 'account_id': 'a'}),
      isNull,
    );
    final id = await recurring.addRule(ledgerId, input('2026-10-25'));
    await (db.update(db.recurringRules)..where((r) => r.id.equals(id))).write(
      const RecurringRulesCompanion(template: Value({'type': 'weird'})),
    );
    expect(await recurring.runDue(ledgerId, LocalDate(2026, 11, 17)), 0);
  });
}
