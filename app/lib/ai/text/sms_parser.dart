/// 형식 규칙을 원문에 맞춰 거래 초안을 만든다.
library;

import '../../core/local_date.dart';
import '../parsed_transaction.dart';
import 'date_parser.dart';
import 'sms_rules.dart';
import 'text_normalizer.dart';

/// 줄바꿈을 접은 원문 [collapsed]를 규칙에 차례로 맞춰 본다. 맞는 규칙이 없으면 null.
///
/// [raw]는 초안에 남길 원문이다. 생략하면 [collapsed]를 쓴다.
///
/// [lines]는 접기 전의 줄들이다. 주면 상대방 · 통장 이름 · 메모가 한 줄 안에서 나왔는지
/// 확인한다. 자유 문자열 그룹이 이웃한 문자나 관계없는 줄까지 삼키는 것을 막는다.
ParsedTransaction? parseWithRules(
  String collapsed, {
  required LocalDate today,
  List<SmsRule>? rules,
  String? raw,
  List<String>? lines,
}) {
  final foldedLines = lines == null
      ? null
      : [for (final line in lines) foldWhitespace(line)];

  final keyValue = _parseKeyValueCard(
    collapsed,
    today: today,
    raw: raw,
    lines: foldedLines,
  );
  if (keyValue != null) return keyValue;

  for (final rule in rules ?? builtinSmsRules) {
    final match = rule.pattern.firstMatch(collapsed);
    if (match == null) continue;
    final parsed = _build(
      rule,
      match,
      today: today,
      raw: raw ?? collapsed,
      lines: foldedLines,
    );
    if (parsed != null) return parsed;
  }
  return null;
}

/// [value]가 [lines] 가운데 한 줄 안에 들어 있는지. 줄 정보가 없으면 통과시킨다.
bool _withinOneLine(String? value, List<String>? lines) {
  if (value == null || value.isEmpty || lines == null) return true;
  return lines.any((line) => line.contains(value));
}

