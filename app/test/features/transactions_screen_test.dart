import 'package:flutter_test/flutter_test.dart';
import 'package:gagyebu/app/providers.dart';
import 'package:gagyebu/core/local_date.dart';
import 'package:gagyebu/data/db/database.dart';
import 'package:gagyebu/data/repositories/ledger_repository.dart';
import 'package:gagyebu/domain/enums.dart';
import 'package:gagyebu/domain/month_period.dart';
import 'package:gagyebu/features/recurring/recurring_screen.dart';
import 'package:gagyebu/features/transactions/amount_input.dart';
import 'package:gagyebu/features/transactions/transaction_calendar.dart';
import 'package:gagyebu/features/transactions/transaction_editor.dart';
import 'package:gagyebu/features/transactions/transactions_screen.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import 'test_app.dart';

/// 시험에 쓰는 거래 묶음. 이름 → 거래 ID.
class _Seed {
  final tx = <String, String>{};
  late final String cashId;
  late final String bankId;
  late final Map<String, String> categories;
}

/// 2026년 11월에 거래 여섯 건을 넣는다(오늘은 11월 17일).
///
/// 16일: 지출 12,500 + 125,000(확인 필요), 취소한 지출 50,000, 이체 100,000
/// 10일: 수입 3,000,000 / 17일: 지출 5,500
Future<_Seed> _seed(AppServices services) async {
  final repo = services.repository;
  final ledgerId = services.ledgerId;
  final seed = _Seed();
  seed.cashId = (await repo.accounts(ledgerId)).single.id;
  seed.bankId = await repo.addAccount(
    ledgerId: ledgerId,
    name: '월급 통장',
    kind: AccountKind.bank,
  );
  seed.categories = {
    for (final c in await repo.categories(ledgerId)) c.name: c.id,
  };

  Future<void> add(
    String name,
    TxType type,
    int amount,
    int day, {
    String? category,
    String? toAccount,
    bool canceled = false,
    TxStatus status = TxStatus.confirmed,
  }) async {
    seed.tx[name] = await repo.addTransaction(
      ledgerId,
      TransactionInput(
        type: type,
        occurredOn: LocalDate(2026, 11, day),
        amount: amount,
        accountId: seed.cashId,
        toAccountId: toAccount,
        counterparty: type == TxType.transfer ? null : name,
        categoryId: category == null ? null : seed.categories[category],
        canceled: canceled,
        status: status,
      ),
    );
  }

  await add('김밥천국', TxType.expense, 12500, 16, category: '식비');
  await add(
    '이마트',
    TxType.expense,
    125000,
    16,
    category: '생활',
    status: TxStatus.needsReview,
  );
  await add('환불한 신발', TxType.expense, 50000, 16, canceled: true);
  await add('이체', TxType.transfer, 100000, 16, toAccount: seed.bankId);
  await add('회사', TxType.income, 3000000, 10, category: '급여');
  await add('스타벅스', TxType.expense, 5500, 17, category: '카페·간식');
  return seed;
}

Finder _key(String key) => find.byKey(ValueKey(key));

String? _text(WidgetTester tester, String key) =>
    tester.widget<Text>(_key(key)).data;

Future<TxRow> _row(AppServices services, String id) async =>
    (await services.repository.transactionById(id))!;

/// 지워졌는지. 지운 거래는 삭제 표시가 붙은 채 남거나(서버에 올린 적이 있을 때) 사라진다.
Future<bool> _deleted(AppServices services, String id) async {
  final row = await services.repository.transactionById(id);
  return row == null || row.deletedAt != null;
}

