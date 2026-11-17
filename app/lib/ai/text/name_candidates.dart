/// 원문에서 상대 · 내용이 될 수 있는 말을 골라낸다.
///
/// 결제 문자에서 날짜, 시각, 금액, 계좌번호, 명의자 이름, '승인' · '잔액' 같은 낱말을 지우면
/// 남는 것은 대개 가맹점이나 보낸 사람의 이름이다. 그 남은 말을 후보로 주고 모델은
/// 그 안에서 고른다. 모델이 이름을 지어내거나 은행 이름을 상대로 적는 일을 막는다.
library;

import '../../core/local_date.dart';
import 'amount_parser.dart';
import 'date_parser.dart';

/// [text]에서 상대 · 내용 후보를 나온 순서대로 돌려준다(최대 12개).
///
/// 한 줄 안에서 이어진 말은 한 후보로 묶는다('세븐일레븐 가평목동'). 한 줄짜리 문장처럼
/// 형식이 없는 글이면 묶음 안의 낱말도 따로 후보로 준다('점심', '김밥천국').
List<String> findNameCandidates(String text, LocalDate today) {
  final messageLike = looksLikeMessage(text);
  final phrases = <String>[];
  final words = <String>[];

  for (final rawLine in text.split('\n')) {
    // '대출실행 ( 원금 )' → '대출실행 (원금)': 괄호 안쪽의 공백 때문에 이름이 끊기지 않게 한다.
    final line = rawLine.replaceAllMapped(
      _spacedParens,
      (m) => '(${m.group(1)})',
    );
    // 날짜와 금액이 차지한 자리를 끊는 표시로 바꾼다. 붙어 있던 말은 남는다:
    // '스타벅스12,000원' → '스타벅스', '출금13,958원' → '출금'(버릴 낱말)
    final spans = <(int, int)>[
      for (final d in findDateExpressions(line, today)) (d.start, d.end),
      for (final a in findAmountCandidates(line)) (a.start, a.end),
    ];
    final masked = StringBuffer();
    for (var i = 0; i < line.length; i++) {
      final cut = spans.any((s) => s.$1 <= i && i < s.$2);
      masked.write(cut ? _cut : line[i]);
    }

    final current = <String>[];
    void flush() {
      if (current.isEmpty) return;
      phrases.add(current.join(' '));
      if (current.length > 1) words.addAll(current);
      current.clear();
    }

    for (final m in _token.allMatches(masked.toString())) {
      var token = m.group(0)!;
      if (token.startsWith(_cut) || _isNoise(token)) {
        flush();
        continue;
      }
      // '쿠팡에서', '엄마한테'의 조사를 뗀다.
      token = token.replaceFirst(_particle, '');
      // '강동밀레니얼점(일시불)'의 결제 방식을 뗀다.
      token = token.replaceFirst(_installmentSuffix, '');
      token = token.replaceAll(_edges, '');
      if (token.isEmpty || _isNoise(token)) {
        flush();
        continue;
      }
      current.add(token);
    }
    flush();
  }

  final result = <String>[];
  for (final candidate in [...phrases, if (!messageLike) ...words]) {
    if (candidate.length > 40 || result.contains(candidate)) continue;
    result.add(candidate);
    if (result.length == 12) break;
  }
  return result;
}

bool _isNoise(String token) =>
    !_hasLetterOrDigit.hasMatch(token) ||
    _keywords.contains(token) ||
    _noisePatterns.any((p) => p.hasMatch(token));

/// 날짜 · 금액이 있던 자리를 나타내는 표시. 원문에 나올 일이 없는 제어 문자를 쓴다.
const _cut = '\u0001';
final _token = RegExp('[^\\s$_cut]+|$_cut+');
final _particle = RegExp(r'(에서|한테|에게|으로)$');
final _installmentSuffix = RegExp(r'\((?:일시불|\d{1,2}개월)\)$');
final _spacedParens = RegExp(r'\(\s+([^()]*?)\s+\)');
// 앞뒤의 문장 부호와, 짝을 잃은 괄호
final _edges = RegExp(r'^[,.:;·|/→\-\])]+|[,.:;·|/→\-\[(]+$');
final _hasLetterOrDigit = RegExp(r'[가-힣A-Za-z0-9]');

