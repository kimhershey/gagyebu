import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:gagyebu/ai/llm/llm_engine.dart';
import 'package:gagyebu/app/providers.dart';
import 'package:material_ui/material_ui.dart';

import 'composer_support.dart';
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

/// 시험이 놓아줄 때까지 답하지 않는 가짜 모델. 진행 표시와 "그만"을 보는 데 쓴다.
class _HeldEngine implements LlmEngine {
  final List<Completer<String>> calls = [];

  @override
  String get modelName => 'held-model';

  @override
  Future<String> generateJson({
    required String system,
    required String user,
    required Map<String, Object?> schema,
    String? grammar,
    int maxTokens = 512,
  }) {
    final call = Completer<String>();
    calls.add(call);
    return call.future;
  }
}

String _answer(String date, int amount, String who) => jsonEncode({
  'tx': [
    {
      'd': date,
      'a': amount,
      'io': 'out',
      'who': who,
      'memo': null,
      'cat': '식비',
    },
  ],
  'real': true,
});

// 어느 형식 규칙에도 맞지 않는 가상의 은행 문자
const _unknownSms = '새마을 11/15 19:02 결제완료 23,000원 동네치킨 잔액 410,000원';

Future<void> _pump(
  WidgetTester tester,
  AppServices services,
  LlmEngine engine,
) => pumpAppWith(
  tester,
  services,
  size: desktop,
  overrides: [llmEngineProvider.overrideWithValue(engine)],
);

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

    await sendFromComposer(tester, _unknownSms);

    expect(engine.inputs, hasLength(1));
    expect(engine.inputs.single, contains('23,000원 = 23000 (금액)'));
    expect(engine.inputs.single, contains('410,000원 = 410000 (잔액)'));
    expect(find.widgetWithText(TextField, '동네치킨'), findsOneWidget);
    expect(find.widgetWithText(TextField, '23,000'), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('review-subtitle-0'))).data,
      startsWith('11월 15일 (일) 19:02'),
    );

    await tester.tap(find.byKey(const ValueKey('review-save')));
    await tester.pumpAndSettle();
    final saved = (await allTransactions(services)).single;
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

    await sendFromComposer(
      tester,
      '삼성1234승인 홍*동 100원 일시불 01/09 20:07 세븐일레븐아산음 누적80,090원',
    );

    expect(engine.inputs, isEmpty);
    expect(find.byKey(const ValueKey('review-0')), findsOneWidget);
    await disposeApp(tester, services);
  });

  testWidgets('모델이 거래가 아니라고 본 글만 있으면 저장할 것이 없다고 알린다', (tester) async {
    final services = await createTestServices();
    final engine = _ScriptedEngine([
      {'tx': <Object>[], 'real': false},
    ]);
    await _pump(tester, services, engine);

    await sendFromComposer(tester, '고객님, 이번 달 포인트 3,000점이 소멸될 예정입니다');

    expect(find.byKey(const ValueKey('review-0')), findsNothing);
    expect(
      find.byKey(const ValueKey('composer-not-transaction')),
      findsOneWidget,
    );
    expect(find.textContaining('거래가 아닌 안내문으로 보여'), findsOneWidget);
    await disposeApp(tester, services);
  });

  testWidgets('모델이 거래가 아니라고 본 글은 안내문으로 접어 둔다', (tester) async {
    final services = await createTestServices();
    final engine = _ScriptedEngine([
      {'tx': <Object>[], 'real': false},
    ]);
    await _pump(tester, services, engine);

    await sendFromComposer(tester, '''
삼성1234승인 홍*동 100원 일시불 01/09 20:07 세븐일레븐아산음 누적80,090원

고객님, 이번 달 포인트 3,000점이 소멸될 예정입니다''');

    expect(engine.inputs, hasLength(1));
    expect(find.byKey(const ValueKey('review-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('review-1')), findsNothing);
    expect(find.text('1건 읽음 · 안내문 1건 제외'), findsOneWidget);
    await disposeApp(tester, services);
  });

  testWidgets('모델이 도는 동안 몇 건 가운데 몇 건인지 보여 준다', (tester) async {
    final services = await createTestServices();
    final engine = _HeldEngine();
    await _pump(tester, services, engine);

    await tester.enterText(
      find.byKey(composerInput),
      '$_unknownSms\n\n새마을 11/16 08:10 결제완료 4,500원 모퉁이빵집 잔액 405,500원',
    );
    await tester.tap(find.byKey(composerSend));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // 첫 건을 읽는 중: 보내기 대신 "그만"이 보인다.
    expect(engine.calls, hasLength(1));
    expect(find.text('읽는 중입니다 · 2건 가운데 1건'), findsOneWidget);
    expect(find.byKey(const ValueKey('composer-stop')), findsOneWidget);
    expect(find.byKey(composerSend), findsNothing);
    expect(find.byKey(const ValueKey('review-0')), findsNothing);

    engine.calls[0].complete(_answer('2026-11-15', 23000, '동네치킨'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(engine.calls, hasLength(2));
    expect(find.text('읽는 중입니다 · 2건 가운데 2건'), findsOneWidget);

    engine.calls[1].complete(_answer('2026-11-16', 4500, '모퉁이빵집'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('composer-stop')), findsNothing);
    expect(find.text('2건 읽음'), findsOneWidget);
    expect(find.byKey(const ValueKey('review-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('review-1')), findsOneWidget);
    await disposeApp(tester, services);
  });

  testWidgets('"그만"을 누르면 해석을 멈추고 글은 남긴다', (tester) async {
    final services = await createTestServices();
    final engine = _HeldEngine();
    await _pump(tester, services, engine);

    final text =
        '$_unknownSms\n\n새마을 11/16 08:10 결제완료 4,500원 모퉁이빵집 잔액 405,500원';
    await tester.enterText(find.byKey(composerInput), text);
    await tester.tap(find.byKey(composerSend));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(engine.calls, hasLength(1));

    await tester.tap(find.byKey(const ValueKey('composer-stop')));
    await tester.pump();
    expect(find.byKey(const ValueKey('composer-stop')), findsNothing);
    expect(find.byKey(composerSend), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byKey(composerInput)).controller!.text,
      text,
    );

    // 이미 넘긴 건의 답이 늦게 와도 검토함에 넣지 않고, 다음 건을 모델에 넘기지 않는다.
    engine.calls[0].complete(_answer('2026-11-15', 23000, '동네치킨'));
    await tester.pumpAndSettle();
    expect(engine.calls, hasLength(1));
    expect(find.byKey(const ValueKey('review-0')), findsNothing);
    expect(find.byKey(const ValueKey('composer-failed')), findsNothing);
    await disposeApp(tester, services);
  });

  testWidgets('모델이 실패하면 예외 문구 대신 다시 해 보라고 알린다', (tester) async {
    final services = await createTestServices();
    final engine = _HeldEngine();
    await _pump(tester, services, engine);

    await tester.enterText(find.byKey(composerInput), _unknownSms);
    await tester.tap(find.byKey(composerSend));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    engine.calls[0].completeError(StateError('모델을 올리지 못했다'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('composer-failed')), findsOneWidget);
    expect(find.textContaining('모델을 올리지 못했다'), findsNothing);
    expect(find.byKey(const ValueKey('review-0')), findsNothing);
    await disposeApp(tester, services);
  });
}
