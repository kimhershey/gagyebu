/// 금액 표기를 원 단위 정수로 바꾸는 규칙.
///
/// 금액 계산은 LLM에 맡기지 않는다. 문장에서 금액 후보를 규칙으로 뽑아 두고,
/// 모델은 후보 중에서 고르기만 한다.
library;

/// '12,500' → 12500. 숫자와 쉼표만 받는다.
int? parseDigits(String text) {
  final cleaned = text.replaceAll(',', '').trim();
  if (cleaned.isEmpty || !_digitsOnly.hasMatch(cleaned)) return null;
  return int.tryParse(cleaned);
}

/// 한글 단위가 섞인 금액을 원 단위 정수로 바꾼다.
///
/// - '12,500원' → 12500
/// - '3만 5천원' → 35000
/// - '8천원' → 8000
/// - '1.5만' → 15000
/// - '2억 3천만' → 230000000
/// - '삼만오천원' → 35000
///
/// 금액으로 읽을 수 없으면 null.
int? parseKoreanAmount(String text) {
  final s = text.replaceAll(_amountNoise, '');
  if (s.isEmpty) return null;
  if (_digitsOnly.hasMatch(s)) return int.tryParse(s);

  num total = 0; // 억 · 만 단위까지 더한 값
  num section = 0; // 만 아래(천 · 백 · 십 · 일)
  num? current; // 단위를 기다리는 숫자
  var sawUnit = false;

  var i = 0;
  while (i < s.length) {
    final ch = s[i];
    final digitMatch = _leadingNumber.matchAsPrefix(s, i);
    if (digitMatch != null) {
      if (current != null) return null; // 숫자가 연달아 나옴
      current = num.parse(digitMatch.group(0)!);
      i = digitMatch.end;
      continue;
    }
    final hangulDigit = _hangulDigits[ch];
    if (hangulDigit != null) {
      if (current != null) return null;
      current = hangulDigit;
      i++;
      continue;
    }
    final small = _smallUnits[ch];
    if (small != null) {
      section += (current ?? 1) * small;
      current = null;
      sawUnit = true;
      i++;
      continue;
    }
    final big = _bigUnits[ch];
    if (big != null) {
      section += current ?? 0;
      if (section == 0) section = 1; // '만원' = 1만
      total += section * big;
      section = 0;
      current = null;
      sawUnit = true;
      i++;
      continue;
    }
    return null; // 금액에 올 수 없는 글자
  }
  if (!sawUnit) return null; // 단위 없는 소수(예: 22.00)는 원화 금액이 아니다
  total += section + (current ?? 0);

  final rounded = total.round();
  if ((total - rounded).abs() > 1e-6) return null; // 1.23456만 같은 값
  return rounded;
}

/// 금액 후보가 문장에서 맡은 역할.
enum AmountRole {
  /// 거래 금액일 수 있다.
  amount,

  /// '잔액' 뒤의 숫자.
  balance,

  /// '누적' 뒤의 숫자.
  cumulative,
}

/// 문장에서 찾은 금액 후보.
class AmountCandidate {
  const AmountCandidate({
    required this.value,
    required this.role,
    required this.text,
    required this.start,
    required this.end,
    required this.hasWonSuffix,
  });

  final int value;
  final AmountRole role;

  /// 원문에서 잘라 낸 표기.
  final String text;
  final int start;
  final int end;

  /// '원'이 붙어 있었는지. 붙어 있으면 금액일 가능성이 높다.
  final bool hasWonSuffix;

  @override
  String toString() => 'AmountCandidate($value, ${role.name}, "$text")';
}

/// 문장에서 금액 후보를 모두 찾아 역할을 붙인다.
///
/// 날짜(11/16), 시각(12:31), 카드 끝자리 같은 숫자는 후보에서 뺀다.
/// 잔액 · 누적 뒤의 숫자는 역할을 따로 붙여, 잔액을 결제 금액으로 읽는 오류를 막는다.
List<AmountCandidate> findAmountCandidates(String text) {
  final result = <AmountCandidate>[];
  for (final m in _candidate.allMatches(text)) {
    final raw = m.group(0)!;
    final trimmed = raw.trimRight();
    final start = m.start;
    final end = start + trimmed.length;
    final hasWon = trimmed.endsWith('원');
    final hasUnit = _anyUnit.hasMatch(trimmed);
    final startsWithDigit = _startsWithDigit.hasMatch(trimmed);

    // 숫자 없이 단위 글자로만 된 표기('천원', '오만원')는 '원'이 있어야 금액으로 본다.
    // '백화점', '김밥천국' 같은 낱말을 금액으로 읽지 않기 위해서다.
    if (!startsWithDigit && !hasWon) continue;

    final before = start > 0 ? text[start - 1] : '';
    final after = end < text.length ? text[end] : '';

    if (!hasWon && !hasUnit) {
      // 꾸밈 없는 숫자. 날짜 · 시각 · 번호의 일부면 버린다.
      if (_numberNeighbors.contains(before) ||
          _numberNeighbors.contains(after)) {
        continue;
      }
      if (_notMoneySuffix.matchAsPrefix(text, end) != null) continue;
      // 괄호 안의 짧은 숫자는 카드 끝자리다.
      if (before == '(' && after == ')' && trimmed.length <= 4) continue;
      // 0으로 시작하는 숫자는 번호다.
      if (trimmed.length > 1 && trimmed.startsWith('0')) continue;
      // 낱말에 붙은 숫자는 수량이나 이름의 일부다: '2박스', '11번가', '24시간', '이마트24'.
      // 조사나 거래 낱말이 붙은 숫자는 금액이다: '4500에', '10000입금'.
      if (!trimmed.contains(',')) {
        if (_letter.hasMatch(after) &&
            _moneyFollower.matchAsPrefix(text, end) == null) {
          continue;
        }
        // 낱말 뒤에 붙은 세 자리 이하의 숫자도 이름이다('당근143'). 거래 낱말 뒤는 금액이다.
        if (trimmed.length <= 3 &&
            _hangul.hasMatch(before) &&
            !_moneyLeader.hasMatch(text.substring(0, start))) {
          continue;
        }
      }
    }

    final value = parseKoreanAmount(trimmed);
    if (value == null) continue;

    result.add(
      AmountCandidate(
        value: value,
        role: _roleFor(text, start),
        text: trimmed,
        start: start,
        end: end,
        hasWonSuffix: hasWon,
      ),
    );
  }
  return result;
}

