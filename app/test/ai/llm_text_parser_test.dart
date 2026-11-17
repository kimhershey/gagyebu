import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:gagyebu/ai/llm/extraction_prompt.dart';
import 'package:gagyebu/ai/llm/llm_engine.dart';
import 'package:gagyebu/ai/llm/llm_text_parser.dart';
import 'package:gagyebu/ai/parsed_transaction.dart';
import 'package:gagyebu/core/local_date.dart';
import 'package:gagyebu/domain/default_seed.dart';

/// 정해 둔 답을 차례로 돌려주는 가짜 엔진. 받은 요청을 기록한다.
class ScriptedEngine implements LlmEngine {
  ScriptedEngine(this.answers);

  final List<Object> answers;
  final List<({String system, String user, Map<String, Object?> schema})>
  requests = [];
  final List<String?> grammars = [];

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
    requests.add((system: system, user: user, schema: schema));
    grammars.add(grammar);
    final answer = answers[requests.length - 1];
    return answer is String ? answer : jsonEncode(answer);
  }
}

Map<String, Object?> tx({
  String date = '2026-11-16',
  int? amount = 8000,
  String direction = 'out',
  String? counterparty = '김밥천국',
  String? memo,
  String? category = '식비',
}) => {
  'd': date,
  'a': amount,
  'io': direction,
  'who': counterparty,
  'memo': memo,
  'cat': category,
};

Map<String, Object?> answer(
  List<Map<String, Object?>> transactions, {
  bool real = true,
}) => {'tx': transactions, 'real': real};

