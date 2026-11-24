import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:gagyebu/ai/llm/llm_engine.dart';
import 'package:gagyebu/ai/llm/narrative_template.dart';
import 'package:gagyebu/ai/llm/narrative_writer.dart';

/// 10월의 집계(`MonthSummary.toStatsJson()`의 꼴).
final stats = <String, Object?>{
  'month': '2026-10',
  'from': '2026-10-01',
  'to': '2026-10-31',
  'income': 3000000,
  'expense': 1860250,
  'net': 1139750,
  'previous_income': 2500000,
  'previous_expense': 1980250,
  'transaction_count': 42,
  'by_category': [
    {'name': '식비', 'amount': 595280, 'ratio': 0.32},
    {'name': '주거·통신', 'amount': 550000, 'ratio': 0.2957},
    {'name': '쇼핑', 'amount': 314970, 'ratio': 0.1693},
  ],
  'budget': {'amount': 2000000, 'spent': 1860250},
  'largest': [
    {'date': '2026-10-14', 'name': '이마트24', 'amount': 123400},
  ],
  'counterparties': [
    {'name': '김밥천국', 'amount': 56000, 'count': 7},
  ],
  'fixed_expense': 550000,
  'daily_average': 60008,
  'no_spend_days': 6,
};

/// 정해 둔 답을 차례로 내는 엔진. 답이 [Exception]이면 던진다.
class ScriptedEngine implements LlmEngine {
  ScriptedEngine(this.answers);

  final List<Object> answers;
  final users = <String>[];
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
    grammars.add(grammar);
    final answer = answers[users.length - 1];
    if (answer is Exception) throw answer;
    return answer as String;
  }
}

String sentences(List<String> list) => jsonEncode({'s': list});

const good = [
  '10월에는 186만 250원을 썼습니다.',
  '전달보다 12만 원 덜 썼습니다.',
  '가장 많이 쓴 분류는 식비(32%)입니다.',
];

List<String> badNumbers(String text) => [
  for (final n in unsupportedNumbers(text, stats)) n.toString(),
];

