import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gagyebu/ai/llm/llm_engine.dart';
import 'package:gagyebu/app/app.dart';
import 'package:gagyebu/app/providers.dart';
import 'package:gagyebu/app/router.dart';
import 'package:material_ui/material_ui.dart';

import 'test_app.dart';

/// 정해 둔 답을 차례로 돌려주는 가짜 모델.
class _ScriptedEngine implements LlmEngine {
  _ScriptedEngine(this.answers);

  final List<Map<String, Object?>> answers;
  final List<String> inputs = [];

  @override
  String get modelName => 'test-model';

  @override
  Future<String> generateJson({
    required String system,
    required String user,
    required Map<String, Object?> schema,
    String? grammar,
    int maxTokens = 512,
  }) async {
    inputs.add(user);
    return jsonEncode(answers[inputs.length - 1]);
  }
}

Future<void> _pump(
  WidgetTester tester,
  AppServices services,
  LlmEngine engine,
) async {
  tester.view.physicalSize = desktop;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appServicesProvider.overrideWithValue(services),
        clockProvider.overrideWithValue(() => testNow),
        llmEngineProvider.overrideWithValue(engine),
      ],
      child: GagyebuApp(router: createRouter(initialLocation: '/input')),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('규칙이 읽지 못한 문자는 기기 안의 모델이 읽는다', (tester) async {
    final services = await createTestServices();
    final engine = _ScriptedEngine([
      {
        'tx': [
          {
            'd': '2026-11-15',
            'a': 23000,
            'io': 'out',
            'who': '동네치킨',
            'memo': null,
            'cat': '식비',
          },
        ],
        'real': true,
      },
    ]);
    await _pump(tester, services, engine);

    // 어느 형식 규칙에도 맞지 않는 가상의 은행 문자
    await tester.enterText(
      find.byKey(const ValueKey('input-text')),
      '새마을 11/15 19:02 결제완료 23,000원 동네치킨 잔액 410,000원',
    );
    await tester.tap(find.byKey(const ValueKey('input-analyze')));
    await tester.pumpAndSettle();

    expect(engine.inputs, hasLength(1));
    expect(engine.inputs.single, contains('23,000원 = 23000 (금액)'));
    expect(engine.inputs.single, contains('410,000원 = 410000 (잔액)'));
    expect(find.widgetWithText(TextField, '동네치킨'), findsOneWidget);
    expect(find.widgetWithText(TextField, '23,000'), findsOneWidget);
    expect(find.text('11월 15일 (일) 19:02'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('input-save')));
    await tester.pumpAndSettle();
    final saved =
        (await services.db.select(services.db.ledgerTransactions).get()).single;
    expect(saved.amount, 23000);
    expect(saved.receiver, '동네치킨');
    expect(saved.occurredTime, '19:02');
    expect(saved.balanceAfter, 410000);
    // 모델이 만든 거래에는 모델 이름을 남긴다.
    expect(saved.aiModel, 'test-model');
    await disposeApp(tester, services);
  });

  testWidgets('아는 형식은 모델을 부르지 않는다', (tester) async {
    final services = await createTestServices();
    final engine = _ScriptedEngine([]);
    await _pump(tester, services, engine);

    await tester.enterText(
      find.byKey(const ValueKey('input-text')),
      '삼성1234승인 홍*동 100원 일시불 01/09 20:07 세븐일레븐아산음 누적80,090원',
    );
    await tester.tap(find.byKey(const ValueKey('input-analyze')));
    await tester.pumpAndSettle();

    expect(engine.inputs, isEmpty);
    expect(find.byKey(const ValueKey('review-0')), findsOneWidget);
    await disposeApp(tester, services);
  });

  testWidgets('모델이 거래가 아니라고 본 글은 저장 대상에서 뺀다', (tester) async {
    final services = await createTestServices();
    final engine = _ScriptedEngine([
      {'tx': <Object>[], 'real': false},
    ]);
    await _pump(tester, services, engine);

    await tester.enterText(
      find.byKey(const ValueKey('input-text')),
      '고객님, 이번 달 포인트 3,000점이 소멸될 예정입니다',
    );
    await tester.tap(find.byKey(const ValueKey('input-analyze')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('review-0')), findsNothing);
    expect(find.text('거래가 아닌 안내문 1건은 뺐다'), findsOneWidget);
    await disposeApp(tester, services);
  });
}
