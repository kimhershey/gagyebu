/// 월별 총평을 모델에게 쓰게 하고, 집계에 없는 숫자가 섞이면 버린다
/// (`docs/SPEC.md` 1.2의 원칙 3, 7.10).
library;

import 'dart:convert';

import '../text/amount_parser.dart';
import 'llm_engine.dart';
import 'narrative_template.dart';

/// 총평 한 편.
class NarrativeResult {
  const NarrativeResult({
    required this.text,
    required this.aiModel,
    required this.attempts,
  });

  final String text;

  /// 글을 쓴 모델의 이름. 문장 틀로 만들었으면 null.
  final String? aiModel;

  /// 모델을 부른 횟수(0–2).
  final int attempts;
}

/// 문장에서 찾은 숫자 하나.
class NarrativeNumber {
  const NarrativeNumber(
    this.value,
    this.text, {
    required this.end,
    required this.percent,
  });

  /// 읽은 값. 읽지 못한 표기는 -1이다(검증에서 걸린다).
  final num value;

  /// 문장에 적힌 그대로('186만 250', '32').
  final String text;

  /// 문장에서 이 숫자가 끝나는 자리.
  final int end;

  /// 뒤에 % · 퍼센트가 붙었는지.
  final bool percent;

  @override
  String toString() => percent ? '$text%' : text;
}

/// 자릿수 쉼표가 있거나 없는 숫자. 소수도 받는다.
const _digits = r'(?:\d{1,3}(?:,\d{3})+|\d+)(?:\.\d+)?';

/// 숫자와, 이어지는 만 · 천 단위('186만 250', '1억 2,345만', '3천').
final _numberPattern = RegExp(
  '(?<![\\d.,])$_digits'
  '(?: ?[억만천백십]+(?: ?$_digits(?: ?[억만천백십]+|(?= ?원)))*)?',
);
final _percentAfter = RegExp(r'^ ?(?:%|퍼센트|프로(?![가-힣]))');
final _rankAfter = RegExp(r'^ ?(?:위|번째|등|가지|개(?!월)|곳)');
final _hasUnit = RegExp('[억만천백십]');
final _anyDigit = RegExp(r'\d');

/// [text]에 적힌 숫자를 모두 찾는다. 쉼표와 만 · 천 단위를 풀어 값으로 바꾼다.
List<NarrativeNumber> findNarrativeNumbers(String text) {
  final result = <NarrativeNumber>[];
  for (final m in _numberPattern.allMatches(text)) {
    final raw = m.group(0)!;
    final num? value = _hasUnit.hasMatch(raw)
        ? parseKoreanAmount(raw)
        : num.tryParse(raw.replaceAll(',', ''));
    result.add(
      NarrativeNumber(
        value ?? -1,
        raw,
        end: m.end,
        percent: _percentAfter.hasMatch(text.substring(m.end)),
      ),
    );
  }
  return result;
}

/// 집계에서 문장에 나와도 되는 숫자들.
class _Allowed {
  /// 그대로 맞아야 하는 값: 건수, 날 수, 날짜, 금액.
  final exact = <num>{};

  /// 반올림해 말해도 되는 값: 금액.
  final money = <int>{};

  /// 비율(%)과 배수.
  final ratios = <double>[];

  void addMoney(int value) {
    final v = value.abs();
    exact.add(v);
    if (v >= 100) money.add(v);
  }

  void addPercent(num part, num whole) {
    if (whole > 0) ratios.add(part / whole * 100);
  }
}