void main() {
  group('문장의 숫자를 집계와 대조한다', () {
    test('쉼표와 만 · 천 단위를 풀어 읽는다', () {
      num? only(String text) => findNarrativeNumbers(text).single.value;
      expect(only('1,860,250원을 썼습니다'), 1860250);
      expect(only('186만 250원'), 1860250);
      expect(only('12만 원'), 120000);
      expect(only('3천 원'), 3000);
      expect(only('1억 2,345만 6,789원'), 123456789);
      expect(only('1.5만 원'), 15000);
      expect(only('32%'), 32);
      expect(findNarrativeNumbers('32%').single.percent, isTrue);
      expect(findNarrativeNumbers('29.6 퍼센트').single.value, 29.6);
      // 단위 뒤의 숫자는 '원'이 따라올 때만 같은 금액이다.
      expect(findNarrativeNumbers('식비 30만 5건').map((n) => n.value), [
        300000,
        5,
      ]);
      expect(findNarrativeNumbers('숫자가 없습니다'), isEmpty);
    });

    test('집계에 있는 값은 통과한다', () {
      expect(badNumbers('10월에는 1,860,250원을 쓰고 3,000,000원을 벌었습니다.'), isEmpty);
      expect(badNumbers('186만 250원을 썼습니다. 수지는 113만 9,750원입니다.'), isEmpty);
      expect(badNumbers('식비가 59만 5,280원으로 32%를 차지했습니다.'), isEmpty);
      expect(badNumbers('주거·통신은 55만 원(30%)입니다.'), isEmpty);
      expect(badNumbers('주거·통신의 비중은 29.6%입니다.'), isEmpty);
      expect(badNumbers('김밥천국에 7번 가서 5만 6천 원을 썼습니다.'), isEmpty);
      expect(badNumbers('지출이 없던 날은 6일이고 거래는 42건입니다.'), isEmpty);
      expect(badNumbers('2026년 10월 1일부터 31일까지의 기록입니다.'), isEmpty);
      expect(badNumbers('10월 14일에 12만 3,400원을 썼습니다.'), isEmpty);
    });

    test('집계에서 한 번에 나오는 차이와 비율은 통과한다', () {
      // 전달과의 차이: 1,980,250 − 1,860,250
      expect(badNumbers('전달보다 12만 원 덜 썼습니다.'), isEmpty);
      // 예산에서 남은 돈과 쓴 비율
      expect(badNumbers('예산이 13만 9,750원 남았습니다.'), isEmpty);
      expect(badNumbers('예산의 93%를 썼습니다.'), isEmpty);
      // 전달 대비 줄어든 비율(6.06%)
      expect(badNumbers('전달보다 6% 줄었습니다.'), isEmpty);
      // 고정 지출을 뺀 나머지
      expect(badNumbers('고정 지출을 빼면 131만 250원입니다.'), isEmpty);
    });

    test('금액은 줄여 말해도 되지만 둘째 자리까지는 맞아야 한다', () {
      expect(badNumbers('약 186만 원을 썼습니다.'), isEmpty);
      expect(badNumbers('190만 원쯤 썼습니다.'), isEmpty);
      expect(badNumbers('하루 평균 6만 원을 썼습니다.'), isEmpty);
      expect(badNumbers('200만 원을 썼습니다.'), isEmpty, reason: '예산이 200만 원이다');
      expect(badNumbers('150만 원을 썼습니다.'), ['150만']);
      // 250만 원은 전달의 수입이라 집계에 있는 값이다. 270만 원은 어디에도 없다.
      expect(badNumbers('270만 원을 썼습니다.'), ['270만']);
      expect(badNumbers('1,860,251원을 썼습니다.'), ['1,860,251']);
    });

    test('집계에 없는 숫자를 잡는다', () {
      expect(badNumbers('식비가 45%를 차지했습니다.'), ['45%']);
      expect(badNumbers('카페에 15번 갔습니다.'), ['15']);
      expect(badNumbers('작년보다 80만 원 늘었습니다.'), ['80만']);
      expect(badNumbers('지출이 없던 날은 8일입니다.'), ['8']);
      // 퍼센트 자리에 온 숫자는 비율하고만 맞춘다. 42는 거래 건수지 비율이 아니다.
      expect(badNumbers('식비가 42% 늘었습니다.'), ['42%']);
      expect(badNumbers('3개월 연속으로 줄었습니다.'), ['3']);
    });

    test('차례를 세는 작은 수와 이름에 든 숫자는 금액이 아니다', () {
      expect(badNumbers('식비가 1위입니다. 상위 3개 분류가 대부분입니다.'), isEmpty);
      expect(badNumbers('가장 큰 지출은 이마트24의 12만 3,400원입니다.'), isEmpty);
      // 집계에 없는 이름의 숫자는 걸린다.
      expect(badNumbers('GS25에서 많이 썼습니다.'), ['25']);
    });
  });

  group('문장 틀', () {
    test('집계를 다섯 문장으로 옮긴다', () {
      expect(
        templateNarrative(stats),
        '10월에는 300만 원을 벌고 186만 250원을 썼습니다. '
        '전달보다 12만 원 덜 썼습니다. '
        '가장 많이 쓴 분류는 식비(32%, 59만 5,280원)입니다. '
        '예산 200만 원 가운데 186만 250원을 써서 13만 9,750원이 남았습니다. '
        '하루 평균 6만 8원을 썼고, 지출이 없던 날은 6일입니다.',
      );
    });

    test('예산이 없으면 고정 지출을, 그것도 없으면 가장 큰 지출을 말한다', () {
      final noBudget = {...stats, 'budget': null};
      expect(
        templateNarrative(noBudget),
        contains('반복 거래로 나간 고정 지출은 55만 원입니다.'),
      );
      final noFixed = {...noBudget, 'fixed_expense': 0};
      expect(
        templateNarrative(noFixed),
        contains('가장 큰 지출은 이마트24 12만 3,400원입니다.'),
      );
    });

    test('예산을 넘겼거나 전달보다 더 썼을 때', () {
      final over = {
        ...stats,
        'previous_expense': 1000000,
        'budget': {'amount': 1500000, 'spent': 1860250},
      };
      final text = templateNarrative(over);
      expect(text, contains('전달보다 86만 250원 더 썼습니다.'));
      expect(text, contains('예산 150만 원을 36만 250원 넘겼습니다.'));
      expect(
        templateNarrative({...stats, 'previous_expense': 1860250}),
        contains('전달과 똑같이 썼습니다.'),
      );
    });

    test('전달의 기록이나 수입이 없으면 그 말을 뺀다', () {
      final text = templateNarrative({
        ...stats,
        'income': 0,
        'previous_expense': 0,
        'no_spend_days': 0,
      });
      expect(text, startsWith('10월에는 186만 250원을 썼습니다. 가장 많이 쓴 분류는'));
      expect(text, isNot(contains('전달')));
      expect(text, endsWith('하루 평균 6만 8원을 썼습니다.'));
    });

    test('분류를 정하지 않은 지출이 가장 많을 때', () {
      final text = templateNarrative({
        ...stats,
        'by_category': [
          {'name': '분류 없음', 'amount': 900000, 'ratio': 0.4838},
        ],
      });
      expect(text, contains('분류를 정하지 않은 지출이 90만 원으로 가장 많았습니다.'));
    });

    test('지출이 없던 달', () {
      expect(
        templateNarrative({
          'month': '2026-10',
          'income': 3000000,
          'expense': 0,
          'previous_expense': 40000,
          'no_spend_days': 31,
        }),
        '10월에는 300만 원을 벌었고 지출은 없었습니다. 전달에는 4만 원을 썼습니다. '
        '지출이 없던 날은 31일입니다.',
      );
    });

    test('3–5문장이고 모두 "…습니다."로 끝난다', () {
      for (final sample in [
        stats,
        {...stats, 'budget': null},
        {...stats, 'budget': null, 'fixed_expense': 0, 'income': 0},
        {...stats, 'previous_expense': 0},
      ]) {
        final list = templateNarrative(sample)
            .split(RegExp(r'(?<=니다\.) '))
            .toList();
        expect(list.length, inInclusiveRange(3, 5), reason: '$list');
        for (final sentence in list) {
          expect(sentence, endsWith('니다.'));
        }
      }
    });

    test('문장 틀의 숫자는 모두 집계에 있다', () {
      for (final sample in [
        stats,
        {...stats, 'budget': null},
        {...stats, 'budget': null, 'fixed_expense': 0},
        {
          ...stats,
          'budget': {'amount': 1500000, 'spent': 1860250},
        },
      ]) {
        expect(
          unsupportedNumbers(templateNarrative(sample), sample),
          isEmpty,
          reason: templateNarrative(sample),
        );
      }
    });

    test('금액을 줄이지 않고 읽기 쉬운 말로 적는다', () {
      expect(koreanWon(0), '0원');
      expect(koreanWon(4500), '4,500원');
      expect(koreanWon(10000), '1만 원');
      expect(koreanWon(120000), '12만 원');
      expect(koreanWon(1860250), '186만 250원');
      expect(koreanWon(100000000), '1억 원');
      expect(koreanWon(123456789), '1억 2,345만 6,789원');
      expect(koreanWon(-35000), '-3만 5,000원');
    });
  });

  group('모델에게 쓰게 한다', () {
    test('검증을 통과한 글을 쓴다', () async {
      final engine = ScriptedEngine([sentences(good)]);
      final result = await NarrativeWriter(engine).write(stats);
      expect(result.text, good.join(' '));
      expect(result.aiModel, 'fake-model');
      expect(result.attempts, 1);
      // 집계는 금액 표기와 차이를 미리 풀어 준다.
      expect(engine.users.single, contains('지출: 186만 250원'));
      expect(engine.users.single, contains('전달보다 12만 원 덜 씀'));
      expect(engine.users.single, contains('식비 59만 5,280원(32%)'));
      expect(engine.grammars.single, contains('{2,4}'));
    });

    test('집계에 없는 숫자가 나오면 버리고 까닭을 붙여 한 번 다시 쓰게 한다', () async {
      final engine = ScriptedEngine([
        sentences([
          '10월에는 270만 원을 썼습니다.',
          '전달보다 12만 원 덜 썼습니다.',
          '식비가 가장 많았습니다.',
        ]),
        sentences(good),
      ]);
      final result = await NarrativeWriter(engine).write(stats);
      expect(result.text, good.join(' '));
      expect(result.aiModel, 'fake-model');
      expect(result.attempts, 2);
      expect(engine.users.last, contains('[앞선 글의 문제]'));
      expect(engine.users.last, contains('270만'));
    });

    test('두 번 어긋나면 문장 틀을 쓴다', () async {
      final engine = ScriptedEngine([
        sentences(['식비가 45%입니다.', '많이 썼습니다.', '아껴야겠습니다.']),
        sentences(['카페에 15번 갔습니다.', '많이 썼습니다.', '아껴야겠습니다.']),
      ]);
      final result = await NarrativeWriter(engine).write(stats);
      expect(result.text, templateNarrative(stats));
      expect(result.aiModel, isNull);
      expect(result.attempts, 2);
    });

    test('문장 수나 말투가 어긋나도 다시 쓰게 한다', () async {
      final engine = ScriptedEngine([
        sentences(['10월에는 186만 250원을 썼습니다.', '전달보다 덜 썼습니다.']),
        sentences(['10월에는 186만 250원을 썼어요.', '전달보다 덜 썼어요.', '잘했어요.']),
      ]);
      final result = await NarrativeWriter(engine).write(stats);
      expect(result.aiModel, isNull);
      expect(engine.users[1], contains('3–5문장'));

      final broken = ScriptedEngine(['{"s":["10월에는', sentences(good)]);
      final second = await NarrativeWriter(broken).write(stats);
      expect(second.aiModel, 'fake-model');
      expect(second.attempts, 2);
    });

    test('마침표가 빠진 문장에는 붙여 준다', () async {
      final engine = ScriptedEngine([
        sentences(['10월에는 186만 250원을 썼습니다', '전달보다 덜 썼습니다', '식비가 가장 많았습니다']),
      ]);
      final result = await NarrativeWriter(engine).write(stats);
      expect(result.text, '10월에는 186만 250원을 썼습니다. 전달보다 덜 썼습니다. 식비가 가장 많았습니다.');
    });

    test('모델이 답하지 못하면 다시 묻지 않고 문장 틀을 쓴다', () async {
      final engine = ScriptedEngine([Exception('모델이 내려갔다')]);
      final result = await NarrativeWriter(engine).write(stats);
      expect(result.text, templateNarrative(stats));
      expect(result.aiModel, isNull);
      expect(engine.users, hasLength(1));
    });

    test('모델이 없으면 문장 틀을 쓴다', () async {
      final result = await NarrativeWriter(null).write(stats);
      expect(result.text, templateNarrative(stats));
      expect(result.aiModel, isNull);
      expect(result.attempts, 0);
    });
  });
}