ParsedTransaction? _build(
  SmsRule rule,
  RegExpMatch match, {
  required LocalDate today,
  required String raw,
  List<String>? lines,
}) {
  String? group(String name) {
    if (!match.groupNames.contains(name)) return null;
    final value = match.namedGroup(name)?.trim();
    return (value == null || value.isEmpty) ? null : value;
  }

  for (final name in const ['party', 'acctname', 'memo']) {
    if (!_withinOneLine(group(name), lines)) return null;
  }

  final warnings = <ParseWarning>{};

  // 날짜와 시각
  final dateResult = _resolveDate(
    year: group('year'),
    month: group('mon'),
    day: group('day'),
    today: today,
  );
  if (dateResult == null) return null;
  final (date, dateWarning) = dateResult;
  if (dateWarning != null) warnings.add(dateWarning);

  String? time;
  final hh = group('hh');
  final mm = group('mm');
  if (hh != null && mm != null) {
    time = formatTime(int.parse(hh), int.parse(mm));
    if (time == null) return null;
  }

  // 방향
  final dirWord = group('dirword') ?? group('dirword2');
  var isCancel = false;
  Direction? direction;
  if (dirWord != null) {
    if (dirWord.contains('취소')) {
      direction = Direction.outgoing;
      isCancel = true;
    } else if (dirWord.contains('입금')) {
      direction = Direction.incoming;
    } else {
      direction = Direction.outgoing;
    }
  }
  direction ??= rule.defaultDirection;
  if (direction == null) return null;

  // 금액
  int? amount;
  final amountText = group('amount') ?? group('amount2');
  if (amountText != null) {
    final value = _parseSignedInt(amountText);
    if (value == null || value == 0) return null;
    if (value < 0) isCancel = true;
    amount = value.abs();
  }

  String? currency;
  num? originalAmount;
  final foreignAmount = group('famount');
  if (foreignAmount != null) {
    originalAmount = num.tryParse(foreignAmount.replaceAll(',', ''));
    currency = _currencies[group('cur')] ?? group('cur');
    if (amount == null) warnings.add(ParseWarning.needsKrwAmount);
  }
  if (amount == null && originalAmount == null) return null;

  // 상대방과 자산 표기
  var party = _cleanParty(group('party'));
  var accountName = group('acctname');
  final memoParts = <String>[];
  final memoGroup = group('memo');
  if (party == null && memoGroup != null) {
    party = _cleanParty(memoGroup);
  } else if (memoGroup != null) {
    memoParts.add(memoGroup);
  }
  if (rule.partyIsOwnAccountWhenOutgoing && direction == Direction.outgoing) {
    // '보낸 쪽 → 받는 쪽' 형식: 출금이면 앞이 내 통장이고 뒤가 상대방이다.
    final swap = party;
    party = _cleanParty(accountName);
    accountName = swap;
  }

  final account = group('acct');
  final accountLabel = accountName ?? rule.institution;
  final accountText = account == null
      ? accountLabel
      : '$accountLabel($account)';

  // 할부 · 결제 방식
  int? installmentMonths;
  final inst = group('inst');
  if (inst != null) {
    final months = _months.firstMatch(inst);
    if (months != null) {
      final n = int.parse(months.group(1)!);
      if (n >= 2) installmentMonths = n;
    } else if (inst == '체크') {
      memoParts.add('체크');
    }
  }

  // '체크카드출금', '전자금융입금'처럼 방향 낱말 앞에 붙은 설명은 메모로 옮긴다.
  if (dirWord != null) {
    final prefix = dirWord.replaceAll(_directionSuffix, '');
    if (prefix.isNotEmpty && prefix != dirWord) memoParts.add(prefix);
  }

  final cashback = group('cashback');
  if (cashback != null) memoParts.add('캐시백 $cashback원');

  if (party == null) warnings.add(ParseWarning.noCounterparty);
  if (rule.kind == AccountHintKind.bank &&
      direction == Direction.outgoing &&
      party != null &&
      _cardCompany.hasMatch(party)) {
    warnings.add(ParseWarning.possibleCardPayment);
  }

  return ParsedTransaction(
    date: date,
    time: time,
    amount: amount,
    direction: direction,
    institution: rule.institution,
    accountKind: rule.kind,
    accountText: accountText,
    accountHint: account,
    counterparty: party,
    installmentMonths: installmentMonths,
    balanceAfter: _parseSignedInt(group('balance')),
    cumulative: _parseSignedInt(group('cum')),
    isCancel: isCancel,
    currency: currency,
    originalAmount: originalAmount,
    memo: memoParts.isEmpty ? null : memoParts.join(' · '),
    ruleId: rule.id,
    raw: raw,
    warnings: warnings,
  );
}

/// 항목형 카드 문자(하나카드 등)를 읽는다.
///
/// `금액 12,300원 카드 하나1*2* 손님명 홍*동 거래종류 신용 거래구분 일시불
/// 사용처 쿠팡(쿠페이) 거래시간 10/15 09:05 누적금액 300,000원`
ParsedTransaction? _parseKeyValueCard(
  String collapsed, {
  required LocalDate today,
  String? raw,
  List<String>? lines,
}) {
  final keys = _kvKey.allMatches(collapsed).toList();
  if (keys.length < 4) return null;
  if (keys.first.start != 0) return null;

  final fields = <String, String>{};
  for (var i = 0; i < keys.length; i++) {
    final end = i + 1 < keys.length ? keys[i + 1].start : collapsed.length;
    final key = keys[i].group(1)!;
    fields.putIfAbsent(key, () => collapsed.substring(keys[i].end, end).trim());
  }

  if (!_withinOneLine(fields['사용처'], lines)) return null;
  final amountMatch = _kvAmount.firstMatch(fields['금액'] ?? '');
  final party = _cleanParty(fields['사용처']);
  final when = _kvWhen.firstMatch(fields['거래시간'] ?? '');
  final card = fields['카드'];
  if (amountMatch == null || party == null || when == null || card == null) {
    return null;
  }

  final value = _parseSignedInt(amountMatch.group(1));
  if (value == null || value == 0) return null;
  final date = resolveMonthDay(
    int.parse(when.group(1)!),
    int.parse(when.group(2)!),
    today,
  );
  final time = formatTime(int.parse(when.group(3)!), int.parse(when.group(4)!));
  if (date == null || time == null) return null;

  final cardMatch = _kvCard.firstMatch(card);
  final institution =
      _kvInstitutions[cardMatch?.group(1)] ?? cardMatch?.group(1);
  final kindText = '${fields['거래종류'] ?? ''} ${fields['거래구분'] ?? ''}';
  final isCancel = value < 0 || kindText.contains('취소');
  final months = _months.firstMatch(fields['거래구분'] ?? '');
  final installment = months == null ? null : int.parse(months.group(1)!);

  return ParsedTransaction(
    date: date,
    time: time,
    amount: value.abs(),
    direction: Direction.outgoing,
    institution: institution,
    accountKind: AccountHintKind.card,
    accountText: card,
    accountHint: cardMatch?.group(2),
    counterparty: party,
    installmentMonths: (installment != null && installment >= 2)
        ? installment
        : null,
    cumulative: _parseSignedInt(
      _kvAmount.firstMatch(fields['누적금액'] ?? fields['누적이용금액'] ?? '')?.group(1),
    ),
    isCancel: isCancel,
    memo: (fields['거래종류'] == '체크') ? '체크' : null,
    ruleId: 'card_key_value',
    raw: raw ?? collapsed,
    warnings: const {ParseWarning.yearInferred},
  );
}