_Allowed _allowedNumbers(Map<String, Object?> stats) {
  final allowed = _Allowed();
  final income = statInt(stats['income']);
  final expense = statInt(stats['expense']);
  final previousIncome = statInt(stats['previous_income']);
  final previousExpense = statInt(stats['previous_expense']);
  final fixed = statInt(stats['fixed_expense']);

  for (final value in [
    income,
    expense,
    statInt(stats['net']),
    previousIncome,
    previousExpense,
    fixed,
    statInt(stats['daily_average']),
    // 집계에서 한 번의 뺄셈으로 나오는 값: 전달과의 차이, 고정 지출을 뺀 나머지.
    expense - previousExpense,
    income - previousIncome,
    expense - fixed,
  ]) {
    allowed.addMoney(value);
  }
  allowed.exact
    ..add(statInt(stats['transaction_count']))
    ..add(statInt(stats['no_spend_days']));

  // 전달 대비 비율과 배수, 수입 대비 지출, 고정 지출의 비중.
  allowed
    ..addPercent((expense - previousExpense).abs(), previousExpense)
    ..addPercent(expense, previousExpense)
    ..addPercent(expense, income)
    ..addPercent((income - expense).abs(), income)
    ..addPercent(fixed, expense);
  if (previousExpense > 0) allowed.ratios.add(expense / previousExpense);

  final categories = statList(stats['by_category']);
  for (final c in categories) {
    allowed.addMoney(statInt(c['amount']));
    final ratio = c['ratio'];
    if (ratio is num) allowed.ratios.add(ratio * 100);
  }
  final largest = statList(stats['largest']);
  for (final e in largest) {
    allowed.addMoney(statInt(e['amount']));
    _addDate(allowed, e['date']);
  }
  final parties = statList(stats['counterparties']);
  for (final p in parties) {
    allowed.addMoney(statInt(p['amount']));
    allowed.exact.add(statInt(p['count']));
  }

  final budget = stats['budget'];
  if (budget is Map) {
    final amount = statInt(budget['amount']);
    final spent = statInt(budget['spent']);
    allowed
      ..addMoney(amount)
      ..addMoney(spent)
      ..addMoney(amount - spent)
      ..addPercent(spent, amount)
      ..addPercent((amount - spent).abs(), amount);
  }

  // 달의 이름과 기간의 날짜, 날 수.
  final monthKey = stats['month'];
  if (monthKey is String) {
    final parts = monthKey.split('-').map(int.tryParse).toList();
    if (parts.length == 2 && parts[0] != null && parts[1] != null) {
      final year = parts[0]!;
      final month = parts[1]!;
      allowed.exact
        ..add(year)
        ..add(month)
        // 전달의 이름
        ..add(month == 1 ? 12 : month - 1);
    }
  }
  final from = _addDate(allowed, stats['from']);
  final to = _addDate(allowed, stats['to']);
  if (from != null && to != null) {
    allowed.exact.add(to.difference(from).inDays + 1);
  }
  return allowed;
}

DateTime? _addDate(_Allowed allowed, Object? value) {
  final date = value is String ? DateTime.tryParse('${value}T00:00:00Z') : null;
  if (date != null) allowed.exact.addAll([date.year, date.month, date.day]);
  return date;
}

/// 금액 [said]가 집계의 금액 [actual]을 줄여 말한 것인지. 위에서 둘째 자리까지는
/// 맞아야 한다('186만 250원'을 '약 186만 원'이나 '190만 원쯤'으로).
bool _roundsTo(num said, int actual) {
  for (var unit = 100; unit * 10 <= actual; unit *= 10) {
    final rounded = (actual / unit).round() * unit;
    final floored = (actual ~/ unit) * unit;
    if (said == rounded || said == floored) return true;
  }
  return false;
}

bool _isRatio(num said, List<double> ratios) {
  for (final ratio in ratios) {
    // 정수로 말했으면 반올림이나 버림, 소수로 말했으면 그 자리까지 맞으면 된다.
    if (said == ratio.round() || said == ratio.floor()) return true;
    if ((said - ratio).abs() < 0.05 + 1e-9) return true;
  }
  return false;
}

/// [text]에 적힌 숫자 가운데 집계 [stats]에서 나오지 않는 것.
///
/// 집계의 값, 한 번의 뺄셈으로 나오는 차이, 비율, 달과 날짜는 받는다. 금액은 줄여
/// 말한 것도 받는다. 비어 있으면 통과다.
List<NarrativeNumber> unsupportedNumbers(
  String text,
  Map<String, Object?> stats,
) {
  final allowed = _allowedNumbers(stats);
  // 이름에 든 숫자('GS25', '11번가')는 금액이 아니다. 집계에 있는 이름은 가리고 본다.
  var body = text;
  for (final key in const ['by_category', 'largest', 'counterparties']) {
    for (final item in statList(stats[key])) {
      final name = item['name'];
      if (name is String && _anyDigit.hasMatch(name)) {
        body = body.replaceAll(name, ' ' * name.length);
      }
    }
  }
  final bad = <NarrativeNumber>[];
  for (final number in findNarrativeNumbers(body)) {
    final value = number.value;
    final after = body.substring(number.end);
    final bool ok;
    if (number.percent) {
      ok = _isRatio(value, allowed.ratios);
    } else if (allowed.exact.contains(value)) {
      ok = true;
    } else if (value >= 1 && value <= 5 && _rankAfter.hasMatch(after)) {
      // '1위', '상위 3개'처럼 차례를 세는 작은 수.
      ok = true;
    } else if (after.startsWith('배') || after.startsWith(' 배')) {
      ok = _isRatio(value, allowed.ratios);
    } else {
      ok = allowed.money.any((actual) => _roundsTo(value, actual));
    }
    if (!ok) bad.add(number);
  }
  return bad;
}