AmountRole _roleFor(String text, int start) {
  // 숫자 바로 앞의 낱말을 본다.
  final from = start - 12 < 0 ? 0 : start - 12;
  final before = text.substring(from, start);
  if (_balanceBefore.hasMatch(before)) return AmountRole.balance;
  if (_cumulativeBefore.hasMatch(before)) return AmountRole.cumulative;
  return AmountRole.amount;
}

final _digitsOnly = RegExp(r'^\d+$');
final _amountNoise = RegExp(r'[\s,원₩]');
final _leadingNumber = RegExp(r'\d+(?:\.\d+)?');
final _anyUnit = RegExp('[억만천백십]');
final _startsWithDigit = RegExp(r'^\d');

const _hangulDigits = <String, int>{
  '일': 1,
  '이': 2,
  '삼': 3,
  '사': 4,
  '오': 5,
  '육': 6,
  '칠': 7,
  '팔': 8,
  '구': 9,
};
const _smallUnits = <String, int>{'천': 1000, '백': 100, '십': 10};
const _bigUnits = <String, int>{'억': 100000000, '만': 10000};

/// 금액 후보. 앞이 숫자 · 영문 · 쉼표 · 마침표면 다른 숫자의 일부로 보고 건너뛴다.
final _candidate = RegExp(
  r'(?<![0-9A-Za-z,.])'
  r'(?:'
  // 단위가 있는 표기: 3만 5천, 8천, 1.5만, 삼만오천, 만
  r'(?:[0-9][0-9,]*(?:\.[0-9]+)?|[일이삼사오육칠팔구])?'
  r' ?[억만천백십]'
  r'(?: ?(?:[0-9][0-9,]*|[일이삼사오육칠팔구])? ?[억만천백십])*'
  r'(?: ?[0-9][0-9,]*)?'
  r' ?원?'
  r'|'
  // 숫자만 있는 표기: 12,500원, 12000
  r'[0-9][0-9,]*(?![0-9.]) ?원?'
  r')',
);

/// 꾸밈 없는 숫자가 이 글자와 붙어 있으면 날짜 · 시각 · 번호다.
const _numberNeighbors = {'/', ':', '-', '.', '*', '#', '_'};

/// 숫자 뒤에 오면 금액이 아닌 단위.
/// 뒤에 한글이 이어지면 단위가 아니라 낱말의 첫 글자다('100,000 잔액'의 '잔').
final _notMoneySuffix = RegExp(
  r' ?(?:(?:년|월|일|시|분|초|개월|개|명|번|호|층|동|회|차|잔|병|장|권|박|주|살|세|퍼센트)(?![가-힣])'
  r'|(?:kg|km|ml|mL|g|L)(?![A-Za-z])|%'
  // 포인트 · 마일리지는 돈이 아니다: '3,000점이 소멸', '500포인트 적립'
  r'|포인트|마일|점(?:이|을|은|의|으로|도)?(?![가-힣]))',
);

final _letter = RegExp(r'[가-힣A-Za-z]');
final _hangul = RegExp(r'[가-힣]');

/// 꾸밈 없는 숫자 바로 뒤에 붙어도 금액으로 보는 말: 조사와 거래 낱말.
final _moneyFollower = RegExp(
  r'(?:을|를|이|가|은|는|에|으로|로|도|씩|짜리|어치|정도|쯤|이나|밖에|입니다|임|요'
  r'|입금|출금|결제|승인|사용|잔액|누적|이체|송금|환불|취소|지출|수입|받|보냄|보냈|냄|냈|씀|썼)',
);

/// 꾸밈 없는 숫자 바로 앞에 붙어 있으면 그 숫자를 금액으로 보는 말.
final _moneyLeader = RegExp(r'(?:입금|출금|결제|승인|사용|잔액|누적|이체|송금|환불|취소|금액)$');

final _balanceBefore = RegExp(r'잔액\s*:?\s*$');
final _cumulativeBefore = RegExp(r'누적(?:금액|이용금액|액)?\s*:?\s*$');