void main() {
  // 2026-11-17은 화요일이다.
  final today = LocalDate(2026, 11, 17);

  Future<LlmParseResult> run(ScriptedEngine engine, String text) =>
      LlmTextParser(engine).parse(
        text,
        today: today,
        expenseCategories: defaultExpenseCategories,
        incomeCategories: defaultIncomeCategories,
      );

  group('요청 만들기', () {
    ExtractionRequest build(String text) => buildExtractionRequest(
      text: text,
      today: today,
      expenseCategories: defaultExpenseCategories,
      incomeCategories: defaultIncomeCategories,
    );

    test('날짜와 금액은 규칙이 후보를 뽑아 준다', () {
      final request = build(
        '신한카드(1234)승인 홍*동 12,500원(일시불) 11/16 12:31 김밥천국 누적 345,600원',
      );
      expect(request.user, contains('[오늘] 2026-11-17 (화)'));
      expect(request.user, contains('11/16 = 2026-11-16'));
      expect(request.user, contains('12,500원 = 12500 (금액)'));
      expect(request.user, contains('345,600원 = 345600 (누적)'));
      expect(request.dateCandidates, {LocalDate(2026, 11, 16)});
      expect(request.amountCandidates, {12500});
    });

    test('상대 날짜는 규칙이 풀어서 후보로 준다', () {
      final request = build('지난주 금요일 회식 3만 5천원');
      expect(request.user, contains('지난주 금요일 = 2026-11-13'));
      expect(request.dateCandidates, {LocalDate(2026, 11, 13)});
    });

    test('글에 날짜가 없으면 오늘이 유일한 후보다', () {
      final request = build('점심 8천원');
      expect(request.dateCandidates, {today});
      expect(request.user, contains('(글에 날짜가 없다) = 2026-11-17'));
    });

    test('잔액과 누적은 금액 후보가 아니다', () {
      final request = build('출금100,000 잔액900,000원 누적 1,200,000원');
      expect(request.amountCandidates, {100000});
      expect(request.balanceCandidates, {900000});
      final item =
          ((request.schema['properties']! as Map)['tx'] as Map)['items'] as Map;
      final properties = item['properties'] as Map;
      expect((properties['a'] as Map)['enum'], [100000]);
      expect(
        (properties['cat'] as Map)['enum'],
        containsAll(['식비', '급여', null]),
      );
      // 문법도 같은 후보만 받는다.
      expect(request.grammar, contains('"100000"'));
      expect(request.grammar, isNot(contains('900000')));
    });

    test('원문의 낱말로 방향이 정해지면 그 값만 받는다', () {
      final out = build('삼성1234승인 홍*동 100원 일시불 01/09 20:07 세븐일레븐');
      expect(out.direction, Direction.outgoing);
      final item =
          ((out.schema['properties']! as Map)['tx'] as Map)['items'] as Map;
      expect(((item['properties'] as Map)['io'] as Map)['enum'], ['out']);

      expect(build('우리 06/20 입금 472원 예금결산').direction, Direction.incoming);
      // 낱말이 없으면 모델이 고른다.
      expect(build('커피 2잔 9000원').direction, isNull);
    });

    test('취소 · 환불은 방향을 묻지 않고 지출의 취소로 둔다', () {
      final request = build('[쓱페이] 환불 완료 12,900원 이마트몰 11/13');
      expect(request.direction, Direction.outgoing);
      expect(_itemSchema(request)['io'], {
        'enum': ['out'],
      });
    });

    test('금액 후보가 없으면 금액은 비워 두게 한다', () {
      final request = build('해외승인 220.00 달러 ANTHROPIC');
      // 모델이 숫자를 지어내지 못한다. 220달러를 220원으로 적는 일을 막는다.
      expect(_itemSchema(request)['a'], {
        'enum': [null],
      });
      expect(request.grammar, contains(r'"\",\"a\":" ("null") '));
    });

    test('거래 낱말과 금액이 있고 안내문 표지가 없으면 거래 여부를 묻지 않는다', () {
      final certain = build('새봄카드(5678)승인 김*수 15,000원 03/08 한빛서점');
      expect(certain.certainlyTransaction, isTrue);
      expect((certain.schema['properties'] as Map)['real'], {'const': true});
      expect(
        certain.grammar.split('\n').first,
        endsWith(r'"],\"real\":" "true" "}"'),
      );

      // 해외 결제는 원화 금액 후보가 없어도 거래다.
      final foreign = build('해외승인 220.00 달러 ANTHROPIC');
      expect(foreign.amountCandidates, isEmpty);
      expect(foreign.certainlyTransaction, isTrue);
      expect(
        ((foreign.schema['properties'] as Map)['tx'] as Map)['minItems'],
        1,
      );

      // 안내문 표지가 있으면 모델이 판정한다.
      expect(
        build('[새봄카드] 11/25 결제예정금액 512,000원').certainlyTransaction,
        isFalse,
      );
      // 거래 낱말이 없는 문장도 모델이 판정한다.
      expect(build('점심 8천원').certainlyTransaction, isFalse);
      // 금액이 없으면 거래 낱말이 있어도 분명하지 않다.
      expect(build('카드 사용 내역을 확인하세요').certainlyTransaction, isFalse);
    });

    test('이름도 규칙이 후보를 뽑아 준다', () {
      final request = build(
        '신한카드(1234)승인 홍*동 12,500원(일시불) 11/16 12:31 김밥천국 누적 345,600원',
      );
      expect(request.nameCandidates, ['김밥천국']);
      expect(request.user, contains('[이름 후보]\n김밥천국\n'));
      final item = _itemSchema(request);
      expect(item['who'], {
        'enum': ['김밥천국', null],
      });
      expect(item['memo'], {
        'enum': ['김밥천국', null],
      });
      // 문법도 후보와 null만 받는다. 모델이 이름을 지어낼 수 없다.
      expect(request.grammar, contains(r'"\"김밥천국\"" | "null"'));
      expect(request.grammar, isNot(contains('string')));
    });

    test('문장에서는 묶음과 낱말을 함께 후보로 준다', () {
      final request = build('어제 점심 김밥천국 8천원 카드로');
      expect(request.nameCandidates, ['점심 김밥천국', '점심', '김밥천국']);
    });

    test('이름 후보가 없으면 null만 받는다', () {
      final request = build('12,000원');
      expect(request.nameCandidates, isEmpty);
      expect(request.user, contains('[이름 후보]\n(없음)\n'));
      expect(_itemSchema(request)['who'], {
        'enum': [null],
      });
    });

    test('금액이 보이면 거래를 먼저 적고 끝에서 판정하게 한다', () {
      final withAmount = build('[새봄카드] 11/25 결제예정금액 512,000원');
      final tx = (withAmount.schema['properties'] as Map)['tx'] as Map;
      expect(tx['minItems'], 1);
      expect(withAmount.schema['required'], ['tx', 'real']);
      expect(
        withAmount.grammar.split('\n').first,
        r'root ::= "{\"tx\":[" tx ("," tx){0,19} "],\"real\":" '
        '("true" | "false") "}"',
      );

      // 금액이 없으면 거래를 적지 않아도 된다.
      final without = build('(광고) 주말 특가 최대 50% 할인');
      expect(without.amountCandidates, isEmpty);
      expect(
        ((without.schema['properties'] as Map)['tx'] as Map)['minItems'],
        0,
      );
      expect(without.grammar, contains('(tx ("," tx){0,19})?'));
    });

    test('예시의 답은 예시의 후보로 만들 수 있다', () async {
      final categories = {
        ...defaultExpenseCategories,
        ...defaultIncomeCategories,
      };
      for (final example in extractionExamples) {
        final request = buildExtractionRequest(
          text: example.input,
          today: extractionExampleToday,
          expenseCategories: defaultExpenseCategories,
          incomeCategories: defaultIncomeCategories,
        );
        final reason = example.input;
        for (final t in example.transactions) {
          expect(
            request.dateCandidates.map((d) => '$d'),
            contains(t['d']),
            reason: reason,
          );
          expect(request.amountCandidates, contains(t['a']), reason: reason);
          expect(request.direction?.code ?? t['io'], t['io'], reason: reason);
          for (final key in ['who', 'memo']) {
            if (t[key] != null) {
              expect(request.nameCandidates, contains(t[key]), reason: reason);
            }
          }
          if (t['cat'] != null) {
            expect(categories, contains(t['cat']), reason: reason);
          }
        }
        // 금액이 보이면 문법이 거래를 한 건 이상 요구한다.
        if (request.amountCandidates.isNotEmpty) {
          expect(example.transactions, isNotEmpty, reason: reason);
        }
        // 규칙이 거래로 못 박은 글을 예시에서 거래가 아니라고 답하면 안 된다.
        if (request.certainlyTransaction) {
          expect(example.real, isTrue, reason: reason);
        }
        expect(request.system, contains('답: ${example.answer(categories)}'));

        // 검증도 그대로 통과한다.
        final engine = ScriptedEngine([example.answer(categories)]);
        final result = await LlmTextParser(engine).parse(
          example.input,
          today: extractionExampleToday,
          expenseCategories: defaultExpenseCategories,
          incomeCategories: defaultIncomeCategories,
        );
        expect(result.failed, isFalse, reason: reason);
        expect(result.attempts, 1, reason: reason);
        expect(result.isTransaction, example.real, reason: reason);
        expect(
          result.transactions,
          hasLength(example.real ? example.transactions.length : 0),
          reason: reason,
        );
      }
    });

    test('요청마다 바뀌지 않는 내용은 고정 부분에 둔다', () {
      final a = build('점심 8천원');
      final b = build('어제 택시 12,300원');
      // 엔진이 고정 부분을 한 번만 읽고 재사용할 수 있다. 날짜도 들어 있지 않다.
      expect(a.system, b.system);
      expect(a.system, contains('[분류]'));
      expect(a.system, contains('예시 1'));
      expect(a.system, isNot(contains('2026-11-17')));
      expect(a.user, isNot(b.user));
    });

    test('사용자의 분류 목록에 없는 분류는 예시에서 null로 적는다', () {
      final request = buildExtractionRequest(
        text: '점심 8천원',
        today: today,
        expenseCategories: const ['먹는 것'],
        incomeCategories: const ['번 돈'],
      );
      expect(request.system, isNot(contains('"cat":"식비"')));
      expect(request.system, contains('"cat":null'));
    });
  });

  group('출력 검증', () {
    test('맞는 답은 거래 초안이 된다', () async {
      final engine = ScriptedEngine([
        answer([tx(memo: '점심')]),
      ]);
      final result = await run(engine, '어제 점심 김밥천국 8천원 카드로');
      expect(result.failed, isFalse);
      expect(result.attempts, 1);
      final parsed = result.transactions.single;
      expect(parsed.date, LocalDate(2026, 11, 16));
      expect(parsed.amount, 8000);
      expect(parsed.direction, Direction.outgoing);
      expect(parsed.counterparty, '김밥천국');
      expect(parsed.memo, '점심');
      expect(parsed.category, '식비');
      expect(parsed.ruleId, 'llm:fake-model');
      expect(parsed.modelName, 'fake-model');
      expect(engine.grammars.single, isNotNull);
    });

    test('후보에 없는 금액은 이유를 붙여 다시 묻는다', () async {
      final engine = ScriptedEngine([
        answer([tx(amount: 345600)]),
        answer([tx(amount: 12500, counterparty: '김밥천국 강남점')]),
      ]);
      final result = await run(
        engine,
        '신한카드(1234)승인 홍*동 12,500원(일시불) 11/16 12:31 김밥천국 강남점 누적 345,600원',
      );
      expect(result.attempts, 2);
      expect(result.transactions.single.amount, 12500);
      expect(engine.requests[1].user, contains('[앞선 답의 문제]'));
      expect(engine.requests[1].user, contains('345600'));
    });

    test('후보에 없는 날짜도 다시 묻는다', () async {
      final engine = ScriptedEngine([
        answer([tx(date: '2026-11-17')]),
        answer([tx(date: '2026-11-16')]),
      ]);
      final result = await run(engine, '어제 점심 김밥천국 8천원');
      expect(result.attempts, 2);
      expect(result.transactions.single.date, LocalDate(2026, 11, 16));
      expect(engine.requests[1].user, contains('[날짜 후보]에 없다'));
    });

    test('두 번 모두 틀리면 포기하고 이유를 남긴다', () async {
      final engine = ScriptedEngine([
        answer([tx(date: '2026-11-17', amount: 1)]),
        answer([tx(date: '2026-11-17', amount: 2)]),
      ]);
      final result = await run(engine, '점심 8천원');
      expect(result.failed, isTrue);
      expect(result.transactions, isEmpty);
      expect(result.failure, contains('금액 후보'));
    });

    test('잘린 JSON은 실패로 보고 다시 묻는다', () async {
      final engine = ScriptedEngine([
        '{"tx":[{"d":"2026-11-1',
        answer([tx()]),
      ]);
      final result = await run(engine, '어제 점심 김밥천국 8천원');
      expect(result.attempts, 2);
      expect(result.transactions, hasLength(1));
    });

    test('안내문으로 본 글은 거래가 없다', () async {
      final engine = ScriptedEngine([answer([])]);
      final result = await run(engine, '고객님의 포인트 3,000점이 곧 소멸됩니다');
      expect(result.isTransaction, isFalse);
      expect(result.transactions, isEmpty);
      expect(result.failed, isFalse);
    });

    test('모델이 돈이 움직이지 않았다고 보면 적어 둔 거래를 버린다', () async {
      final engine = ScriptedEngine([
        answer([
          tx(
            date: '2025-11-25',
            amount: 512000,
            counterparty: null,
            category: null,
          ),
        ], real: false),
      ]);
      final result = await run(engine, '[새봄카드] 11/25 결제예정금액 512,000원');
      expect(result.isTransaction, isFalse);
      expect(result.transactions, isEmpty);
      expect(result.failed, isFalse);
      expect(result.attempts, 1);
    });

    test('상대와 내용에 같은 말을 고르면 상대로만 둔다', () async {
      final engine = ScriptedEngine([
        answer([tx(date: '2026-11-17', memo: '김밥천국')]),
      ]);
      final result = await run(engine, '김밥천국 8천원');
      expect(result.transactions.single.counterparty, '김밥천국');
      expect(result.transactions.single.memo, isNull);
    });

    test('규칙으로 거래가 분명하면 모델이 아니라고 해도 초안을 만든다', () async {
      final engine = ScriptedEngine([
        answer([
          tx(date: '2026-11-16', amount: 12500, counterparty: '김밥천국'),
        ], real: false),
      ]);
      final result = await run(
        engine,
        '새봄카드(1234)승인취소 12,500원 11/16 12:31 김밥천국',
      );
      expect(result.isTransaction, isTrue);
      expect(result.transactions.single.amount, 12500);
      expect(result.transactions.single.isCancel, isTrue);
    });

    test('규칙으로 거래가 분명한데 거래를 적지 않으면 다시 묻는다', () async {
      final engine = ScriptedEngine([
        answer([], real: false),
        answer([tx(date: '2026-11-16', amount: 12500)]),
      ]);
      final result = await run(engine, '새봄카드(1234)승인 12,500원 11/16 김밥천국');
      expect(result.attempts, 2);
      expect(engine.requests[1].user, contains('거래를 한 건 이상 적어야 한다.'));
      expect(result.transactions, hasLength(1));
    });

    test('금액 후보가 없으면 모델이 적은 숫자를 버린다', () async {
      final engine = ScriptedEngine([
        answer([
          tx(date: '2026-11-11', amount: 220, counterparty: 'ANTHROPIC'),
        ]),
      ]);
      final result = await run(engine, '해외승인 220.00 달러 11/11 ANTHROPIC');
      expect(result.transactions.single.amount, isNull);
      expect(
        result.transactions.single.warnings,
        contains(ParseWarning.needsKrwAmount),
      );
    });

    test('연도 없는 날짜는 규칙이 가장 가까운 과거로 정해 둔다', () async {
      // 오늘(11월 17일)보다 뒤인 12월 11일은 지난해다. 후보가 이미 그렇게 풀려 있다.
      final engine = ScriptedEngine([
        answer([tx(date: '2025-12-11', amount: 7250, counterparty: '세븐일레븐')]),
      ]);
      final result = await run(engine, '12/11 15:42 출금 7,250원 세븐일레븐');
      final parsed = result.transactions.single;
      expect(parsed.date, LocalDate(2025, 12, 11));
      expect(parsed.warnings, contains(ParseWarning.yearInferred));
    });

    test('글에 연도가 있으면 그 날짜가 후보다', () async {
      final engine = ScriptedEngine([
        answer([tx(date: '2021-08-19', amount: 11000, counterparty: null)]),
      ]);
      final result = await run(engine, '2021/08/19 04:55 출금 11,000원');
      final parsed = result.transactions.single;
      expect(parsed.date, LocalDate(2021, 8, 19));
      expect(parsed.warnings, isNot(contains(ParseWarning.yearInferred)));
    });

    test('글에 없는 상대 · 내용과 없는 분류는 버린다', () async {
      final engine = ScriptedEngine([
        answer([tx(counterparty: '스타벅스 강남점', memo: '아메리카노', category: '없는분류')]),
      ]);
      final result = await run(engine, '어제 커피 8천원');
      final parsed = result.transactions.single;
      expect(parsed.counterparty, isNull);
      expect(parsed.memo, isNull);
      expect(parsed.category, isNull);
      expect(parsed.warnings, contains(ParseWarning.noCounterparty));
    });

    test('가린 이름은 상대로 받지 않는다', () async {
      final engine = ScriptedEngine([
        answer([tx(date: '2026-02-08', amount: 129857, counterparty: '홍*동')]),
      ]);
      final result = await run(
        engine,
        'KB국민카드1234승인 홍*동님 129,857원 일시불 02/08 22:39 마켓컬리',
      );
      expect(result.transactions.single.counterparty, isNull);
    });

    test('시각 · 잔액 · 할부 개월은 규칙이 원문에서 읽는다', () async {
      final engine = ScriptedEngine([
        answer([tx(date: '2026-11-16', amount: 600000, counterparty: '하이마트')]),
      ]);
      final result = await run(
        engine,
        '새로운카드 승인 600,000원 6개월 11/16 12:31 하이마트 잔액 4,123,123원',
      );
      final parsed = result.transactions.single;
      expect(parsed.time, '12:31');
      expect(parsed.balanceAfter, 4123123);
      expect(parsed.installmentMonths, 6);
      expect(parsed.counterparty, '하이마트');
      expect(parsed.isCancel, isFalse);
    });

    test('취소 여부는 원문의 낱말로 정한다', () async {
      final engine = ScriptedEngine([
        answer([tx(date: '2026-10-09', amount: 4020, counterparty: '쿠팡')]),
      ]);
      final result = await run(engine, '새로운카드 승인취소 4,020원 10/09 19:41 쿠팡');
      expect(result.transactions.single.isCancel, isTrue);
    });

    test('기간을 뜻하는 개월은 할부로 읽지 않는다', () async {
      final engine = ScriptedEngine([
        answer([tx(date: '2026-11-17', amount: 270000, counterparty: '헬스장')]),
      ]);
      final result = await run(engine, '오늘 헬스장 3개월 27만원');
      expect(result.transactions.single.installmentMonths, isNull);
    });

    test('여러 건이면 시각과 잔액을 붙이지 않는다', () async {
      final engine = ScriptedEngine([
        answer([
          tx(date: '2026-11-16', amount: 8000, counterparty: '김밥천국'),
          tx(date: '2026-11-16', amount: 4500, counterparty: '스타벅스'),
        ]),
      ]);
      final result = await run(engine, '어제 12:31 김밥천국 8천원, 스타벅스 4500원');
      expect(result.transactions, hasLength(2));
      expect(result.transactions.every((t) => t.time == null), isTrue);
    });

    test('원문의 낱말로 정해진 방향은 모델의 답보다 앞선다', () async {
      final engine = ScriptedEngine([
        answer([
          tx(
            date: '2026-06-20',
            amount: 472,
            direction: 'out',
            counterparty: '예금결산',
          ),
        ]),
      ]);
      final result = await run(
        engine,
        '우리 06/20 11:20 입금 472원 예금결산 잔액 1,199,234원',
      );
      final parsed = result.transactions.single;
      expect(parsed.direction, Direction.incoming);
      expect(parsed.warnings, contains(ParseWarning.directionMismatch));
    });

    test('금액 후보가 없는 해외 결제는 원화 금액을 비워 둔다', () async {
      final engine = ScriptedEngine([
        answer([
          tx(date: '2026-11-11', amount: null, counterparty: 'ANTHROPIC'),
        ]),
      ]);
      final result = await run(engine, '해외승인 220.00 달러 11/11 ANTHROPIC');
      final parsed = result.transactions.single;
      expect(parsed.amount, isNull);
      expect(parsed.warnings, contains(ParseWarning.needsKrwAmount));
    });
  });
}

Map<String, Object?> _itemSchema(ExtractionRequest request) {
  final tx = (request.schema['properties'] as Map)['tx'] as Map;
  return ((tx['items'] as Map)['properties'] as Map).cast<String, Object?>();
}
