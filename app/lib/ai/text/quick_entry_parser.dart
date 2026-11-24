/// 한 줄 문장을 규칙만으로 거래 초안으로 바꾼다.
///
/// '어제 점심 김밥천국 8천원 카드로' 같은 문장에서 날짜 · 금액 · 결제수단을 떼어 내고,
/// 남은 말 가운데 무엇에 쓴 돈인지를 가리키는 말만 상대방으로 둔다('김밥천국'). 끼니 ·
/// 수량 · 함께한 사람은 메모로 보내고('점심'), '먹음' · '결제' 같은 말은 버린다. 사람이 쓴 한 줄 문장은 기기 내 LLM이 있어도 이 규칙이 먼저
/// 읽는다. 홀드아웃 실측에서 소형 모델보다 정확했고 기다림이 없기 때문이다. 순서는
/// `input_interpreter.dart`에 있다.
library;

import '../../core/local_date.dart';
import '../parsed_transaction.dart';
import 'amount_parser.dart';
import 'date_parser.dart';
import 'direction_rules.dart';
import 'text_normalizer.dart';

/// 금액을 찾지 못하면 null.
ParsedTransaction? parseQuickEntry(String text, {required LocalDate today}) {
  final original = foldWhitespace(normalizeText(text));
  if (original.isEmpty) return null;

  var rest = original;
  final warnings = <ParseWarning>{};

  // 날짜
  var date = today;
  final dateExpression = findDateExpression(rest, today);
  if (dateExpression != null) {
    date = dateExpression.date;
    rest = _cut(rest, dateExpression.start, dateExpression.end);
  }

  // 시각
  String? time;
  final timeMatch = _clock.firstMatch(rest);
  if (timeMatch != null) {
    time = formatTime(
      int.parse(timeMatch.group(1)!),
      int.parse(timeMatch.group(2)!),
    );
    if (time != null) rest = _cut(rest, timeMatch.start, timeMatch.end);
  }

  // 금액: '원'이나 한글 단위가 붙은 표기를 먼저 고르고, 없으면 100 이상의 숫자를 쓴다.
  final candidates = findAmountCandidates(rest)
      .where((c) => c.role == AmountRole.amount && c.value > 0)
      .toList();
  if (candidates.isEmpty) return null;
  final marked = candidates.where(
    (c) => c.hasWonSuffix || _unit.hasMatch(c.text),
  );
  final AmountCandidate chosen;
  if (marked.isNotEmpty) {
    chosen = marked.first;
  } else {
    final plain = candidates.where((c) => c.value >= 100);
    if (plain.isEmpty) return null;
    chosen = plain.first;
    warnings.add(ParseWarning.amountWithoutUnit);
  }
  // 금액이 있던 자리를 표시해 둔다. 그 뒤의 한 글자 낱말('삼', '씀')은 동작으로 본다.
  rest =
      '${rest.substring(0, chosen.start)} $_amountMark '
      '${rest.substring(chosen.end)}';

  // 방향
  final direction = incomingWords.hasMatch(original)
      ? Direction.incoming
      : Direction.outgoing;

  // 결제수단
  String? accountText;
  final payment = _payment.firstMatch(rest);
  if (payment != null) {
    accountText = payment.group(1);
    rest = _cut(rest, payment.start, payment.end);
  }

  // 남은 말에서 군말을 덜어 내고 무엇에 쓴 돈인지만 남긴다.
  final described = _describe(rest);
  final party = described.party;
  final memo = described.memo;
  if (party == null) warnings.add(ParseWarning.noCounterparty);

  return ParsedTransaction(
    date: date,
    time: time,
    amount: chosen.value,
    direction: direction,
    accountText: accountText,
    counterparty: party,
    memo: memo,
    ruleId: 'quick_entry',
    raw: text,
    warnings: warnings,
  );
}

/// [start, end)를 공백으로 바꿔 잘라 낸다.
String _cut(String text, int start, int end) =>
    '${text.substring(0, start)} ${text.substring(end)}';

final _clock = RegExp(r'(?<![\d:])(\d{1,2}):(\d{2})(?![\d:])');
final _unit = RegExp('[억만천백십]');
final _edges = RegExp(r'^[\s,.:·\-]+|[\s,.:·\-]+$');

/// 결제수단. 조사 '로/으로'가 붙었거나 낱말로 따로 떨어져 있을 때만 뗀다.
final _payment = RegExp(
  r'(?<![가-힣A-Za-z])(신용카드|체크카드|카드|현금|계좌이체|삼성페이|카카오페이|네이버페이|토스페이|페이)'
  r'(?:으로|로)?(?![가-힣A-Za-z])',
);

