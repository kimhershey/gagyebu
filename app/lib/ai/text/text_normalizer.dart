/// 붙여넣은 원문을 파서가 다루기 쉬운 형태로 정리한다.
///
/// 결제 문자와 은행 앱 텍스트에는 전각 공백, '・' 구분자, CRLF, 보이지 않는 제어 문자가
/// 섞여 온다. 뜻은 바꾸지 않고 표기만 통일한다.
library;

/// 표기를 통일한다. 줄바꿈은 유지한다.
String normalizeText(String input) {
  final sb = StringBuffer();
  for (final rune in input.runes) {
    // 보이지 않는 문자(폭 없는 공백, BOM, 소프트 하이픈, 방향 표시)
    if (rune == 0x200B ||
        rune == 0x200C ||
        rune == 0x200D ||
        rune == 0x200E ||
        rune == 0x200F ||
        rune == 0x2060 ||
        rune == 0xFEFF ||
        rune == 0x00AD) {
      continue;
    }
    // 줄바꿈과 탭을 뺀 제어 문자
    if ((rune < 0x20 && rune != 0x0A && rune != 0x0D && rune != 0x09) ||
        rune == 0x7F) {
      continue;
    }
    // 전각 영숫자와 기호 → 반각
    if (rune >= 0xFF01 && rune <= 0xFF5E) {
      sb.writeCharCode(rune - 0xFEE0);
      continue;
    }
    switch (rune) {
      case 0x09: // 탭
      case 0x00A0: // 줄바꿈 없는 공백
      case 0x3000: // 전각 공백
      case 0x202F:
      case 0x205F:
      case >= 0x2000 && <= 0x200A:
        sb.write(' ');
      case 0x30FB: // ・
      case 0xFF65: // ･
      case 0x2022: // •
      case 0x2027: // ‧
        sb.write('·');
      case 0xFFE6: // ￦
        sb.write('₩');
      case 0x2212: // −
      case >= 0x2010 && <= 0x2015: // 여러 가지 줄표
        sb.write('-');
      case 0x2192: // →
      case 0x279C:
      case 0x27A1:
        sb.write('→');
      default:
        sb.writeCharCode(rune);
    }
  }
  final unified = sb.toString().replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  return unified
      .split('\n')
      .map((line) => line.replaceAll(_spaces, ' ').trim())
      .join('\n')
      .trim();
}

/// 줄바꿈까지 공백 하나로 접는다.
///
/// 같은 문자도 SMS · RCS · 앱 알림에 따라 줄바꿈이 달라서, 형식 규칙은 이 형태에 맞춘다.
String foldWhitespace(String text) =>
    text.replaceAll(_anyWhitespace, ' ').trim();

final _spaces = RegExp(r' {2,}');
final _anyWhitespace = RegExp(r'\s+');
