import 'dart:convert';

import '../../core/local_date.dart';
import '../../domain/enums.dart';
import '../llm/llm_engine.dart';
import 'ledger_query.dart';

/// 모델에 보내는 조회 조건 요청.
class QueryConditionRequest {
  const QueryConditionRequest({
    required this.system,
    required this.user,
    required this.schema,
    required this.grammar,
  });

  final String system;
  final String user;

  /// 조건 JSON의 스키마. `period`는 정해진 기호, `category`는 분류 이름 가운데 하나다.
  final Map<String, Object?> schema;

  /// 같은 형식을 공백 없이 강제하는 GBNF 문법(llama.cpp).
  final String grammar;
}

const _rules = '''
너는 가계부 앱의 조회 해석기다. [물음]을 읽고 조건을 JSON으로만 답한다. 계산하지 않는다.

출력 형식: {"period":기간,"category":분류,"party":상대,"type":종류,"agg":집계}
- period: [기간]의 기호 가운데 하나다. 물음에 기간이 없으면 "this_month"다.
- category: 물음에 그 분류를 가리키는 말이 있을 때만 [분류]의 이름 가운데 하나를 고른다. '쓴 돈 전부', '지출 내역', '수입 합계'처럼 분류를 말하지 않았거나 가게 · 사람 이름만 있으면 null이다. 억지로 고르지 않는다.
- party: 물음에 나온 가게나 사람의 이름을 그대로 적는다. 없으면 null이다.
- type: 쓴 돈이면 "expense", 번 돈 · 받은 돈이면 "income", 내 계좌 사이에 옮긴 돈이면 "transfer"다. 가리지 않으면 null이다.
- agg: 금액을 물으면 "sum", 횟수를 물으면 "count", 평균을 물으면 "avg", 내역을 보여 달라면 "list"다.

[기간] today(오늘) yesterday(어제) this_week(이번 주) last_week(지난주) this_month(이번 달) last_month(지난달) this_year(올해) last_year(작년) last_7_days(최근 7일) last_30_days(최근 30일) last_90_days(최근 90일) month_1 … month_12(그 달)

[예시]
물음: 저번 달에 밥값으로 나간 게 어느 정도야
{"period":"last_month","category":"식비","party":null,"type":"expense","agg":"sum"}
물음: 요새 한 주 동안 스타벅스 간 횟수
{"period":"last_7_days","category":null,"party":"스타벅스","type":"expense","agg":"count"}
물음: 이달에 나간 돈 다 더하면
{"period":"this_month","category":null,"party":null,"type":"expense","agg":"sum"}
물음: 저번 주 이마트에서 얼마 긁었지
{"period":"last_week","category":null,"party":"이마트","type":"expense","agg":"sum"}
물음: 어제 들어온 돈 목록
{"period":"yesterday","category":null,"party":null,"type":"income","agg":"list"}
물음: 올해 핸드폰 요금으로 낸 돈
{"period":"this_year","category":"주거·통신","party":null,"type":"expense","agg":"sum"}
물음: 지난달 간식 사 먹은 횟수
{"period":"last_month","category":"카페·간식","party":null,"type":"expense","agg":"count"}
물음: 이번 달 보너스 얼마 받았어
{"period":"this_month","category":"급여","party":null,"type":"income","agg":"sum"}''';

/// 조건 요청을 만든다. [feedback]은 앞선 답이 검증에서 떨어진 까닭이다.
QueryConditionRequest buildQueryConditionRequest({
  required String text,
  required List<QueryCategory> categories,
  String? feedback,
}) {
  final names = <String>{for (final c in categories) c.name}.toList();
  final expense = [
    for (final c in categories)
      if (c.kind == CategoryKind.expense) c.name,
  ];
  final income = [
    for (final c in categories)
      if (c.kind == CategoryKind.income) c.name,
  ];
  final system = StringBuffer(_rules)
    ..writeln()
    ..writeln()
    ..write('[분류] 지출: ${expense.join(', ')} / 수입: ${income.join(', ')}');
  final user = StringBuffer('물음: ${text.trim()}');
  if (feedback != null) {
    user
      ..writeln()
      ..write('[앞선 답의 문제] $feedback 고쳐서 다시 답한다.');
  }
  return QueryConditionRequest(
    system: system.toString(),
    user: user.toString(),
    schema: _schema(names),
    grammar: _grammar(names),
  );
}

const _typeCodes = ['expense', 'income', 'transfer'];

Map<String, Object?> _schema(List<String> categories) => {
  'type': 'object',
  'properties': {
    'period': {'type': 'string', 'enum': QueryPeriod.modelSymbols},
    'category': {
      'enum': [...categories, null],
    },
    'party': {
      'type': ['string', 'null'],
      'maxLength': 30,
    },
    'type': {
      'enum': [..._typeCodes, null],
    },
    'agg': {
      'type': 'string',
      'enum': [for (final a in QueryAggregation.values) a.code],
    },
  },
  'required': ['period', 'category', 'party', 'type', 'agg'],
  'additionalProperties': false,
};