/// 금융사나 앱이 보낸 글로 보이는지. 사람이 쓴 한 줄 문장과 가르는 데 쓴다.
///
/// 여러 줄이거나, 거래 문자의 낱말 · 시각(12:31) · 가린 글자(홍*동) · 머리말([KB]) ·
/// 카드 끝자리((1234))가 있으면 그렇게 본다.
bool looksLikeMessage(String text) =>
    text.trim().contains('\n') || _messageMarkers.hasMatch(text);

final _messageMarkers = RegExp(
  r'잔액|누적|승인|출금|입금|일시불|결제완료|취소완료'
  r'|\d{1,2}:\d{2}|\*|^\s*\[|\(\d{4}\)',
);

const _keywords = <String>{
  '승인', '승인취소', '취소', '취소완료', '해외승인', '출금', '입금', '사용', '결제', '완료',
  '일시불', '체크', '신용', '개인', '법인', '누적', '총누적', '누적금액', '누적이용금액',
  '잔액', '카드', '계좌', '내용', '메모', '금액', '손님명', '거래종류', '거래구분', '사용처',
  '거래시간', '알림', '입출금', '캐시백', '원', '달러', '님',
  '을', '를', '이', '가', '은', '는', '에', '의', '로', '와', '과', '도',
  '(광고)', '광고', '수신거부', '무료수신거부', '[Web발신]', '[국외발신]',
  // 문장 입력에서 상대도 내용도 아닌 말
  '오늘', '어제', '그제', '그저께', '엊그제', '아침', '저녁에', '받음', '받았어', '받았다',
  '보냄', '보냈다', '보내줌', '들어옴', '들어왔다', '냄', '냈다', '납부', '구매', '샀다',
  '자동이체', '이체', '팔아서', '현금', '신용카드', '체크카드', '카드로', '현금으로',
  '계좌이체', '삼성페이', '카카오페이로', '네이버페이로', '토스페이로',
};

final _noisePatterns = <RegExp>[
  // 날짜 · 시각의 조각
  RegExp(r'^\(?\d{1,4}[/.\-]\d{1,2}(?:[/.\-]\d{1,2})?\)?$'),
  RegExp(r'^\d{1,2}:\d{2}(?::\d{2})?$'),
  // 계좌 · 카드 · 전화번호
  RegExp(r'^[\d*\-()\[\]]{3,}$'),
  // 가린 이름과 '님'으로 끝나는 명의자
  RegExp(r'^[가-힣A-Za-z]{0,3}\*+[가-힣A-Za-z*]{0,4}(?:\([\d*]{2,}\))?님?$'),
  RegExp(r'^[가-힣]{2,4}님$'),
  // 할부 · 결제 방식
  RegExp(r'^\(?(?:일시불|\d{1,2}개월)\)?$'),
  // '체크카드출금', '전자금융입금'
  RegExp(r'^\S*(?:입금|출금)$'),
  // 금융사 머리말: [KB], 신한카드(1234)승인, 삼성1234승인, 부산BC(1234), 하나, …
  RegExp(r'^\[[^\]]*\]$'),
  RegExp(r'(?:카드|은행|뱅크|BC|Card|통장|계좌|입출금)[(\[]?[\d*]{2,}'),
  RegExp(
    r'^[\[(]?(?:KB국민|KB|국민|신한|우리|하나|농협|NH농협|NH|IBK|기업|삼성|현대|롯데|씨티|카카오뱅크|케이뱅크|토스뱅크|토스|부산)'
    r'(?:카드|은행|뱅크|체크|법인)?[\d*()\[\],/:.\-]*(?:해외승인|승인취소|승인|취소)?[\])]?$',
  ),
  // 괄호 안의 나라 · 통화 부호: (US), (USD)
  RegExp(r'^\([A-Z]{2,3}\)$'),
  // 금융사 이름으로 끝나는 낱말: 새봄은행, [새봄카드]
  RegExp(r'^[(\[]?[가-힣A-Za-z]{1,8}(?:은행|카드|뱅크|금고|증권)[)\]]?$'),
  // 금융 낱말로만 이루어진 조각: 출금예정, 결제예정금액, 해외승인, 승인취소, (일시불)
  RegExp(
    r'^[(\[]?(?:출금|입금|결제|승인|이체|납부|청구|이용|사용|거래|예정|금액|완료|안내|내역|취소|거절|실패|일시불|일시|'
    r'잔액|누적|한도|체크|신용|카드|계좌|자동|해외|국내|할부|환불|대금|명세서|알림|총|원)+[)\]]?$',
  ),
];
