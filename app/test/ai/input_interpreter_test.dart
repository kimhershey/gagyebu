import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:gagyebu/ai/input_interpreter.dart';
import 'package:gagyebu/ai/llm/llm_engine.dart';
import 'package:gagyebu/ai/parsed_transaction.dart';
import 'package:gagyebu/core/local_date.dart';
import 'package:gagyebu/domain/default_seed.dart';

/// 정해 둔 답을 돌려주고, 불린 횟수를 센다.
class _CountingEngine implements LlmEngine {
  _CountingEngine(this.answer);

  final Object answer;
  final List<String> inputs = [];

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
    inputs.add(user);
    final a = answer;
    return a is String ? a : jsonEncode(a);
  }
}

Map<String, Object?> _one({
  required String date,
  required int amount,
  String direction = 'out',
  String? who,
  bool real = true,
}) => {
  'tx': [
    {
      'd': date,
      'a': amount,
      'io': direction,
      'who': who,
      'memo': null,
      'cat': null,
    },
  ],
  'real': real,
};

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

  test('아는 형식의 문자는 규칙이 읽고 모델을 부르지 않는다', () async {
    final engine = _CountingEngine(_one(date: '2026-11-16', amount: 1));
    final result = await run(
      '신한카드(1234)승인 홍*동 12,500원(일시불)11/16 12:31 김밥천국 누적345,600원',
      engine: engine,
    );
    expect(engine.inputs, isEmpty);
    expect(result.transactions.single.amount, 12500);
    expect(result.transactions.single.modelName, isNull);
    expect(result.fromSentence, isFalse);
  });

  test('사람이 쓴 한 줄 문장은 모델이 있어도 규칙으로 읽는다', () async {
    final engine = _CountingEngine(_one(date: '2026-11-16', amount: 1));
    final result = await run('어제 점심 김밥천국 8천원 카드로', engine: engine);
    expect(engine.inputs, isEmpty);
    expect(result.fromSentence, isTrue);
    final parsed = result.transactions.single;
    expect(parsed.amount, 8000);
    expect(parsed.date, LocalDate(2026, 11, 16));
    expect(parsed.modelName, isNull);
  });

  test('모르는 형식의 한 줄 문자는 모델에 넘긴다', () async {
    final engine = _CountingEngine(
      _one(date: '2026-11-14', amount: 150000, direction: 'in', who: '김영희'),
    );
    final result = await run(
      '[새솔저축은행] 11/14 09:12 입금 150,000원 김영희 잔액 1,250,000원',
      engine: engine,
    );
    expect(engine.inputs, hasLength(1));
    final parsed = result.transactions.single;
    expect(parsed.counterparty, '김영희');
    expect(parsed.direction, Direction.incoming);
    expect(parsed.balanceAfter, 1250000);
    expect(parsed.modelName, 'fake-model');
  });

  test('모델이 없으면 모르는 형식의 한 줄 문자도 규칙으로 읽어 본다', () async {
    final result = await run(
      '[새솔저축은행] 11/14 09:12 입금 150,000원 김영희 잔액 1,250,000원',
    );
    final parsed = result.transactions.single;
    expect(parsed.amount, 150000);
    expect(parsed.date, LocalDate(2026, 11, 14));
    expect(parsed.direction, Direction.incoming);
  });

  test('규칙이 금액을 찾지 못한 문장은 모델에 넘긴다', () async {
    final engine = _CountingEngine({'tx': <Object>[], 'real': false});
    final result = await run('오늘은 아무것도 안 샀다', engine: engine);
    expect(engine.inputs, hasLength(1));
    expect(result.transactions, isEmpty);
    expect(result.items.single, isA<NonTransactionItem>());
  });

  test('여러 줄의 모르는 형식은 모델에 넘기고, 모델이 거래가 아니라고 보면 뺀다', () async {
    final engine = _CountingEngine({'tx': <Object>[], 'real': false});
    final result = await run('새솔저축은행\n고객님의 우대금리가\n변경되었습니다', engine: engine);
    expect(engine.inputs, hasLength(1));
    final item = result.items.single;
    expect(item, isA<NonTransactionItem>());
    expect(
      (item as NonTransactionItem).reason,
      NonTransactionReason.judgedByModel,
    );
  });

  test('모델의 답이 검증에서 두 번 떨어지면 읽지 못한 글로 남긴다', () async {
    final engine = _CountingEngine('JSON이 아닌 답');
    final result = await run(
      '신협\n출금 12,000원\n11/16 18:30\n올리브영 강남점',
      engine: engine,
    );
    expect(engine.inputs, hasLength(2));
    expect(result.items.single, isA<UnrecognizedItem>());
  });
}