String _grammar(List<String> categories) {
  String literal(String text) => jsonEncode(text);
  // JSON 문자열 값을 문법의 글자 그대로로 적는다: "식비" → "\"식비\""
  String quoted(String value) => literal(jsonEncode(value));

  final period = QueryPeriod.modelSymbols.map(quoted).join(' | ');
  final category = [...categories.map(quoted), '"null"'].join(' | ');
  final type = [..._typeCodes.map(quoted), '"null"'].join(' | ');
  final agg = QueryAggregation.values.map((a) => quoted(a.code)).join(' | ');
  return [
    'root ::= ${literal('{"period":')} ($period) ${literal(',"category":')} '
        '($category) ${literal(',"party":')} party ${literal(',"type":')} '
        '($type) ${literal(',"agg":')} ($agg) "}"',
    // 상대는 따옴표 · 역슬래시 · 줄바꿈이 없는 짧은 글이다.
    r'party ::= "null" | "\"" [^"\\\n]{1,30} "\""',
  ].join('\n');
}

/// 규칙이 읽지 못한 물음의 조건을 기기 안의 모델로 읽는다.
///
/// 모델은 조건만 고른다. 날짜 범위는 코드가 계산하고 숫자는 SQL이 센다. 답은 여기서
/// 다시 검증한다(문법을 쓰지 못하는 엔진도 있다): 기간은 정해진 기호, 분류는 가계부의
/// 이름, 상대는 물음에 있는 글자여야 한다. 어긋나면 한 번 다시 묻고, 또 어긋나면
/// 포기한다(null).
class LlmQueryParser {
  LlmQueryParser(this.engine);

  final LlmEngine engine;

  Future<LedgerQuery?> parse(
    String text, {
    required LocalDate today,
    required List<QueryCategory> categories,
    int startDay = 1,
  }) async {
    String? feedback;
    for (var attempt = 1; attempt <= 2; attempt++) {
      final request = buildQueryConditionRequest(
        text: text,
        categories: categories,
        feedback: feedback,
      );
      final raw = await engine.generateJson(
        system: request.system,
        user: request.user,
        schema: request.schema,
        grammar: request.grammar,
        maxTokens: 120,
      );
      final outcome = _validate(
        raw,
        text: text,
        today: today,
        categories: categories,
        startDay: startDay,
      );
      if (outcome.query != null) return outcome.query;
      feedback = outcome.problem;
    }
    return null;
  }

  ({LedgerQuery? query, String? problem}) _validate(
    String raw, {
    required String text,
    required LocalDate today,
    required List<QueryCategory> categories,
    required int startDay,
  }) {
    ({LedgerQuery? query, String? problem}) fail(String problem) =>
        (query: null, problem: problem);

    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      return fail('JSON이 아니다.');
    }
    if (decoded is! Map) return fail('JSON 객체가 아니다.');

    final symbol = decoded['period'];
    final period = symbol is String && QueryPeriod.modelSymbols.contains(symbol)
        ? QueryPeriod.fromSymbol(symbol)
        : null;
    if (period == null) return fail('period "$symbol"는 [기간]에 없다.');

    final aggregation = QueryAggregation.fromCode(decoded['agg']);
    if (aggregation == null) {
      return fail('agg "${decoded['agg']}"는 sum · count · avg · list가 아니다.');
    }

    QueryCategory? category;
    final categoryName = decoded['category'];
    if (categoryName != null) {
      for (final c in categories) {
        if (c.name == categoryName) {
          category = c;
          break;
        }
      }
      if (category == null) return fail('category "$categoryName"는 [분류]에 없다.');
    }

    final typeCode = decoded['type'];
    TxType? type;
    if (typeCode != null) {
      if (!_typeCodes.contains(typeCode)) {
        return fail('type "$typeCode"는 expense · income · transfer가 아니다.');
      }
      type = TxType.fromCode(typeCode as String);
    }
    // 분류가 있으면 종류는 분류를 따른다. 둘이 어긋나면 결과가 늘 비기 때문이다.
    if (category != null) {
      type = category.kind == CategoryKind.income
          ? TxType.income
          : TxType.expense;
    }

    // 상대는 물음에 있는 글자여야 한다. 모델이 지어낸 이름으로는 찾지 않는다.
    String? party;
    final partyText = decoded['party'];
    if (partyText is String && partyText.trim().isNotEmpty) {
      final wanted = _squeeze(partyText);
      if (!_squeeze(text).contains(wanted)) {
        return fail('party "$partyText"는 물음에 없는 말이다.');
      }
      party = partyText.trim();
    }

    return (
      query: LedgerQuery(
        period: period,
        range: period.resolve(today: today, startDay: startDay),
        category: category?.name,
        party: party,
        type: type,
        aggregation: aggregation,
        aiModel: engine.modelName,
      ),
      problem: null,
    );
  }
}

String _squeeze(String text) =>
    text.replaceAll(RegExp(r'\s+'), '').toLowerCase();
