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

  /// 수지.
  int get net => income - expense;

  /// 일평균 지출(지난 날 기준).
  int get dailyAverageExpense =>
      elapsedDays == 0 ? 0 : (expense / elapsedDays).round();

  /// 직전 기간 대비 지출 증감(원).
  int get expenseChange => expense - previousExpense;

  /// 설계안의 집계 JSON. 월별 요약 보관과 LLM 총평의 입력으로 쓴다.
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
    'daily_average_expense': dailyAverageExpense,
    'no_spend_days': noSpendDays,
    'by_category': [
      for (final c in byCategory)
        {
          'category_id': c.categoryId,
          'name': c.name,
          'amount': c.amount,
          'share': expense == 0 ? 0 : c.amount / expense,
        },
    ],
    'top_counterparties': [
      for (final c in topCounterparties)
        {'name': c.name, 'amount': c.amount, 'count': c.count},
    ],
    'largest_expenses': [
      for (final e in largestExpenses)
        {'date': e.date.toString(), 'name': e.name, 'amount': e.amount},
    ],
  };
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
