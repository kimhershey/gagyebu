/// 입금 · 출금 같은 낱말이 들어 있지만 돈이 움직이지 않은 안내문을 거른다.
library;

import '../parsed_transaction.dart';

/// 거래가 아닌 안내문이면 그 이유를, 아니면 null을 돌려준다.
///
/// [collapsed]는 줄바꿈을 공백으로 접은 원문이다.
NonTransactionReason? detectNonTransaction(String collapsed) {
  for (final (pattern, reason) in _patterns) {
    if (pattern.hasMatch(collapsed)) return reason;
  }
  return null;
}

final List<(RegExp, NonTransactionReason)> _patterns = [
  (
    RegExp(r'인증\s?번호|본인\s?확인|인증\s?코드|일회용\s?비밀번호|OTP'),
    NonTransactionReason.verification,
  ),
  (
    RegExp(r'\(광고\)|\[광고\]|무료\s?수신\s?거부|무료\s?거부|수신\s?거부'),
    NonTransactionReason.advertisement,
  ),
  (
    RegExp(
      r'(?:출금|결제|납부|이체|인출|청구)\s?(?:예정|할\s?예정|될\s?예정)'
      r'|자동이체\s?예정',
    ),
    NonTransactionReason.scheduled,
  ),
  (
    RegExp(r'결제\s?금액.{0,24}기준|결제\s?예정\s?금액|청구\s?금액|이용\s?대금\s?명세서|명세서'),
    NonTransactionReason.statement,
  ),
  (
    RegExp(r'납입일|납입\s?예정|상환일|이자\s?납입|대출이\s?실행|대출금\s?:|대출\s?만기'),
    NonTransactionReason.loanNotice,
  ),
  (
    RegExp(
      r'(?:출금|결제|이체|승인|납부)\s?(?:실패|거절|불가)'
      r'|한도\s?초과|잔액\s?부족|잔액이\s?부족',
    ),
    NonTransactionReason.failed,
  ),
  (
    // 카드사가 보낸 '입금되었습니다'는 카드대금을 받았다는 안내다.
    RegExp(r'카드\]?.{0,40}입금\s?(?:되었습니다|완료|처리)'),
    NonTransactionReason.cardPaymentReceived,
  ),
];
