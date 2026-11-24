import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gagyebu/app/app.dart';
import 'package:gagyebu/app/providers.dart';
import 'package:gagyebu/app/router.dart';
import 'package:gagyebu/app/theme/palettes.dart';
import 'package:gagyebu/core/local_date.dart';
import 'package:gagyebu/domain/month_period.dart';
import 'package:gagyebu/features/common/summary_parts.dart';
import 'package:gagyebu/features/stats/charts.dart';
import 'package:gagyebu/features/stats/narrative_provider.dart';
import 'package:gagyebu/features/stats/stats_screen.dart';
import 'package:gagyebu/features/transactions/transactions_screen.dart';
import 'package:material_ui/material_ui.dart';

import 'home_stats_seed.dart';
import 'test_app.dart';

/// 총평을 [narratives](달 → 문장)로 바꿔 끼워 통계 화면을 띄운다. 총평을 물어본 달을
/// [asked]에 적는다.
Future<void> pumpStatsWithNarrative(
  WidgetTester tester,
  AppServices services, {
  required Map<String, String?> narratives,
  List<String>? asked,
  Size size = phone,
  double textScale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appServicesProvider.overrideWithValue(services),
        clockProvider.overrideWithValue(() => testNow),
        monthNarrativeProvider.overrideWith((ref, period) async {
          asked?.add(period.key);
          return narratives[period.key];
        }),
      ],
      child: GagyebuApp(router: createRouter(initialLocation: '/stats')),
    ),
  );
  await tester.pumpAndSettle();
}

Finder _scrollable() => find
    .descendant(of: find.byType(StatsScreen), matching: find.byType(Scrollable))
    .first;

Future<void> _show(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(finder, 200, scrollable: _scrollable());
  await tester.pumpAndSettle();
}

