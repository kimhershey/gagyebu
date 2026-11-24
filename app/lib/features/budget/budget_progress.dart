import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../data/db/database.dart';
import '../../data/repositories/budget_repository.dart';
import '../../domain/enums.dart';
import '../categories/category_tree.dart';

/// 예산 한 줄(전체 또는 분류 하나)의 진행.
class BudgetLine {
  const BudgetLine({
    required this.categoryId,
    required this.name,
    required this.budget,
    required this.spent,
    this.icon,
    this.colorIndex,
    this.isChild = false,
  });

  /// null이면 전체 예산이다.
  final String? categoryId;
  final String name;

  /// 정한 금액과 그 달에 쓴 돈(원). 취소한 거래와 이체는 쓴 돈에 들지 않는다.
  final int budget;
  final int spent;

  /// 분류의 아이콘 이름과 색의 자리. 전체 예산에는 없다.
  final String? icon;
  final int? colorIndex;

  /// 소분류의 예산인지.
  final bool isChild;

  /// 남은 돈. 넘겼으면 음수다.
  int get remaining => budget - spent;

  bool get isOver => spent > budget;

  /// 넘긴 금액. 넘기지 않았으면 0.
  int get overBy => isOver ? spent - budget : 0;

  /// 예산 가운데 쓴 비율. 예산이 0원이면 한 푼이라도 쓴 순간 다 쓴 것으로 본다.
  double get ratio {
    if (budget <= 0) return spent > 0 ? 1 : 0;
    return spent / budget;
  }
}

/// 한 달의 예산 진행(`docs/SPEC.md` 7.11).
class BudgetProgress {
  const BudgetProgress({
    required this.month,
    required this.total,
    required this.categories,
    required this.categorySum,
  });

  /// 'YYYY-MM'
  final String month;

  /// 전체 예산. 정하지 않았으면 null.
  final BudgetLine? total;

  /// 분류별 예산. 분류의 순서대로, 소분류는 그 대분류 바로 아래에 온다.
  final List<BudgetLine> categories;

  /// 분류 예산의 합. 대분류에도 예산이 있는 소분류의 예산은 대분류에 든 것으로 보고
  /// 더하지 않는다.
  final int categorySum;

  bool get isEmpty => total == null && categories.isEmpty;

  /// 분류 예산의 합이 전체 예산을 넘긴 금액. 넘지 않았거나 전체 예산이 없으면 0.
  int get overAllocated {
    final limit = total?.budget;
    if (limit == null || categorySum <= limit) return 0;
    return categorySum - limit;
  }
}

/// 예산과 그 달의 지출로 진행을 계산한다.
///
/// [budgets]는 한 달의 예산(겹친 행은 이미 하나로 고른 것), [expenseByCategory]는
/// 분류별 지출(키가 null이면 분류 없음)이다. 대분류의 쓴 돈에는 소분류에 쓴 돈이 든다.
/// 지워진 분류와 수입 분류의 예산은 보이지 않는다.
BudgetProgress computeBudgetProgress({
  required String month,
  required List<BudgetRow> budgets,
  required List<CategoryRow> categories,
  required int totalExpense,
  required Map<String?, int> expenseByCategory,
}) {
  final amountOf = <String?, int>{
    for (final row in budgets)
      if (row.month == month) row.categoryId: row.amount,
  };
  final lines = <BudgetLine>[];
  var sum = 0;
  for (final group in buildCategoryGroups(categories, CategoryKind.expense)) {
    final root = group.category;
    final rootBudget = amountOf[root.id];
    if (rootBudget != null) {
      var spent = expenseByCategory[root.id] ?? 0;
      for (final child in group.children) {
        spent += expenseByCategory[child.category.id] ?? 0;
      }
      lines.add(
        BudgetLine(
          categoryId: root.id,
          name: root.name,
          icon: root.icon,
          colorIndex: group.colorIndex,
          budget: rootBudget,
          spent: spent,
        ),
      );
      sum += rootBudget;
    }
    for (final child in group.children) {
      final budget = amountOf[child.category.id];
      if (budget == null) continue;
      lines.add(
        BudgetLine(
          categoryId: child.category.id,
          name: child.category.name,
          icon: child.category.icon,
          colorIndex: child.colorIndex,
          budget: budget,
          spent: expenseByCategory[child.category.id] ?? 0,
          isChild: true,
        ),
      );
      if (rootBudget == null) sum += budget;
    }
  }
  final total = amountOf[null];
  return BudgetProgress(
    month: month,
    total: amountOf.containsKey(null)
        ? BudgetLine(
            categoryId: null,
            name: '전체 예산',
            budget: total!,
            spent: totalExpense,
          )
        : null,
    categories: lines,
    categorySum: sum,
  );
}

/// 보고 있는 달의 예산.
final monthBudgetsProvider = StreamProvider<List<BudgetRow>>(
  (ref) => ref
      .watch(budgetRepositoryProvider)
      .watchBudgets(
        ref.watch(ledgerIdProvider),
        ref.watch(selectedPeriodProvider).key,
      ),
);

/// 보고 있는 달의 앞 달 예산. '지난달 예산 가져오기'를 권할지 정하는 데 쓴다.
final previousMonthBudgetsProvider = StreamProvider<List<BudgetRow>>(
  (ref) => ref
      .watch(budgetRepositoryProvider)
      .watchBudgets(
        ref.watch(ledgerIdProvider),
        ref.watch(selectedPeriodProvider).previous.key,
      ),
);

/// 보고 있는 달의 예산 진행. 예산 화면과 홈이 함께 쓴다.
///
/// 쓴 돈은 월 시작일을 반영한 그 달의 지출이다(`monthSummaryProvider`와 같은 기간).
final budgetProgressProvider = Provider<AsyncValue<BudgetProgress>>((ref) {
  final month = ref.watch(selectedPeriodProvider).key;
  final budgets = ref.watch(monthBudgetsProvider);
  final categories = ref.watch(categoriesProvider);
  final summary = ref.watch(monthSummaryProvider);

  for (final value in <AsyncValue<Object?>>[budgets, categories, summary]) {
    if (value.hasError && !value.hasValue) {
      return AsyncValue.error(value.error!, value.stackTrace!);
    }
  }
  // 달을 넘기는 동안에는 앞 달의 값이 잠깐 남아 있다. 다른 달의 지출과 섞지 않게 새 값이
  // 올 때까지 기다린다.
  if (budgets.isLoading || summary.isLoading || !categories.hasValue) {
    return const AsyncValue.loading();
  }
  final monthSummary = summary.requireValue;
  if (monthSummary.period.key != month) return const AsyncValue.loading();
  return AsyncValue.data(
    computeBudgetProgress(
      month: month,
      budgets: budgets.requireValue,
      categories: categories.requireValue,
      totalExpense: monthSummary.expense,
      expenseByCategory: {
        for (final c in monthSummary.byCategory) c.categoryId: c.amount,
      },
    ),
  );
});