(LocalDate, ParseWarning?)? _resolveDate({
  required String? year,
  required String? month,
  required String? day,
  required LocalDate today,
}) {
  if (month == null || day == null) {
    return (today, ParseWarning.dateFromNow);
  }
  final m = int.parse(month);
  final d = int.parse(day);
  if (year != null) {
    final date = LocalDate.tryCreate(int.parse(year), m, d);
    return date == null ? null : (date, null);
  }
  final date = resolveMonthDay(m, d, today);
  return date == null ? null : (date, ParseWarning.yearInferred);
}

int? _parseSignedInt(String? text) {
  if (text == null) return null;
  final cleaned = text.replaceAll(',', '').trim();
  if (!_signedDigits.hasMatch(cleaned)) return null;
  return int.tryParse(cleaned);
}

/// 상대방 문자열을 다듬는다. 비면 null.
String? _cleanParty(String? text) {
  if (text == null) return null;
  final cleaned = text.replaceAll(_partyEdges, '').trim();
  return cleaned.isEmpty ? null : cleaned;
}

final _signedDigits = RegExp(r'^-?\d+$');
final _months = RegExp(r'^(\d{1,2})개월$');
final _directionSuffix = RegExp(r'(?:입금|출금)$');
final _partyEdges = RegExp(r'^[\s:·|/\-]+|[\s:·|/\-]+$');

/// 은행 출금의 상대방이 카드사면 카드대금일 가능성이 높다.
final _cardCompany = RegExp(
  r'카드대금|(?:국민|신한|삼성|현대|롯데|우리|하나|비씨|BC|NH|농협|씨티|KB)\s?카드',
);

const _currencies = <String, String>{
  '달러': 'USD',
  '엔': 'JPY',
  '유로': 'EUR',
  '위안': 'CNY',
  '파운드': 'GBP',
};

final _kvKey = RegExp(r'(?:^| )(금액|카드|손님명|거래종류|거래구분|사용처|거래시간|누적금액|누적이용금액) ');
final _kvAmount = RegExp(r'^(-?[\d,]+)원?');
final _kvWhen = RegExp(r'^(\d{1,2})[/.](\d{1,2})\s+(\d{1,2}):(\d{2})');
final _kvCard = RegExp(r'^([가-힣A-Za-z]+?)(\d{4}|\d\*\d\*)$');

const _kvInstitutions = <String, String>{
  '하나': '하나카드',
  '국민': 'KB국민카드',
  'KB국민': 'KB국민카드',
  '신한': '신한카드',
  '삼성': '삼성카드',
  '현대': '현대카드',
  '롯데': '롯데카드',
  '우리': '우리카드',
  'BC': 'BC카드',
  'NH': 'NH농협카드',
};
