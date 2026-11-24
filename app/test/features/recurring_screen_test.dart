import 'package:flutter_test/flutter_test.dart';
import 'package:gagyebu/app/providers.dart';
import 'package:gagyebu/core/local_date.dart';
import 'package:gagyebu/data/db/database.dart';
import 'package:gagyebu/data/repositories/ledger_repository.dart';
import 'package:gagyebu/data/repositories/recurring_repository.dart';
import 'package:gagyebu/domain/enums.dart';
import 'package:gagyebu/features/recurring/recurring_form.dart';
import 'package:gagyebu/features/recurring/recurring_screen.dart';
import 'package:material_ui/material_ui.dart';

import 'test_app.dart';

RecurringRepository recurringOf(AppServices services) =>
    RecurringRepository(services.repository);

Future<String> cashId(AppServices services) async =>
    (await services.repository.accounts(services.ledgerId)).first.id;

Future<String> categoryId(AppServices services, String name) async =>
    (await services.repository.categories(services.ledgerId))
        .firstWhere((c) => c.name == name)
        .id;

Future<String> addRule(
  AppServices services, {
  String party = '집주인',
  int amount = 500000,
  String next = '2026-11-25',
  String? end,
  RecurringFrequency frequency = RecurringFrequency.monthly,
  int interval = 1,
  TxType type = TxType.expense,
  String? accountId,
  String? toAccountId,
  bool autoPost = false,
  bool isActive = true,
}) async => recurringOf(services).addRule(
  services.ledgerId,
  RecurringRuleInput(
    template: RecurringTemplate(
      type: type,
      amount: amount,
      accountId: accountId ?? await cashId(services),
      toAccountId: toAccountId,
      counterparty: party,
    ),
    frequency: frequency,
    intervalCount: interval,
    nextRunOn: LocalDate.parse(next),
    endOn: end == null ? null : LocalDate.parse(end),
    autoPost: autoPost,
    isActive: isActive,
  ),
);

Future<List<TxRow>> transactions(AppServices services) =>
    services.db.select(services.db.ledgerTransactions).get();