/// 모델에 보내는 총평 요청.
class NarrativeRequest {
  const NarrativeRequest({
    required this.system,
    required this.user,
    required this.schema,
    required this.grammar,
  });

  final String system;
  final String user;
  final Map<String, Object?> schema;
  final String grammar;
}

const _system = '''
너는 가계부 앱의 월별 총평을 쓴다. [집계]를 읽고 한 달을 돌아보는 글을 JSON으로만 답한다.

출력 형식: {"s":[문장, 문장, 문장]}
- 3–5문장으로 쓴다. 문장마다 "…습니다."로 끝낸다.
- 숫자는 [집계]에 적힌 것만 쓴다. 더하거나 빼거나 새로 만들지 않는다. 금액은 [집계]에 적힌 표기를 그대로 옮긴다.
- [집계]에 없는 가게, 분류, 사실을 지어내지 않는다.
- 전달과 견준 것, 가장 많이 쓴 분류, 예산이나 고정 지출, 눈에 띄는 지출 가운데 중요한 것을 고른다.
- 훈계하지 않는다. 사실을 담담하게 적는다.
- 가계부 주인에게 말하듯 쓴다: "○월에는 ○○을 썼습니다.", "전달보다 ○○ 덜 썼습니다.", "가장 많이 쓴 분류는 ○○입니다."처럼. ○ 자리에는 [집계]의 값을 넣는다. '집계', '기록', '데이터'라는 말은 쓰지 않는다.
- 숫자와 단위는 붙여 쓴다(10월, 186만 250원, 32%, 7번).''';

/// 총평 요청을 만든다. [feedback]은 앞선 글이 검증에서 떨어진 까닭이다.
///
/// 집계는 JSON 그대로가 아니라 풀어 쓴 표로 준다. 금액 표기와 차이 · 비율을 미리
/// 계산해 두어 모델이 옮겨 적기만 하게 한다(소형 모델은 계산을 틀린다).
NarrativeRequest buildNarrativeRequest(
  Map<String, Object?> stats, {
  String? feedback,
}) {
  final user = StringBuffer(_factSheet(stats));
  if (feedback != null) {
    user
      ..writeln()
      ..write('[앞선 글의 문제] $feedback 고쳐서 다시 쓴다.');
  }
  return NarrativeRequest(
    system: _system,
    user: user.toString(),
    schema: const {
      'type': 'object',
      'properties': {
        's': {
          'type': 'array',
          'items': {'type': 'string', 'minLength': 5, 'maxLength': 160},
          'minItems': 3,
          'maxItems': 5,
        },
      },
      'required': ['s'],
      'additionalProperties': false,
    },
    grammar: [
      r'root ::= "{\"s\":[" sentence ("," sentence){2,4} "]}"',
      r'sentence ::= "\"" [^"\\\n]{5,160} "\""',
    ].join('\n'),
  );
}

