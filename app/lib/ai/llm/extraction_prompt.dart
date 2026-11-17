/// 텍스트 해석 요청(프롬프트와 출력 형식)을 만든다.
///
/// 원칙
/// - 규칙으로 정할 수 있는 것은 규칙이 정한다. 날짜 · 금액 · 이름은 규칙이 원문에서 후보를
///   뽑고, 모델은 그 안에서 고르기만 한다. 후보가 하나면 문법이 그 값을 강제한다.
///   방향도 원문의 낱말(입금 · 출금 · 승인)로 정해지면 모델에 묻지 않는다.
/// - 모델에는 뜻을 알아야 답할 수 있는 것만 묻는다: 후보 가운데 어느 것이 상대이고 어느 것이
///   내용인지, 분류가 무엇인지, 돈이 실제로 움직인 글인지.
/// - 거래인지 아닌지는 맨 끝에 묻는다. 금액이 보이면 먼저 거래를 적게 하고 그다음에
///   `real`로 판정하게 한다. 첫 토큰에서 "거래 없음"으로 빠지는 일을 막는다.
///   원문에 거래 낱말(승인 · 출금 · 입금 · 취소)과 금액이 있고 안내문 표지가 없으면 묻지
///   않고 거래로 본다.
/// - 금액은 규칙이 찾은 것만 쓴다. 후보가 없으면 모델이 숫자를 지어내지 못하게 비워 둔다.
/// - 출력은 짧게 한다. 기기 안의 추론은 토큰 하나마다 시간이 들기 때문에 키를 줄이고
///   공백 없는 문법으로 묶는다.
/// - 요청마다 바뀌지 않는 내용(규칙, 분류, 예시)은 [ExtractionRequest.system]에 두어 추론
///   엔진이 한 번만 읽고 재사용하게 한다.
///
/// 이렇게 정한 근거는 `eval/README.md`의 실측 기록에 있다.
library;

import 'dart:convert';

import '../../core/formatters.dart';
import '../../core/local_date.dart';
import '../parsed_transaction.dart';
import '../text/amount_parser.dart';
import '../text/date_parser.dart';
import '../text/direction_rules.dart';
import '../text/name_candidates.dart';
import '../text/non_transaction.dart';
import '../text/text_normalizer.dart';

/// 프롬프트와 출력 형식의 판. 바꾸면 올리고, 평가 보고서에 함께 적는다.
const extractionPromptVersion = 'v5';

/// 모델에 보낼 요청.
class ExtractionRequest {
  const ExtractionRequest({
    required this.system,
    required this.user,
    required this.schema,
    required this.grammar,
    required this.dateCandidates,
    required this.amountCandidates,
    required this.balanceCandidates,
    required this.nameCandidates,
    required this.direction,
    required this.certainlyTransaction,
  });

  /// 고정 부분: 규칙, 분류, 예시.
  final String system;

  /// 요청마다 달라지는 부분: 오늘, 날짜 · 금액 · 이름 후보, 입력.
  final String user;

  /// 출력의 JSON 스키마.
  final Map<String, Object?> schema;

  /// 같은 형식을 공백 없이 강제하는 GBNF 문법(llama.cpp).
  final String grammar;

  /// 거래 날짜로 고를 수 있는 값. 원문에 날짜가 없으면 오늘 하나다.
  final Set<LocalDate> dateCandidates;

  /// 거래 금액으로 고를 수 있는 값.
  final Set<int> amountCandidates;

  /// 잔액으로 읽힌 값.
  final Set<int> balanceCandidates;

  /// 상대 · 내용으로 고를 수 있는 말.
  final List<String> nameCandidates;

  /// 원문의 낱말로 정해진 방향. 정해지지 않았으면 null이고 모델이 고른다.
  final Direction? direction;

  /// 규칙만으로 거래가 분명한 글인지. true면 모델에 거래 여부를 묻지 않는다.
  final bool certainlyTransaction;
}