/// 날짜 · 금액 · 결제수단을 떼고 남은 말을 상대방과 메모로 나눈다.
///
/// - 상대방: 가게 · 사람 · 물건처럼 무엇에 쓴 돈인지를 가리키는 말. '…에서'가 붙은 말이
///   있으면 그것, 없으면 '…한테'가 붙은 말이나 돈을 준 사람, 그것도 없으면 남은 이름들.
/// - 메모: 끼니('점심'), 수량('2잔'), 함께한 사람('친구랑'), 그리고 상대방이 따로 정해졌을
///   때의 나머지 이름.
/// - 버리는 말: 동작('먹음', '샀다', '결제'), 조사, '방금' 같은 때를 가리키는 말.
///
/// 이름이 하나도 남지 않으면 메모로 갈 말을, 그것도 없으면 '결제' 같은 말을 상대방으로 쓴다
/// ('점심 12000' → '점심').
({String? party, String? memo}) _describe(String rest) {
  final text = foldWhitespace(rest).replaceAll(_relativePeriod, ' ');
  final giving = _giving.hasMatch(text);
  final tokens = [
    for (final raw in text.split(' '))
      if (raw.replaceAll(_edges, '').isNotEmpty) raw.replaceAll(_edges, ''),
  ];

  String? place;
  String? person;
  // 나온 순서를 지킨다. name이 true면 이름, false면 메모로 갈 말.
  final kept = <({String text, bool name})>[];
  final actions = <String>[];

  var afterAmount = false;
  var first = true;
  for (var i = 0; i < tokens.length; i++) {
    var token = tokens[i];
    if (token == _amountMark) {
      afterAmount = true;
      continue;
    }
    final leading = first && !afterAmount;
    first = false;

    // 수량: '2잔', '한 박스', '두권'
    if (_koreanCount.hasMatch(token) &&
        i + 1 < tokens.length &&
        _counter.hasMatch(tokens[i + 1])) {
      kept.add((text: '$token ${tokens[i + 1]}', name: false));
      i++;
      continue;
    }
    if (_quantity.hasMatch(token) || _fusedCount.hasMatch(token)) {
      kept.add((text: token, name: false));
      continue;
    }

    // 동작. '삼' · '감'처럼 한 글자인 말은 물건 이름일 수도 있어서, 금액보다 앞에 맨 처음
    // 나올 때는 남긴다('감 한 박스 2만원').
    if (_fillers.contains(token) || _verb.hasMatch(token)) continue;
    if (!leading && _shortVerbs.contains(token)) continue;
    final tail = _verbTail.firstMatch(token);
    if (tail != null) {
      token = token.substring(0, tail.start);
      if (token.isEmpty || token == '밥' || token == '돈') continue;
    }

    // 조사
    final from = _from.firstMatch(token);
    if (from != null && place == null) {
      place = from.group(1);
      continue;
    }
    final to =
        _to.firstMatch(token) ?? (giving ? _giver.firstMatch(token) : null);
    if (to != null && person == null) {
      person = to.group(1);
      continue;
    }
    if (_with.hasMatch(token) || _by.hasMatch(token)) {
      kept.add((text: token, name: false));
      continue;
    }
    token = _objectParticle.firstMatch(token)?.group(1) ?? token;

    if (_fillers.contains(token)) continue;
    if (_actionNouns.contains(token)) {
      actions.add(token);
    } else {
      kept.add((text: token, name: !_context.contains(token)));
    }
  }

  String? join(Iterable<String> words) =>
      words.isEmpty ? null : words.join(' ');

  final names = kept.where((k) => k.name).map((k) => k.text);
  if (place != null) {
    return (party: place, memo: join([?person, ...kept.map((k) => k.text)]));
  }
  if (person != null) {
    return (party: person, memo: join(kept.map((k) => k.text)));
  }
  if (names.isNotEmpty) {
    return (
      party: join(names),
      memo: join(kept.where((k) => !k.name).map((k) => k.text)),
    );
  }
  return (party: join(kept.map((k) => k.text)) ?? join(actions), memo: null);
}

/// 금액이 있던 자리. 원문에 나올 일이 없는 제어 문자를 쓴다.
const _amountMark = '\u0001';

/// '이번 달', '지난주'. 날짜로 읽히지 않고 남은 것은 이름이 아니다.
final _relativePeriod = RegExp(
  r'(?<![가-힣])(?:이번|지난|저번)\s?(?:달|주말|주|해)에?(?![가-힣])',
);