void main() {
  testWidgets('추가 → 수정 → 끄기 → 삭제', (tester) async {
    final services = await createTestServices();
    await pumpApp(tester, services, size: desktop, location: '/recurring');

    expect(find.byType(RecurringScreen), findsOneWidget);
    expect(find.textContaining('등록한 반복 거래가 없습니다'), findsOneWidget);

    // 추가: 다음 날짜를 그대로 두면 오늘(2026-11-17)부터다.
    await tester.tap(find.byKey(const ValueKey('recurring-add')));
    await tester.pumpAndSettle();
    expect(find.text('반복 거래 추가'), findsWidgets);
    await tester.enterText(
      find.byKey(const ValueKey('recurring-form-amount')),
      '17000',
    );
    await tester.enterText(
      find.byKey(const ValueKey('recurring-form-party')),
      '넷플릭스',
    );
    await tester.tap(find.byKey(const ValueKey('recurring-form-save')));
    await tester.pumpAndSettle();

    var rule = (await recurringOf(services).rules(services.ledgerId)).single;
    expect(rule.template['amount'], 17000);
    expect(rule.template['counterparty'], '넷플릭스');
    expect(rule.template['type'], 'expense');
    expect(rule.frequency, 'monthly');
    expect(rule.autoPost, isFalse);
    // 오늘 몫은 바로 만들고 다음 날짜를 한 달 뒤로 옮긴다.
    expect(find.text('반복 거래를 저장하고 거래 1건을 만들었습니다.'), findsOneWidget);
    expect(rule.nextRunOn, LocalDate(2026, 12, 17));
    final made = (await transactions(services)).single;
    expect(made.occurredOn, LocalDate(2026, 11, 17));
    expect(made.source, TxSource.recurring);
    expect(made.status, TxStatus.needsReview);

    final tile = find.byKey(ValueKey('recurring-rule-${rule.id}'));
    Finder inTile(String text) =>
        find.descendant(of: tile, matching: find.textContaining(text));
    expect(inTile('넷플릭스'), findsOneWidget);
    // 지출에는 - 부호를 붙인다.
    expect(inTile('-17,000원'), findsOneWidget);
    expect(inTile('매달 17일 · 다음 12월 17일 · 확인 후 등록'), findsOneWidget);

    // 수정: 금액을 올리고 자동 등록을 켠다.
    await tester.tap(inTile('넷플릭스'));
    await tester.pumpAndSettle();
    expect(find.text('반복 거래 고치기'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('recurring-form-amount')),
      '20000',
    );
    // 글 칸이 커서를 화면에 두려고 스크롤하는 일이 끝난 뒤에 아래로 내린다.
    await tester.pumpAndSettle();
    final auto = find.byKey(const ValueKey('recurring-form-auto'));
    await tester.ensureVisible(auto);
    await tester.pumpAndSettle();
    await tester.tap(auto);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('recurring-form-save')));
    await tester.pumpAndSettle();
    rule = (await recurringOf(services).rules(services.ledgerId)).single;
    expect(rule.template['amount'], 20000);
    expect(rule.template['anchor_day'], 17);
    expect(rule.autoPost, isTrue);
    expect(inTile('-20,000원'), findsOneWidget);
    expect(inTile('자동 등록'), findsOneWidget);

    // 끄기
    await tester.tap(find.byKey(ValueKey('recurring-active-${rule.id}')));
    await tester.pumpAndSettle();
    rule = (await recurringOf(services).rules(services.ledgerId)).single;
    expect(rule.isActive, isFalse);
    expect(inTile('꺼짐'), findsOneWidget);

    // 삭제: 만든 거래는 남는다.
    await tester.tap(inTile('넷플릭스'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('recurring-form-delete')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('confirm-yes')));
    await tester.pumpAndSettle();
    expect(await recurringOf(services).rules(services.ledgerId), isEmpty);
    expect(find.textContaining('등록한 반복 거래가 없습니다'), findsOneWidget);
    expect(await transactions(services), hasLength(1));

    expect(tester.takeException(), isNull);
    await disposeApp(tester, services);
  });

  testWidgets('주소에 from이 있으면 그 거래를 틀로 새 규칙을 만드는 칸을 연다', (tester) async {
    final services = await createTestServices();
    final rent = await categoryId(services, '주거·통신');
    final txId = await services.repository.addTransaction(
      services.ledgerId,
      TransactionInput(
        type: TxType.expense,
        occurredOn: LocalDate(2026, 10, 25),
        amount: 500000,
        accountId: await cashId(services),
        counterparty: '집주인',
        categoryId: rent,
        memo: '월세',
      ),
    );
    await pumpApp(
      tester,
      services,
      size: largePhone,
      location: '/recurring?from=$txId',
    );

    expect(find.text('반복으로 등록'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, '500,000'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, '집주인'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, '월세'), findsOneWidget);
    // 틀이 된 거래의 다음 달 같은 날부터다.
    expect(find.text(fullDateLabelOf(2026, 11, 25)), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('recurring-form-save')));
    await tester.pumpAndSettle();

    final rule = (await recurringOf(services).rules(services.ledgerId)).single;
    expect(rule.template, {
      'type': 'expense',
      'amount': 500000,
      'account_id': await cashId(services),
      'to_account_id': null,
      'counterparty': '집주인',
      'category_id': rent,
      'memo': '월세',
      'anchor_day': 25,
    });
    expect(rule.nextRunOn, LocalDate(2026, 11, 25));
    expect(rule.frequency, 'monthly');
    // 아직 날짜가 되지 않아 거래는 틀이 된 한 건뿐이다.
    expect(await transactions(services), hasLength(1));
    // 칸이 닫히면 다시 열리지 않는다.
    expect(find.text('반복으로 등록'), findsNothing);
    expect(find.textContaining('집주인'), findsOneWidget);

    expect(tester.takeException(), isNull);
    await disposeApp(tester, services);
  });

  testWidgets('틀로 삼을 거래가 없으면 알리고 목록을 보여 준다', (tester) async {
    final services = await createTestServices();
    await pumpApp(
      tester,
      services,
      size: phone,
      location: '/recurring?from=missing',
    );
    expect(find.text('틀로 삼을 거래를 찾지 못했습니다.'), findsOneWidget);
    expect(find.text('반복으로 등록'), findsNothing);
    expect(find.byType(RecurringScreen), findsOneWidget);
    await disposeApp(tester, services);
  });

  testWidgets('다시 켜면 밀린 거래를 만든다', (tester) async {
    final services = await createTestServices();
    final id = await addRule(services, next: '2026-09-25', isActive: false);
    await pumpApp(tester, services, size: foldable, location: '/recurring');
    // 앱을 켤 때 도는 일은 꺼 둔 규칙을 건너뛴다.
    expect(await transactions(services), isEmpty);
    expect(find.textContaining('꺼짐'), findsOneWidget);

    await tester.tap(find.byKey(ValueKey('recurring-active-$id')));
    await tester.pumpAndSettle();

    expect(find.text('밀린 거래 2건을 만들었습니다.'), findsOneWidget);
    expect(await transactions(services), hasLength(2));
    expect(find.textContaining('다음 11월 25일'), findsOneWidget);
    await disposeApp(tester, services);
  });

  testWidgets('앱을 켜면 밀린 반복 거래를 만든다', (tester) async {
    final services = await createTestServices();
    await addRule(services, next: '2026-10-25', autoPost: true);
    // 반복 거래 화면이 아니어도 뼈대가 켜 둔다.
    await pumpApp(tester, services, size: phone, location: '/');

    final made = (await transactions(services)).single;
    expect(made.occurredOn, LocalDate(2026, 10, 25));
    expect(made.status, TxStatus.confirmed);
    expect(made.source, TxSource.recurring);
    await disposeApp(tester, services);
  });

  testWidgets('이체 · 끝난 규칙 · 자산이 지워진 규칙을 알아볼 수 있게 보여 준다', (tester) async {
    final services = await createTestServices();
    final bank = await services.repository.addAccount(
      ledgerId: services.ledgerId,
      name: '적금',
      kind: AccountKind.bank,
    );
    final gone = await services.repository.addAccount(
      ledgerId: services.ledgerId,
      name: '없앨 통장',
      kind: AccountKind.bank,
    );
    final transfer = await addRule(
      services,
      party: '',
      type: TxType.transfer,
      toAccountId: bank,
      amount: 300000,
      next: '2026-12-01',
    );
    final ended = await addRule(
      services,
      party: '헬스장',
      next: '2026-12-05',
      end: '2026-11-30',
    );
    final broken = await addRule(
      services,
      party: '보험',
      accountId: gone,
      next: '2026-12-10',
    );
    final income = await addRule(
      services,
      party: '회사',
      type: TxType.income,
      amount: 3000000,
      next: '2026-12-25',
      frequency: RecurringFrequency.weekly,
      interval: 2,
    );
    await services.repository.deleteAccount(gone);
    await pumpApp(tester, services, size: desktop, location: '/recurring');

    Finder inRule(String id, String text) => find.descendant(
      of: find.byKey(ValueKey('recurring-rule-$id')),
      matching: find.textContaining(text),
    );
    expect(inRule(transfer, '현금 → 적금'), findsOneWidget);
    // 이체에는 부호가 없다.
    expect(
      find.descendant(
        of: find.byKey(ValueKey('recurring-rule-$transfer')),
        matching: find.text('300,000원'),
      ),
      findsOneWidget,
    );
    expect(inRule(ended, '끝남'), findsOneWidget);
    expect(inRule(broken, '자산이 지워져 거래를 만들지 못합니다'), findsOneWidget);
    expect(inRule(income, '+3,000,000원'), findsOneWidget);
    expect(inRule(income, '2주마다 금요일'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await disposeApp(tester, services);
  });

  group('주기를 글로 옮긴다', () {
    test('매주 · 매달 · 매년과 간격', () {
      final tuesday = LocalDate(2026, 11, 17);
      expect(describeSchedule(RecurringFrequency.weekly, 1, tuesday), '매주 화요일');
      expect(
        describeSchedule(RecurringFrequency.weekly, 3, tuesday),
        '3주마다 화요일',
      );
      expect(
        describeSchedule(RecurringFrequency.monthly, 1, tuesday),
        '매달 17일',
      );
      expect(
        describeSchedule(RecurringFrequency.monthly, 2, tuesday),
        '2달마다 17일',
      );
      // 2월 28일에 와 있어도 고른 날이 31일이면 말일 규칙이다.
      expect(
        describeSchedule(
          RecurringFrequency.monthly,
          1,
          LocalDate(2027, 2, 28),
          anchorDay: 31,
        ),
        '매달 말일',
      );
      expect(
        describeSchedule(RecurringFrequency.yearly, 1, LocalDate(2027, 3, 1)),
        '매년 3월 1일',
      );
      expect(
        describeSchedule(RecurringFrequency.yearly, 2, LocalDate(2027, 3, 1)),
        '2년마다 3월 1일',
      );
    });
  });

  group('거래를 틀로 삼을 때', () {
    final at = DateTime.utc(2026, 11, 1);
    TxRow tx(String date, {TxType type = TxType.expense}) => TxRow(
      id: 'tx',
      version: 0,
      clientUpdatedAt: at,
      createdAt: at,
      updatedAt: at,
      ledgerId: 'ledger',
      type: type,
      occurredOn: LocalDate.parse(date),
      amount: 9900,
      accountId: 'account',
      toAccountId: type == TxType.transfer ? 'other' : null,
      sender: type == TxType.income ? '회사' : '내 통장',
      receiver: type == TxType.expense ? '넷플릭스' : '내 통장',
      categoryId: 'category',
      memo: '구독',
      tags: const [],
      source: TxSource.paste,
      status: TxStatus.confirmed,
    );

    test('오늘 이후의 가장 가까운 같은 날부터 매달', () {
      final today = LocalDate(2026, 11, 17);
      expect(
        ruleInputFromTransaction(tx('2026-11-10'), today).nextRunOn,
        LocalDate(2026, 12, 10),
      );
      // 오래된 거래를 골라도 밀린 거래가 쏟아지지 않는다.
      expect(
        ruleInputFromTransaction(tx('2026-07-20'), today).nextRunOn,
        LocalDate(2026, 11, 20),
      );
      // 31일 거래는 짧은 달에 마지막 날로 당기고 고른 날은 31일로 남긴다.
      final endOfMonth = ruleInputFromTransaction(tx('2026-10-31'), today);
      expect(endOfMonth.nextRunOn, LocalDate(2026, 11, 30));
      expect(endOfMonth.template.anchorDay, 31);
      expect(endOfMonth.frequency, RecurringFrequency.monthly);
      expect(endOfMonth.autoPost, isFalse);
    });

    test('상대방은 지출이면 받는 쪽, 수입이면 보낸 쪽, 이체에는 없다', () {
      final today = LocalDate(2026, 11, 17);
      final expense = ruleInputFromTransaction(tx('2026-11-10'), today);
      expect(expense.template.counterparty, '넷플릭스');
      expect(expense.template.amount, 9900);
      expect(expense.template.accountId, 'account');
      expect(expense.template.categoryId, 'category');
      expect(expense.template.memo, '구독');
      expect(
        ruleInputFromTransaction(
          tx('2026-11-10', type: TxType.income),
          today,
        ).template.counterparty,
        '회사',
      );
      final transfer = ruleInputFromTransaction(
        tx('2026-11-10', type: TxType.transfer),
        today,
      );
      expect(transfer.template.counterparty, isNull);
      expect(transfer.template.toAccountId, 'other');
    });
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
          final bank = await services.repository.addAccount(
            ledgerId: services.ledgerId,
            name: '아주 긴 이름의 주거래 급여 통장 (신한은행 123-456-789012)',
            kind: AccountKind.bank,
          );
          final long = await addRule(
            services,
            party: '이름이 아주 아주 긴 상대방 — 주식회사 어디어디 월 정기 구독 서비스 이용료',
            amount: 1234567890,
            next: '2027-01-31',
            end: '2028-12-31',
            accountId: bank,
          );
          await addRule(
            services,
            party: '',
            type: TxType.transfer,
            toAccountId: bank,
            amount: 300000,
            next: '2026-12-01',
            isActive: false,
          );
          await addRule(
            services,
            party: '회사',
            type: TxType.income,
            amount: 3000000,
            next: '2026-12-25',
            frequency: RecurringFrequency.yearly,
            interval: 2,
            autoPost: true,
          );
          await pumpApp(
            tester,
            services,
            size: size,
            location: '/recurring',
            textScale: scale,
          );
          expect(find.byType(RecurringScreen), findsOneWidget);
          expect(tester.takeException(), isNull);

          await tester.drag(
            find.byType(RecurringScreen),
            const Offset(0, -600),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await tester.drag(find.byType(RecurringScreen), const Offset(0, 900));
          await tester.pumpAndSettle();

          // 편집 칸을 끝까지 내려도 넘치지 않는다.
          final tile = find.byKey(ValueKey('recurring-rule-$long'));
          await Scrollable.ensureVisible(tester.element(tile), alignment: 0.5);
          await tester.pumpAndSettle();
          await tester.tap(
            find.descendant(
              of: tile,
              matching: find.textContaining('이름이 아주 아주 긴'),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text('반복 거래 고치기'), findsOneWidget);
          expect(tester.takeException(), isNull);
          final active = find.byKey(const ValueKey('recurring-form-active'));
          await tester.ensureVisible(active);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await disposeApp(tester, services);
        });
      }
    }
  });
}

/// 편집 칸에 보이는 날짜 글('2026년 11월 25일 (수)').
String fullDateLabelOf(int year, int month, int day) {
  const weekdays = ['월', '화', '수', '목', '금', '토', '일'];
  final date = LocalDate(year, month, day);
  return '$year년 $month월 $day일 (${weekdays[date.weekday - 1]})';
}