const _rules = '''
너는 가계부 앱의 입력 해석기다. [입력]을 읽고 JSON으로만 답한다.

출력 형식: {"tx":[{"d":날짜,"a":금액,"io":방향,"who":상대,"memo":내용,"cat":분류}],"real":참거짓}
- d: [날짜 후보]에서 이 거래의 날짜를 고른다.
- a: [금액 후보]에서 역할이 "금액"인 값을 고른다. "잔액"과 "누적"은 거래 금액이 아니다. 고를 값이 없으면 null이다.
- io: 돈이 들어왔으면 "in"(입금, 급여, 환급, 받음), 나갔으면 "out"(출금, 승인, 결제, 사용, 보냄)이다. 물건이나 서비스의 이름과 금액만 있으면 "out"이다.
- who: [이름 후보]에서 가맹점이나 돈을 주고받은 상대를 고른다. 결제 문자와 입출금 알림의 후보는 대개 상대다. 상대가 없으면 null이다.
- memo: [이름 후보]에서 무엇에 쓴 돈인지 나타내는 말을 고른다(점심, 택시비). who와 같은 말은 고르지 않는다. 없으면 null이다.
- cat: [분류]의 이름 가운데 하나다. 맞는 것이 없으면 null이다.
- real: 돈이 실제로 움직였으면 true다. 광고, 인증번호, 출금 · 결제 예정 안내, 명세서 · 한도 안내, 실패 · 거절 안내처럼 돈이 움직이지 않은 글이면 false다.''';

/// 원문에서 규칙이 읽어 낸 것.
class _Analysis {
  _Analysis(String text, LocalDate today)
    : dateFinds = findDateExpressions(text, today),
      amountFinds = findAmountCandidates(text),
      names = findNameCandidates(text, today),
      // 취소 · 환불은 결제를 되돌린 것이라 '지출의 취소'로 적는다. 방향을 모델에 묻지 않는다.
      direction = mentionsCancel(text)
          ? Direction.outgoing
          : directionFromKeywords(text);

  final List<DateExpression> dateFinds;
  final List<AmountCandidate> amountFinds;
  final List<String> names;
  final Direction? direction;
}

/// [text]를 해석해 달라는 요청을 만든다.
///
/// [feedback]은 앞선 답이 검증에서 떨어졌을 때 덧붙이는 설명이다.
ExtractionRequest buildExtractionRequest({
  required String text,
  required LocalDate today,
  required List<String> expenseCategories,
  required List<String> incomeCategories,
  String? feedback,
}) {
  final found = _Analysis(text, today);
  final amounts = <int>{
    for (final c in found.amountFinds)
      if (c.role == AmountRole.amount && c.value > 0) c.value,
  };
  final balances = <int>{
    for (final c in found.amountFinds)
      if (c.role == AmountRole.balance) c.value,
  };
  final dates = <LocalDate>{
    if (found.dateFinds.isEmpty)
      today
    else
      ...found.dateFinds.map((d) => d.date),
  };
  final categories = [...expenseCategories, ...incomeCategories];
  // 거래 낱말과 금액이 있고 안내문 표지가 없으면 거래가 분명하다.
  final certain =
      (amounts.isNotEmpty || _foreignAmount.hasMatch(text)) &&
      (found.direction != null || mentionsCancel(text)) &&
      detectNonTransaction(foldWhitespace(text)) == null;
  final shape = _Shape(
    dates: dates,
    amounts: amounts,
    direction: found.direction,
    names: found.names,
    categories: categories,
    certain: certain,
  );

  final system = StringBuffer(_rules)
    ..writeln()
    ..writeln()
    ..writeln(
      '[분류] 지출: ${expenseCategories.join(', ')} / 수입: ${incomeCategories.join(', ')}',
    )
    ..writeln()
    ..write(_examples(categories.toSet()));

  final user = StringBuffer(_userBlock(today, found, text));
  if (feedback != null) {
    user
      ..writeln()
      ..write('[앞선 답의 문제] $feedback 고쳐서 다시 답한다.');
  }

  return ExtractionRequest(
    system: system.toString(),
    user: user.toString(),
    schema: _schema(shape),
    grammar: _grammar(shape),
    dateCandidates: dates,
    amountCandidates: amounts,
    balanceCandidates: balances,
    nameCandidates: found.names,
    direction: found.direction,
    certainlyTransaction: certain,
  );
}

