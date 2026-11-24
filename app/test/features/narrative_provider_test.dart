import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gagyebu/ai/llm/llm_engine.dart';
import 'package:gagyebu/ai/llm/narrative_template.dart';
import 'package:gagyebu/ai/llm/narrative_writer.dart';
import 'package:gagyebu/app/providers.dart';
import 'package:gagyebu/core/local_date.dart';
import 'package:gagyebu/data/repositories/monthly_summary_repository.dart';
import 'package:gagyebu/data/repositories/summary_repository.dart';
import 'package:gagyebu/domain/month_period.dart';
import 'package:gagyebu/features/stats/narrative_provider.dart';
import 'package:gagyebu/features/stats/stats_screen.dart';
import 'package:material_ui/material_ui.dart';

import 'home_stats_seed.dart';
import 'test_app.dart';

/// 정해 둔 문장들을 내는 엔진.
class FixedEngine implements LlmEngine {
  FixedEngine(this.sentences);

  List<String> sentences;
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
    return jsonEncode({'s': sentences});
  }
}

ProviderContainer containerFor(AppServices services, {LlmEngine? engine}) {
  final container = ProviderContainer(
    overrides: [
      appServicesProvider.overrideWithValue(services),
      clockProvider.overrideWithValue(() => testNow),
      llmEngineProvider.overrideWithValue(engine),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

final october = MonthPeriod(2026, 10);
final november = MonthPeriod(2026, 11);

void main() {
  test('모델이 없으면 문장 틀로 만들어 보관한다', () async {
    final services = await createTestServices();
    addTearDown(services.db.close);
    await Seed.filled(services);
    final container = containerFor(services);

    final text = await container.read(monthNarrativeProvider(october).future);
    // 10월: 지출 40,000원, 전달(9월) 지출 300,000원
    expect(text, startsWith('10월에는 4만 원을 썼습니다. 전달보다 26만 원 덜 썼습니다.'));

    final summary = await container
        .read(summaryRepositoryProvider)
        .monthSummary(
          services.ledgerId,
          october,
          today: LocalDate.fromDateTime(testNow),
        );
    final stats = summary.toStatsJson();
    expect(text, templateNarrative(stats));
    expect(unsupportedNumbers(text!, stats), isEmpty);

    final row = await container
        .read(monthlySummaryRepositoryProvider)
        .latest(services.ledgerId, '2026-10');
    expect(row!.narrative, text);
    expect(row.dataHash, statsHash(stats));
    expect(row.aiModel, isNull);
    expect(row.stats['expense'], 40000);
    final queued = await (services.db.select(
      services.db.outbox,
    )..where((o) => o.targetTable.equals('monthly_summaries'))).get();
    expect(queued.single.rowId, row.id);
  });

  test('이번 달과 적은 것이 없는 달은 만들지 않는다', () async {
    final services = await createTestServices();
    addTearDown(services.db.close);
    await Seed.filled(services);
    final container = containerFor(services);

    expect(await container.read(monthNarrativeProvider(november).future), null);
    expect(
      await container.read(monthNarrativeProvider(MonthPeriod(2026, 8)).future),
      null,
    );
    expect(
      await services.db.select(services.db.monthlySummaries).get(),
      isEmpty,
    );
  });

  test('모델이 있으면 모델의 글을 검증해 쓰고, 다시 열 때는 보관한 글을 쓴다', () async {
    final services = await createTestServices();
    addTearDown(services.db.close);
    await Seed.filled(services);
    final engine = FixedEngine([
      '10월에는 4만 원을 썼습니다.',
      '전달보다 26만 원 덜 썼습니다.',
      '가장 큰 지출은 지난달 가게였습니다.',
    ]);

    final first = containerFor(services, engine: engine);
    final text = await first.read(monthNarrativeProvider(october).future);
    expect(text, '10월에는 4만 원을 썼습니다. 전달보다 26만 원 덜 썼습니다. 가장 큰 지출은 지난달 가게였습니다.');
    expect(engine.calls, 1);
    final row = await first
        .read(monthlySummaryRepositoryProvider)
        .latest(services.ledgerId, '2026-10');
    expect(row!.aiModel, 'fake-model');

    // 앱을 다시 켠 것처럼 새 상태로 읽는다. 해시가 같으니 모델을 부르지 않는다.
    final second = containerFor(services, engine: engine);
    expect(await second.read(monthNarrativeProvider(october).future), text);
    expect(engine.calls, 1);
    expect(
      await services.db.select(services.db.monthlySummaries).get(),
      hasLength(1),
    );
  });

  test('모델이 집계에 없는 숫자를 쓰면 두 번 묻고 문장 틀로 돌아간다', () async {
    final services = await createTestServices();
    addTearDown(services.db.close);
    await Seed.filled(services);
    final engine = FixedEngine([
      '10월에는 77만 원을 썼습니다.',
      '전달보다 줄었습니다.',
      '잘 아꼈습니다.',
    ]);
    final container = containerFor(services, engine: engine);
    final text = await container.read(monthNarrativeProvider(october).future);
    expect(engine.calls, 2);
    expect(text, startsWith('10월에는 4만 원을 썼습니다.'));
    expect(text, isNot(contains('77만')));
    final row = await container
        .read(monthlySummaryRepositoryProvider)
        .latest(services.ledgerId, '2026-10');
    expect(row!.aiModel, isNull);
  });

  test('지난달의 거래를 고치면 총평을 다시 만든다', () async {
    final services = await createTestServices();
    addTearDown(services.db.close);
    final seed = await Seed.filled(services);
    final container = containerFor(services);
    // 값을 붙들고 있어야 바뀐 것을 따라간다(화면이 보고 있는 것과 같다).
    final subscription = container.listen(
      monthNarrativeProvider(october),
      (_, _) {},
    );
    addTearDown(subscription.close);

    final before = await container.read(monthNarrativeProvider(october).future);
    expect(before, contains('10월에는 4만 원을 썼습니다.'));

    await seed.add(60000, LocalDate(2026, 10, 9), party: '뒤늦게 적은 가게');
    await pumpEventQueue();
    final after = await container.read(monthNarrativeProvider(october).future);
    expect(after, contains('10월에는 10만 원을 썼습니다.'));

    final rows = await services.db.select(services.db.monthlySummaries).get();
    expect(rows, hasLength(1));
    expect(rows.single.narrative, after);
    expect(rows.single.stats['expense'], 100000);
  });

  testWidgets('통계 화면은 끝난 달에만 총평을 보여 준다', (tester) async {
    final services = await createTestServices();
    await Seed.filled(services);
    await pumpApp(tester, services, size: phone, location: '/stats');
    expect(find.byType(StatsScreen), findsOneWidget);
    expect(find.byKey(const ValueKey('stats-narrative')), findsNothing);

    await tester.tap(find.byTooltip('이전 달'));
    await tester.pumpAndSettle();
    final card = find.byKey(const ValueKey('stats-narrative'));
    expect(card, findsOneWidget);
    expect(
      find.descendant(
        of: card,
        matching: find.textContaining('10월에는 4만 원을 썼습니다.'),
      ),
      findsOneWidget,
    );
    await disposeApp(tester, services);
  });
}
