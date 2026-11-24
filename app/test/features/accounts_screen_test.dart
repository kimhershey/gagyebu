import 'package:flutter_test/flutter_test.dart';
import 'package:gagyebu/app/providers.dart';
import 'package:gagyebu/core/local_date.dart';
import 'package:gagyebu/data/db/database.dart';
import 'package:gagyebu/data/repositories/account_repository.dart';
import 'package:gagyebu/data/repositories/ledger_repository.dart';
import 'package:gagyebu/domain/card_due.dart';
import 'package:gagyebu/domain/enums.dart';
import 'package:gagyebu/features/accounts/account_list.dart';
import 'package:gagyebu/features/accounts/accounts_screen.dart';
import 'package:material_ui/material_ui.dart';

import 'test_app.dart';

Future<String> addAccount(
  AppServices services,
  String name,
  AccountKind kind, {
  int openingBalance = 0,
  int? billingDay,
  String? paymentAccountId,
}) => services.repository.addAccount(
  ledgerId: services.ledgerId,
  name: name,
  kind: kind,
  openingBalance: openingBalance,
  billingDay: billingDay,
  paymentAccountId: paymentAccountId,
);

Future<String> spend(
  AppServices services,
  String accountId,
  String date,
  int amount, {
  bool canceled = false,
}) => services.repository.addTransaction(
  services.ledgerId,
  TransactionInput(
    type: TxType.expense,
    occurredOn: LocalDate.parse(date),
    amount: amount,
    accountId: accountId,
    counterparty: '가게',
    canceled: canceled,
  ),
);

Future<List<String>> bankNames(AppServices services) async => [
  for (final a in await services.repository.accounts(services.ledgerId))
    if (a.kind == AccountKind.bank) a.name,
];

