import '../core/local_date.dart';
import 'enums.dart';

/// 결제 예정을 셀 카드 자산. 도메인이 데이터 층의 행 타입을 보지 않게 필요한 값만 둔다.
class CardAccount {
  const CardAccount({required this.id, required this.billingDay});

  final String id;

  /// 결제일(1–31). 그 달에 없는 날이면 마지막 날로 당긴다.
  final int billingDay;
}

/// 결제 예정을 세는 데 쓰는 거래의 값.
class CardSpend {
  const CardSpend({
    required this.accountId,
    required this.type,
    required this.date,
    required this.amount,
    this.canceled = false,
  });

  final String accountId;
  final TxType type;
  final LocalDate date;

  /// 원 단위.
  final int amount;
  final bool canceled;
}

/// 카드의 다음 결제일과 그날 빠져나갈 것으로 보이는 금액.
class CardDue {
  const CardDue({required this.date, required this.amount});

  final LocalDate date;
  final int amount;

  @override
  bool operator ==(Object other) =>
      other is CardDue && other.date == date && other.amount == amount;

  @override
  int get hashCode => Object.hash(date, amount);

  @override
  String toString() => 'CardDue($date, $amount)';
}

/// [year]년 [month]월의 결제일. 그 달에 없는 날(31일 → 2월)이면 마지막 날이다.
LocalDate billingDateIn(int year, int month, int billingDay) {
  final last = LocalDate.daysInMonth(year, month);
  return LocalDate(year, month, billingDay > last ? last : billingDay);
}

/// [today] 기준으로 [account]의 다음 결제일과 결제 예정액을 센다(`docs/SPEC.md` 7.12).
///
/// 예정액은 지난 결제일 다음 날부터 이번 결제일까지 그 카드로 쓴 지출의 합이다.
/// 취소한 거래는 뺀다. 할부도 쓴 날에 전액을 잡는다. 카드사의 실제 청구 기간과는 다를 수
/// 있는 단순한 규칙이다.
CardDue cardDue(
  CardAccount account,
  Iterable<CardSpend> transactions,
  LocalDate today,
) {
  if (account.billingDay < 1 || account.billingDay > 31) {
    throw ArgumentError.value(account.billingDay, 'billingDay', '1–31이어야 한다');
  }
  // 이번 결제일: 오늘이거나 오늘 뒤에 오는 가장 가까운 결제일.
  var due = billingDateIn(today.year, today.month, account.billingDay);
  if (due < today) {
    final next = LocalDate(today.year, today.month, 1).addMonths(1);
    due = billingDateIn(next.year, next.month, account.billingDay);
  }
  // 지난 결제일은 날짜를 한 달 당겨서가 아니라 앞 달의 결제일로 다시 센다.
  // (2월 28일에서 한 달을 빼면 1월 28일이 되어 31일 결제 카드의 기간이 어긋난다.)
  final before = LocalDate(due.year, due.month, 1).addMonths(-1);
  final previous = billingDateIn(before.year, before.month, account.billingDay);

  var amount = 0;
  for (final tx in transactions) {
    if (tx.accountId != account.id) continue;
    if (tx.type != TxType.expense || tx.canceled) continue;
    if (tx.date > previous && tx.date <= due) amount += tx.amount;
  }
  return CardDue(date: due, amount: amount);
}