String _factSheet(Map<String, Object?> stats) {
  final month = statMonth(stats);
  final income = statInt(stats['income']);
  final expense = statInt(stats['expense']);
  final previous = statInt(stats['previous_expense']);
  final lines = <String>[
    '[집계] ${month == null ? '' : '$month월 '}(${stats['from']} – ${stats['to']})',
    '지출: ${koreanWon(expense)}',
    '수입: ${koreanWon(income)}',
  ];
  if (previous > 0) {
    final change = expense - previous;
    final compared = switch (change) {
      < 0 => '전달보다 ${koreanWon(-change)} 덜 씀',
      > 0 => '전달보다 ${koreanWon(change)} 더 씀',
      _ => '전달과 같음',
    };
    lines.add('전달 지출: ${koreanWon(previous)} ($compared)');
  }
  final categories = statList(stats['by_category']);
  if (categories.isNotEmpty) {
    lines.add(
      '분류별 지출: ${[for (final c in categories.take(5)) '${c['name']} ${koreanWon(statInt(c['amount']))}(${_percent(c['ratio'])})'].join(', ')}',
    );
  }
  final budget = stats['budget'];
  if (budget is Map) {
    final amount = statInt(budget['amount']);
    final spent = statInt(budget['spent']);
    lines.add(
      spent > amount
          ? '예산: ${koreanWon(amount)} (${koreanWon(spent - amount)} 넘김)'
          : '예산: ${koreanWon(amount)} (${koreanWon(amount - spent)} 남음)',
    );
  }
  final fixed = statInt(stats['fixed_expense']);
  if (fixed > 0) lines.add('고정 지출(반복 거래): ${koreanWon(fixed)}');
  final largest = statList(stats['largest']);
  if (largest.isNotEmpty) {
    lines.add(
      '큰 지출: ${[for (final e in largest.take(3)) '${e['name']} ${koreanWon(statInt(e['amount']))}'].join(', ')}',
    );
  }
  final parties = statList(stats['counterparties']);
  if (parties.isNotEmpty) {
    lines.add(
      '많이 쓴 곳: ${[for (final p in parties.take(3)) '${p['name']} ${koreanWon(statInt(p['amount']))}(${statInt(p['count'])}번)'].join(', ')}',
    );
  }
  lines
    ..add('하루 평균 지출: ${koreanWon(statInt(stats['daily_average']))}')
    // '13일'을 13일이라는 날짜로 읽지 않게 날수라고 밝힌다.
    ..add('지출이 없던 날의 수: 모두 ${statInt(stats['no_spend_days'])}일(날짜가 아니라 날수)');
  return lines.join('\n');
}

String _percent(Object? ratio) =>
    ratio is num ? '${(ratio * 100).round()}%' : '';

final _polite = RegExp(r'니다[.!]?$');

final _dayAsDate = RegExp(r'(\d+)일에');

/// [sentences]가 집계 [stats]의 사실을 잘못 옮긴 곳. 없으면 null.
///
/// 숫자가 맞아도 뜻이 틀릴 수 있다. 실제 모델(Qwen3.5-2B)에서 본 두 가지를 잡는다.
/// - 가게를 분류라고 한다('가장 많이 쓴 분류는 스타벅스입니다').
/// - 지출이 없던 날의 수를 날짜로 쓴다('13일에는 지출이 없었습니다').
String? misstatedFact(List<String> sentences, Map<String, Object?> stats) {
  final categories = [
    for (final c in statList(stats['by_category'])) '${c['name']}',
  ];
  final shops = {
    for (final p in statList(stats['counterparties'])) '${p['name']}',
    for (final e in statList(stats['largest'])) '${e['name']}',
  }..removeAll(categories);
  final noSpendDays = statInt(stats['no_spend_days']);

  for (final sentence in sentences) {
    if (sentence.contains('분류')) {
      for (final shop in shops) {
        if (sentence.contains(shop)) return '"$shop"은 분류가 아니라 가게다.';
      }
      if (sentence.contains('가장 많이') &&
          categories.isNotEmpty &&
          !sentence.contains(categories.first)) {
        return '가장 많이 쓴 분류는 ${categories.first}이다.';
      }
    }
    if (sentence.contains('없')) {
      for (final match in _dayAsDate.allMatches(sentence)) {
        if (int.parse(match[1]!) == noSpendDays) {
          return '지출이 없던 날은 날짜가 아니다. 모두 $noSpendDays일이라고 쓴다.';
        }
      }
    }
  }
  return null;
}

/// 문장 앞에 붙은 쉼표 · 마침표 · 공백. 소형 모델은 배열의 쉼표를 문장 안에 한 번 더 쓴다.
final _leadingPunctuation = RegExp(r'^[\s,.·]+');