/// 조사만 남은 조각과, 때 · 나를 가리키는 말.
const _fillers = <String>{
  '에',
  '을',
  '를',
  '은',
  '는',
  '이',
  '가',
  '도',
  '로',
  '으로',
  '에서',
  '짜리',
  '어치',
  '정도',
  '쯤',
  '씩',
  '방금',
  '아까',
  '오늘',
  '어제',
  '어젯밤',
  '오늘밤',
  '내가',
  '제가',
};

/// 무엇에 쓴 돈인지보다 언제 · 어떻게를 말하는 낱말. 다른 이름이 있으면 메모로 간다.
const _context = <String>{
  '아침',
  '점심',
  '저녁',
  '야식',
  '브런치',
  '식사',
  '밥',
  '오전',
  '오후',
  '새벽',
  '밤',
  '낮',
  '배달',
  '포장',
};

/// 동작을 가리키는 명사. 다른 말이 하나도 없을 때만 상대방으로 쓴다.
const _actionNouns = <String>{
  '결제',
  '구매',
  '구입',
  '계산',
  '지출',
  '주문',
  '납부',
  '사용',
  '입금',
  '출금',
  '이체',
  '송금',
  '자동이체',
  '자동결제',
  '계좌이체',
};

const _shortVerbs = <String>{'삼', '씀', '냄', '탐', '감', '함', '봄', '쏨', '줌'};

const _pastStems =
    '먹었|마셨|샀|썼|냈|탔|시켰|했|갔|봤|쐈|질렀|긁었|받았|보냈|줬|드렸|'
    '빠져나갔|들어왔|나갔|됐|팔았';
const _pastEndings = '다|어|음|어요|습니다|네|지|는데';

/// 낱말 전체가 동작인 것.
final _verb = RegExp(
  '^(?:드림|받음|보냄|지름|긁음|먹음|사먹음|시켜먹음|마심|시킴|시켜|주고|가서|와서|해서|사서|'
  '팔고|팔아서|받은|보낸|먹은|들어옴|나감|빠져나감|보내줌|보내주심|주심|사줌|됨|'
  '(?:$_pastStems)(?:$_pastEndings)?)\$',
);

/// 이름 뒤에 붙은 동작: '밥먹음', '커피마심', '결제함', '주문했음'.
///
/// '함'은 동작 명사 뒤에서만 뗀다('수납함'은 물건이다).
final _verbTail = RegExp(
  '(?:시켜먹음|사먹음|먹음|마심|시킴|들어옴|빠져나감|보내주심|보내줌|됨|'
  '(?<=결제|주문|구매|구입|계산|지출|이체|송금|납부|충전|예약|예매|환불|입금|출금)함|'
  '(?:$_pastStems)(?:$_pastEndings))\$',
);

/// 돈을 준 사람이 주어로 나오는 문장인지('엄마가 20만원 보내줌').
final _giving = RegExp(
  r'보내\s?(?:줌|줬|주심|주셨)|(?<![가-힣])줌(?![가-힣])|줬|주심|주셨|쏨(?![가-힣])|쐈|사줌|사줬',
);

/// '김밥천국에서'의 '김밥천국'.
final _from = RegExp(r'^(.+)에서$');

/// '엄마한테'의 '엄마'.
final _to = RegExp(r'^(.+)(?:한테|에게)$|^(?:(.{2,})께)$');

/// 돈을 준 사람: '엄마가', '동생이'. '이'는 사람을 가리키는 말에서만 뗀다('떡볶이').
final _giver = RegExp(r'^(.{2,})가$|^(동생|형|삼촌|남편|아들|딸|[가-힣]+님)이$');

/// '친구랑', '동료들이랑'.
final _with = RegExp(r'^.{2,}랑$');

/// '온라인으로'.
final _by = RegExp(r'^.{2,}으로$');

/// '중고나라에', '저녁을'. 두 글자 낱말('카페', '가을')은 건드리지 않는다.
final _objectParticle = RegExp(r'^(.{2,})(?:에|을|를)$');

const _counters =
    '잔|박스|명|개월|개|권|병|장|번|인분|봉지|봉|팩|캔|통|벌|켤레|마리|그릇|판|줄|'
    '포기|송이|세트|조각|곡|편|시간';
final _quantity = RegExp(
  '^\\d+(?:\\.\\d+)?(?:$_counters|kg|g|ml|L|l|리터|회|매|인|박|알|단|달|주|일|년)에?\$',
);
final _koreanCount = RegExp(r'^(?:한|두|세|네|다섯|여섯|일곱|여덟|아홉|열|몇)$');
final _counter = RegExp('^(?:$_counters|단|달)\$');
final _fusedCount = RegExp(
  r'^(?:한|두|세|네)(?:잔|박스|개|권|병|장|번|팩|캔|통|벌|마리|그릇|판|줄|봉지|세트|조각)$',
);
