import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gagyebu/ai/llm/llm_engine.dart';
import 'package:gagyebu/app/app.dart';
import 'package:gagyebu/app/providers.dart';
import 'package:gagyebu/app/router.dart';
import 'package:gagyebu/core/local_date.dart';
import 'package:gagyebu/features/query/query_screen.dart';
import 'package:gagyebu/features/transactions/transactions_screen.dart';
import 'package:material_ui/material_ui.dart';

import 'home_stats_seed.dart';
import 'test_app.dart';

String queryLocation(String question) =>
    Uri(path: '/query', queryParameters: {'q': question}).toString();

String textOf(WidgetTester tester, String key) =>
    tester.widget<Text>(find.byKey(ValueKey(key))).data!;

/// 정해 둔 답 하나를 내는 엔진.
class OneAnswerEngine implements LlmEngine {
  OneAnswerEngine(this.answer);

  final String answer;
  var calls = 0;

  @override
  String get modelName => 'fake-model';

  @override
  Future<String> generateJson({
    required String system,
    required String user,
    required Map<String, Object?> schema,
    String? grammar,
    int maxTokens = 512,
  }) async {
    calls++;
    return answer;
  }
}

void main() {
  testWidgets('문장, 읽은 조건, 답을 보여 준다', (tester) async {
    final services = await createTestServices();
    await Seed.filled(services);
    await pumpApp(
      tester,
      services,
      size: phone,
      location: queryLocation('이번 달 식비 얼마야?'),
    );

    expect(textOf(tester, 'query-question'), '이번 달 식비 얼마야?');
    expect(find.text('이번 달 · 11월 1일 – 11월 30일'), findsOneWidget);
    expect(find.byKey(const ValueKey('query-chip-category')), findsOneWidget);
    expect(find.text('지출'), findsOneWidget);
    expect(find.text('합계'), findsOneWidget);
    expect(find.text('지출 합계'), findsOneWidget);
    // 지출에는 − 부호가 붙는다.
    expect(textOf(tester, 'query-answer'), '-20,000원');
    expect(textOf(tester, 'query-answer-detail'), '2건');
    // 무엇을 센 것인지 최근 내역으로 보인다.
    expect(find.text('김밥천국'), findsNWidgets(2));
    expect(find.text('-12,000원'), findsOneWidget);
    await disposeApp(tester, services);
  });

  testWidgets('횟수와 목록, 수입의 부호', (tester) async {
    final services = await createTestServices();
    await Seed.filled(services);
    await pumpApp(
      tester,
      services,
      size: largePhone,
      location: queryLocation('이번 달 김밥천국 몇 번 갔어?'),
    );
    expect(textOf(tester, 'query-answer'), '2건');
    expect(textOf(tester, 'query-answer-detail'), '합계 -20,000원');
    expect(find.text('‘김밥천국’ 포함'), findsOneWidget);
    await disposeApp(tester, services);

    final second = await createTestServices();
    await Seed.filled(second);
    await pumpApp(
      tester,
      second,
      size: largePhone,
      location: queryLocation('올해 수입 합계'),
    );
    expect(textOf(tester, 'query-answer'), '+5,500,000원');
    expect(find.text('올해 · 1월 1일 – 12월 31일'), findsOneWidget);
    await disposeApp(tester, second);

    final third = await createTestServices();
    await Seed.filled(third);
    await pumpApp(
      tester,
      third,
      size: largePhone,
      location: queryLocation('어제 내역 보여줘'),
    );
    expect(find.text('어제 · 11월 16일'), findsOneWidget);
    expect(textOf(tester, 'query-answer'), '1건');
    expect(find.text('내역'), findsOneWidget);
    expect(find.text('분류없는가게'), findsOneWidget);
    await disposeApp(tester, third);
  });

  testWidgets('기간을 적지 않으면 이번 달로 보고 그렇게 알린다', (tester) async {
    final services = await createTestServices();
    await Seed.filled(services);
    await pumpApp(
      tester,
      services,
      size: phone,
      location: queryLocation('쿠팡 얼마 썼어?'),
    );
    expect(textOf(tester, 'query-answer'), '-50,000원');
    expect(textOf(tester, 'query-note'), contains('이번 달로 봤습니다'));
    await disposeApp(tester, services);
  });

  testWidgets('조건에 맞는 내역이 없으면 그렇게 말한다', (tester) async {
    final services = await createTestServices();
    await pumpApp(
      tester,
      services,
      size: phone,
      location: queryLocation('지난달 식비 얼마야?'),
    );
    expect(find.byKey(const ValueKey('query-empty')), findsOneWidget);
    expect(find.text('조건에 맞는 내역이 없습니다.'), findsOneWidget);
    expect(find.byKey(const ValueKey('query-answer')), findsNothing);
    // 조건은 그대로 보인다.
    expect(find.text('지난달 · 10월 1일 – 10월 31일'), findsOneWidget);
    await disposeApp(tester, services);
  });

  testWidgets('조건을 읽지 못하면 그렇게 말하고 예시를 보여 준다', (tester) async {
    final services = await createTestServices();
    await Seed.filled(services);
    await pumpApp(
      tester,
      services,
      size: phone,
      location: queryLocation('얼마야?'),
    );
    expect(find.text('조건을 읽지 못했습니다'), findsOneWidget);
    for (final example in queryExamples) {
      expect(find.text(example), findsOneWidget);
    }
    expect(find.byKey(const ValueKey('query-answer')), findsNothing);

    // 예시를 누르면 그 물음의 답으로 바뀐다.
    await tester.tap(find.text('올해 수입 합계'));
    await tester.pumpAndSettle();
    expect(currentUri(tester).queryParameters['q'], '올해 수입 합계');
    expect(textOf(tester, 'query-answer'), '+5,500,000원');
    await disposeApp(tester, services);
  });

  testWidgets('물음이 비어 있으면 예시만 보여 준다', (tester) async {
    final services = await createTestServices();
    await pumpApp(tester, services, size: phone, location: '/query');
    expect(find.text('물음이 없습니다'), findsOneWidget);
    expect(find.byKey(const ValueKey('query-question')), findsNothing);
    await disposeApp(tester, services);
  });

  testWidgets('"내역에서 보기"는 조회한 달의 내역으로 간다', (tester) async {
    final services = await createTestServices();
    await Seed.filled(services);
    await pumpApp(
      tester,
      services,
      size: phone,
      location: queryLocation('9월 구월 가게 얼마 썼어?'),
    );
    expect(textOf(tester, 'query-answer'), '-300,000원');
    await tester.ensureVisible(
      find.byKey(const ValueKey('query-open-transactions')),
    );
    await tester.tap(find.byKey(const ValueKey('query-open-transactions')));
    await tester.pumpAndSettle();

    expect(currentUri(tester).path, '/transactions');
    expect(find.byType(TransactionsScreen), findsOneWidget);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(TransactionsScreen)),
    );
    expect(container.read(selectedPeriodProvider).key, '2026-09');
    expect(container.read(searchQueryProvider), '구월 가게');
    await disposeApp(tester, services);
  });

  testWidgets('뒤로 단추는 갈 곳이 없으면 홈으로 간다', (tester) async {
    final services = await createTestServices();
    await pumpApp(
      tester,
      services,
      size: phone,
      location: queryLocation('오늘 얼마 썼어'),
    );
    await tester.tap(find.byTooltip('뒤로'));
    await tester.pumpAndSettle();
    expect(currentUri(tester).path, '/');
    await disposeApp(tester, services);
  });

  testWidgets('월 시작일을 반영한 기간으로 답한다', (tester) async {
    final services = await createTestServices();
    await Seed.filled(services);
    await services.repository.setMonthStartDay(services.ledgerId, 25);
    await pumpApp(
      tester,
      services,
      size: phone,
      location: queryLocation('지난달 얼마 썼어?'),
    );
    // '10월'은 9/25–10/24다. 10월 20일의 40,000원만 든다.
    expect(find.text('지난달 · 9월 25일 – 10월 24일'), findsOneWidget);
    expect(textOf(tester, 'query-answer'), '-40,000원');
    await disposeApp(tester, services);
  });

  testWidgets('규칙이 못 읽으면 기기 안의 모델이 조건을 고르고, 숫자는 SQL이 센다', (tester) async {
    final services = await createTestServices();
    await Seed.filled(services);
    final engine = OneAnswerEngine(
      jsonEncode({
        'period': 'this_month',
        'category': '식비',
        'party': null,
        'type': 'expense',
        // 모델이 숫자를 덧붙여도 쓰이지 않는다.
        'total': 999999,
        'agg': 'sum',
      }),
    );
    tester.view.physicalSize = phone;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appServicesProvider.overrideWithValue(services),
          clockProvider.overrideWithValue(() => testNow),
          llmEngineProvider.overrideWithValue(engine),
        ],
        child: GagyebuApp(
          router: createRouter(
            initialLocation: queryLocation('요즘 밥 사 먹는 데 들어간 게 어느 정도인지 궁금해?'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(engine.calls, 1);
    expect(textOf(tester, 'query-answer'), '-20,000원');
    expect(textOf(tester, 'query-note'), contains('기기 안의 모델이 조건을 읽었습니다'));
    await disposeApp(tester, services);
  });

  testWidgets('규칙이 읽은 물음은 모델을 부르지 않는다', (tester) async {
    final services = await createTestServices();
    await Seed.filled(services);
    final engine = OneAnswerEngine('{}');
    tester.view.physicalSize = phone;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appServicesProvider.overrideWithValue(services),
          clockProvider.overrideWithValue(() => testNow),
          llmEngineProvider.overrideWithValue(engine),
        ],
        child: GagyebuApp(
          router: createRouter(initialLocation: queryLocation('이번 달 식비 얼마야?')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(engine.calls, 0);
    expect(textOf(tester, 'query-answer'), '-20,000원');
    await disposeApp(tester, services);
  });

  group('네 화면 크기와 큰 글자에서 넘치지 않는다', () {
    for (final (name, size) in [
      ('휴대폰', phone),
      ('큰 휴대폰', largePhone),
      ('폴더블', foldable),
      ('PC', desktop),
    ]) {
      testWidgets(name, (tester) async {
        final services = await createTestServices();
        final seed = await Seed.filled(services);
        // 목록이 길고 금액이 큰 경우
        for (var i = 0; i < 12; i++) {
          await seed.add(
            123456789,
            LocalDate(2026, 11, 2 + i),
            party: '이름이 아주 긴 가게 $i호점 테헤란로 지점',
            category: '경조사·선물',
          );
        }
        for (final question in [
          '올해 지출 내역 보여줘',
          '이번 달 경조사 얼마 썼어?',
          '이번 달 하루 평균 얼마 썼어?',
          '얼마야?',
        ]) {
          await pumpApp(
            tester,
            services,
            size: size,
            location: queryLocation(question),
            textScale: 2,
          );
          await expectNoOverflowWhileScrolling(tester, QueryScreen);
        }
        await disposeApp(tester, services);
      });
    }
  });
}