/// 해외 결제 금액. 원화 금액 후보가 없어도 돈이 움직인 글로 본다.
final _foreignAmount = RegExp(
  r'\d(?:\.\d+)?\s?(?:달러|엔|유로|위안|파운드|USD|EUR|JPY|CNY|GBP)'
  r'|(?:USD|EUR|JPY|CNY|GBP|US\$|\$|€|¥|£)\s?\d',
);

/// 답의 꼴을 정하는 값.
class _Shape {
  const _Shape({
    required this.dates,
    required this.amounts,
    required this.direction,
    required this.names,
    required this.categories,
    required this.certain,
  });

  final Set<LocalDate> dates;
  final Set<int> amounts;
  final Direction? direction;
  final List<String> names;
  final List<String> categories;
  final bool certain;

  /// 금액이 보이거나 거래가 분명하면 거래를 한 건 이상 적게 한다.
  bool get needsTransaction => amounts.isNotEmpty || certain;
}

/// 요청마다 달라지는 부분. 예시도 같은 꼴로 적는다.
String _userBlock(LocalDate today, _Analysis found, String input) {
  final b = StringBuffer()
    ..writeln('[오늘] $today (${weekdayName(today)})')
    ..writeln('[날짜 후보]');
  if (found.dateFinds.isEmpty) {
    b.writeln('(글에 날짜가 없다) = $today');
  } else {
    for (final d in found.dateFinds) {
      b.writeln('${d.text} = ${d.date}');
    }
  }
  b.writeln('[금액 후보]');
  if (found.amountFinds.isEmpty) {
    b.writeln('(없음)');
  } else {
    for (final c in found.amountFinds) {
      b.writeln('${c.text} = ${c.value} (${_roleLabel(c.role)})');
    }
  }
  b.writeln('[이름 후보]');
  if (found.names.isEmpty) {
    b.writeln('(없음)');
  } else {
    found.names.forEach(b.writeln);
  }
  b
    ..writeln('[입력]')
    ..write(input);
  return b.toString();
}

/// 고정 부분에 넣는 예시 한 건.
class ExtractionExample {
  const ExtractionExample(this.input, this.transactions, {this.real = true});

  final String input;

  /// 답의 거래. `cat`에는 기본 분류의 이름을 적는다. 사용자의 분류 목록에 없는 이름은
  /// 답을 만들 때 null로 바뀐다.
  final List<Map<String, Object?>> transactions;
  final bool real;

  /// [categories]에 맞춘 답.
  String answer(Set<String> categories) => jsonEncode({
    'tx': [
      for (final t in transactions)
        {...t, 'cat': categories.contains(t['cat']) ? t['cat'] : null},
    ],
    'real': real,
  });
}

/// 예시 속의 '오늘'.
final extractionExampleToday = LocalDate(2026, 3, 10);

/// 고정 부분에 넣는 예시. 후보 목록은 실제 요청과 같은 코드로 만든다.
const extractionExamples = <ExtractionExample>[
  ExtractionExample('어제 점심 김밥천국 8천원 카드로', [
    {
      'd': '2026-03-09',
      'a': 8000,
      'io': 'out',
      'who': '김밥천국',
      'memo': '점심',
      'cat': '식비',
    },
  ]),
  ExtractionExample(
    '새봄카드(5678)승인 김*수 15,000원 일시불 03/08 19:20 한빛서점 누적230,000원',
    [
      {
        'd': '2026-03-08',
        'a': 15000,
        'io': 'out',
        'who': '한빛서점',
        'memo': null,
        'cat': '교육',
      },
    ],
  ),
  ExtractionExample(
    '새봄은행 03/05 09:00 123-***-456 입금 2,500,000원 (주)한빛상사 잔액 3,100,000원',
    [
      {
        'd': '2026-03-05',
        'a': 2500000,
        'io': 'in',
        'who': '(주)한빛상사',
        'memo': null,
        'cat': '급여',
      },
    ],
  ),
  ExtractionExample('아침 버스비 1500원', [
    {
      'd': '2026-03-10',
      'a': 1500,
      'io': 'out',
      'who': null,
      'memo': '버스비',
      'cat': '교통',
    },
  ]),
  ExtractionExample('[새봄카드] 김*수님 03/25 결제예정금액 512,000원', [
    {
      'd': '2025-03-25',
      'a': 512000,
      'io': 'out',
      'who': null,
      'memo': null,
      'cat': null,
    },
  ], real: false),
  ExtractionExample('(광고) 새봄마트 주말 특가 수신거부 080-123-4567', [], real: false),
];

