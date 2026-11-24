import 'package:flutter_test/flutter_test.dart';
import 'package:gagyebu/core/local_date.dart';
import 'package:gagyebu/domain/card_due.dart';
import 'package:gagyebu/domain/enums.dart';

CardSpend spend(
  String date,
  int amount, {
  String account = 'card',
  TxType type = TxType.expense,
  bool canceled = false,
}) => CardSpend(
  accountId: account,
  type: type,
  date: LocalDate.parse(date),
  amount: amount,
  canceled: canceled,
);

void main() {
  const card = CardAccount(id: 'card', billingDay: 25);

  test('지난 결제일 다음 날부터 이번 결제일까지의 지출을 더한다', () {
    final due = cardDue(card, [
      spend('2026-10-25', 1000), // 지난 결제일 당일은 지난 기간이다
      spend('2026-10-26', 20000),
      spend('2026-11-17', 300000),
      spend('2026-11-25', 112000),
      spend('2026-11-26', 5000), // 이번 결제일 다음 날은 다음 기간이다
    ], LocalDate(2026, 11, 17));
    expect(due, CardDue(date: LocalDate(2026, 11, 25), amount: 432000));
  });

  test('오늘이 결제일이면 오늘이 다음 결제일이고, 지났으면 다음 달이다', () {
    final spends = [spend('2026-11-20', 7000), spend('2026-11-26', 9000)];
    expect(
      cardDue(card, spends, LocalDate(2026, 11, 25)),
      CardDue(date: LocalDate(2026, 11, 25), amount: 7000),
    );
    expect(
      cardDue(card, spends, LocalDate(2026, 11, 26)),
      CardDue(date: LocalDate(2026, 12, 25), amount: 9000),
    );
  });

  test('취소한 거래 · 다른 자산의 거래 · 지출이 아닌 거래는 뺀다', () {
    final due = cardDue(card, [
      spend('2026-11-01', 10000),
      spend('2026-11-02', 50000, canceled: true),
      spend('2026-11-03', 3000, account: 'other-card'),
      spend('2026-11-04', 70000, type: TxType.income),
      spend('2026-11-05', 90000, type: TxType.transfer),
    ], LocalDate(2026, 11, 17));
    expect(due.amount, 10000);
  });

  group('결제일이 그 달에 없으면 마지막 날로 당긴다', () {
    const endOfMonth = CardAccount(id: 'card', billingDay: 31);

    test('31일 → 2월 28일, 기간은 2월 1일부터', () {
      final due = cardDue(endOfMonth, [
        spend('2027-01-31', 1), // 지난 결제일(1월 31일) 당일
        spend('2027-02-01', 10),
        spend('2027-02-28', 100),
        spend('2027-03-01', 1000),
      ], LocalDate(2027, 2, 10));
      expect(due, CardDue(date: LocalDate(2027, 2, 28), amount: 110));
    });

    test('2월 결제일이 지난 뒤에는 3월 31일, 기간은 3월 1일부터', () {
      // 2월 28일에서 한 달을 빼 1월 28일로 잡으면 2월분이 두 번 잡힌다.
      final due = cardDue(endOfMonth, [
        spend('2027-02-28', 100),
        spend('2027-03-01', 1000),
        spend('2027-03-31', 10000),
      ], LocalDate(2027, 3, 1));
      expect(due, CardDue(date: LocalDate(2027, 3, 31), amount: 11000));
    });

    test('윤년 2월은 29일, 30일까지인 달은 30일', () {
      expect(
        cardDue(endOfMonth, const [], LocalDate(2028, 2, 1)).date,
        LocalDate(2028, 2, 29),
      );
      expect(
        cardDue(endOfMonth, const [], LocalDate(2026, 11, 17)).date,
        LocalDate(2026, 11, 30),
      );
    });
  });

  test('해가 바뀌는 달', () {
    final due = cardDue(const CardAccount(id: 'card', billingDay: 5), [
      spend('2026-12-05', 1),
      spend('2026-12-06', 4000),
      spend('2027-01-05', 6000),
    ], LocalDate(2026, 12, 20));
    expect(due, CardDue(date: LocalDate(2027, 1, 5), amount: 10000));
  });

  test('결제일이 1–31이 아니면 받지 않는다', () {
    expect(
      () => cardDue(
        const CardAccount(id: 'card', billingDay: 0),
        const [],
        LocalDate(2026, 11, 17),
      ),
      throwsArgumentError,
    );
  });
}
