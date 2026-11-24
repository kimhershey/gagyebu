import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gagyebu/app/providers.dart';
import 'package:gagyebu/core/local_date.dart';
import 'package:gagyebu/data/db/database.dart';
import 'package:gagyebu/data/repositories/ledger_repository.dart';
import 'package:gagyebu/domain/enums.dart';

import 'settings_harness.dart';

void main() {
  Future<String> cashId(AppServices services) async =>
      (await services.repository.accounts(services.ledgerId)).first.id;

  Future<String> addLunch(AppServices services) async =>
      services.repository.addTransaction(
        services.ledgerId,
        TransactionInput(
          type: TxType.expense,
          occurredOn: LocalDate(2026, 11, 16),
          amount: 8000,
          accountId: await cashId(services),
          counterparty: '김밥천국',
        ),
      );

  Future<int> record(
    AppServices services, {
    String table = 'transactions',
    required String rowId,
    required Map<String, Object?> loser,
    String side = 'local',
    DateTime? at,
  }) => services.db
      .into(services.db.syncConflicts)
      .insert(
        SyncConflictsCompanion.insert(
          ledgerId: services.ledgerId,
          targetTable: table,
          rowId: rowId,
          loser: loser,
          loserSide: side,
          detectedAt: at ?? DateTime.utc(2026, 11, 17, 1, 30),
        ),
      );

  Future<Map<String, Object?>> lunchLoser(
    AppServices services, {
    String memo = '둘이서',
  }) async => {
    'type': 'expense',
    'occurred_on': '2026-11-15',
    'occurred_time': null,
    'amount': 12000,
    'currency': null,
    'original_amount': null,
    'account_id': await cashId(services),
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
    'dedup_key': 'x',
  };

  Future<void> open(
    WidgetTester tester,
    AppServices services, {
    Size size = desktop,
    double textScale = 1,
  }) => pumpAppWith(
    tester,
    services,
    size: size,
    textScale: textScale,
    location: '/settings/conflicts',
  );

  Future<void> tapKey(WidgetTester tester, String key) async {
    final target = find.byKey(ValueKey(key));
    await scrollSubScreenTo(tester, target);
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  Finder rich(String text) => find.textContaining(text, findRichText: true);

  testWidgets('기록이 없으면 없다고 알린다', (tester) async {
    final services = await createTestServices();
    await open(tester, services);
    expect(find.text('동기화 충돌'), findsOneWidget);
    expect(find.text('충돌 기록이 없습니다.'), findsOneWidget);
    await disposeApp(tester, services);
  });

  testWidgets('어느 쪽이 언제 밀려났는지와 달라진 칸을 보여 준다', (tester) async {
    final services = await createTestServices();
    final id = await addLunch(services);
    await record(services, rowId: id, loser: await lunchLoser(services));
    await open(tester, services);

    expect(find.text('거래 · 11월 15일 · 김밥천국 본점 · 12,000원'), findsOneWidget);
    // 시험의 시간대와 상관없이 날짜와 시각이 함께 보인다.
    expect(find.textContaining('이 기기에서 고친 것이 밀려났습니다 · 11월 1'), findsOneWidget);
    expect(rich('금액'), findsOneWidget);
    expect(rich('12,000원  (지금: 8,000원)'), findsOneWidget);
    expect(rich('(지금: 김밥천국)'), findsOneWidget);
    expect(rich('둘이서  (지금: 없음)'), findsOneWidget);
    // 같은 칸(자산, 종류)은 보이지 않는다.
    expect(rich('자산  '), findsNothing);
    expect(rich('종류  '), findsNothing);
    await disposeApp(tester, services);
  });

  testWidgets('되살리면 거래가 밀려난 값으로 바뀌고 기록이 사라진다', (tester) async {
    final services = await createTestServices();
    final id = await addLunch(services);
    final seq = await record(
      services,
      rowId: id,
      loser: await lunchLoser(services),
    );
    await open(tester, services);

    await tapKey(tester, 'conflict-restore-$seq');
    expect(find.text('밀려난 값으로 되살렸습니다'), findsOneWidget);
    expect(find.text('충돌 기록이 없습니다.'), findsOneWidget);
    final tx = (await services.repository.transactionById(id))!;
    expect(tx.amount, 12000);
    expect(tx.receiver, '김밥천국 본점');
    expect(tx.memo, '둘이서');
    await disposeApp(tester, services);
  });

  testWidgets('지우기는 기록만 지운다', (tester) async {
    final services = await createTestServices();
    final id = await addLunch(services);
    final seq = await record(
      services,
      rowId: id,
      loser: await lunchLoser(services),
    );
    await open(tester, services);

    await tapKey(tester, 'conflict-delete-$seq');
    expect(find.text('기록을 지웠습니다'), findsOneWidget);
    expect(find.text('충돌 기록이 없습니다.'), findsOneWidget);
    expect((await services.repository.transactionById(id))!.amount, 8000);
    await disposeApp(tester, services);
  });

  testWidgets('거래가 아닌 표는 값만 보여 주고 되살리기가 없다', (tester) async {
    final services = await createTestServices();
    final cash = await cashId(services);
    final seq = await record(
      services,
      table: 'accounts',
      rowId: cash,
      side: 'remote',
      loser: {
        'name': '지갑',
        'kind': 'cash',
        'institution': null,
        'match_hints': <String>[],
        'opening_balance': 50000,
        'billing_day': null,
        'payment_account_id': null,
        'sort_order': 0,
      },
    );
    await open(tester, services);

    expect(find.text('자산 · 지갑'), findsOneWidget);
    expect(find.textContaining('다른 기기에서 고친 것이 밀려났습니다'), findsOneWidget);
    expect(rich('지갑  (지금: 현금)'), findsOneWidget);
    expect(rich('50,000원  (지금: 0원)'), findsOneWidget);
    expect(find.byKey(ValueKey('conflict-restore-$seq')), findsNothing);
    expect(find.byKey(ValueKey('conflict-delete-$seq')), findsOneWidget);
    await disposeApp(tester, services);
  });

  testWidgets('밀려난 쪽이 삭제였으면 다시 지울 수 있다', (tester) async {
    final services = await createTestServices();
    final id = await addLunch(services);
    final seq = await record(services, rowId: id, loser: {'deleted': true});
    await open(tester, services);

    expect(find.textContaining('이 항목을 지운 것이었습니다. 지금은 남아 있습니다'), findsOneWidget);
    expect(find.text('다시 지우기'), findsOneWidget);
    await tapKey(tester, 'conflict-restore-$seq');
    expect(find.text('거래를 다시 지웠습니다'), findsOneWidget);
    expect(await services.repository.transactionById(id), isNull);
    await disposeApp(tester, services);
  });

  testWidgets('쓰던 자산이 없어져 되살리지 못하면 까닭을 알리고 기록을 남긴다', (tester) async {
    final services = await createTestServices();
    final id = await addLunch(services);
    final seq = await record(
      services,
      rowId: id,
      loser: {...await lunchLoser(services), 'account_id': 'gone'},
    );
    await open(tester, services);

    expect(rich('(지워진 자산)'), findsOneWidget);
    await tapKey(tester, 'conflict-restore-$seq');
    expect(find.textContaining('되살리지 못했습니다'), findsOneWidget);
    expect(find.textContaining('ArgumentError'), findsNothing);
    expect(find.byKey(ValueKey('conflict-restore-$seq')), findsOneWidget);
    expect((await services.repository.transactionById(id))!.amount, 8000);
    await disposeApp(tester, services);
  });

  testWidgets('화면을 열 때 30일 지난 기록을 지운다', (tester) async {
    final services = await createTestServices();
    final id = await addLunch(services);
    await record(
      services,
      rowId: id,
      loser: {'deleted': true},
      at: testNow.toUtc().subtract(const Duration(days: 40)),
    );
    final kept = await record(
      services,
      rowId: id,
      loser: await lunchLoser(services),
    );
    await open(tester, services);

    final left = await services.db.select(services.db.syncConflicts).get();
    expect(left.single.seq, kept);
    expect(find.byKey(ValueKey('conflict-$kept')), findsOneWidget);
    await disposeApp(tester, services);
  });

  group('넘치지 않는다', () {
    for (final (name, size) in fourSizes) {
      testWidgets(name, (tester) async {
        final services = await createTestServices();
        final id = await addLunch(services);
        final seq = await record(
          services,
          rowId: id,
          loser: await lunchLoser(services, memo: '아주 긴 메모입니다. ' * 12),
        );
        await record(services, rowId: id, loser: {'deleted': true});
        await open(tester, services, size: size);
        expect(tester.takeException(), isNull);
        await scrollSubScreenTo(
          tester,
          find.byKey(ValueKey('conflict-restore-$seq')),
        );
        expect(tester.takeException(), isNull);
        await disposeApp(tester, services);
      });
    }

    testWidgets('소형 폰에서 글자를 200%로 키워도', (tester) async {
      final services = await createTestServices();
      final id = await addLunch(services);
      final seq = await record(
        services,
        rowId: id,
        loser: await lunchLoser(services),
      );
      await open(tester, services, size: phone, textScale: 2);
      expect(tester.takeException(), isNull);
      await scrollSubScreenTo(
        tester,
        find.byKey(ValueKey('conflict-restore-$seq')),
      );
      expect(tester.takeException(), isNull);
      await disposeApp(tester, services);
    });
  });
}
