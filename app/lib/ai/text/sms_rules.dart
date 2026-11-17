/// 금융사별 결제 문자 · 앱 알림 형식 규칙.
///
/// 규칙은 데이터다. 정규식 하나와 금융사 정보로 이뤄지고, 이름 붙인 그룹을 공통 해석기
/// ([parseWithRules])가 거래 초안으로 옮긴다. 나중에 원격 카탈로그(JSON)로 내려받아
/// 앱 업데이트 없이 고칠 수 있게 하려는 구조다.
///
/// 규칙은 줄바꿈을 공백 하나로 접은 원문에 맞춘다. 같은 문자도 SMS · RCS · 앱 알림에 따라
/// 줄바꿈이 달라지기 때문이다.
///
/// 그룹 이름
/// - `year` `mon` `day` `hh` `mm`: 날짜와 시각. 날짜가 없으면 붙여넣은 날을 쓴다.
/// - `amount` (`amount2`): 금액. 음수면 취소로 본다.
/// - `dirword` (`dirword2`): 입금 · 출금 · 승인 · 취소 같은 낱말.
/// - `acct`: 계좌 · 카드 번호 표기. `acctname`: 통장 · 카드 상품 이름.
/// - `party`: 상대방. `memo`: 메모.
/// - `balance`: 잔액. `cum`: 누적 사용액.
/// - `inst`: 일시불 · N개월 · 체크.
/// - `holder`: 명의자(저장하지 않는다).
/// - `famount` `cur`: 해외 결제의 원래 금액과 통화.
/// - `cashback`: 캐시백 금액(메모에 적는다).
library;

import '../parsed_transaction.dart';

/// 형식 규칙 하나.
class SmsRule {
  SmsRule({
    required this.id,
    required this.institution,
    required this.kind,
    required String pattern,
    this.defaultDirection,
    this.partyIsOwnAccountWhenOutgoing = false,
  }) : pattern = RegExp(pattern);

  /// 골든 세트와 로그에서 규칙을 가리키는 이름.
  final String id;

  /// 금융사 이름.
  final String institution;
  final AccountHintKind kind;
  final RegExp pattern;

  /// `dirword` 그룹이 없는 형식의 방향.
  final Direction? defaultDirection;

  /// '보낸 쪽 → 받는 쪽' 형식에서 출금이면 앞뒤가 바뀌는 규칙.
  final bool partyIsOwnAccountWhenOutgoing;
}

// 공통 조각. 한 규칙 안에서 같은 그룹 이름은 한 번만 쓴다.
const _d = r'(?<mon>\d{1,2})[/.](?<day>\d{1,2})';
const _t = r'(?<hh>\d{1,2}):(?<mm>\d{2})(?::\d{2})?';
const _amt = r'(?<amount>-?[\d,]+)';
const _holder = r'(?<holder>[가-힣A-Za-z*]{2,}?님?)';
const _inst = r'(?<inst>일시불|\d{1,2}개월|체크)';
const _bal = r'잔액\s*(?<balance>-?[\d,]+)원?';
const _cum = r'(?:\s*(?:총\s*)?누적(?:금액|이용금액)?\s*(?<cum>[\d,]+)원?)?';
const _acct = r'(?<acct>[\d*][\d*\-]{3,})';
const _card4 = r'(?<acct>\d{4}|\d\*\d\*)';
const _cardWord = r'(?<dirword>승인취소|승인|취소)';

