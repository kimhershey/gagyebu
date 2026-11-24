import 'package:flutter_test/flutter_test.dart';
import 'package:gagyebu/ai/input_interpreter.dart';
import 'package:gagyebu/ai/llm/llm_engine.dart';
import 'package:gagyebu/ai/llm/local_model_engine.dart';
import 'package:gagyebu/ai/llm/local_model_runtime.dart';
import 'package:gagyebu/ai/parsed_transaction.dart';
import 'package:gagyebu/core/local_date.dart';
import 'package:gagyebu/domain/default_seed.dart';

import 'model_manager_fakes.dart';

/// 부를 때마다 실패하는 엔진.
class BrokenEngine implements LlmEngine {
  BrokenEngine(this.error);

  final Object error;
  var calls = 0;

  @override
  String get modelName => 'broken-model';

  @override
  Future<String> generateJson({
    required String system,
    required String user,
    required Map<String, Object?> schema,
    String? grammar,
    int maxTokens = 512,
  }) async {
    calls++;
    throw error;
  }
}

const known = '신한카드(1234)승인 홍*동 12,500원(일시불)11/16 12:31 김밥천국 누적345,600원';
const unknownOneLine = '[새솔저축은행] 11/14 09:12 입금 150,000원 김영희 잔액 1,250,000원';
const unknownBlock = '신협\n출금 12,000원\n11/16 18:30\n올리브영 강남점';

void main() {
  final today = LocalDate(2026, 11, 17);

  Future<InterpretedInput> run(String input, {LlmEngine? engine}) =>
      interpretInput(
        input,
        today: today,
        engine: engine,
        expenseCategories: defaultExpenseCategories,
        incomeCategories: defaultIncomeCategories,
      );

  test('엔진이 없으면 규칙만으로 읽는다', () async {
    final card = await run(known);
    expect(card.transactions.single.amount, 12500);
    final sentence = await run('어제 점심 김밥천국 8천원');
    expect(sentence.transactions.single.amount, 8000);
    // 규칙이 모르는 여러 줄 글은 읽지 못한 것으로 남는다.
    expect((await run(unknownBlock)).items.single, isA<UnrecognizedItem>());
  });

  test('엔진이 고장 나도 규칙으로 읽은 것은 잃지 않는다', () async {
    final engine = BrokenEngine(StateError('모델 파일이 깨졌다'));
    // 아는 형식은 모델을 부르지도 않는다.
    final card = await run(known, engine: engine);
    expect(card.transactions.single.amount, 12500);
    expect(engine.calls, 0);

    // 모르는 형식의 한 줄은 모델이 실패하면 규칙으로 읽어 본다.
    final line = await run(unknownOneLine, engine: engine);
    expect(engine.calls, 1);
    expect(line.transactions.single.amount, 150000);
    expect(line.transactions.single.modelName, isNull);

    // 여러 줄 글은 읽지 못한 것으로 남는다. 예외로 끝나지 않는다.
    final block = await run(unknownBlock, engine: engine);
    expect(block.items.single, isA<UnrecognizedItem>());
  });

  test('모델을 올리지 못하는 기기 안의 엔진도 마찬가지다', () async {
    final engine = LocalModelEngine(
      spec: const LocalModelSpec(name: 'm', modelPath: '/없는/파일.gguf'),
      runtimeFactory: (spec) =>
          FakeRuntime(spec, [])
            ..onLoad = () async => throw StateError('파일을 열지 못했다'),
    );
    addTearDown(engine.dispose);
    final line = await run(unknownOneLine, engine: engine);
    expect(line.transactions.single.amount, 150000);
    expect(
      (await run(unknownBlock, engine: engine)).items.single,
      isA<UnrecognizedItem>(),
    );
  });

  test('사용자가 멈춘 것은 부르는 쪽에 알린다', () async {
    final engine = BrokenEngine(const GenerationCancelled());
    await expectLater(
      run(unknownBlock, engine: engine),
      throwsA(isA<GenerationCancelled>()),
    );
    expect(engine.calls, 1);
  });
}