/// [handle]을 잡고 [from] 줄을 바로 아래의 [to] 줄 밑으로 끌어 놓는다.
///
/// 아래 줄의 가운데를 넘기되 끝은 넘기지 않게, 줄 간격의 3/4만큼 옮긴다.
Future<void> dragBelow(
  WidgetTester tester,
  Finder handle, {
  required Finder from,
  required Finder to,
}) async {
  final distance = tester.getTopLeft(to).dy - tester.getTopLeft(from).dy;
  final gesture = await tester.startGesture(tester.getCenter(handle));
  await tester.pump(const Duration(milliseconds: 100));
  await gesture.moveBy(Offset(0, distance * 0.4));
  await tester.pump(const Duration(milliseconds: 100));
  await gesture.moveBy(Offset(0, distance * 0.35));
  await tester.pump(const Duration(milliseconds: 100));
  await gesture.up();
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('추가 → 수정 → 순서 바꾸기 → 삭제', (tester) async {
    final services = await createTestServices();
    final spare = await addAccount(services, '비상금', AccountKind.bank);
    await pumpApp(tester, services, size: desktop, location: '/accounts');

    expect(find.byType(AccountsScreen), findsOneWidget);
    expect(find.text('현금'), findsWidgets);
    expect(find.text('비상금'), findsOneWidget);

    // 추가
    await tester.tap(find.byKey(const ValueKey('accounts-add')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('account-form-name')),
      '월급 통장',
    );
    await tester.enterText(
      find.byKey(const ValueKey('account-form-opening')),
      '1500000',
    );
    await tester.tap(find.byKey(const ValueKey('account-form-save')));
    await tester.pumpAndSettle();
    expect(find.text('월급 통장'), findsOneWidget);
    expect(find.text('1,500,000원'), findsWidgets);
    expect(await bankNames(services), ['비상금', '월급 통장']);

    // 수정: 이름과 문자와 잇는 말
    await tester.tap(find.text('월급 통장'));
    await tester.pumpAndSettle();
    expect(find.text('자산 고치기'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('account-form-name')),
      '주거래 통장',
    );
    await tester.enterText(
      find.byKey(const ValueKey('account-form-hints')),
      '신한, 1234',
    );
    await tester.tap(find.byKey(const ValueKey('account-form-save')));
    await tester.pumpAndSettle();
    expect(find.text('주거래 통장'), findsOneWidget);
    expect(find.text('월급 통장'), findsNothing);
    final edited = (await services.repository.accounts(services.ledgerId))
        .firstWhere((a) => a.name == '주거래 통장');
    expect(edited.matchHints, ['신한', '1234']);
    expect(edited.openingBalance, 1500000);

    // 순서: 비상금의 손잡이를 끌어 주거래 통장 아래로
    await dragBelow(
      tester,
      find.byKey(ValueKey('account-handle-$spare')),
      from: find.text('비상금'),
      to: find.text('주거래 통장'),
    );
    expect(await bankNames(services), ['주거래 통장', '비상금']);
    expect(
      tester.getTopLeft(find.text('주거래 통장')).dy,
      lessThan(tester.getTopLeft(find.text('비상금')).dy),
    );

    // 삭제
    await tester.tap(find.text('비상금'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('account-form-delete')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('confirm-yes')));
    await tester.pumpAndSettle();
    expect(find.text('비상금'), findsNothing);
    expect(await bankNames(services), ['주거래 통장']);

    // 바꾼 것은 모두 대기열에 올라갔다.
    final queued = await services.db.select(services.db.outbox).get();
    expect(queued.where((o) => o.targetTable == 'accounts'), isNotEmpty);
    expect(tester.takeException(), isNull);
    await disposeApp(tester, services);
  });

  testWidgets('거래가 있는 자산은 지우지 못하고 거래를 옮기라고 안내한다', (tester) async {
    final services = await createTestServices();
    final bank = await addAccount(services, '월급 통장', AccountKind.bank);
    await spend(services, bank, '2026-11-10', 12000);
    await pumpApp(tester, services, size: phone, location: '/accounts');

    await tester.tap(find.text('월급 통장'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('account-form-delete')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('confirm-yes')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('account-delete-blocked')),
      findsOneWidget,
    );
    expect(find.textContaining('다른 자산으로 옮긴 뒤에'), findsOneWidget);
    expect(await bankNames(services), ['월급 통장']);
    expect(tester.takeException(), isNull);
    await disposeApp(tester, services);
  });

  testWidgets('카드 자산에 다음 결제일과 결제 예정액을 보여 준다', (tester) async {
    final services = await createTestServices();
    final bank = await addAccount(services, '월급 통장', AccountKind.bank);
    final card = await addAccount(
      services,
      '신한카드',
      AccountKind.creditCard,
      billingDay: 25,
      paymentAccountId: bank,
    );
    // 오늘은 2026-11-17. 10월 26일 – 11월 25일에 쓴 것만 센다.
    await spend(services, card, '2026-10-25', 99999);
    await spend(services, card, '2026-10-26', 32000);
    await spend(services, card, '2026-11-16', 400000);
    await spend(services, card, '2026-11-12', 70000, canceled: true);
    await pumpApp(tester, services, size: largePhone, location: '/accounts');

    expect(find.text('다음 결제일 25일 · 예정 432,000원'), findsOneWidget);
    expect(find.text('결제 계좌 월급 통장'), findsOneWidget);
    expect(find.textContaining('실제 청구액과 다를 수 있습니다'), findsOneWidget);

    // 카드의 결제일을 고치면 예정액이 바뀐다.
    await tester.tap(find.text('신한카드'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('account-form-billing-day')),
      '15',
    );
    await tester.tap(find.byKey(const ValueKey('account-form-save')));
    await tester.pumpAndSettle();
    // 11월 15일이 지났으므로 다음 결제일은 12월 15일, 기간은 11월 16일부터다.
    expect(find.text('다음 결제일 15일 · 예정 400,000원'), findsOneWidget);

    expect(tester.takeException(), isNull);
    await disposeApp(tester, services);
  });

  test('체크카드로 쓴 돈은 연결 계좌의 잔액에서 뺀다', () {
    final at = DateTime.utc(2026, 11, 1);
    AccountBalance balance(
      String id,
      AccountKind kind,
      int amount, {
      String? payment,
      int? billingDay,
    }) => AccountBalance(
      account: AccountRow(
        id: id,
        version: 0,
        clientUpdatedAt: at,
        createdAt: at,
        updatedAt: at,
        ledgerId: 'ledger',
        name: id,
        kind: kind,
        matchHints: const [],
        openingBalance: 0,
        billingDay: billingDay,
        paymentAccountId: payment,
        sortOrder: 0,
      ),
      balance: amount,
    );

    final sections = buildAccountSections(
      [
        balance('bank', AccountKind.bank, 1000000),
        balance('check', AccountKind.checkCard, -30000, payment: 'bank'),
        balance('loose', AccountKind.checkCard, -5000),
        balance('gone', AccountKind.checkCard, -7000, payment: 'deleted'),
        balance('credit', AccountKind.creditCard, -200000, billingDay: 25),
        balance('no-day', AccountKind.creditCard, 0),
      ],
      spends: [
        CardSpend(
          accountId: 'credit',
          type: TxType.expense,
          date: LocalDate(2026, 11, 3),
          amount: 200000,
        ),
      ],
      today: LocalDate(2026, 11, 17),
    );

    expect(
      [for (final s in sections) s.kind],
      [AccountKind.bank, AccountKind.creditCard, AccountKind.checkCard],
    );
    final items = {
      for (final s in sections)
        for (final i in s.items) i.account.id: i,
    };
    expect(items['bank']!.balance, 970000);
    expect(items['check']!.balance, isNull);
    expect(items['check']!.paymentAccountName, 'bank');
    // 연결 계좌가 없거나 지워졌으면 카드의 잔액을 그대로 보인다.
    expect(items['loose']!.balance, -5000);
    expect(items['gone']!.balance, -7000);
    expect(
      items['credit']!.due,
      CardDue(date: LocalDate(2026, 11, 25), amount: 200000),
    );
    expect(items['no-day']!.due, isNull);
    // 합계는 합치기 전과 같다.
    final total = items.values.fold<int>(0, (sum, i) => sum + (i.balance ?? 0));
    expect(total, 1000000 - 30000 - 5000 - 7000 - 200000);
  });

  group('넘치지 않는다', () {
    for (final (name, size) in [
      ('360×640', phone),
      ('412×915', largePhone),
      ('700×800', foldable),
      ('1280×800', desktop),
    ]) {
      for (final scale in [1.0, 2.0]) {
        testWidgets('$name, 글자 $scale배', (tester) async {
          final services = await createTestServices();
          await seedMany(services);
          await pumpApp(
            tester,
            services,
            size: size,
            location: '/accounts',
            textScale: scale,
          );
          expect(find.byType(AccountsScreen), findsOneWidget);
          expect(tester.takeException(), isNull);

          await tester.drag(find.byType(AccountsScreen), const Offset(0, -600));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await tester.drag(find.byType(AccountsScreen), const Offset(0, 900));
          await tester.pumpAndSettle();

          // 편집 칸도 넘치지 않는다(카드의 칸이 가장 길다).
          await tester.tap(find.byKey(const ValueKey('accounts-add')));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await tester.tap(find.byKey(const ValueKey('editor-close')));
          await tester.pumpAndSettle();
          final row = find.textContaining('아주 긴 이름의').first;
          await tester.ensureVisible(row);
          await tester.pumpAndSettle();
          await tester.tap(row);
          await tester.pumpAndSettle();
          expect(find.text('자산 고치기'), findsOneWidget);
          expect(tester.takeException(), isNull);
          await disposeApp(tester, services);
        });
      }
    }
  });

  testWidgets('자산이 없으면 빈 상태를 보여 준다', (tester) async {
    final services = await createTestServices();
    final cash = (await services.repository.accounts(services.ledgerId)).single;
    await services.repository.deleteAccount(cash.id);
    await pumpApp(tester, services, size: phone, location: '/accounts');

    expect(find.textContaining('등록한 자산이 없습니다'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('accounts-add-first')));
    await tester.pumpAndSettle();
    expect(find.text('자산 추가'), findsWidgets);
    await disposeApp(tester, services);
  });

  testWidgets('저장소로 순서를 바꾸면 화면이 따라간다', (tester) async {
    final services = await createTestServices();
    final a = await addAccount(services, '가 통장', AccountKind.bank);
    final b = await addAccount(services, '나 통장', AccountKind.bank);
    await pumpApp(tester, services, size: foldable, location: '/accounts');
    expect(
      tester.getTopLeft(find.text('가 통장')).dy,
      lessThan(tester.getTopLeft(find.text('나 통장')).dy),
    );

    await AccountRepository(
      services.db,
      services.repository.outbox,
    ).reorderAccounts(services.ledgerId, [b, a]);
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.text('나 통장')).dy,
      lessThan(tester.getTopLeft(find.text('가 통장')).dy),
    );
    await disposeApp(tester, services);
  });
}

/// 긴 이름과 큰 금액, 카드가 섞인 자산을 넣는다.
Future<void> seedMany(AppServices services) async {
  final bank = await addAccount(
    services,
    '아주 긴 이름의 주거래 급여 통장 (신한은행 123-456-789012)',
    AccountKind.bank,
    openingBalance: 1234567890,
  );
  await addAccount(services, '비상금', AccountKind.bank, openingBalance: 500000);
  final card = await addAccount(
    services,
    '신한 Deep Dream 플래티넘 플러스 카드',
    AccountKind.creditCard,
    billingDay: 31,
    paymentAccountId: bank,
  );
  await addAccount(services, '결제일 없는 카드', AccountKind.creditCard);
  await addAccount(
    services,
    '체크카드',
    AccountKind.checkCard,
    paymentAccountId: bank,
  );
  await addAccount(services, '연결 없는 체크카드', AccountKind.checkCard);
  await addAccount(services, '네이버페이', AccountKind.pay, openingBalance: 30000);
  await addAccount(services, '상품권', AccountKind.other, openingBalance: 100000);
  await spend(services, card, '2026-11-10', 123456789);
}
