import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:gagyebu/ai/llm/llm_engine.dart';
import 'package:gagyebu/ai/query/ledger_query.dart';
import 'package:gagyebu/ai/query/llm_query_parser.dart';
import 'package:gagyebu/core/local_date.dart';
import 'package:gagyebu/domain/enums.dart';

/// 정해 둔 답을 차례로 내는 엔진.
class ScriptedEngine implements LlmEngine {
  ScriptedEngine(this.answers);

  final List<String> answers;
  final users = <String>[];
  final schemas = <Map<String, Object?>>[];
  final grammars = <String?>[];

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
    users.add(user);
    schemas.add(schema);
    grammars.add(grammar);
    return answers[users.length - 1];
  }
}

final today = LocalDate(2026, 11, 17);
const categories = [
  QueryCategory('식비', CategoryKind.expense),
  QueryCategory('카페·간식', CategoryKind.expense),
  QueryCategory('급여', CategoryKind.income),
];

String answer({
  String period = 'last_month',
  String? category,
  String? party,
  String? type = 'expense',
  String agg = 'sum',
}) => jsonEncode({
  'period': period,
  'category': category,
  'party': party,
  'type': type,
  'agg': agg,
});

void main() {
  test('모델이 고른 조건을 조회 조건으로 바꾼다', () async {
    final engine = ScriptedEngine([
      answer(period: 'last_month', category: '식비', agg: 'sum'),
    ]);
    final query = await LlmQueryParser(engine).parse(
      '저번 달에 밥값으로 나간 게 어느 정도야',
      today: today,
      categories: categories,
      startDay: 25,
    );
    expect(query, isNotNull);
    expect(query!.period, const QueryPeriod.lastMonth());
    // 날짜 범위는 모델이 아니라 코드가 계산한다(월 시작일 25일).
    expect(query.range.from, LocalDate(2026, 9, 25));
    expect(query.range.toExclusive, LocalDate(2026, 10, 25));
    expect(query.category, '식비');
    expect(query.type, TxType.expense);
    expect(query.aggregation, QueryAggregation.sum);
    expect(query.aiModel, 'fake-model');
    expect(engine.users, hasLength(1));
  });

  test('스키마와 문법이 기간은 기호로, 분류는 가계부의 이름으로 묶는다', () async {
    final engine = ScriptedEngine([answer()]);
    await LlmQueryParser(engine)
        .parse('아무 물음', today: today, categories: categories);
    final properties = engine.schemas.single['properties']! as Map;
    expect((properties['period'] as Map)['enum'], QueryPeriod.modelSymbols);
    expect((properties['category'] as Map)['enum'], [
      '식비',
      '카페·간식',
      '급여',
      null,
    ]);
    expect((properties['agg'] as Map)['enum'], ['sum', 'count', 'avg', 'list']);
    final grammar = engine.grammars.single!;
    expect(grammar, startsWith('root ::= '));
    expect(grammar, contains(r'"\"last_month\""'));
    expect(grammar, contains(r'"\"카페·간식\""'));
    expect(grammar, contains('party ::= '));
  });

  test('기간이 기호가 아니면 까닭을 붙여 한 번 다시 묻는다', () async {
    final engine = ScriptedEngine([
      answer(period: '2026-10'),
      answer(period: 'month_10'),
    ]);
    final query = await LlmQueryParser(engine)
        .parse('시월에 얼마 썼나', today: today, categories: categories);
    expect(query!.period, const QueryPeriod.month(10));
    expect(engine.users, hasLength(2));
    expect(engine.users.last, contains('[앞선 답의 문제]'));
    expect(engine.users.last, contains('2026-10'));
  });

  test('두 번 어긋나면 포기한다', () async {
    final engine = ScriptedEngine(['{"period":', '죄송합니다']);
    final query = await LlmQueryParser(engine)
        .parse('시월에 얼마 썼나', today: today, categories: categories);
    expect(query, isNull);
    expect(engine.users, hasLength(2));
  });

  test('가계부에 없는 분류와 물음에 없는 상대는 받지 않는다', () async {
    final unknownCategory = ScriptedEngine([
      answer(category: '유흥'),
      answer(category: '유흥'),
    ]);
    expect(
      await LlmQueryParser(unknownCategory)
          .parse('술값 얼마', today: today, categories: categories),
      isNull,
    );

    // 모델이 지어낸 가게 이름으로는 찾지 않는다.
    final invented = ScriptedEngine([
      answer(party: '스타벅스'),
      answer(party: '별다방'),
    ]);
    final query = await LlmQueryParser(invented)
        .parse('요새 별다방 간 횟수', today: today, categories: categories);
    expect(query!.party, '별다방');
    expect(invented.users, hasLength(2));
  });

  test('분류가 있으면 종류는 분류를 따른다', () async {
    final engine = ScriptedEngine([
      answer(category: '급여', type: 'expense', agg: 'count'),
    ]);
    final query = await LlmQueryParser(engine)
        .parse('월급날이 몇 번', today: today, categories: categories);
    expect(query!.type, TxType.income);
    expect(query.aggregation, QueryAggregation.count);
  });

  test('모르는 종류와 집계는 받지 않는다', () async {
    final engine = ScriptedEngine([answer(type: 'refund'), answer(agg: 'max')]);
    expect(
      await LlmQueryParser(engine)
          .parse('환불 얼마', today: today, categories: categories),
      isNull,
    );
  });
}