/// 필터 칸의 아래쪽 항목은 굴려야 그려진다. 그려진 뒤에는 누를 수 있게 끝까지 올린다.
Future<void> _revealInFilter(WidgetTester tester, String key) async {
  await tester.scrollUntilVisible(
    _key(key),
    80,
    scrollable: find
        .descendant(
          of: _key('filter-scroll'),
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await tester.ensureVisible(_key(key));
  await tester.pumpAndSettle();
}

/// 시험 안에서 주소를 옮긴다.
Future<void> _go(WidgetTester tester, String location) async {
  GoRouter.of(tester.element(find.byType(TransactionsScreen))).go(location);
  await tester.pumpAndSettle();
}

void main() {
  // 누른 자리에 그 위젯이 없으면(가려졌거나 화면 밖이면) 시험을 실패로 친다.
  setUp(() => WidgetController.hitTestWarningShouldBeFatal = true);
  tearDown(() => WidgetController.hitTestWarningShouldBeFatal = false);

  group('줄인 금액', () {
    test('만 원 미만은 그대로, 그 위는 만 · 억으로 줄인다', () {
      expect(compactAmount(0), '0');
      expect(compactAmount(9500), '9,500');
      expect(compactAmount(10000), '1만');
      expect(compactAmount(12500), '1.3만');
      expect(compactAmount(125000), '12.5만');
      expect(compactAmount(137500), '13.8만');
      expect(compactAmount(999500), '100만');
      expect(compactAmount(1250000), '125만');
      expect(compactAmount(3000000), '300만');
      expect(compactAmount(12345678), '1,235만');
      expect(compactAmount(99995000), '1억');
      expect(compactAmount(120000000), '1.2억');
      expect(compactAmount(-125000), '12.5만');
    });

    test('부호를 붙인다', () {
      expect(signedCompactAmount(125000), '+12.5만');
      expect(signedCompactAmount(-5500), '-5,500');
    });
  });

  group('달력의 주', () {
    test('일요일부터 시작해 그 달을 덮는다', () {
      final weeks = calendarWeeks(MonthPeriod(2026, 11));
      // 2026년 11월 1일은 일요일, 30일은 월요일이다.
      expect(weeks, hasLength(5));
      expect(weeks.first.first, LocalDate(2026, 11, 1));
      expect(weeks.last.last, LocalDate(2026, 12, 5));
      expect(weeks.every((week) => week.length == 7), isTrue);
    });

    test('월 시작일이 25일이면 10월 25일부터 11월 24일까지다', () {
      final period = MonthPeriod(2026, 11, startDay: 25);
      final weeks = calendarWeeks(period);
      expect(weeks.first.first, LocalDate(2026, 10, 25));
      expect(weeks.last.first, LocalDate(2026, 11, 22));
      expect(weeks.last.last, LocalDate(2026, 11, 28));
      final inPeriod = [
        for (final week in weeks)
          for (final day in week)
            if (period.contains(day)) day,
      ];
      expect(inPeriod, hasLength(period.days));
    });
  });

  group('목록', () {
    testWidgets('취소한 거래는 숨기고, 확인이 필요한 거래에 표시를 단다', (tester) async {
      final services = await createTestServices();
      final seed = await _seed(services);
      await pumpApp(tester, services, size: phone, location: '/transactions');

      expect(_key('row-${seed.tx['김밥천국']}'), findsOneWidget);
      expect(_key('row-${seed.tx['환불한 신발']}'), findsNothing);
      // 확인 필요 표시는 이마트 한 건에만 붙는다.
      final marked = find.textContaining('확인 필요', findRichText: true);
      expect(marked, findsOneWidget);
      expect(
        find.descendant(of: _key('row-${seed.tx['이마트']}'), matching: marked),
        findsOneWidget,
      );
      await disposeApp(tester, services);
    });

    testWidgets('빈 달에는 안내를 보인다', (tester) async {
      final services = await createTestServices();
      await pumpApp(tester, services, size: phone, location: '/transactions');
      expect(find.text('이 달의 내역이 없습니다'), findsOneWidget);
      expect(find.textContaining('입력창에'), findsOneWidget);
      await disposeApp(tester, services);
    });

    testWidgets('취소한 거래만 있는 달은 그렇게 알리고 보여 줄 수 있다', (tester) async {
      final services = await createTestServices();
      final cashId = (await services.repository.accounts(services.ledgerId))
          .single
          .id;
      final id = await services.repository.addTransaction(
        services.ledgerId,
        TransactionInput(
          type: TxType.expense,
          occurredOn: LocalDate(2026, 11, 3),
          amount: 9000,
          accountId: cashId,
          counterparty: '취소한 밥',
          canceled: true,
        ),
      );
      await pumpApp(tester, services, size: phone, location: '/transactions');
      expect(find.text('취소한 거래 1건만 있습니다'), findsOneWidget);

      await tester.tap(_key('show-canceled'));
      await tester.pumpAndSettle();
      expect(_key('row-$id'), findsOneWidget);
      expect(_key('filter-chip-canceled'), findsOneWidget);
      await disposeApp(tester, services);
    });
  });

  group('달력', () {
    testWidgets('날짜 칸에 그날의 수입과 지출 합계를 적는다', (tester) async {
      final services = await createTestServices();
      await _seed(services);
      await pumpApp(tester, services, size: phone, location: '/transactions');
      await tester.tap(_key('view-calendar'));
      await tester.pumpAndSettle();

      // 16일: 12,500 + 125,000. 취소한 50,000과 이체 100,000은 빠진다.
      expect(_text(tester, 'calendar-expense-2026-11-16'), '-13.8만');
      expect(_key('calendar-income-2026-11-16'), findsNothing);
      expect(_text(tester, 'calendar-income-2026-11-10'), '+300만');
      expect(_key('calendar-expense-2026-11-10'), findsNothing);
      expect(_text(tester, 'calendar-expense-2026-11-17'), '-5,500');
      // 거래가 없는 날에는 합계가 없다.
      expect(_key('calendar-day-2026-11-04'), findsOneWidget);
      expect(_key('calendar-expense-2026-11-04'), findsNothing);
      // 11월의 서른 날만 누를 수 있다.
      expect(_key('calendar-day-2026-11-30'), findsOneWidget);
      expect(_key('calendar-day-2026-12-01'), findsNothing);
      await disposeApp(tester, services);
    });

    testWidgets('좁은 창: 날짜를 누르면 아래에 그날의 거래가 뜬다', (tester) async {
      final services = await createTestServices();
      final seed = await _seed(services);
      await pumpApp(
        tester,
        services,
        size: largePhone,
        location: '/transactions',
      );
      await tester.tap(_key('view-calendar'));
      await tester.pumpAndSettle();

      // 처음에는 오늘(17일)의 거래가 보인다.
      expect(_text(tester, 'calendar-day-title'), '11월 17일 (화)');
      final scroll = find.descendant(
        of: _key('calendar-scroll'),
        matching: find.byType(Scrollable),
      );
      await tester.scrollUntilVisible(
        _key('row-${seed.tx['스타벅스']}'),
        100,
        scrollable: scroll.first,
      );

      await tester.scrollUntilVisible(
        _key('calendar-day-2026-11-16'),
        -100,
        scrollable: scroll.first,
      );
      await tester.tap(_key('calendar-day-2026-11-16'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        _key('row-${seed.tx['이체']}'),
        100,
        scrollable: scroll.first,
      );
      expect(_text(tester, 'calendar-day-title'), '11월 16일 (월)');
      expect(_text(tester, 'calendar-day-expense'), '-137,500원');
      expect(_key('row-${seed.tx['김밥천국']}'), findsOneWidget);
      expect(_key('row-${seed.tx['이마트']}'), findsOneWidget);
      expect(_key('row-${seed.tx['스타벅스']}'), findsNothing);

      // 거래를 누르면 편집 화면이 열린다.
      await tester.tap(_key('row-${seed.tx['김밥천국']}'));
      await tester.pumpAndSettle();
      expect(find.byType(TransactionEditor), findsOneWidget);
      expect(find.widgetWithText(TextFormField, '12,500'), findsOneWidget);
      await disposeApp(tester, services);
    });

    testWidgets('넓은 창: 날짜를 누르면 옆 칸에 그날의 거래가 뜬다', (tester) async {
      final services = await createTestServices();
      final seed = await _seed(services);
      await pumpApp(tester, services, size: desktop, location: '/transactions');
      await tester.tap(_key('view-calendar'));
      await tester.pumpAndSettle();

      // 칸이 넓으면 금액을 줄이지 않고 적는다.
      expect(_text(tester, 'calendar-income-2026-11-10'), '+3,000,000');
      expect(_text(tester, 'calendar-expense-2026-11-16'), '-137,500');

      await tester.tap(_key('calendar-day-2026-11-10'));
      await tester.pumpAndSettle();
      final pane = _key('calendar-day-pane');
      expect(pane, findsOneWidget);
      expect(
        find.descendant(of: pane, matching: _key('row-${seed.tx['회사']}')),
        findsOneWidget,
      );
      expect(_text(tester, 'calendar-day-income'), '+3,000,000원');
      // 달력은 왼쪽, 그날의 거래는 오른쪽에 있다.
      expect(
        tester.getTopLeft(pane).dx,
        greaterThan(tester.getTopRight(_key('calendar-day-2026-11-10')).dx),
      );

      await tester.tap(_key('calendar-day-2026-11-04'));
      await tester.pumpAndSettle();
      expect(find.text('이 날의 내역이 없습니다'), findsOneWidget);
      await disposeApp(tester, services);
    });

    testWidgets('월 시작일을 반영한다', (tester) async {
      final services = await createTestServices();
      await services.repository.setMonthStartDay(services.ledgerId, 25);
      await pumpApp(tester, services, size: desktop, location: '/transactions');
      await tester.tap(_key('view-calendar'));
      await tester.pumpAndSettle();

      // 오늘(11월 17일)이 든 기간은 10월 25일 – 11월 24일이다.
      expect(_key('calendar-day-2026-10-25'), findsOneWidget);
      expect(_key('calendar-day-2026-11-24'), findsOneWidget);
      expect(_key('calendar-day-2026-10-24'), findsNothing);
      expect(_key('calendar-day-2026-11-25'), findsNothing);
      await disposeApp(tester, services);
    });

    testWidgets('달력에서 날을 고르고 새 거래를 열면 그날로 채운다', (tester) async {
      final services = await createTestServices();
      await _seed(services);
      await pumpApp(tester, services, size: desktop, location: '/transactions');
      await tester.tap(_key('view-calendar'));
      await tester.pumpAndSettle();
      await tester.tap(_key('calendar-day-2026-11-04'));
      await tester.pumpAndSettle();
      await tester.tap(_key('new-transaction'));
      await tester.pumpAndSettle();
      expect(find.text('2026년 11월 4일 (수)'), findsOneWidget);
      await disposeApp(tester, services);
    });
  });

  group('필터', () {
    testWidgets('주소의 review=1은 확인 필요만 보여 준다', (tester) async {
      final services = await createTestServices();
      final seed = await _seed(services);
      await pumpApp(
        tester,
        services,
        size: phone,
        location: '/transactions?review=1',
      );
      expect(_key('row-${seed.tx['이마트']}'), findsOneWidget);
      expect(_key('row-${seed.tx['김밥천국']}'), findsNothing);
      expect(_key('row-${seed.tx['스타벅스']}'), findsNothing);
      expect(_key('filter-chip-review'), findsOneWidget);

      // 칩을 지우면 모두 보인다.
      await tester.tap(find.byTooltip('확인 필요만 필터 지우기'));
      await tester.pumpAndSettle();
      expect(_key('filter-chip-review'), findsNothing);
      expect(_key('row-${seed.tx['김밥천국']}'), findsOneWidget);

      // 같은 주소로 다시 들어오면 다시 걸린다.
      await _go(tester, '/transactions?review=1');
      expect(_key('filter-chip-review'), findsOneWidget);
      expect(_key('row-${seed.tx['김밥천국']}'), findsNothing);

      // 거래를 열었다 닫아도 필터는 남는다.
      await tester.tap(_key('row-${seed.tx['이마트']}'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('닫기'));
      await tester.pumpAndSettle();
      expect(_key('filter-chip-review'), findsOneWidget);
      await disposeApp(tester, services);
    });

    testWidgets('다른 탭에서 넘어와도 주소의 필터가 걸린다', (tester) async {
      final services = await createTestServices();
      final seed = await _seed(services);
      await pumpApp(tester, services, size: phone);
      final router = GoRouter.of(tester.element(_key('nav-bottom')));

      // 홈의 "확인 필요"를 누른 것처럼 옮겨 간다.
      router.go('/transactions?review=1');
      await tester.pumpAndSettle();
      expect(_key('filter-chip-review'), findsOneWidget);
      expect(_key('row-${seed.tx['이마트']}'), findsOneWidget);
      expect(_key('row-${seed.tx['김밥천국']}'), findsNothing);

      // 통계의 분류를 누르면 앞의 필터를 버리고 그 분류만 건다.
      router.go('/');
      await tester.pumpAndSettle();
      router.go('/transactions?category=${seed.categories['식비']}');
      await tester.pumpAndSettle();
      expect(_key('filter-chip-review'), findsNothing);
      expect(_key('row-${seed.tx['김밥천국']}'), findsOneWidget);
      expect(_key('row-${seed.tx['이마트']}'), findsNothing);
      await disposeApp(tester, services);
    });

    testWidgets('주소의 category는 그 분류만 보여 준다', (tester) async {
      final services = await createTestServices();
      final seed = await _seed(services);
      final food = seed.categories['식비']!;
      await pumpApp(
        tester,
        services,
        size: desktop,
        location: '/transactions?category=$food',
      );
      expect(_key('row-${seed.tx['김밥천국']}'), findsOneWidget);
      expect(_key('row-${seed.tx['이마트']}'), findsNothing);
      expect(_key('row-${seed.tx['회사']}'), findsNothing);
      expect(
        find.descendant(
          of: _key('filter-chip-category-$food'),
          matching: find.text('식비'),
        ),
        findsOneWidget,
      );
      await disposeApp(tester, services);
    });

    for (final (name, size) in [('좁음', phone), ('넓음', desktop)]) {
      testWidgets('$name 창: 필터를 골라 걸고 칩으로 하나씩 지운다', (tester) async {
        final services = await createTestServices();
        final seed = await _seed(services);
        await pumpApp(tester, services, size: size, location: '/transactions');

        await tester.tap(_key('filter-button'));
        await tester.pumpAndSettle();
        await tester.tap(_key('filter-type-expense'));
        await tester.pumpAndSettle();
        await _revealInFilter(tester, 'filter-min');
        await tester.enterText(_key('filter-min'), '10000');
        await tester.pumpAndSettle();
        await tester.tap(_key('filter-apply'));
        await tester.pumpAndSettle();

        // 지출이면서 1만 원 이상: 김밥천국, 이마트
        expect(_key('row-${seed.tx['김밥천국']}'), findsOneWidget);
        expect(_key('row-${seed.tx['이마트']}'), findsOneWidget);
        expect(_key('row-${seed.tx['스타벅스']}'), findsNothing);
        expect(_key('row-${seed.tx['회사']}'), findsNothing);
        expect(_key('filter-chip-type-expense'), findsOneWidget);
        expect(find.text('10,000원 이상'), findsOneWidget);

        // 금액 칩만 지우면 지출이 모두 보인다.
        await tester.tap(find.byTooltip('10,000원 이상 필터 지우기'));
        await tester.pumpAndSettle();
        expect(_key('filter-chip-amount'), findsNothing);
        expect(_key('filter-chip-type-expense'), findsOneWidget);
        expect(_key('row-${seed.tx['스타벅스']}'), findsOneWidget);
        expect(_key('row-${seed.tx['회사']}'), findsNothing);

        // 검색어와 함께 건다.
        await tester.enterText(_key('transaction-search'), '이마트');
        await tester.pumpAndSettle();
        expect(_key('row-${seed.tx['이마트']}'), findsOneWidget);
        expect(_key('row-${seed.tx['김밥천국']}'), findsNothing);
        await disposeApp(tester, services);
      });
    }

    testWidgets('걸리는 것이 없으면 안내하고 필터를 지울 수 있다', (tester) async {
      final services = await createTestServices();
      final seed = await _seed(services);
      await pumpApp(tester, services, size: phone, location: '/transactions');

      await tester.tap(_key('filter-button'));
      await tester.pumpAndSettle();
      await tester.tap(_key('filter-type-transfer'));
      await _revealInFilter(tester, 'filter-review');
      await tester.tap(_key('filter-review'));
      await tester.pumpAndSettle();
      await tester.tap(_key('filter-apply'));
      await tester.pumpAndSettle();

      expect(find.text('조건에 맞는 내역이 없습니다'), findsOneWidget);
      expect(find.text('이 달의 내역이 없습니다'), findsNothing);

      await tester.tap(_key('filter-clear-all'));
      await tester.pumpAndSettle();
      expect(_key('filter-chips'), findsNothing);
      expect(_key('row-${seed.tx['김밥천국']}'), findsOneWidget);
      await disposeApp(tester, services);
    });

    testWidgets('취소 포함을 켜면 취소한 거래도 보인다', (tester) async {
      final services = await createTestServices();
      final seed = await _seed(services);
      await pumpApp(tester, services, size: phone, location: '/transactions');

      await tester.tap(_key('filter-button'));
      await tester.pumpAndSettle();
      await _revealInFilter(tester, 'filter-canceled');
      await tester.tap(_key('filter-canceled'));
      await tester.pumpAndSettle();
      await tester.tap(_key('filter-apply'));
      await tester.pumpAndSettle();
      expect(_key('row-${seed.tx['환불한 신발']}'), findsOneWidget);
      expect(_key('filter-chip-canceled'), findsOneWidget);
      await disposeApp(tester, services);
    });
  });

  group('확인 필요', () {
    testWidgets('"확인함"을 누르면 확인한 거래가 된다', (tester) async {
      final services = await createTestServices();
      final seed = await _seed(services);
      final id = seed.tx['이마트']!;
      await pumpApp(
        tester,
        services,
        size: phone,
        location: '/transactions?id=$id',
      );
      expect(_key('editor-review-banner'), findsOneWidget);

      await tester.tap(_key('editor-confirm'));
      await tester.pumpAndSettle();

      final row = await _row(services, id);
      expect(row.status, TxStatus.confirmed);
      // 다른 값은 그대로다.
      expect(row.amount, 125000);
      expect(row.receiver, '이마트');
      expect(row.categoryId, seed.categories['생활']);
      // 목록으로 돌아오고 표시가 사라진다.
      expect(find.byType(TransactionEditor), findsNothing);
      expect(find.textContaining('확인 필요', findRichText: true), findsNothing);
      // 대기열에 올라간다.
      final outbox = await services.db.select(services.db.outbox).get();
      expect(outbox.where((o) => o.rowId == id), hasLength(1));
      await disposeApp(tester, services);
    });

    testWidgets('고쳐서 저장해도 확인한 거래가 된다', (tester) async {
      final services = await createTestServices();
      final seed = await _seed(services);
      final id = seed.tx['이마트']!;
      await pumpApp(
        tester,
        services,
        size: desktop,
        location: '/transactions?id=$id',
      );
      await tester.enterText(_key('editor-amount'), '99000');
      await tester.ensureVisible(_key('editor-save'));
      await tester.pumpAndSettle();
      await tester.tap(_key('editor-save'));
      await tester.pumpAndSettle();

      final row = await _row(services, id);
      expect(row.status, TxStatus.confirmed);
      expect(row.amount, 99000);
      await disposeApp(tester, services);
    });

    testWidgets('확인한 거래에는 알림이 없다', (tester) async {
      final services = await createTestServices();
      final seed = await _seed(services);
      await pumpApp(
        tester,
        services,
        size: phone,
        location: '/transactions?id=${seed.tx['김밥천국']}',
      );
      expect(find.byType(TransactionEditor), findsOneWidget);
      expect(_key('editor-review-banner'), findsNothing);
      expect(_key('editor-confirm'), findsNothing);
      await disposeApp(tester, services);
    });
  });

  group('일괄 수정', () {
    testWidgets('여러 행을 골라 분류를 바꾼다', (tester) async {
      final services = await createTestServices();
      final seed = await _seed(services);
      await pumpApp(tester, services, size: desktop, location: '/transactions');
      expect(_key('bulk-bar'), findsNothing);

      await tester.tap(_key('select-${seed.tx['김밥천국']}'));
      await tester.tap(_key('select-${seed.tx['스타벅스']}'));
      await tester.tap(_key('select-${seed.tx['회사']}'));
      await tester.pumpAndSettle();
      expect(_text(tester, 'bulk-count'), '3건 고름');

      await tester.tap(_key('bulk-category'));
      await tester.pumpAndSettle();
      final shopping = seed.categories['쇼핑']!;
      await tester.ensureVisible(_key('bulk-pick-category-$shopping'));
      await tester.pumpAndSettle();
      await tester.tap(_key('bulk-pick-category-$shopping'));
      await tester.pumpAndSettle();

      // 지출 두 건만 바뀌고, 수입에는 지출 분류를 붙이지 않는다.
      expect((await _row(services, seed.tx['김밥천국']!)).categoryId, shopping);
      expect((await _row(services, seed.tx['스타벅스']!)).categoryId, shopping);
      expect(
        (await _row(services, seed.tx['회사']!)).categoryId,
        seed.categories['급여'],
      );
      expect(find.textContaining("2건을 '쇼핑' 분류로 바꿨습니다"), findsOneWidget);
      expect(find.textContaining('1건은 그대로'), findsOneWidget);
      // 끝나면 고른 것이 풀린다.
      expect(_key('bulk-bar'), findsNothing);
      // 행마다 대기열에 올라간다.
      final outbox = await services.db.select(services.db.outbox).get();
      expect(outbox.where((o) => o.rowId == seed.tx['김밥천국']), hasLength(1));
      await disposeApp(tester, services);
    });

    testWidgets('모두 골라 자산을 바꾼다', (tester) async {
      final services = await createTestServices();
      final seed = await _seed(services);
      await pumpApp(tester, services, size: desktop, location: '/transactions');

      await tester.tap(_key('select-all'));
      await tester.pumpAndSettle();
      expect(_text(tester, 'bulk-count'), '5건 고름');

      await tester.tap(_key('bulk-account'));
      await tester.pumpAndSettle();
      await tester.tap(_key('bulk-pick-account-${seed.bankId}'));
      await tester.pumpAndSettle();

      for (final name in ['김밥천국', '이마트', '회사', '스타벅스']) {
        expect((await _row(services, seed.tx[name]!)).accountId, seed.bankId);
      }
      // 확인 상태는 그대로 둔다.
      expect(
        (await _row(services, seed.tx['이마트']!)).status,
        TxStatus.needsReview,
      );
      // 통장으로 보내는 이체는 통장에서 보낼 수 없어 그대로 둔다.
      final transfer = await _row(services, seed.tx['이체']!);
      expect(transfer.accountId, seed.cashId);
      expect(find.textContaining("4건을 '월급 통장' 자산으로 바꿨습니다"), findsOneWidget);
      await disposeApp(tester, services);
    });

    testWidgets('골라서 지운다', (tester) async {
      final services = await createTestServices();
      final seed = await _seed(services);
      await pumpApp(tester, services, size: desktop, location: '/transactions');

      await tester.tap(_key('select-${seed.tx['김밥천국']}'));
      await tester.tap(_key('select-${seed.tx['이체']}'));
      await tester.pumpAndSettle();
      await tester.tap(_key('bulk-delete'));
      await tester.pumpAndSettle();
      expect(find.text('거래 2건을 지울까요?'), findsOneWidget);
      await tester.tap(_key('bulk-delete-confirm'));
      await tester.pumpAndSettle();

      expect(await _deleted(services, seed.tx['김밥천국']!), isTrue);
      expect(await _deleted(services, seed.tx['이체']!), isTrue);
      expect(await _deleted(services, seed.tx['이마트']!), isFalse);
      expect(_key('row-${seed.tx['김밥천국']}'), findsNothing);
      expect(_key('row-${seed.tx['이마트']}'), findsOneWidget);
      await disposeApp(tester, services);
    });

    testWidgets('확인이 필요한 거래를 골라 한꺼번에 확인한다', (tester) async {
      final services = await createTestServices();
      final seed = await _seed(services);
      await pumpApp(tester, services, size: desktop, location: '/transactions');

      await tester.tap(_key('select-${seed.tx['김밥천국']}'));
      await tester.pumpAndSettle();
      // 확인할 것이 없으면 단추가 없다.
      expect(_key('bulk-confirm'), findsNothing);
      await tester.tap(_key('select-${seed.tx['이마트']}'));
      await tester.pumpAndSettle();
      await tester.tap(_key('bulk-confirm'));
      await tester.pumpAndSettle();

      expect(
        (await _row(services, seed.tx['이마트']!)).status,
        TxStatus.confirmed,
      );
      expect(find.text('1건을 확인했습니다.'), findsOneWidget);
      await disposeApp(tester, services);
    });

    testWidgets('좁은 창에는 고르는 칸이 없다', (tester) async {
      final services = await createTestServices();
      final seed = await _seed(services);
      await pumpApp(tester, services, size: phone, location: '/transactions');
      expect(_key('row-${seed.tx['김밥천국']}'), findsOneWidget);
      expect(_key('select-${seed.tx['김밥천국']}'), findsNothing);
      expect(_key('select-all'), findsNothing);
      await disposeApp(tester, services);
    });
  });

  group('거래 편집', () {
    testWidgets('상대방을 적으면 예전에 고른 분류를 제안한다', (tester) async {
      final services = await createTestServices();
      final seed = await _seed(services);
      final cafe = seed.categories['카페·간식']!;
      await services.repository.rememberCategory(
        services.ledgerId,
        '스타벅스',
        cafe,
      );
      await pumpApp(
        tester,
        services,
        size: phone,
        location: '/transactions?new=expense',
      );
      expect(_key('editor-suggest-category'), findsNothing);

      await tester.enterText(_key('editor-party'), '스타벅스 강남점');
      await tester.pumpAndSettle();
      expect(find.text('예전에 고른 분류: 카페·간식'), findsOneWidget);

      await tester.ensureVisible(_key('editor-suggest-category'));
      await tester.pumpAndSettle();
      await tester.tap(_key('editor-suggest-category'));
      await tester.pumpAndSettle();
      // 분류가 채워지고 제안은 사라진다.
      expect(_key('category-TxType.expense-$cafe'), findsOneWidget);
      expect(_key('editor-suggest-category'), findsNothing);

      // 모르는 상대방에는 제안하지 않는다.
      await tester.enterText(_key('editor-party'), '처음 가는 곳');
      await tester.pumpAndSettle();
      expect(_key('editor-suggest-category'), findsNothing);
      await disposeApp(tester, services);
    });

    testWidgets('이체를 고르면 받는 자산을 묻고 분류는 묻지 않는다', (tester) async {
      final services = await createTestServices();
      await _seed(services);
      await pumpApp(
        tester,
        services,
        size: phone,
        location: '/transactions?new=expense',
      );
      expect(_key('editor-party'), findsOneWidget);
      await tester.tap(find.widgetWithText(SegmentedButton<TxType>, '이체'));
      await tester.tap(find.text('이체'));
      await tester.pumpAndSettle();
      expect(find.text('받는 자산'), findsOneWidget);
      expect(find.text('보내는 자산'), findsOneWidget);
      expect(_key('editor-party'), findsNothing);
      await disposeApp(tester, services);
    });

    testWidgets('"반복으로 등록"은 반복 거래 화면에 거래 ID를 넘긴다', (tester) async {
      final services = await createTestServices();
      final seed = await _seed(services);
      final id = seed.tx['김밥천국']!;
      await pumpApp(
        tester,
        services,
        size: desktop,
        location: '/transactions?id=$id',
      );
      await tester.ensureVisible(_key('editor-recurring'));
      await tester.pumpAndSettle();
      await tester.tap(_key('editor-recurring'));
      await tester.pumpAndSettle();

      final screen = find.byType(RecurringScreen);
      expect(screen, findsOneWidget);
      expect(
        GoRouterState.of(tester.element(screen)).uri.toString(),
        '/recurring?from=$id',
      );
      await disposeApp(tester, services);
    });

    testWidgets('새 거래에는 "반복으로 등록"이 없다', (tester) async {
      final services = await createTestServices();
      await pumpApp(
        tester,
        services,
        size: phone,
        location: '/transactions?new=expense',
      );
      expect(find.byType(TransactionEditor), findsOneWidget);
      expect(_key('editor-recurring'), findsNothing);
      await disposeApp(tester, services);
    });

    testWidgets('창을 넓혀도 적던 내용이 남는다', (tester) async {
      final services = await createTestServices();
      await pumpApp(
        tester,
        services,
        size: phone,
        location: '/transactions?new=expense',
      );
      await tester.enterText(_key('editor-amount'), '4500');
      await tester.enterText(_key('editor-party'), '붕어빵');
      tester.view.physicalSize = desktop;
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextFormField, '4,500'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, '붕어빵'), findsOneWidget);
      await disposeApp(tester, services);
    });
  });

  group('칸이 좁아지는 너비에서도 넘치지 않는다', () {
    // 600: 두 칸이 가장 좁다. 840 · 1000: 넓은 창이지만 표를 그릴 자리가 없다.
    for (final width in [600.0, 840.0, 1000.0]) {
      for (final scale in [1.0, 2.0]) {
        testWidgets('${width.toInt()}dp 글자 ${(scale * 100).round()}%', (
          tester,
        ) async {
          final services = await createTestServices();
          final seed = await _seed(services);
          await pumpApp(
            tester,
            services,
            size: Size(width, 800),
            location: '/transactions?review=1',
            textScale: scale,
          );
          expect(tester.takeException(), isNull, reason: '목록');
          expect(_key('row-${seed.tx['이마트']}'), findsOneWidget);

          await tester.tap(_key('view-calendar'));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: '달력');

          await _go(tester, '/transactions?id=${seed.tx['이마트']}');
          expect(tester.takeException(), isNull, reason: '편집');
          await disposeApp(tester, services);
        });
      }
    }
  });

  group('네 화면 크기에서 넘치지 않는다', () {
    for (final (name, size) in [
      ('360×640', phone),
      ('412×915', largePhone),
      ('700×800', foldable),
      ('1280×800', desktop),
    ]) {
      for (final scale in [1.0, 2.0]) {
        testWidgets('$name 글자 ${(scale * 100).round()}%', (tester) async {
          final services = await createTestServices();
          final seed = await _seed(services);
          // 넘침은 시험에서 예외로 잡힌다.
          void check(String step) =>
              expect(tester.takeException(), isNull, reason: step);

          await pumpApp(
            tester,
            services,
            size: size,
            location: '/transactions?review=1',
            textScale: scale,
          );
          check('필터가 걸린 목록');

          await tester.tap(_key('filter-button'));
          await tester.pumpAndSettle();
          check('필터 고르기');
          await tester.tap(_key('filter-type-expense'));
          await tester.pumpAndSettle();
          await tester.ensureVisible(_key('filter-apply'));
          await tester.pumpAndSettle();
          await tester.tap(_key('filter-apply'));
          await tester.pumpAndSettle();
          check('칩 두 개');

          // 글자를 키우면 "모두 지우기"는 칩 줄을 옆으로 밀어야 나온다.
          await tester.ensureVisible(_key('filter-clear'));
          await tester.pumpAndSettle();
          await tester.tap(_key('filter-clear'));
          await tester.pumpAndSettle();
          check('목록');

          if (size == desktop) {
            await tester.tap(_key('select-all'));
            await tester.pumpAndSettle();
            check('일괄 수정 줄');
            await tester.tap(_key('bulk-clear'));
            await tester.pumpAndSettle();
          }

          await tester.tap(_key('view-calendar'));
          await tester.pumpAndSettle();
          check('달력');
          await tester.ensureVisible(_key('calendar-day-2026-11-16'));
          await tester.pumpAndSettle();
          await tester.tap(_key('calendar-day-2026-11-16'));
          await tester.pumpAndSettle();
          check('달력에서 고른 날');

          await _go(tester, '/transactions?id=${seed.tx['이마트']}');
          expect(find.byType(TransactionEditor), findsOneWidget);
          check('확인이 필요한 거래의 편집');

          await _go(tester, '/transactions?new=transfer');
          check('새 이체');
          await disposeApp(tester, services);
        });
      }
    }
  });
}
