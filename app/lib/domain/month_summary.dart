import '../core/local_date.dart';
import 'month_period.dart';

/// 한 달 집계. 숫자는 전부 SQL 집계에서 나온다(LLM은 이 값을 문장으로 옮기기만 한다).
class MonthSummary {
  const MonthSummary({
    required this.period,
    required this.income,
    required this.expense,
    required this.previousIncome,
    required this.previousExpense,
    required this.transactionCount,
    required this.byCategory,
    required this.topCounterparties,
    required this.largestExpenses,
    required this.dailyExpense,
    required this.noSpendDays,
    required this.elapsedDays,
    this.fixedExpense = 0,
    this.budget,
  });

  final MonthPeriod period;

  /// 총수입 · 총지출(원). 이체와 취소된 거래는 뺀다.
  final int income;
  final int expense;

  /// 직전 기간의 총수입 · 총지출.
  final int previousIncome;
  final int previousExpense;

  final int transactionCount;

  /// 지출 분류별 합계. 금액이 큰 순서.
  final List<CategoryTotal> byCategory;

  /// 지출 상대방 상위 5곳.
  final List<CounterpartyTotal> topCounterparties;

  /// 큰 지출 상위 5건.
  final List<LargeExpense> largestExpenses;

  /// 날짜별 지출 합계.
  final Map<LocalDate, int> dailyExpense;

  /// 지출이 없던 날 수(오늘까지 지난 날 가운데).
  final int noSpendDays;

  /// 기간에서 오늘까지 지난 날 수. 지난 기간이면 전체 일수.
  final int elapsedDays;

  /// 고정 지출: 반복 거래가 만든 지출의 합. 기본 집계(`LedgerRepository.monthSummary`)는
  /// 이 값을 채우지 않는다. `SummaryRepository.monthSummary`가 채운다.
  final int fixedExpense;

  /// 전체 예산 대비. 그 달에 전체 예산을 정하지 않았으면 null. [fixedExpense]처럼
  /// `SummaryRepository.monthSummary`가 채운다.
  final MonthBudget? budget;

  /// 수지.
  int get net => income - expense;

  /// 일평균 지출(지난 날 기준).
  int get dailyAverageExpense =>
      elapsedDays == 0 ? 0 : (expense / elapsedDays).round();

  /// 직전 기간 대비 지출 증감(원).
  int get expenseChange => expense - previousExpense;

  /// 고정 지출과 예산 대비를 채운 집계.
  MonthSummary withExtras({required int fixedExpense, MonthBudget? budget}) =>
      MonthSummary(
        period: period,
        income: income,
        expense: expense,
        previousIncome: previousIncome,
        previousExpense: previousExpense,
        transactionCount: transactionCount,
        byCategory: byCategory,
        topCounterparties: topCounterparties,
        largestExpenses: largestExpenses,
        dailyExpense: dailyExpense,
        noSpendDays: noSpendDays,
        elapsedDays: elapsedDays,
        fixedExpense: fixedExpense,
        budget: budget,
      );

  /// 집계 JSON(`docs/SPEC.md` 7.10의 "데이터"). `monthly_summaries.stats`에 보관하고
  /// 총평의 입력으로 쓴다. 총평은 여기에 있는 숫자만 말할 수 있다.
  ///
  /// 값이 같으면 글자도 같아야 `data_hash`가 흔들리지 않는다. 그래서 비중은 소수 넷째
  /// 자리에서 끊고, 분류의 ID처럼 기기마다 다를 수 있는 것은 넣지 않는다.
  Map<String, Object?> toStatsJson() => {
    'month': period.key,
    'from': period.start.toString(),
    'to': period.last.toString(),
    'income': income,
    'expense': expense,
    'net': net,
    'previous_income': previousIncome,
    'previous_expense': previousExpense,
    'transaction_count': transactionCount,
    'by_category': [
      for (final c in byCategory)
        {
          'name': c.name,
          'amount': c.amount,
          'ratio': _ratio(c.amount, expense),
        },
    ],
    'budget': budget == null
        ? null
        : {'amount': budget!.amount, 'spent': budget!.spent},
    'largest': [
      for (final e in largestExpenses)
        {'date': e.date.toString(), 'name': e.name, 'amount': e.amount},
    ],
    'counterparties': [
      for (final c in topCounterparties)
        {'name': c.name, 'amount': c.amount, 'count': c.count},
    ],
    'fixed_expense': fixedExpense,
    'daily_average': dailyAverageExpense,
    'no_spend_days': noSpendDays,
  };
}

