/// 이미지 해석 요청(프롬프트와 출력 형식)을 만든다(`docs/SPEC.md` 5.5).
///
/// 원칙
/// - 모델은 이미지에 보이는 글자를 **그대로 옮기기만** 한다. 날짜의 연도, 금액의 숫자,
///   방향의 부호는 규칙이 다시 읽는다(`vision_rows.dart`). 글 해석과 달리 규칙이 먼저 뽑아
///   둔 후보가 없으므로, 잔액이 이어지는지 · 품목의 합이 총액과 맞는지로 검산한다.
/// - 종류(`kind`)를 맨 앞에 묻는다. 거래내역 화면인지 영수증인지에 따라 줄의 뜻이 달라지기
///   때문이다(거래 한 건 · 품목 한 줄).
/// - 출력은 짧게 한다. 키를 줄이고 공백 없는 문법으로 묶는다. 값의 길이도 문법으로 막아
///   한 칸에서 끝없이 이어 쓰지 못하게 한다.
/// - 요청마다 바뀌는 것이 없어 고정 부분([VisionRequest.system])을 엔진이 재사용한다.
///
/// 이 프롬프트는 실제 이미지 모델로 돌려 본 적이 없다. 통할지는 추정이다.
library;

import 'dart:convert';

/// 프롬프트와 출력 형식의 판. 바꾸면 올린다.
const visionPromptVersion = 'v1';

/// 한 장에서 읽는 줄 수의 한도. 화면 캡처 한 장에 이보다 많은 거래가 보이기는 어렵다.
const visionMaxRows = 40;

/// 모델에 보낼 요청.
class VisionRequest {
  const VisionRequest({
    required this.system,
    required this.user,
    required this.schema,
    required this.grammar,
  });

  /// 고정 부분: 규칙과 답의 본보기.
  final String system;

  /// 이미지와 함께 보내는 말. 앞선 답이 검증에서 떨어졌으면 그 까닭이 붙는다.
  final String user;

  /// 출력의 JSON 스키마.
  final Map<String, Object?> schema;

  /// 같은 형식을 공백 없이 강제하는 GBNF 문법(llama.cpp).
  final String grammar;
}

const _rules = '''
너는 가계부 앱의 이미지 판독기다. 이미지를 보고 JSON으로만 답한다.

출력 형식: {"kind":종류,"shop":가게,"rows":[{"d":날짜,"t":시각,"a":금액,"io":방향,"who":이름,"bal":잔액}],"total":총액}
- kind: 은행 · 카드 앱의 거래 목록이면 "statement", 가게에서 받은 영수증이면 "receipt", 둘 다 아니면 "other"다.
- 모든 값은 이미지에 보이는 글자를 그대로 옮긴다. 더하거나 빼지 않고, 고치지 않고, 짐작해서 채우지 않는다. 보이지 않는 값은 null이다.
- rows: 위에서 아래로 보이는 순서대로 적는다. 줄을 빠뜨리거나 합치지 않는다. "other"면 비운다.

kind가 "statement"일 때(거래 한 건이 한 줄)
- d: 그 거래의 날짜("11.15", "2026-11-15", "11월 15일", "어제"). 날짜가 묶음의 머리에만 있으면 그 묶음의 줄마다 같은 날짜를 적는다.
- t: 시각("14:32"). 없으면 null.
- a: 거래 금액의 숫자("12,500"). 앞에 +나 -가 보이면 함께 적는다. 잔액을 적지 않는다.
- io: 돈이 들어왔으면 "in"(입금, +), 나갔으면 "out"(출금, 결제, 승인, -)이다. 알 수 없으면 null.
- who: 상대방, 가맹점, 적요로 보이는 말.
- bal: 그 줄에 적힌 거래 뒤 잔액의 숫자("1,234,500"). 잔액이 보이지 않으면 null.
- shop과 total은 null이다.

kind가 "receipt"일 때(품목 하나가 한 줄)
- shop: 가게 이름.
- d, t: 영수증에 찍힌 거래 날짜와 시각. 첫 줄에만 적고 나머지 줄은 null로 둔다.
- a: 그 품목의 금액(단가가 아니라 수량을 곱한 금액). 할인처럼 빼는 줄은 앞에 -를 붙인다.
- who: 품목 이름.
- io는 "out", bal은 null이다.
- total: 실제로 낸 금액(합계, 결제금액, 받을 금액)의 숫자.
- 합계 · 부가세 · 받은 돈 · 거스름돈 줄은 rows에 넣지 않는다.''';

