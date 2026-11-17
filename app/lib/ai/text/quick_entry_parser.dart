/// 한 줄 문장을 규칙만으로 거래 초안으로 바꾼다.
///
/// '어제 점심 김밥천국 8천원 카드로' 같은 문장에서 날짜 · 금액 · 결제수단을 떼어 내고,
/// 남은 말을 상대방으로 둔다. 사람이 쓴 한 줄 문장은 기기 내 LLM이 있어도 이 규칙이 먼저
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
  rest = _cut(rest, chosen.start, chosen.end);

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

  // 남은 말이 상대방이다. '…에서' 꼴이면 조사를 뗀다.
  var party = foldWhitespace(rest).replaceAll(_edges, '');
  String? memo;
  final place = _place.firstMatch(party);
  if (place != null) {
    final name = place.group(1)!;
    final others = foldWhitespace(_cut(party, place.start, place.end));
    party = name;
    memo = others.isEmpty ? null : others;
  }
  if (party.isEmpty) warnings.add(ParseWarning.noCounterparty);

  return ParsedTransaction(
    date: date,
    time: time,
    amount: chosen.value,
    direction: direction,
    accountText: accountText,
    counterparty: party.isEmpty ? null : party,
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

/// '김밥천국에서'의 '김밥천국'.
final _place = RegExp(r'(\S+?)에서(?=\s|$)');
