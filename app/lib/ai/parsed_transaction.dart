/// 원문(문자 · 붙여넣기 · 문장 · 이미지)에서 읽어 낸 거래 초안.
///
/// 정규식 규칙과 LLM이 같은 형태를 만든다. 초안은 검토 카드에서 사용자가 확인한 뒤에
/// 거래로 저장된다.
library;

import '../core/local_date.dart';

/// 돈이 움직인 방향.
enum Direction {
  /// 입금 · 수입
  incoming('in'),

  /// 출금 · 결제 · 지출
  outgoing('out'),

  /// 내 자산 사이의 이체
  transfer('transfer');

  const Direction(this.code);

  /// JSON에 쓰는 값.
  final String code;

  static Direction? fromCode(String? code) {
    for (final d in values) {
      if (d.code == code) return d;
    }
    return null;
  }
}

/// 원문에 보이는 자산의 종류.
enum AccountHintKind { bank, card }

/// 사용자가 검토 카드에서 눈여겨봐야 할 점.
enum ParseWarning {
  /// 원문에 연도가 없어 가장 가까운 과거 날짜로 채웠다.
  yearInferred,

  /// 원문에 날짜가 없어 붙여넣은 날로 채웠다.
  dateFromNow,

  /// 해외 결제라 원화 금액을 사용자가 넣어야 한다.
  needsKrwAmount,

  /// 카드대금 출금으로 보인다. 지출이 아니라 이체로 처리해야 이중 계상이 없다.
  possibleCardPayment,

  /// 금액에 '원'이 없었다. 잔액 · 누적과 헷갈렸을 수 있다.
  amountWithoutUnit,

  /// 상대방(가맹점 · 보낸 사람)을 원문에서 찾지 못했다.
  noCounterparty,

  /// 모델이 고른 방향이 원문의 낱말(입금 · 출금 · 승인)과 어긋난다.
  directionMismatch,
}

/// 거래 초안 한 건.
class ParsedTransaction {
  const ParsedTransaction({
    required this.date,
    required this.direction,
    required this.raw,
    required this.ruleId,
    this.time,
    this.amount,
    this.institution,
    this.accountKind,
    this.accountText,
    this.accountHint,
    this.counterparty,
    this.installmentMonths,
    this.balanceAfter,
    this.cumulative,
    this.isCancel = false,
    this.currency,
    this.originalAmount,
    this.memo,
    this.category,
    this.warnings = const {},
  });

  final LocalDate date;

  /// 'HH:mm'. 원문에 없으면 null.
  final String? time;

  /// 원 단위 양의 정수. 해외 결제처럼 원화 금액을 모르면 null.
  final int? amount;

  final Direction direction;

  /// 금융사 이름(예: '신한카드', 'KB국민은행').
  final String? institution;
  final AccountHintKind? accountKind;

  /// 원문의 카드 · 계좌 표기(예: '신한카드(1234)').
  final String? accountText;

  /// 등록한 자산과 맞춰 볼 식별 문구(예: '1234').
  final String? accountHint;

  /// 상대방. 입금이면 보낸 쪽, 출금이면 받는 쪽.
  final String? counterparty;

  /// 할부 개월 수. 일시불이면 null.
  final int? installmentMonths;

  /// 거래 후 잔액.
  final int? balanceAfter;

  /// 카드 누적 사용액. 저장하지 않고 금액과 구분하는 데만 쓴다.
  final int? cumulative;

  /// 승인취소 · 환불이면 true. 금액은 양수로 둔다.
  final bool isCancel;

  /// 해외 결제의 통화(ISO 4217).
  final String? currency;

  /// 해외 결제의 원래 금액.
  final num? originalAmount;

  final String? memo;

  /// 모델이 고른 분류 이름. 사용자의 분류 목록에 있는 이름만 온다. 규칙은 채우지 않는다.
  final String? category;

  /// 이 초안을 만든 규칙의 ID. 모델이 만들었으면 'llm:<모델 이름>'이다.
  final String ruleId;

  /// 모델이 만든 초안이면 그 모델의 이름.
  String? get modelName =>
      ruleId.startsWith('llm:') ? ruleId.substring(4) : null;

  /// 초안의 근거가 된 원문.
  final String raw;

  final Set<ParseWarning> warnings;

  /// 모델 출력 스키마와 같은 키를 쓴다(설계안 "출력 형식").
  Map<String, Object?> toJson() => {
    'date': date.toString(),
    'time': time,
    'amount': amount,
    'direction': direction.code,
    'institution': institution,
    'account': accountText,
    'account_hint': accountHint,
    'counterparty': counterparty,
    'installment_months': installmentMonths,
    'balance_after': balanceAfter,
    'is_cancel': isCancel,
    'currency': currency,
    'original_amount': originalAmount,
    'memo': memo,
    'category': category,
    'rule': ruleId,
    'warnings': [for (final w in warnings) w.name],
  };

  @override
  String toString() => 'ParsedTransaction(${toJson()})';
}

/// 붙여넣은 원문에서 잘라 낸 한 덩어리의 판정.
sealed class ParsedItem {
  const ParsedItem(this.raw);

  /// 판정의 대상이 된 원문.
  final String raw;
}

/// 거래로 읽었다.
class TransactionItem extends ParsedItem {
  TransactionItem(this.transaction) : super(transaction.raw);

  final ParsedTransaction transaction;
}

/// 돈이 움직이지 않은 안내문이라 기록하지 않는다.
class NonTransactionItem extends ParsedItem {
  const NonTransactionItem(super.raw, this.reason);

  final NonTransactionReason reason;
}

/// 아는 형식이 아니다. 기기 내 LLM이 있으면 넘기고, 없으면 직접 입력으로 넘긴다.
class UnrecognizedItem extends ParsedItem {
  const UnrecognizedItem(super.raw);
}

/// 거래가 아니라고 본 이유.
enum NonTransactionReason {
  /// 인증번호 · 본인확인
  verification,

  /// 광고
  advertisement,

  /// 출금 · 결제 예정 안내
  scheduled,

  /// 결제금액 · 청구 안내
  statement,

  /// 대출 실행 · 납입일 안내
  loanNotice,

  /// 출금 · 결제 실패, 승인 거절
  failed,

  /// 카드사가 대금을 받았다는 안내. 실제 출금은 은행 쪽 문자로 온다.
  cardPaymentReceived,

  /// 기기 내 모델이 거래가 아닌 글로 봤다.
  judgedByModel,
}
