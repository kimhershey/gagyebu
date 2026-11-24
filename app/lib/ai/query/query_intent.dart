import '../text/amount_parser.dart';

/// [text]가 거래를 적는 글이 아니라 가계부에 묻는 글인지(`docs/SPEC.md` 7.15).
/// 입력창이 조회 화면으로 보낼지 정하는 데 쓴다.
///
/// 금액이 없고, 물음 낱말이나 물음표가 있는 한 줄이면 묻는 글이다. 금액이 있으면
/// 물음표가 있어도 거래로 본다('점심 9천원?'). 거래를 조회로 잘못 보내면 적으려던
/// 내용이 사라지지만, 조회를 거래로 보내면 "읽지 못했습니다"로 끝나서 덜 해롭다.
bool looksLikeQuery(String text) {
  final line = text.trim();
  if (line.isEmpty || line.length > _maxLength) return false;
  if (line.contains('\n') || line.contains('\r')) return false;
  if (findAmountCandidates(line).isNotEmpty) return false;
  return _askMark.hasMatch(line) || _askWord.hasMatch(line);
}

/// 묻는 글은 짧다. 긴 한 줄은 붙여넣은 알림일 가능성이 높다.
const _maxLength = 80;

final _askMark = RegExp('[?？]');
final _askWord = RegExp('얼마|몇|언제|뭐|보여|알려|합계|평균');