/// 기본 규칙. 위에서부터 차례로 맞춰 보고 처음 맞는 규칙을 쓴다.
final List<SmsRule> builtinSmsRules = List.unmodifiable([
  // ------------------------------------------------------------------ 은행 문자
  SmsRule(
    id: 'kb_bank',
    institution: 'KB국민은행',
    kind: AccountHintKind.bank,
    // [KB]7/10 16:40 123456****7890 홍길동 1,000,000 입금 잔액 50,000 1644-9999
    // [KB]11/18 14:58 123456**789 과일놀이터 체크카드출금 18,000 잔액238,281
    pattern:
        '^\\[KB\\]\\s*$_d\\s+$_t\\s+$_acct\\s+(?<party>.+?)\\s+'
        '(?:(?<dirword>\\S*?(?:입금|출금))\\s*$_amt원?'
        '|(?<amount2>[\\d,]+)원?\\s*(?<dirword2>\\S*?(?:입금|출금)))'
        '(?:\\s+$_bal)?(?:\\s+\\d{2,4}-\\d{3,4}(?:-\\d{4})?)?\$',
  ),
  SmsRule(
    id: 'shinhan_bank',
    institution: '신한은행',
    kind: AccountHintKind.bank,
    // 신한02/01 11:05 110-***-000000 출금 14,510 잔액 532,513 신한체크교통
    pattern:
        '^신한\\s*$_d\\s+$_t\\s+$_acct\\s+(?<dirword>입금|출금)\\s*$_amt원?'
        '\\s+$_bal(?:\\s+(?<party>.+))?\$',
  ),
  SmsRule(
    id: 'woori_bank',
    institution: '우리은행',
    kind: AccountHintKind.bank,
    // 우리 06/20 11:20 *123456 입금 472원 예금결산 잔액 1,199,234원
    pattern:
        '^우리\\s+$_d\\s+$_t\\s+$_acct\\s+(?<dirword>입금|출금)\\s*$_amt원?'
        '\\s+(?:(?<party>.+?)\\s+)?$_bal\$',
  ),
  SmsRule(
    id: 'hana_bank',
    institution: '하나은행',
    kind: AccountHintKind.bank,
    // 하나,09/10 11:17 123******45607 출금13,958원 0908_GOOGLE*i 잔액669,942원
    pattern:
        '^하나,\\s*$_d\\s+$_t\\s+$_acct\\s+(?<dirword>입금|출금)\\s*$_amt원?'
        '\\s+(?:(?<party>.+?)\\s+)?$_bal\$',
  ),
  SmsRule(
    id: 'nh_bank',
    institution: 'NH농협은행',
    kind: AccountHintKind.bank,
    // 농협 입금73,000원 08/14 23:34 123-****-4567-89 HONGGILD 잔액123,189원
    // 올원뱅크 알림은 앞에 '입출금 알림'이 붙는다.
    pattern:
        '^(?:입출금\\s?알림\\s+)?(?:\\[?농협\\]?|NH농협)\\s*(?<dirword>입금|출금)\\s*$_amt원?'
        '\\s+$_d\\s+$_t\\s+$_acct\\s+(?:(?<party>.+?)\\s+)?$_bal\$',
  ),
  SmsRule(
    id: 'ibk_bank',
    institution: 'IBK기업은행',
    kind: AccountHintKind.bank,
    // 2021/08/19 04:55 출금 11,000원 잔액 1,003,145원 HONGGILD_아 123***45678901 기업
    pattern:
        '^(?<year>\\d{4})/(?<mon>\\d{2})/(?<day>\\d{2})\\s+$_t\\s+'
        '(?<dirword>입금|출금)\\s*$_amt원?\\s+$_bal\\s+(?<party>.+?)\\s+$_acct\\s+기업\$',
  ),
  SmsRule(
    id: 'busan_bank',
    institution: '부산은행',
    kind: AccountHintKind.bank,
    // 입금 10/12 14:53 1 계좌 123456789***0 내용 당근143 잔액 500,000
    // 출금 10/12 16:17 24,000 계좌 123456789***0 내용 메모 토스 홍길동 잔액 476,000
    pattern:
        '^(?<dirword>입금|출금)\\s+$_d\\s+$_t\\s+$_amt원?\\s+계좌\\s+$_acct'
        '\\s+내용\\s*(?<party>.*?)\\s*(?:메모\\s+(?<memo>.*?)\\s*)?$_bal\$',
  ),
  SmsRule(
    id: 'kakaobank',
    institution: '카카오뱅크',
    kind: AccountHintKind.bank,
    // [카카오뱅크] 홍*동(1234) 12/11 15:42 출금 7,250원 세븐일레븐 가평목동 잔액 4,123,123원
    pattern:
        '^\\[카카오뱅크\\]\\s*(?<holder>\\S+?)\\((?<acct>\\d{4})\\)\\s+$_d\\s+$_t\\s+'
        '(?<dirword>입금|출금)\\s*$_amt원?\\s+(?:(?<party>.+?)\\s+)?$_bal\$',
  ),
  SmsRule(
    id: 'kbank',
    institution: '케이뱅크',
    kind: AccountHintKind.bank,
    // [케이뱅크] 홍*동(1234) 출금 12,000원 잔액 345,678원 SK매직_홍길동
    pattern:
        '^\\[케이뱅크\\]\\s*(?<holder>\\S+?)\\((?<acct>\\d{4})\\)\\s+'
        '(?<dirword>입금|출금)\\s*$_amt원?\\s+$_bal(?:\\s+(?<party>.+))?\$',
  ),

  // ------------------------------------------------------------------ 카드 문자
  SmsRule(
    id: 'kb_card',
    institution: 'KB국민카드',
    kind: AccountHintKind.card,
    // KB국민카드1234승인 홍*동님 129,857원 일시불 02/08 22:39 마켓컬리 누적800,000원
    pattern:
        '^KB국민(?:카드|체크)\\s*$_card4\\s*$_cardWord\\s+$_holder\\s+$_amt원\\s+$_inst'
        '\\s+$_d\\s+$_t\\s+(?<party>.+?)$_cum\$',
  ),
  SmsRule(
    id: 'shinhan_card_foreign',
    institution: '신한카드',
    kind: AccountHintKind.card,
    defaultDirection: Direction.outgoing,
    // 신한(1234)해외승인 홍*동 220.00 달러 (US)11/11 22:34 ANTHROPIC* 누적2,027,221원
    pattern:
        '^신한(?:카드|체크)?\\((?<acct>\\d{4})\\)해외승인\\s+$_holder\\s+'
        '(?<famount>[\\d,]+(?:\\.\\d+)?)\\s*(?<cur>달러|USD|엔|JPY|유로|EUR|위안|CNY|파운드|GBP)'
        '\\s*(?:\\([A-Z]{2}\\))?\\s*$_d\\s+$_t\\s+(?<party>.+?)$_cum\$',
  ),
  SmsRule(
    id: 'shinhan_card',
    institution: '신한카드',
    kind: AccountHintKind.card,
    // 신한카드(1234)승인 홍*동 2,400원(일시불)02/23 16:56 세븐일레븐영 누적1,427,265원
    pattern:
        '^신한(?:카드|체크)?\\((?<acct>\\d{4})\\)$_cardWord\\s+$_holder\\s+$_amt원'
        '\\($_inst\\)\\s*$_d\\s+$_t\\s+(?<party>.+?)$_cum\$',
  ),
  SmsRule(
    id: 'samsung_card',
    institution: '삼성카드',
    kind: AccountHintKind.card,
    // 삼성1234승인 홍*동 100원 일시불 01/09 20:07 세븐일레븐아산음 누적80,090원
    // 삼성1234취소 홍*동 -4,020원 일시불 10/09 19:41 쿠팡 누적1,100,000원
    pattern:
        '^삼성(?:카드)?\\s*$_card4\\s*$_cardWord\\s+$_holder\\s+$_amt원\\s+$_inst'
        '\\s+$_d\\s+$_t\\s+(?<party>.+?)$_cum\$',
  ),
  SmsRule(
    id: 'hyundai_card',
    institution: '현대카드',
    kind: AccountHintKind.card,
    // 현대 ZERO 승인 2,500원 일시불 04/10 13:15 코레일유통서울지사 누적 560,852원
    pattern:
        '^현대(?:카드)?\\s+(?<acctname>\\S+)\\s+$_cardWord\\s+(?:$_holder\\s+)?$_amt원\\s+$_inst'
        '\\s+$_d\\s+$_t\\s+(?<party>.+?)$_cum\$',
  ),
  SmsRule(
    id: 'woori_card',
    institution: '우리카드',
    kind: AccountHintKind.card,
    // 우리(1234)승인취소 홍*동님 4562원 일시불 12/07 20:29 네이버페이 누적123,456원
    pattern:
        '^우리(?:카드)?\\((?<acct>\\d{4})\\)$_cardWord\\s+$_holder\\s+$_amt원\\s+$_inst'
        '\\s+$_d\\s+$_t\\s+(?<party>.+?)$_cum\$',
  ),
  SmsRule(
    id: 'hana_card',
    institution: '하나카드',
    kind: AccountHintKind.card,
    // 하나1*3*승인 홍*동 200,000원 일시불 11/05 16:07 국민카메라 누적2,566,980원
    pattern:
        '^하나(?:카드)?\\s*$_card4\\s*$_cardWord\\s+$_holder\\s+$_amt원\\s+$_inst'
        '\\s+$_d\\s+$_t\\s+(?<party>.+?)$_cum\$',
  ),
  SmsRule(
    id: 'bc_card',
    institution: 'BC카드',
    kind: AccountHintKind.card,
    // 부산BC(1234) 12,300원 사용 개인 홍길동님 일시불 04/24 13:45 총누적 100,000원 스타벅스
    pattern:
        '^(?<acctname>\\S*?BC)\\((?<acct>\\d{4})\\)\\s+$_amt원\\s+'
        '(?<dirword>사용|승인취소|승인|취소)\\s+(?:(?:개인|법인)\\s+)?$_holder\\s+$_inst'
        '\\s+$_d\\s+$_t\\s+(?:(?:총\\s*)?누적\\s*(?<cum>[\\d,]+)원\\s+)?(?<party>.+)\$',
  ),
  SmsRule(
    id: 'nh_card',
    institution: 'NH농협카드',
    kind: AccountHintKind.card,
    // NH카드1*3*승인 홍*동 10,000원 체크 03/16 00:44 (주)이니셜커뮤니케이션즈
    pattern:
        '^NH(?:농협)?카드\\s*$_card4\\s*$_cardWord\\s+$_holder\\s+$_amt원\\s+$_inst'
        '\\s+$_d\\s+$_t\\s+(?<party>.+?)(?:\\s+$_bal)?$_cum\$',
  ),
  SmsRule(
    id: 'jb_card',
    institution: 'JB카드',
    kind: AccountHintKind.card,
    // [JBCard]4321 500,000원 일시불승인 10/22 13:00 롯데쇼핑주식회사
    pattern:
        '^\\[JBCard\\]\\s*(?<acct>\\d{4})\\s+$_amt원\\s+(?<inst>일시불|\\d{1,2}개월|체크)?\\s*'
        '$_cardWord\\s+$_d\\s+$_t\\s+(?<party>.+)\$',
  ),
  SmsRule(
    id: 'citi_card',
    institution: '씨티카드',
    kind: AccountHintKind.card,
    defaultDirection: Direction.outgoing,
    // 씨티카드(1234*56*) 홍길동님 04/24 13:45 일시불 12,300원 스타벅스
    pattern:
        '^씨티카드\\((?<acct>[\\d*]+)\\)\\s+$_holder\\s+$_d\\s+$_t\\s+$_inst\\s+$_amt원'
        '\\s+(?<party>.+)\$',
  ),
  // 롯데카드는 가맹점 이름으로 시작해서 다른 규칙보다 뒤에 둔다.
  SmsRule(
    id: 'lotte_card',
    institution: '롯데카드',
    kind: AccountHintKind.card,
    // 메가엠지씨커피 12,800원 승인 홍*동 롯데법인1234 일시불 11/10 09:27 누적723,270원
    pattern:
        '^(?<party>.+?)\\s+$_amt원\\s+(?<dirword>승인|취소)\\s+$_holder\\s+'
        '(?<acctname>롯데\\S*?)$_card4\\s+$_inst\\s+$_d\\s+$_t$_cum\$',
  ),
  SmsRule(
    id: 'lotte_card_cancel',
    institution: '롯데카드',
    kind: AccountHintKind.card,
    // 토스페이먼츠 주식회사 118,329원 취소완료 홍*동 롯데1*3* 11/06
    pattern:
        '^(?<party>.+?)\\s+$_amt원\\s+(?<dirword>취소완료)\\s+$_holder\\s+'
        '(?<acctname>롯데\\S*?)$_card4\\s+$_d(?:\\s+$_t)?\$',
  ),

  // ------------------------------------------------------------------ 앱 알림
  // 제목과 본문을 이어 붙인 형태다.
  SmsRule(
    id: 'kbstar_push',
    institution: 'KB국민은행',
    kind: AccountHintKind.bank,
    // 출금 10,000원 홍*동님 07/27 09:53 123456-**-***789 한국도로교통 체크카드출금 10,000 잔액52,980
    pattern:
        '^(?:(?:입금|출금)\\s*[\\d,]+원\\s+)?$_holder\\s+$_d\\s+$_t\\s+$_acct\\s+(?<party>.+?)\\s+'
        '(?<dirword>\\S*?(?:입금|출금))\\s*$_amt원?\\s+$_bal\$',
  ),
  SmsRule(
    id: 'hana_pay_push',
    institution: '하나카드',
    kind: AccountHintKind.card,
    // (결제) 4,500원 동네식품 / 신용(일시불,1*2*) / 11.09 15:16 / 누적이용금액 1,146,438원
    pattern:
        '^\\((?<dirword>결제|취소)\\)\\s*$_amt원\\s+(?<party>.+?)\\s*/\\s*(?:신용|체크)'
        '\\((?<inst>일시불|\\d{1,2}개월),\\s*$_card4\\)\\s*/\\s*$_d\\s+$_t'
        '(?:\\s*/\\s*누적이용금액\\s*(?<cum>[\\d,]+)원)?\$',
  ),
  SmsRule(
    id: 'tossbank_cashback_push',
    institution: '토스뱅크',
    kind: AccountHintKind.card,
    defaultDirection: Direction.outgoing,
    // 6원 캐시백 2,300원 결제 | 세븐일레븐 강동열린점 잔액 146,658원(토스뱅크 체크카드)
    pattern:
        '^(?<cashback>[\\d,]+)원\\s+캐시백\\s+$_amt원\\s+결제\\s*\\|\\s*(?<party>.+?)\\s+'
        '잔액\\s*(?<balance>[\\d,]+)원\\((?<acctname>[^)]+)\\)\$',
  ),
  SmsRule(
    id: 'toss_pay_push',
    institution: '토스',
    kind: AccountHintKind.card,
    defaultDirection: Direction.outgoing,
    // 133,500원 결제 하나카드 | 비비큐 강동밀레니얼점(일시불)
    pattern:
        '^$_amt원\\s+결제\\s+(?<acctname>\\S+?)\\s*\\|\\s*(?<party>.+?)'
        '\\((?<inst>일시불|\\d{1,2}개월)\\)\$',
  ),
  SmsRule(
    id: 'kakaobank_push',
    institution: '카카오뱅크',
    kind: AccountHintKind.bank,
    partyIsOwnAccountWhenOutgoing: true,
    // 입금 50,440원 Npay정산 → 개인사업자통장(1111) 잔액 50,440원
    pattern:
        '^(?<dirword>입금|출금)\\s*$_amt원\\s+(?<party>.+?)\\s*→\\s*(?<acctname>.+?)'
        '(?:\\((?<acct>\\d{4})\\))?\\s+$_bal\$',
  ),
  SmsRule(
    id: 'kbank_push',
    institution: '케이뱅크',
    kind: AccountHintKind.bank,
    // 케이뱅크 입금 3,000,000원 대출실행 ( 원금 ) | 생활통장(0000) 잔액 3,109,662원
    pattern:
        '^(?:케이뱅크\\s+)?(?<dirword>입금|출금)\\s*$_amt원\\s+(?<party>.+?)\\s*\\|\\s*'
        '(?<acctname>[^|]+?)\\((?<acct>\\d{4})\\)\\s+$_bal\$',
  ),
  SmsRule(
    id: 'tossbank_push',
    institution: '토스뱅크',
    kind: AccountHintKind.bank,
    partyIsOwnAccountWhenOutgoing: true,
    // 200,000원 입금 홍길동 → 내 토스뱅크 통장
    pattern:
        '^$_amt원\\s+(?<dirword>입금|출금)\\s+(?<party>.+?)\\s*→\\s*(?<acctname>.+)\$',
  ),
  SmsRule(
    id: 'shinhan_sol_push',
    institution: '신한은행',
    kind: AccountHintKind.bank,
    // 출금 1,000원 홍길동 입출금(0000) 11.09 16:41
    pattern:
        '^(?<dirword>입금|출금)\\s+$_amt원\\s+(?<party>.+?)\\s+(?<acctname>\\S+?)'
        '\\((?<acct>\\d{4})\\)\\s+$_d\\s+$_t\$',
  ),
  SmsRule(
    id: 'samsung_wallet_push',
    institution: '삼성 월렛',
    kind: AccountHintKind.card,
    defaultDirection: Direction.outgoing,
    // ₩7,100 결제 완료 씨유 휘경행복점
    pattern: '^₩\\s*$_amt\\s+결제\\s?완료\\s+(?<party>.+)\$',
  ),
]);