void main() {
  test('막대 위의 짧은 금액', () {
    expect(compactAmount(0), '0');
    expect(compactAmount(9500), '9,500');
    expect(compactAmount(10000), '1만');
    expect(compactAmount(74500), '7.5만');
    expect(compactAmount(120000), '12만');
    expect(compactAmount(1234500), '123만');
    expect(compactAmount(12345000), '1,235만');
    expect(compactAmount(123456789), '1.2억');
    expect(compactAmount(-74500), '-7.5만');
  });

  group('분류 비중', () {
    testWidgets('분류의 색으로 그린 막대와 금액 · 비중을 보여 준다', (tester) async {
      final services = await createTestServices();
      await Seed.filled(services);
      await pumpApp(tester, services, size: desktop, location: '/stats');

      expect(find.text('분류별 지출 · 1,860,250원'), findsOneWidget);
      final rows = tester
          .widgetList<CategoryBarRow>(find.byType(CategoryBarRow))
          .toList();
      // 홈과 달리 모든 분류를 보여 준다.
      expect(
        [for (final r in rows) r.name],
        ['경조사·선물', '주거·통신', '쇼핑', '식비', '분류 없음', '교통'],
      );
      expect(rows.first.ratio, closeTo(1234500 / 1860250, 1e-9));
      expect(
        rows.fold<int>(0, (sum, r) => sum + r.amount),
        Seed.novemberExpense,
      );
      // 막대의 색은 분류의 자리에서 온다: 경조사·선물은 열 번째(9), 교통은 세 번째(2).
      final bars = tester
          .widgetList<LinearProgressIndicator>(
            find.descendant(
              of: find.byType(CategoryBarRow),
              matching: find.byType(LinearProgressIndicator),
            ),
          )
          .toList();
      expect(bars.first.color, categoryColorsLight[9]);
      expect(bars.last.color, categoryColorsLight[2]);
      // 막대의 값을 글로 읽어 준다.
      expect(find.bySemanticsLabel('경조사·선물 1,234,500원, 66%'), findsOneWidget);
      expect(find.bySemanticsLabel('교통 1,250원, 0%'), findsOneWidget);
      await disposeApp(tester, services);
    });

    testWidgets('분류를 누르면 그 분류로 거른 내역으로 간다', (tester) async {
      final services = await createTestServices();
      final seed = await Seed.filled(services);
      await pumpApp(tester, services, size: phone, location: '/stats');
      final shopping = seed.categoryIds['쇼핑']!;
      await tester.tap(find.byKey(ValueKey('stats-category-$shopping')));
      await tester.pumpAndSettle();
      expect(find.byType(TransactionsScreen), findsOneWidget);
      expect(currentUri(tester).toString(), '/transactions?category=$shopping');
      await disposeApp(tester, services);
    });

    testWidgets('분류가 없는 줄은 누를 수 없다', (tester) async {
      final services = await createTestServices();
      await Seed.filled(services);
      await pumpApp(tester, services, size: desktop, location: '/stats');
      final row = tester.widget<CategoryBarRow>(
        find.byKey(const ValueKey('stats-category-none')),
      );
      expect(row.onTap, isNull);
      await disposeApp(tester, services);
    });
  });

  group('날짜별 추이', () {
    testWidgets('막대와 함께 값을 읽어 주는 설명이 있다', (tester) async {
      final services = await createTestServices();
      await Seed.filled(services);
      await pumpApp(tester, services, size: desktop, location: '/stats');
      expect(find.text('날짜별 지출'), findsOneWidget);
      // 지출이 있던 날: 1, 3, 5, 12, 14, 16일
      expect(
        find.bySemanticsLabel(
          '날짜별 지출 막대 그림. 지출이 있는 날은 6일이고, '
          '가장 많은 날은 11월 14일 (토) 1,234,500원입니다.',
        ),
        findsOneWidget,
      );
      // 17일이 지났고 지출이 있던 날이 6일이다.
      expect(
        find.text(
          '가장 많이 쓴 날은 11월 14일 (토) 1,234,500원입니다. '
          '하루 평균은 109,426원, 무지출은 11일입니다.',
        ),
        findsOneWidget,
      );
      await disposeApp(tester, services);
    });
  });

  group('최근 6개월 추이', () {
    testWidgets('보고 있는 달까지 여섯 달의 지출을 막대로 그린다', (tester) async {
      final services = await createTestServices();
      await Seed.filled(services);
      await pumpApp(tester, services, size: desktop, location: '/stats');

      final card = find.byKey(const ValueKey('stats-trend'));
      expect(card, findsOneWidget);
      expect(find.text('최근 6개월 지출'), findsOneWidget);
      // 여섯 달의 값을 글로 읽어 준다. 5월 31일의 999원은 여섯 달 밖이다.
      expect(
        find.bySemanticsLabel(
          '최근 6개월 지출 막대 그림. 6월 120,000원, 7월 0원, 8월 0원, '
          '9월 300,000원, 10월 40,000원, 11월 1,860,250원.',
        ),
        findsOneWidget,
      );
      // 달 이름과 막대 위의 짧은 금액
      for (final label in ['6월', '7월', '8월', '9월', '10월', '11월']) {
        expect(
          find.descendant(of: card, matching: find.text(label)),
          findsOneWidget,
        );
      }
      for (final label in ['12만', '30만', '4만', '186만']) {
        expect(
          find.descendant(of: card, matching: find.text(label)),
          findsOneWidget,
        );
      }
      // 막대의 높이는 값에 비례하고, 0원인 달은 막대가 없다.
      double barHeight(String month) => tester
          .getSize(
            find.descendant(
              of: find.byKey(ValueKey('trend-bar-$month')),
              matching: find.byType(DecoratedBox),
            ),
          )
          .height;
      expect(barHeight('2026-11'), closeTo(120, 1.5));
      expect(barHeight('2026-09'), closeTo(120 * 300000 / 1860250, 1));
      expect(barHeight('2026-06'), closeTo(120 * 120000 / 1860250, 1));
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('trend-bar-2026-07')),
          matching: find.byType(DecoratedBox),
        ),
        findsNothing,
      );
      // 보고 있는 달만 진하게 그린다.
      Color barColor(String month) =>
          (tester
                      .widget<DecoratedBox>(
                        find.descendant(
                          of: find.byKey(ValueKey('trend-bar-$month')),
                          matching: find.byType(DecoratedBox),
                        ),
                      )
                      .decoration
                  as BoxDecoration)
              .color!;
      expect(barColor('2026-11'), quietLight.expense);
      expect(barColor('2026-09').a, lessThan(1));
      expect(
        find.text('여섯 달 가운데 가장 많이 쓴 달은 11월(1,860,250원)입니다.'),
        findsOneWidget,
      );
      await disposeApp(tester, services);
    });

    testWidgets('달을 넘기면 그 달까지의 여섯 달로 바뀐다', (tester) async {
      final services = await createTestServices();
      await Seed.filled(services);
      await pumpApp(tester, services, size: desktop, location: '/stats');
      await tester.tap(find.byTooltip('이전 달'));
      await tester.pumpAndSettle();
      expect(
        find.bySemanticsLabel(
          '최근 6개월 지출 막대 그림. 5월 999원, 6월 120,000원, 7월 0원, 8월 0원, '
          '9월 300,000원, 10월 40,000원.',
        ),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('trend-bar-2026-11')), findsNothing);
      await disposeApp(tester, services);
    });

    testWidgets('거래를 더하면 막대가 따라 바뀐다', (tester) async {
      final services = await createTestServices();
      final seed = await Seed.filled(services);
      await pumpApp(tester, services, size: desktop, location: '/stats');
      await seed.add(500000, LocalDate(2026, 8, 3), party: '팔월 가게');
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel(RegExp('8월 500,000원')), findsOneWidget);
      await disposeApp(tester, services);
    });

    testWidgets('여섯 달 동안 아무것도 없으면 안내를 보여 준다', (tester) async {
      final services = await createTestServices();
      await pumpApp(tester, services, size: desktop, location: '/stats');
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('stats-trend')),
          matching: find.text('지출이 없습니다'),
        ),
        findsOneWidget,
      );
      expect(find.byType(TrendBars), findsNothing);
      await disposeApp(tester, services);
    });
  });

  group('상대방과 큰 지출', () {
    testWidgets('상대방 상위 5와 큰 지출 5를 보여 준다', (tester) async {
      final services = await createTestServices();
      await Seed.filled(services);
      await pumpApp(tester, services, size: desktop, location: '/stats');
      expect(find.text('많이 쓴 곳'), findsOneWidget);
      expect(find.text('큰 지출'), findsOneWidget);
      // 김밥천국은 두 건을 합쳐 20,000원이다.
      expect(find.text('2건'), findsOneWidget);
      expect(find.text('20,000원'), findsWidgets);
      // 큰 지출의 금액에는 부호가 붙는다.
      expect(find.text('-1,234,500원'), findsOneWidget);
      expect(find.text('-550,000원'), findsOneWidget);
      // 여섯 번째로 큰 지출(버스 1,250원)은 큰 지출에 없다.
      expect(find.text('-1,250원'), findsNothing);

      await tester.tap(find.text('-550,000원'));
      await tester.pumpAndSettle();
      expect(currentUri(tester).path, '/transactions');
      expect(currentUri(tester).queryParameters['id'], isNotEmpty);
      await disposeApp(tester, services);
    });
  });

  group('지출 · 수입 전환', () {
    testWidgets('수입으로 바꾸면 모든 칸이 수입을 보여 준다', (tester) async {
      final services = await createTestServices();
      await Seed.filled(services);
      await pumpApp(tester, services, size: desktop, location: '/stats');
      await tester.tap(find.byKey(const ValueKey('stats-flow-income')));
      await tester.pumpAndSettle();

      expect(find.text('분류별 수입 · 3,000,000원'), findsOneWidget);
      expect(find.text('날짜별 수입'), findsOneWidget);
      expect(find.text('최근 6개월 수입'), findsOneWidget);
      expect(find.text('많이 받은 곳'), findsOneWidget);
      expect(find.text('큰 수입'), findsOneWidget);
      expect(find.text('날짜별 지출'), findsNothing);

      final row = tester.widget<CategoryBarRow>(find.byType(CategoryBarRow));
      expect((row.name, row.amount, row.ratio), ('급여', 3000000, 1.0));
      // 수입 분류의 자리는 수입 분류끼리 센다: 급여가 첫 번째다.
      expect(row.visual!.index, 0);
      expect(
        find.bySemanticsLabel(
          '최근 6개월 수입 막대 그림. 6월 0원, 7월 0원, 8월 0원, '
          '9월 2,500,000원, 10월 0원, 11월 3,000,000원.',
        ),
        findsOneWidget,
      );
      expect(
        find.text('가장 많이 받은 날은 11월 10일 (화) 3,000,000원입니다.'),
        findsOneWidget,
      );
      expect(find.text('+3,000,000원'), findsOneWidget);
      expect(find.text('(주)회사'), findsWidgets);

      // 다시 지출로
      await tester.tap(find.byKey(const ValueKey('stats-flow-expense')));
      await tester.pumpAndSettle();
      expect(find.text('날짜별 지출'), findsOneWidget);
      expect(find.text('분류별 지출 · 1,860,250원'), findsOneWidget);
      await disposeApp(tester, services);
    });

    testWidgets('수입이 없으면 칸마다 안내를 보여 준다', (tester) async {
      final services = await createTestServices();
      await pumpApp(tester, services, size: desktop, location: '/stats');
      expect(find.text('지출이 없습니다'), findsNWidgets(5));
      await tester.tap(find.byKey(const ValueKey('stats-flow-income')));
      await tester.pumpAndSettle();
      expect(find.text('수입이 없습니다'), findsNWidgets(5));
      await disposeApp(tester, services);
    });
  });

  group('총평', () {
    testWidgets('이번 달에는 총평을 묻지도 그리지도 않는다', (tester) async {
      final services = await createTestServices();
      await Seed.filled(services);
      final asked = <String>[];
      await pumpStatsWithNarrative(
        tester,
        services,
        narratives: {'2026-11': '이번 달의 총평.', '2026-10': '10월의 총평입니다.'},
        asked: asked,
      );
      expect(find.byKey(const ValueKey('stats-narrative')), findsNothing);
      expect(asked, isEmpty);
      await disposeApp(tester, services);
    });

    testWidgets('지난달을 보면 맨 위에 보여 준다', (tester) async {
      final services = await createTestServices();
      await Seed.filled(services);
      final asked = <String>[];
      await pumpStatsWithNarrative(
        tester,
        services,
        narratives: {'2026-10': '10월에는 지난달보다 26만 원 덜 썼습니다.'},
        asked: asked,
      );
      await tester.tap(find.byTooltip('이전 달'));
      await tester.pumpAndSettle();

      expect(asked, ['2026-10']);
      final card = find.byKey(const ValueKey('stats-narrative'));
      expect(card, findsOneWidget);
      expect(find.text('10월 총평'), findsOneWidget);
      expect(find.text('10월에는 지난달보다 26만 원 덜 썼습니다.'), findsOneWidget);
      // 분류 비중보다 위에 있다.
      expect(
        tester.getBottomLeft(card).dy,
        lessThanOrEqualTo(tester.getTopLeft(find.text('분류별 지출 · 40,000원')).dy),
      );

      // 다음 달(이번 달)로 돌아오면 사라진다.
      await tester.tap(find.byTooltip('다음 달'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('stats-narrative')), findsNothing);
      await disposeApp(tester, services);
    });

    testWidgets('총평이 없으면(null) 아무것도 그리지 않는다', (tester) async {
      final services = await createTestServices();
      await Seed.filled(services);
      await pumpStatsWithNarrative(tester, services, narratives: const {});
      await tester.tap(find.byTooltip('이전 달'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('stats-narrative')), findsNothing);
      expect(find.textContaining('총평'), findsNothing);
      expect(find.text('분류별 지출 · 40,000원'), findsOneWidget);
      await disposeApp(tester, services);
    });

    testWidgets('기본 제공자(아직 채우지 않은 자리)로도 지난달이 그려진다', (tester) async {
      final services = await createTestServices();
      await Seed.filled(services);
      await pumpApp(tester, services, size: phone, location: '/stats');
      await tester.tap(find.byTooltip('이전 달'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('stats-narrative')), findsNothing);
      expect(find.text('날짜별 지출'), findsOneWidget);
      await disposeApp(tester, services);
    });
  });

  group('배치', () {
    testWidgets('휴대폰은 한 줄로 쌓고 PC는 두 칸으로 나눈다', (tester) async {
      final services = await createTestServices();
      await Seed.filled(services);
      await pumpApp(tester, services, size: desktop, location: '/stats');
      final categories = tester.getRect(find.text('분류별 지출 · 1,860,250원'));
      final daily = tester.getRect(find.text('날짜별 지출'));
      expect(daily.left, greaterThan(categories.right));
      expect((daily.top - categories.top).abs(), lessThan(4));
      await disposeApp(tester, services);

      final phoneServices = await createTestServices();
      await Seed.filled(phoneServices);
      await pumpApp(tester, phoneServices, size: phone, location: '/stats');
      final top = tester.getRect(find.text('분류별 지출 · 1,860,250원'));
      await _show(tester, find.text('날짜별 지출'));
      expect(tester.getRect(find.text('날짜별 지출')).left, closeTo(top.left, 1));
      await _show(tester, find.text('최근 6개월 지출'));
      await _show(tester, find.text('많이 쓴 곳'));
      await _show(tester, find.text('큰 지출'));
      await disposeApp(tester, phoneServices);
    });
  });

  group('네 화면 크기에서 넘치지 않는다', () {
    for (final (name, size) in fourSizes) {
      for (final scale in [1.0, 2.0]) {
        testWidgets('$name, 글자 ${(scale * 100).round()}%', (tester) async {
          final services = await createTestServices();
          final seed = await Seed.filled(services);
          // 자릿수가 많은 금액
          await seed.add(
            123456789,
            LocalDate(2026, 11, 15),
            party: '아주 큰 지출',
            category: '금융·보험',
          );
          await seed.add(
            987654321,
            LocalDate(2026, 10, 15),
            party: '지난달의 아주 큰 지출',
          );
          await pumpStatsWithNarrative(
            tester,
            services,
            narratives: {
              '2026-10':
                  '10월에는 지난달보다 많이 썼습니다. 가장 많이 쓴 분류는 분류 없음입니다. '
                  '하루 평균은 3천만 원이 넘었습니다.',
            },
            size: size,
            textScale: scale,
          );
          await expectNoOverflowWhileScrolling(tester, StatsScreen);

          // 수입 쪽도 본다.
          tester.state<ScrollableState>(_scrollable()).position.jumpTo(0);
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const ValueKey('stats-flow-income')));
          await tester.pumpAndSettle();
          await expectNoOverflowWhileScrolling(tester, StatsScreen);

          // 총평이 있는 지난달도 본다.
          tester.state<ScrollableState>(_scrollable()).position.jumpTo(0);
          await tester.pumpAndSettle();
          await tester.tap(find.byTooltip('이전 달'));
          await tester.pumpAndSettle();
          expect(find.byKey(const ValueKey('stats-narrative')), findsOneWidget);
          await expectNoOverflowWhileScrolling(tester, StatsScreen);
          await disposeApp(tester, services);
        });
      }
    }
  });

  test('MonthPeriod는 총평 제공자의 열쇠로 쓸 수 있다(같은 달은 같은 값)', () {
    expect(MonthPeriod(2026, 10), MonthPeriod(2026, 10));
    expect(MonthPeriod(2026, 10).hashCode, MonthPeriod(2026, 10).hashCode);
  });
}