/// [part]가 [whole]에서 차지하는 비중(0–1, 소수 넷째 자리까지).
double _ratio(int part, int whole) =>
    whole <= 0 ? 0 : (part / whole * 10000).round() / 10000;

/// 예산과 쓴 돈(`docs/SPEC.md` 7.11의 진행 계산).
class MonthBudget {
  const MonthBudget({required this.amount, required this.spent});

  /// 정한 예산(원, 0 이상).
  final int amount;

  /// 그 달의 지출. 취소된 거래와 이체는 들어 있지 않다.
  final int spent;

  /// 남은 금액. 넘겼으면 음수다.
  int get remaining => amount - spent;

  bool get isOver => spent > amount;

  /// 넘긴 금액. 넘기지 않았으면 0.
  int get overBy => isOver ? spent - amount : 0;

  /// 쓴 비율. 넘기면 1보다 크다. 예산이 0원이면 한 푼이라도 썼을 때 다 쓴 것으로 본다.
  double get ratio {
    if (amount <= 0) return spent > 0 ? 1 : 0;
    return spent / amount;
  }

  @override
  bool operator ==(Object other) =>
      other is MonthBudget && other.amount == amount && other.spent == spent;

  @override
  int get hashCode => Object.hash(amount, spent);

  @override
  String toString() => 'MonthBudget($spent / $amount)';
}

/// 한 달의 수입 · 지출 합계. 여러 달의 추이를 그릴 때 쓴다.
class MonthTotal {
  const MonthTotal({
    required this.period,
    required this.income,
    required this.expense,
  });

  final MonthPeriod period;
  final int income;
  final int expense;
}

/// 수입이나 지출 한쪽만 본 한 달의 내용. 통계 화면이 지출 · 수입을 바꿔 가며 그린다.
class FlowBreakdown {
  const FlowBreakdown({
    required this.period,
    required this.total,
    required this.byCategory,
    required this.daily,
    required this.topCounterparties,
    required this.largest,
  });

  /// 집계의 지출 쪽.
  factory FlowBreakdown.expenseOf(MonthSummary summary) => FlowBreakdown(
    period: summary.period,
    total: summary.expense,
    byCategory: summary.byCategory,
    daily: summary.dailyExpense,
    topCounterparties: summary.topCounterparties,
    largest: summary.largestExpenses,
  );

  final MonthPeriod period;
  final int total;

  /// 분류별 합계. 금액이 큰 순서.
  final List<CategoryTotal> byCategory;

  /// 날짜별 합계.
  final Map<LocalDate, int> daily;

  /// 상대방 상위 5곳.
  final List<CounterpartyTotal> topCounterparties;

  /// 큰 거래 상위 5건.
  final List<LargeExpense> largest;
}

class CategoryTotal {
  const CategoryTotal({
    required this.categoryId,
    required this.name,
    required this.amount,
  });

  /// 분류가 없는 거래의 합계면 null.
  final String? categoryId;
  final String name;
  final int amount;
}

class CounterpartyTotal {
  const CounterpartyTotal({
    required this.name,
    required this.amount,
    required this.count,
  });

  final String name;
  final int amount;
  final int count;
}

class LargeExpense {
  const LargeExpense({
    required this.transactionId,
    required this.date,
    required this.name,
    required this.amount,
  });

  final String transactionId;
  final LocalDate date;
  final String name;
  final int amount;
}