/// 숫자와 단위 사이의 공백('10 월', '186 만 250 원', '7 번').
final _digitUnitGap = RegExp(r'(\d)\s+(억|만|천|원|월|일|년|주|번|건|개|회|%)');

/// '%' 뒤의 공백('32% 를').
final _percentGap = RegExp(r'%\s+(?=[가-힣])');

/// 모델이 쓴 문장을 다듬는다. 뜻과 숫자는 건드리지 않고 띄어쓰기와 앞의 군더더기만 고친다.
String _tidy(String sentence) => sentence
    .replaceFirst(_leadingPunctuation, '')
    .replaceAllMapped(_digitUnitGap, (m) => '${m[1]}${m[2]}')
    .replaceAll(_percentGap, '%')
    .trim();

/// 총평을 쓴다(`docs/SPEC.md` 7.10).
///
/// 모델이 있으면 집계를 3–5문장으로 옮기게 한다. 집계에 없는 숫자가 나오거나 문장
/// 수와 말투가 어긋나면 그 글을 버리고 까닭을 붙여 한 번 다시 쓰게 한다. 또 어긋나거나
/// 모델이 없으면 문장 틀([templateNarrative])을 쓴다. 숫자는 어느 쪽이든 집계의 것이다.
class NarrativeWriter {
  NarrativeWriter(this.engine);

  /// 기기 안의 모델. 없으면 null이고 문장 틀만 쓴다.
  final LlmEngine? engine;

  Future<NarrativeResult> write(Map<String, Object?> stats) async {
    final engine = this.engine;
    var attempts = 0;
    // 쓴 돈이 없는 달은 할 말이 정해져 있다. 모델에 맡기면 같은 말을 되풀이한다.
    final hasSpending = statInt(stats['expense']) > 0;
    if (engine != null && hasSpending) {
      String? feedback;
      for (var attempt = 1; attempt <= 2; attempt++) {
        final request = buildNarrativeRequest(stats, feedback: feedback);
        final String raw;
        try {
          attempts = attempt;
          raw = await engine.generateJson(
            system: request.system,
            user: request.user,
            schema: request.schema,
            grammar: request.grammar,
            maxTokens: 480,
          );
        } on Object {
          // 모델이 답하지 못하면(내려갔거나 시간이 넘었으면) 다시 묻지 않는다.
          break;
        }
        final checked = _check(raw, stats);
        if (checked.text != null) {
          return NarrativeResult(
            text: checked.text!,
            aiModel: engine.modelName,
            attempts: attempt,
          );
        }
        feedback = checked.problem;
      }
    }
    return NarrativeResult(
      text: templateNarrative(stats),
      aiModel: null,
      attempts: attempts,
    );
  }

  ({String? text, String? problem}) _check(
    String raw,
    Map<String, Object?> stats,
  ) {
    ({String? text, String? problem}) fail(String problem) =>
        (text: null, problem: problem);

    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      // 토큰 한도에서 잘린 글도 여기로 온다.
      return fail('JSON이 아니다.');
    }
    final list = decoded is Map ? decoded['s'] : null;
    if (list is! List) return fail('"s" 배열이 없다.');
    final sentences = [
      for (final item in list)
        if (item is String && _tidy(item).isNotEmpty) _tidy(item),
    ];
    if (sentences.length != list.length) return fail('빈 문장이 있다.');
    if (sentences.length < 3 || sentences.length > 5) {
      return fail('문장이 ${sentences.length}개다. 3–5문장이어야 한다.');
    }
    for (final sentence in sentences) {
      // 지시문의 빈칸 표시를 그대로 옮긴 글.
      if (sentence.contains('○') || sentence.contains('…')) {
        return fail('"$sentence"에 빈칸 표시가 남아 있다.');
      }
      if (!_polite.hasMatch(sentence)) {
        return fail('"$sentence"가 "…습니다."로 끝나지 않는다.');
      }
    }
    final text = [
      for (final s in sentences) s.endsWith('.') || s.endsWith('!') ? s : '$s.',
    ].join(' ');
    final bad = unsupportedNumbers(text, stats);
    if (bad.isNotEmpty) {
      return fail('[집계]에 없는 숫자(${bad.join(', ')})가 있다.');
    }
    final misstated = misstatedFact(sentences, stats);
    if (misstated != null) return fail(misstated);
    return (text: text, problem: null);
  }
}
