import 'package:flutter_test/flutter_test.dart';
import 'package:gagyebu/core/local_date.dart';
import 'package:gagyebu/domain/month_period.dart';
import 'package:gagyebu/domain/month_summary.dart';

MonthSummary _summary({int expense = 74500, int income = 3000000}) =>
    MonthSummary(
      period: MonthPeriod(2026, 11),
      income: income,
      expense: expense,
      previousIncome: 0,
      previousExpense: 40000,
      transactionCount: 5,
      byCategory: const [
        CategoryTotal(categoryId: 'c1', name: '쇼핑', amount: 50000),
        CategoryTotal(categoryId: 'c2', name: '식비', amount: 20000),
        CategoryTotal(categoryId: null, name: '분류 없음', amount: 4500),
      ],
      topCounterparties: const [
        CounterpartyTotal(name: '쿠팡', amount: 50000, count: 1),
      ],
      largestExpenses: [
        LargeExpense(
          transactionId: 't1',
          date: LocalDate(2026, 11, 5),
          name: '쿠팡',
          amount: 50000,
        ),
      ],
      dailyExpense: {LocalDate(2026, 11, 5): 58000},
      noSpendDays: 14,
      elapsedDays: 17,
    );

void main() {
  group('MonthBudget: 예산 진행 계산', () {
    test('남은 금액은 예산에서 쓴 돈을 뺀 값이다', () {
      const budget = MonthBudget(amount: 600000, spent: 160600);
      expect(budget.remaining, 439400);
      expect(budget.isOver, isFalse);
      expect(budget.overBy, 0);
      expect(budget.ratio, closeTo(0.2677, 0.0001));
    });

    test('넘기면 넘긴 금액을 알려 주고 비율은 1을 넘는다', () {
      const budget = MonthBudget(amount: 100000, spent: 112000);
      expect(budget.isOver, isTrue);
      expect(budget.overBy, 12000);
      expect(budget.remaining, -12000);
      expect(budget.ratio, closeTo(1.12, 0.0001));
    });

    test('딱 맞게 쓰면 넘긴 것이 아니다', () {
      const budget = MonthBudget(amount: 100000, spent: 100000);
      expect(budget.isOver, isFalse);
      expect(budget.remaining, 0);
      expect(budget.ratio, 1);
    });

    test('예산이 0원이면 쓴 돈이 있을 때 다 쓴 것으로 본다', () {
      expect(const MonthBudget(amount: 0, spent: 0).ratio, 0);
      expect(const MonthBudget(amount: 0, spent: 0).isOver, isFalse);
      expect(const MonthBudget(amount: 0, spent: 500).ratio, 1);
      expect(const MonthBudget(amount: 0, spent: 500).overBy, 500);
    });
  });

  group('MonthSummary', () {
    test('고정 지출과 예산을 주지 않으면 0과 null이다(기존 생성자와 맞는다)', () {
      final s = _summary();
      expect(s.fixedExpense, 0);
      expect(s.budget, isNull);
    });

    test('withExtras는 고정 지출과 예산만 바꾼다', () {
      final base = _summary();
      final s = base.withExtras(
        fixedExpense: 30000,
        budget: const MonthBudget(amount: 100000, spent: 74500),
      );
      expect(s.fixedExpense, 30000);
      expect(s.budget, const MonthBudget(amount: 100000, spent: 74500));
      expect(s.expense, base.expense);
      expect(s.byCategory, same(base.byCategory));
      expect(s.dailyExpense, same(base.dailyExpense));
      expect(s.noSpendDays, base.noSpendDays);
      expect(s.elapsedDays, base.elapsedDays);
    });

    test('집계 JSON에는 설계서 7.10의 키가 모두 있다', () {
      final json = _summary()
          .withExtras(
            fixedExpense: 30000,
            budget: const MonthBudget(amount: 100000, spent: 74500),
          )
          .toStatsJson();
      expect(
        json.keys,
        containsAll([
          'income',
          'expense',
          'net',
          'previous_expense',
          'by_category',
          'budget',
          'largest',
          'counterparties',
          'fixed_expense',
          'daily_average',
          'no_spend_days',
        ]),
      );
      expect(json['income'], 3000000);
      expect(json['expense'], 74500);
      expect(json['net'], 2925500);
      expect(json['previous_expense'], 40000);
      expect(json['fixed_expense'], 30000);
      expect(json['budget'], {'amount': 100000, 'spent': 74500});
      expect(json['daily_average'], (74500 / 17).round());
      expect(json['no_spend_days'], 14);
      expect(json['by_category'], [
        {'name': '쇼핑', 'amount': 50000, 'ratio': 0.6711},
        {'name': '식비', 'amount': 20000, 'ratio': 0.2685},
        {'name': '분류 없음', 'amount': 4500, 'ratio': 0.0604},
      ]);
      expect(json['largest'], [
        {'date': '2026-11-05', 'name': '쿠팡', 'amount': 50000},
      ]);
      expect(json['counterparties'], [
        {'name': '쿠팡', 'amount': 50000, 'count': 1},
      ]);
    });

    test('예산을 정하지 않은 달의 집계 JSON에서 budget은 null이다', () {
      final json = _summary().toStatsJson();
      expect(json.containsKey('budget'), isTrue);
      expect(json['budget'], isNull);
      expect(json['fixed_expense'], 0);
    });

    test('지출이 없으면 비중은 0이다', () {
      final json = _summary(expense: 0).toStatsJson();
      final first = (json['by_category']! as List).first as Map;
      expect(first['ratio'], 0);
    });

    test('FlowBreakdown.expenseOf는 집계의 지출 쪽을 그대로 옮긴다', () {
      final s = _summary();
      final flow = FlowBreakdown.expenseOf(s);
      expect(flow.period, s.period);
      expect(flow.total, s.expense);
      expect(flow.byCategory, same(s.byCategory));
      expect(flow.daily, same(s.dailyExpense));
      expect(flow.topCounterparties, same(s.topCounterparties));
      expect(flow.largest, same(s.largestExpenses));
    });
  });
}
