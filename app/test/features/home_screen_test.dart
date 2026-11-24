import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gagyebu/app/app.dart';
import 'package:gagyebu/app/providers.dart';
import 'package:gagyebu/app/router.dart';
import 'package:gagyebu/app/theme/palettes.dart';
import 'package:gagyebu/core/local_date.dart';
import 'package:gagyebu/data/prefs/device_prefs.dart';
import 'package:gagyebu/domain/enums.dart';
import 'package:gagyebu/domain/month_summary.dart';
import 'package:gagyebu/features/budget/budget_screen.dart';
import 'package:gagyebu/features/common/summary_parts.dart';
import 'package:gagyebu/features/home/home_screen.dart';
import 'package:gagyebu/features/transactions/transactions_screen.dart';
import 'package:material_ui/material_ui.dart';

import 'home_stats_seed.dart';
import 'test_app.dart';

String textOf(WidgetTester tester, String key) =>
    tester.widget<Text>(find.byKey(ValueKey(key))).data!;

void main() {
  group('이번 달 지출과 수입 · 수지', () {
    testWidgets('지출이 가장 크고 그 아래에 수입과 수지가 있다', (tester) async {
      final services = await createTestServices();
      await Seed.filled(services);
      await pumpApp(tester, services, size: phone);

      expect(find.text('이번 달 지출'), findsOneWidget);
      expect(textOf(tester, 'total-expense'), '1,860,250원');
      expect(textOf(tester, 'total-income'), '3,000,000원');
      expect(textOf(tester, 'total-net'), '+1,139,750원');

      double fontSize(String key) =>
          tester.widget<Text>(find.byKey(ValueKey(key))).style!.fontSize!;
      // 가장 큰 글자는 테마가 정한 크기다(시스템에 맞춤 · 밝게 = 금융의 34).
      expect(fontSize('total-expense'), 34);
      expect(fontSize('total-income'), lessThan(fontSize('total-expense')));
      expect(fontSize('total-net'), lessThan(fontSize('total-expense')));

      final expense = tester.getRect(
        find.byKey(const ValueKey('total-expense')),
      );
      final income = tester.getRect(find.byKey(const ValueKey('total-income')));
      final net = tester.getRect(find.byKey(const ValueKey('total-net')));
      expect(income.top, greaterThanOrEqualTo(expense.bottom));
      expect(net.top, greaterThanOrEqualTo(expense.bottom));

      // 지난달(40,000원)과 견준 한 줄
      expect(find.text('지난달보다 1,820,250원 더 썼습니다'), findsOneWidget);
      await disposeApp(tester, services);
    });

    testWidgets('다른 달을 보면 그 달의 이름으로 부른다', (tester) async {
      final services = await createTestServices();
      await Seed.filled(services);
      await pumpApp(tester, services, size: phone);
      await tester.tap(find.byTooltip('이전 달'));
      await tester.pumpAndSettle();
      expect(find.text('10월 지출'), findsOneWidget);
      expect(find.text('이번 달 지출'), findsNothing);
      expect(textOf(tester, 'total-expense'), '40,000원');
      await disposeApp(tester, services);
    });
  });

  group('예산 진행', () {
    testWidgets('전체 예산을 정하지 않았으면 막대가 없다', (tester) async {
      final services = await createTestServices();
      await Seed.filled(services);
      await pumpApp(tester, services, size: phone);
      expect(find.byKey(const ValueKey('home-budget')), findsNothing);
      expect(find.text('예산'), findsNothing);
      await disposeApp(tester, services);
    });

    testWidgets('다른 달의 예산은 보이지 않는다', (tester) async {
      final services = await createTestServices();
      final seed = await Seed.filled(services);
      await seed.setTotalBudget(900000, month: '2026-10');
      await pumpApp(tester, services, size: phone);
      expect(find.byKey(const ValueKey('home-budget')), findsNothing);
      await disposeApp(tester, services);
    });

    testWidgets('전체 예산이 있으면 쓴 비율과 남은 돈을 보여 준다', (tester) async {
      final services = await createTestServices();
      final seed = await Seed.filled(services);
      await seed.setTotalBudget(3000000);
      await pumpApp(tester, services, size: phone);

      final card = find.byKey(const ValueKey('home-budget'));
      expect(card, findsOneWidget);
      // 1,860,250 / 3,000,000 = 62%
      expect(textOf(tester, 'home-budget-ratio'), '3,000,000원 중 62%');
      expect(textOf(tester, 'home-budget-status'), '1,139,750원 남았습니다');
      // 11월은 30일이고 오늘은 17일이다: 13일 남았다.
      expect(find.text('하루 87,673원씩 쓸 수 있습니다 · 13일 남음'), findsOneWidget);
      final bar = tester.widget<LinearProgressIndicator>(
        find.descendant(
          of: card,
          matching: find.byType(LinearProgressIndicator),
        ),
      );
      expect(bar.value, closeTo(0.62, 0.005));
      expect(bar.color, quietLight.accent);
      // 막대의 값을 글로도 읽어 준다.
      expect(
        find.bySemanticsLabel(
          RegExp(r'예산 3,000,000원 가운데 1,860,250원 사용, 62%\. 1,139,750원 남았습니다'),
        ),
        findsOneWidget,
      );
      // 예산 카드는 수입 · 수지 아래, 분류별 지출 위에 있다.
      expect(
        tester.getTopLeft(card).dy,
        greaterThan(
          tester.getBottomLeft(find.byKey(const ValueKey('total-net'))).dy,
        ),
      );
      expect(
        tester.getBottomLeft(card).dy,
        lessThan(tester.getTopLeft(find.text('분류별 지출')).dy),
      );

      await tester.tap(card);
      await tester.pumpAndSettle();
      expect(find.byType(BudgetScreen), findsOneWidget);
      expect(currentUri(tester).path, '/budget');
      await disposeApp(tester, services);
    });

    testWidgets('예산을 넘기면 경고색으로 넘긴 금액을 보여 준다', (tester) async {
      final services = await createTestServices();
      final seed = await Seed.filled(services);
      await seed.setTotalBudget(1800000);
      await pumpApp(tester, services, size: phone);

      expect(textOf(tester, 'home-budget-status'), '60,250원 넘음');
      final status = tester.widget<Text>(
        find.byKey(const ValueKey('home-budget-status')),
      );
      expect(status.style!.color, quietLight.warn);
      final bar = tester.widget<LinearProgressIndicator>(
        find.descendant(
          of: find.byKey(const ValueKey('home-budget')),
          matching: find.byType(LinearProgressIndicator),
        ),
      );
      expect(bar.value, 1);
      expect(bar.color, quietLight.warn);
      // 색만으로 알리지 않는다.
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('home-budget')),
          matching: find.byIcon(Icons.warning_amber_rounded),
        ),
        findsOneWidget,
      );
      expect(find.textContaining('쓸 수 있습니다'), findsNothing);
      await disposeApp(tester, services);
    });

    testWidgets('예산을 정하면 바로 나타나고, 지난 달에는 남은 날을 말하지 않는다', (tester) async {
      final services = await createTestServices();
      final seed = await Seed.filled(services);
      await pumpApp(tester, services, size: phone);
      expect(find.byKey(const ValueKey('home-budget')), findsNothing);

      await seed.setTotalBudget(3000000);
      await seed.setTotalBudget(100000, month: '2026-10');
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('home-budget')), findsOneWidget);

      await tester.tap(find.byTooltip('이전 달'));
      await tester.pumpAndSettle();
      expect(textOf(tester, 'home-budget-ratio'), '100,000원 중 40%');
      expect(textOf(tester, 'home-budget-status'), '60,000원 남았습니다');
      expect(find.textContaining('쓸 수 있습니다'), findsNothing);
      await disposeApp(tester, services);
    });
  });

  group('확인 필요', () {
    testWidgets('확인할 것이 없으면 보이지 않는다', (tester) async {
      final services = await createTestServices();
      final seed = await Seed.empty(services);
      await seed.add(12000, LocalDate(2026, 11, 3), party: '김밥천국');
      await pumpApp(tester, services, size: phone);
      expect(find.byKey(const ValueKey('home-needs-review')), findsNothing);
      expect(find.textContaining('확인 필요'), findsNothing);
      await disposeApp(tester, services);
    });

    testWidgets('있으면 건수를 보여 주고, 누르면 걸러 낸 내역으로 간다', (tester) async {
      final services = await createTestServices();
      final seed = await Seed.filled(services);
      await seed.add(
        3300,
        LocalDate(2026, 11, 13),
        party: '택시',
        status: TxStatus.needsReview,
      );
      // 다른 달의 것은 이 달의 건수에 들지 않는다.
      await seed.add(
        900,
        LocalDate(2026, 10, 30),
        party: '지난달 택시',
        status: TxStatus.needsReview,
      );
      await pumpApp(tester, services, size: phone);

      final chip = find.byKey(const ValueKey('home-needs-review'));
      expect(chip, findsOneWidget);
      expect(find.text('확인 필요 2건'), findsOneWidget);
      // 경고색 글자와 옅은 경고색 바탕
      expect(
        tester.widget<Text>(find.text('확인 필요 2건')).style!.color,
        quietLight.warn,
      );
      expect(
        tester
            .widget<Material>(
              find.ancestor(of: chip, matching: find.byType(Material)).first,
            )
            .color,
        quietLight.warnSoft,
      );
      // 누름 영역은 48dp 이상이다.
      expect(tester.getSize(chip).height, greaterThanOrEqualTo(48));

      await tester.tap(chip);
      await tester.pumpAndSettle();
      expect(find.byType(TransactionsScreen), findsOneWidget);
      expect(currentUri(tester).toString(), '/transactions?review=1');
      await disposeApp(tester, services);
    });
  });

  group('분류별 지출과 최근 내역', () {
    testWidgets('분류는 금액이 큰 다섯 개를 분류의 색과 아이콘으로 보여 준다', (tester) async {
      final services = await createTestServices();
      final seed = await Seed.filled(services);
      await pumpApp(tester, services, size: desktop);

      final rows = tester
          .widgetList<CategoryBarRow>(find.byType(CategoryBarRow))
          .toList();
      // 여섯 분류 가운데 가장 작은 교통(1,250원)은 빠진다.
      expect(
        [for (final r in rows) (r.name, r.amount)],
        [
          ('경조사·선물', 1234500),
          ('주거·통신', 550000),
          ('쇼핑', 50000),
          ('식비', 20000),
          ('분류 없음', 4500),
        ],
      );
      // 색은 분류의 자리를 따른다(금액 순위가 아니다): 식비 0, 주거·통신 3, 쇼핑 5,
      // 경조사·선물 9.
      expect([for (final r in rows) r.visual?.index], [9, 3, 5, 0, null]);
      expect(rows[3].visual!.icon, Icons.restaurant);
      expect(rows[0].visual!.icon, Icons.card_giftcard);

      // 줄 전체를 값으로 읽어 준다.
      expect(find.bySemanticsLabel('식비 20,000원, 1%'), findsOneWidget);

      await tester.tap(
        find.byKey(ValueKey('home-category-${seed.categoryIds['식비']}')),
      );
      await tester.pumpAndSettle();
      expect(
        currentUri(tester).toString(),
        '/transactions?category=${seed.categoryIds['식비']}',
      );
      await disposeApp(tester, services);
    });

    testWidgets('최근 내역은 다섯 건이다', (tester) async {
      final services = await createTestServices();
      await Seed.filled(services);
      await pumpApp(tester, services, size: desktop);
      expect(find.text('최근 내역'), findsOneWidget);
      final rows = find.byWidgetPredicate((w) {
        final key = w.key;
        return key is ValueKey<String> && key.value.startsWith('home-recent-');
      });
      expect(rows, findsNWidgets(5));
      // 최근 순: 16일, 14일, …
      expect(
        find.descendant(of: rows.at(0), matching: find.text('분류없는가게')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: rows.at(1),
          matching: find.textContaining('이름이 아주아주 긴'),
        ),
        findsOneWidget,
      );
      // 금액은 부호와 함께 쓴다.
      expect(
        find.descendant(of: rows.at(0), matching: find.text('-4,500원')),
        findsOneWidget,
      );
      // 누르면 그 거래를 내역에서 연다.
      await tester.tap(rows.at(0));
      await tester.pumpAndSettle();
      expect(currentUri(tester).path, '/transactions');
      expect(currentUri(tester).queryParameters['id'], isNotEmpty);
      await disposeApp(tester, services);
    });
  });

  group('배치', () {
    testWidgets('휴대폰은 한 줄로 쌓는다', (tester) async {
      final services = await createTestServices();
      final seed = await Seed.filled(services);
      await seed.setTotalBudget(3000000);
      await pumpApp(tester, services, size: largePhone);
      final expense = tester.getRect(
        find.byKey(const ValueKey('total-expense')),
      );
      final budget = tester.getRect(find.byKey(const ValueKey('home-budget')));
      final review = tester.getRect(
        find.byKey(const ValueKey('home-needs-review')),
      );
      final categories = tester.getRect(find.text('분류별 지출'));
      expect(budget.top, greaterThan(expense.bottom));
      expect(review.top, greaterThan(budget.bottom));
      expect(categories.top, greaterThan(review.bottom));
      // 최근 내역은 분류 카드 아래에 있어 내려야 보인다.
      await tester.scrollUntilVisible(
        find.text('최근 내역'),
        200,
        scrollable: find
            .descendant(
              of: find.byType(HomeScreen),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(
        tester.getRect(find.text('최근 내역')).left,
        lessThan(largePhone.width / 2),
      );
      await disposeApp(tester, services);
    });

    testWidgets('PC는 두 칸으로 나눈다', (tester) async {
      final services = await createTestServices();
      final seed = await Seed.filled(services);
      await seed.setTotalBudget(3000000);
      await pumpApp(tester, services, size: desktop);
      final categories = tester.getRect(find.text('분류별 지출'));
      final recent = tester.getRect(find.text('최근 내역'));
      final expense = tester.getRect(
        find.byKey(const ValueKey('total-expense')),
      );
      // 최근 내역은 오른쪽 칸의 맨 위, 큰 금액과 같은 높이에서 시작한다.
      expect(recent.left, greaterThan(categories.right));
      expect(recent.top, lessThan(categories.top));
      expect((recent.top - expense.top).abs(), lessThan(40));
      await disposeApp(tester, services);
    });
  });

  group('빈 상태', () {
    for (final (name, size) in fourSizes) {
      testWidgets('$name: 내역이 없으면 안내를 보여 준다', (tester) async {
        final services = await createTestServices();
        await pumpApp(tester, services, size: size);
        expect(find.byKey(const ValueKey('home-empty')), findsOneWidget);
        expect(find.textContaining('아직 내역이 없습니다'), findsOneWidget);
        expect(find.textContaining('입력창에'), findsOneWidget);
        // 합계는 0원으로 보인다.
        expect(textOf(tester, 'total-expense'), '0원');
        expect(textOf(tester, 'total-income'), '0원');
        expect(textOf(tester, 'total-net'), '0원');
        expect(find.text('분류별 지출'), findsNothing);
        expect(find.text('최근 내역'), findsNothing);
        expect(tester.takeException(), isNull);
        await disposeApp(tester, services);
      });
    }

    testWidgets('내역이 생기면 안내가 사라진다', (tester) async {
      final services = await createTestServices();
      final seed = await Seed.empty(services);
      await pumpApp(tester, services, size: desktop);
      expect(find.byKey(const ValueKey('home-empty')), findsOneWidget);
      await seed.add(12000, LocalDate(2026, 11, 3), party: '김밥천국');
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('home-empty')), findsNothing);
      expect(find.text('최근 내역'), findsOneWidget);
      expect(textOf(tester, 'total-expense'), '12,000원');
      await disposeApp(tester, services);
    });
  });

  group('오류', () {
    testWidgets('집계를 못 읽으면 예외 문구 없이 알리고 다시 해 볼 수 있다', (tester) async {
      final services = await createTestServices();
      await Seed.filled(services);
      var fail = true;
      tester.view.physicalSize = phone;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appServicesProvider.overrideWithValue(services),
            clockProvider.overrideWithValue(() => testNow),
            devicePrefsProvider.overrideWithValue(
              MemoryDevicePrefs({'onboarding.done': 'true'}),
            ),
            monthSummaryProvider.overrideWith(
              (ref) => fail
                  ? Stream<MonthSummary>.error(StateError('SqliteException(1)'))
                  : services.repository.watchMonthSummary(
                      services.ledgerId,
                      ref.watch(selectedPeriodProvider),
                      today: ref.watch(todayProvider),
                    ),
            ),
          ],
          child: GagyebuApp(router: createRouter()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('이 달의 집계를 불러오지 못했습니다'), findsOneWidget);
      expect(find.textContaining('SqliteException'), findsNothing);
      expect(find.textContaining('Bad state'), findsNothing);
      expect(find.byKey(const ValueKey('total-expense')), findsNothing);
      // 달을 고르는 줄은 그대로 있다.
      expect(find.byKey(const ValueKey('period-label')), findsOneWidget);

      fail = false;
      await tester.tap(find.text('다시 시도'));
      await tester.pumpAndSettle();
      expect(textOf(tester, 'total-expense'), '1,860,250원');
      expect(find.textContaining('불러오지 못했습니다'), findsNothing);
      await disposeApp(tester, services);
    });
  });

  group('네 화면 크기에서 넘치지 않는다', () {
    for (final (name, size) in fourSizes) {
      for (final scale in [1.0, 2.0]) {
        testWidgets('$name, 글자 ${(scale * 100).round()}%', (tester) async {
          final services = await createTestServices();
          final seed = await Seed.filled(services);
          await seed.setTotalBudget(1800000);
          // 자릿수가 많은 금액
          await seed.add(
            123456789,
            LocalDate(2026, 11, 15),
            party: '아주 큰 지출',
            category: '금융·보험',
          );
          await pumpApp(tester, services, size: size, textScale: scale);
          expect(find.byKey(const ValueKey('home-budget')), findsOneWidget);
          expect(
            find.byKey(const ValueKey('home-needs-review')),
            findsOneWidget,
          );
          await expectNoOverflowWhileScrolling(tester, HomeScreen);
          await disposeApp(tester, services);
        });
      }
    }
  });
}