String _examples(Set<String> categories) {
  final b = StringBuffer();
  for (final (i, example) in extractionExamples.indexed) {
    final found = _Analysis(example.input, extractionExampleToday);
    b
      ..writeln('예시 ${i + 1}')
      ..writeln(_userBlock(extractionExampleToday, found, example.input))
      ..writeln('답: ${example.answer(categories)}')
      ..writeln();
  }
  return b.toString().trimRight();
}

String _roleLabel(AmountRole role) => switch (role) {
  AmountRole.amount => '금액',
  AmountRole.balance => '잔액',
  AmountRole.cumulative => '누적',
};

List<String> _sortedDates(Set<LocalDate> dates) => [
  for (final d in dates.toList()..sort()) d.toString(),
];

Map<String, Object?> _schema(_Shape shape) => {
  'type': 'object',
  'properties': {
    'tx': {
      'type': 'array',
      'minItems': shape.needsTransaction ? 1 : 0,
      'maxItems': 20,
      'items': {
        'type': 'object',
        'properties': {
          'd': {'enum': _sortedDates(shape.dates)},
          // 후보가 없으면(해외 결제 등) 비워 둔다.
          'a': {
            'enum': shape.amounts.isEmpty
                ? [null]
                : (shape.amounts.toList()..sort()),
          },
          'io': {
            'enum': shape.direction == null
                ? ['in', 'out']
                : [shape.direction!.code],
          },
          'who': {
            'enum': [...shape.names, null],
          },
          'memo': {
            'enum': [...shape.names, null],
          },
          'cat': {
            'enum': [...shape.categories, null],
          },
        },
        'required': ['d', 'a', 'io', 'who', 'memo', 'cat'],
        'additionalProperties': false,
      },
    },
    'real': shape.certain ? {'const': true} : {'type': 'boolean'},
  },
  'required': ['tx', 'real'],
  'additionalProperties': false,
};

/// 출력 형식을 공백 없이 강제하는 GBNF 문법.
String _grammar(_Shape shape) {
  String literal(String text) => jsonEncode(text);
  // JSON 문자열 값을 문법의 글자 그대로로 적는다: "식비" → "\"식비\""
  String quoted(String value) => literal(jsonEncode(value));

  final date = _sortedDates(shape.dates).map(literal).join(' | ');
  final amount = shape.amounts.isEmpty
      ? '"null"'
      : (shape.amounts.toList()..sort()).map((a) => literal('$a')).join(' | ');
  final io = shape.direction == null
      ? '"in" | "out"'
      : literal(shape.direction!.code);
  final name = [for (final n in shape.names) quoted(n), '"null"'].join(' | ');
  final category = [
    for (final c in shape.categories) quoted(c),
    '"null"',
  ].join(' | ');
  final list = shape.needsTransaction
      ? 'tx ("," tx){0,19}'
      : '(tx ("," tx){0,19})?';
  final real = shape.certain ? '"true"' : '("true" | "false")';

  return [
    'root ::= ${literal('{"tx":[')} $list ${literal('],"real":')} $real "}"',
    'tx ::= ${literal('{"d":"')} ($date) ${literal('","a":')} ($amount) '
        '${literal(',"io":"')} ($io) ${literal('","who":')} ($name) '
        '${literal(',"memo":')} ($name) '
        '${literal(',"cat":')} ($category) "}"',
  ].join('\n');
}
