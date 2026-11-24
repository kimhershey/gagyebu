import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gagyebu/data/db/database.dart';
import 'package:gagyebu/data/repositories/account_repository.dart';
import 'package:gagyebu/data/repositories/ledger_repository.dart';
import 'package:gagyebu/domain/enums.dart';

void main() {
  late AppDatabase db;
  late LedgerRepository ledger;
  late AccountRepository accounts;
  late String ledgerId;
  var now = DateTime.utc(2026, 11, 17, 3);

  setUp(() async {
    now = DateTime.utc(2026, 11, 17, 3);
    db = AppDatabase(NativeDatabase.memory());
    ledger = LedgerRepository(db, clock: () => now);
    accounts = AccountRepository(db, ledger.outbox);
    ledgerId = await ledger.ensureLocalLedger();
  });
  tearDown(() => db.close());

  Future<AccountRow> row(String id) =>
      (db.select(db.accounts)..where((a) => a.id.equals(id))).getSingle();

  Future<List<OutboxRow>> queued() => (db.select(
    db.outbox,
  )..where((o) => o.targetTable.equals('accounts'))).get();

  /// 서버에 올라간 적이 있는 행처럼 만든다: 판 번호를 주고 대기열을 비운다.
  Future<void> markSynced(String id, int version) async {
    await (db.update(db.accounts)..where((a) => a.id.equals(id))).write(
      AccountsCompanion(version: Value(version)),
    );
    await db.delete(db.outbox).go();
  }

  Future<String> add(String name, {AccountKind kind = AccountKind.bank}) =>
      ledger.addAccount(ledgerId: ledgerId, name: name, kind: kind);

  group('updateAccount', () {
    test('고친 값이 저장되고, 그 행의 지금 판 번호로 대기열에 올라간다', () async {
      final bank = await add('월급 통장');
      final card = await add('신한카드', kind: AccountKind.creditCard);
      await markSynced(card, 4);

      now = DateTime.utc(2026, 11, 18, 9);
      await accounts.updateAccount(
        card,
        name: ' 신한 Deep Dream ',
        kind: AccountKind.creditCard,
        institution: '신한카드',
        matchHints: ['신한', ' 1234 ', ''],
        openingBalance: -50000,
        billingDay: 25,
        paymentAccountId: bank,
      );

      final saved = await row(card);
      expect(saved.name, '신한 Deep Dream');
      expect(saved.institution, '신한카드');
      expect(saved.matchHints, ['신한', '1234']);
      expect(saved.openingBalance, -50000);
      expect(saved.billingDay, 25);
      expect(saved.paymentAccountId, bank);
      expect(saved.clientUpdatedAt, now);
      expect(saved.updatedAt, now);

      final entry = (await queued()).single;
      expect(entry.rowId, card);
      expect(entry.op, 'upsert');
      expect(entry.baseVersion, 4);
      expect(entry.clientUpdatedAt, now);
    });

    test('카드가 아닌 종류로 바꾸면 결제일과 결제 계좌를 비운다', () async {
      final bank = await add('월급 통장');
      final card = await add('카드', kind: AccountKind.creditCard);
      await accounts.updateAccount(
        card,
        name: '카드',
        kind: AccountKind.creditCard,
        billingDay: 14,
        paymentAccountId: bank,
      );
      await accounts.updateAccount(
        card,
        name: '카드',
        kind: AccountKind.checkCard,
        billingDay: 14,
        paymentAccountId: bank,
      );
      var saved = await row(card);
      expect(saved.billingDay, isNull, reason: '체크카드에는 결제일이 없다');
      expect(saved.paymentAccountId, bank);

      await accounts.updateAccount(
        card,
        name: '카드',
        kind: AccountKind.pay,
        billingDay: 14,
        paymentAccountId: bank,
      );
      saved = await row(card);
      expect(saved.billingDay, isNull);
      expect(saved.paymentAccountId, isNull);
    });

    test('빈 이름 · 범위를 벗어난 결제일 · 자기 자신 · 없는 자산은 받지 않는다', () async {
      final card = await add('카드', kind: AccountKind.creditCard);
      await db.delete(db.outbox).go();
      Future<void> update({
        String name = '카드',
        int? billingDay,
        String? payment,
        String? id,
      }) => accounts.updateAccount(
        id ?? card,
        name: name,
        kind: AccountKind.creditCard,
        billingDay: billingDay,
        paymentAccountId: payment,
      );
      await expectLater(update(name: '  '), throwsArgumentError);
      await expectLater(update(billingDay: 0), throwsArgumentError);
      await expectLater(update(billingDay: 32), throwsArgumentError);
      await expectLater(update(payment: card), throwsArgumentError);
      await expectLater(update(id: 'missing'), throwsStateError);
      expect(await queued(), isEmpty);
    });
  });

  group('reorderAccounts', () {
    test('한 줄을 옮기면 그 줄만 가운데 값으로 고쳐 올린다', () async {
      final a = await add('가');
      final b = await add('나');
      final c = await add('다');
      final orders = {
        for (final id in [a, b, c]) id: (await row(id)).sortOrder,
      };
      expect(orders[b]! - orders[a]!, 10);
      await markSynced(c, 2);

      // 다를 가와 나 사이로
      final changed = await accounts.reorderAccounts(ledgerId, [a, c, b]);
      expect(changed, 1);
      expect((await row(c)).sortOrder, orders[a]! + 5);
      expect((await row(a)).sortOrder, orders[a]);
      expect((await row(b)).sortOrder, orders[b]);

      final entry = (await queued()).single;
      expect(entry.rowId, c);
      expect(entry.baseVersion, 2);

      final names = [
        for (final account in await ledger.accounts(ledgerId))
          if (account.kind == AccountKind.bank) account.name,
      ];
      expect(names, ['가', '다', '나']);
    });

    test('맨 뒤로 옮기면 마지막 값에 10을 더한다', () async {
      final a = await add('가');
      final b = await add('나');
      final c = await add('다');
      final last = (await row(c)).sortOrder;
      await db.delete(db.outbox).go();

      expect(await accounts.reorderAccounts(ledgerId, [b, c, a]), 1);
      expect((await row(a)).sortOrder, last + 10);
      expect((await queued()).single.rowId, a);
    });

    test('끼워 넣을 자리가 없으면 그 묶음 전체를 10 간격으로 다시 매긴다', () async {
      final ids = [await add('가'), await add('나'), await add('다')];
      // 이웃한 값으로 만들어 사이에 자리가 없게 한다.
      for (var i = 0; i < ids.length; i++) {
        await (db.update(db.accounts)..where((a) => a.id.equals(ids[i]))).write(
          AccountsCompanion(sortOrder: Value(i + 1)),
        );
      }
      await db.delete(db.outbox).go();

      final order = [ids[2], ids[0], ids[1]];
      expect(await accounts.reorderAccounts(ledgerId, order), 3);
      expect([for (final id in order) (await row(id)).sortOrder], [10, 20, 30]);
      expect(await queued(), hasLength(3));
    });

    test('순서가 그대로면 아무것도 올리지 않는다', () async {
      final a = await add('가');
      final b = await add('나');
      await db.delete(db.outbox).go();
      expect(await accounts.reorderAccounts(ledgerId, [a, b]), 0);
      expect(await queued(), isEmpty);
    });
  });

  group('planSortOrders', () {
    test('값이 모두 같으면 다시 매긴다', () {
      expect(planSortOrders({'a': 0, 'b': 0, 'c': 0}, ['c', 'a', 'b']), {
        'c': 10,
        'a': 20,
        'b': 30,
      });
    });

    test('맨 앞으로 옮기면 첫 값에서 10을 빼고, 0 이하가 되면 다시 매긴다', () {
      expect(planSortOrders({'a': 20, 'b': 30, 'c': 40}, ['c', 'a', 'b']), {
        'c': 10,
      });
      expect(planSortOrders({'a': 10, 'b': 20, 'c': 30}, ['c', 'a', 'b']), {
        'c': 10,
        'a': 20,
        'b': 30,
      });
    });

    test('모르는 행이나 겹친 행은 받지 않는다', () {
      expect(() => planSortOrders({'a': 10}, ['a', 'x']), throwsArgumentError);
      expect(() => planSortOrders({'a': 10}, ['a', 'a']), throwsArgumentError);
    });
  });
}
