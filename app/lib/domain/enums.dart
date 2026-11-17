/// 서버와 기기가 함께 쓰는 열거형. [code]가 DB와 JSON에 저장되는 값이다.
library;

/// 거래 종류.
enum TxType {
  /// 출금 · 지출
  expense('expense'),

  /// 입금 · 수입
  income('income'),

  /// 내 자산 사이의 이체
  transfer('transfer');

  const TxType(this.code);
  final String code;

  static TxType fromCode(String code) =>
      values.firstWhere((v) => v.code == code);
}

/// 자산 종류.
enum AccountKind {
  cash('cash', '현금'),
  bank('bank', '은행 계좌'),
  creditCard('credit_card', '신용카드'),
  checkCard('check_card', '체크카드'),
  pay('pay', '간편결제'),
  other('other', '기타');

  const AccountKind(this.code, this.label);
  final String code;

  /// 화면에 보이는 이름.
  final String label;

  static AccountKind fromCode(String code) =>
      values.firstWhere((v) => v.code == code);
}

/// 분류 종류.
enum CategoryKind {
  expense('expense'),
  income('income');

  const CategoryKind(this.code);
  final String code;

  static CategoryKind fromCode(String code) =>
      values.firstWhere((v) => v.code == code);
}

/// 거래가 만들어진 경로.
enum TxSource {
  /// 직접 입력
  manual('manual'),

  /// 한 줄 문장
  nl('nl'),

  /// 붙여넣기
  paste('paste'),

  /// 이미지
  image('image'),

  /// 다른 앱의 공유
  share('share'),

  /// 파일 가져오기
  import('import'),

  /// 반복 거래
  recurring('recurring');

  const TxSource(this.code);
  final String code;

  static TxSource fromCode(String code) =>
      values.firstWhere((v) => v.code == code);
}

/// 거래 확인 상태.
enum TxStatus {
  confirmed('confirmed'),
  needsReview('needs_review');

  const TxStatus(this.code);
  final String code;

  static TxStatus fromCode(String code) =>
      values.firstWhere((v) => v.code == code);
}