/// 답의 본보기. 이미지를 넣을 수 없어 어떤 화면이었는지 글로 적는다.
const _examples = <(String, Map<String, Object?>)>[
  (
    '은행 앱의 거래내역. 위가 최근 거래다. 11.15 묶음에 두 줄, 11.14 묶음에 한 줄이 보인다.',
    {
      'kind': 'statement',
      'shop': null,
      'rows': [
        {
          'd': '11.15',
          't': '19:20',
          'a': '-15,000',
          'io': 'out',
          'who': '한빛서점',
          'bal': '985,000',
        },
        {
          'd': '11.15',
          't': '09:00',
          'a': '+500,000',
          'io': 'in',
          'who': '김한빛',
          'bal': '1,000,000',
        },
        {
          'd': '11.14',
          't': '12:31',
          'a': '-8,000',
          'io': 'out',
          'who': '새봄분식',
          'bal': '500,000',
        },
      ],
      'total': null,
    },
  ),
  (
    '카페 영수증. 품목 두 줄과 할인 한 줄, 합계 8,500원이 보인다.',
    {
      'kind': 'receipt',
      'shop': '새봄커피 한빛점',
      'rows': [
        {
          'd': '2026-03-08',
          't': '13:05',
          'a': '4,500',
          'io': 'out',
          'who': '아메리카노',
          'bal': null,
        },
        {
          'd': null,
          't': null,
          'a': '5,000',
          'io': 'out',
          'who': '카페라떼',
          'bal': null,
        },
        {
          'd': null,
          't': null,
          'a': '-1,000',
          'io': 'out',
          'who': '쿠폰 할인',
          'bal': null,
        },
      ],
      'total': '8,500',
    },
  ),
  (
    '풍경 사진. 거래도 영수증도 없다.',
    {'kind': 'other', 'shop': null, 'rows': <Object?>[], 'total': null},
  ),
];

/// 이미지를 읽어 달라는 요청을 만든다.
///
/// [feedback]은 앞선 답이 검증에서 떨어졌을 때 덧붙이는 설명이다.
VisionRequest buildVisionRequest({String? feedback}) {
  final system = StringBuffer(_rules)
    ..writeln()
    ..writeln();
  for (final (i, (scene, answer)) in _examples.indexed) {
    system
      ..writeln('예시 ${i + 1} ($scene)')
      ..writeln('답: ${jsonEncode(answer)}');
    if (i < _examples.length - 1) system.writeln();
  }

  final user = StringBuffer('이 이미지를 읽고 출력 형식대로 답한다.');
  if (feedback != null) {
    user
      ..writeln()
      ..write('[앞선 답의 문제] $feedback 고쳐서 다시 답한다.');
  }

  return VisionRequest(
    system: system.toString().trimRight(),
    user: user.toString(),
    schema: _schema,
    grammar: _grammar,
  );
}

/// 숫자 칸(금액 · 잔액 · 총액)에 올 수 있는 글자: 부호, 숫자, 쉼표.
const _numberPattern = r'^[+-]?[0-9][0-9,]{0,17}$';

const _nullableNumber = <String, Object?>{
  'type': ['string', 'null'],
  'pattern': _numberPattern,
};

Map<String, Object?> _nullableText(int maxLength) => {
  'type': ['string', 'null'],
  'maxLength': maxLength,
};

final Map<String, Object?> _schema = {
  'type': 'object',
  'properties': {
    'kind': {
      'enum': ['statement', 'receipt', 'other'],
    },
    'shop': _nullableText(40),
    'rows': {
      'type': 'array',
      'maxItems': visionMaxRows,
      'items': {
        'type': 'object',
        'properties': {
          'd': _nullableText(20),
          't': _nullableText(12),
          'a': _nullableNumber,
          'io': {
            'enum': ['in', 'out', null],
          },
          'who': _nullableText(40),
          'bal': _nullableNumber,
        },
        'required': ['d', 't', 'a', 'io', 'who', 'bal'],
        'additionalProperties': false,
      },
    },
    'total': _nullableNumber,
  },
  'required': ['kind', 'shop', 'rows', 'total'],
  'additionalProperties': false,
};

/// 출력 형식을 공백 없이 강제하는 GBNF 문법.
final String _grammar = () {
  String literal(String text) => jsonEncode(text);
  return [
    'root ::= ${literal('{"kind":')} kind ${literal(',"shop":')} name '
        '${literal(',"rows":[')} (row ("," row){0,${visionMaxRows - 1}})? '
        '${literal('],"total":')} number "}"',
    'kind ::= ${literal('"statement"')} | ${literal('"receipt"')} | '
        '${literal('"other"')}',
    'row ::= ${literal('{"d":')} date ${literal(',"t":')} time '
        '${literal(',"a":')} number ${literal(',"io":')} io '
        '${literal(',"who":')} name ${literal(',"bal":')} number "}"',
    'io ::= ${literal('"in"')} | ${literal('"out"')} | "null"',
    r'number ::= "\"" [+-]? [0-9] [0-9,]{0,17} "\"" | "null"',
    r'date ::= "\"" char{1,20} "\"" | "null"',
    r'time ::= "\"" char{1,12} "\"" | "null"',
    r'name ::= "\"" char{1,40} "\"" | "null"',
    // JSON 문자열 안에 올 수 있는 글자. 따옴표와 역슬래시는 앞에 역슬래시를 붙인다.
    r'char ::= [^"\\\x00-\x1F] | "\\" ["\\/]',
  ].join('\n');
}();
