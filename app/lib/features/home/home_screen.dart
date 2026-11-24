import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/providers.dart';
import '../../app/theme/tokens.dart';
import '../../core/breakpoints.dart';
import '../../core/formatters.dart';
import '../../data/repositories/ledger_repository.dart';
import '../../data/repositories/summary_repository.dart';
import '../../domain/enums.dart';
import '../../domain/month_summary.dart';
import '../common/summary_parts.dart';
import '../common/widgets.dart';
import '../onboarding/onboarding_card.dart';
import '../transactions/transaction_tile.dart';

/// 홈: 고른 달의 요약(`docs/SPEC.md` 7.9).
///
/// 위에서부터 첫 실행 안내, 이번 달 지출(가장 크게)과 수입 · 수지, 예산 진행, 확인 필요,
/// 분류별 지출 상위 5, 최근 내역 5건. 휴대폰은 한 줄로 쌓고 PC는 두 칸으로 나눈다.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(monthSummaryProvider);
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          // 보여 줄 것이 없으면 스스로 사라진다. 집계를 못 읽어도 안내는 보여야 하므로
          // 집계 바깥에 둔다.
          const OnboardingCard(),
          const Align(alignment: Alignment.centerLeft, child: MonthSwitcher()),
          const SizedBox(height: 8),
          LoadBody<MonthSummary>(
            value: summary,
            what: '이 달의 집계를',
            onRetry: () => ref.invalidate(monthSummaryProvider),
            builder: (s) => _HomeBody(summary: s),
          ),
        ],
      ),
    );
  }
}

class _HomeBody extends ConsumerWidget {
  const _HomeBody({required this.summary});

  final MonthSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wide = WindowSize.of(context).isExpanded;
    final recent = ref.watch(monthTransactionsProvider);
    final budget = ref.watch(totalBudgetProgressProvider).value;
    final needsReview = ref.watch(needsReviewCountProvider).value ?? 0;
    final current = summary.period.contains(ref.watch(todayProvider));
    // 이체만 있는 달도 내역은 있는 달이다. 집계의 건수가 아니라 목록으로 판단한다.
    final empty = recent.hasValue && recent.value!.isEmpty;

    const gap = SizedBox(height: 12);
    final overview = <Widget>[
      _Hero(summary: summary, current: current),
      if (budget != null) ...[
        gap,
        _BudgetCard(
          budget: budget,
          // 지난 달이면 남은 날이 없다. 오지 않은 달이면 한 달이 다 남았다.
          daysLeft: summary.period.days - summary.elapsedDays,
        ),
      ],
      if (needsReview > 0) ...[gap, _NeedsReview(count: needsReview)],
      if (!empty) ...[gap, _CategoryCard(summary: summary)],
    ];
    final side = empty ? const _EmptyCard() : _RecentCard(transactions: recent);

    if (!wide) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [...overview, gap, side],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 5,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: overview,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(flex: 4, child: side),
      ],
    );
  }
}

/// 이번 달 지출을 가장 크게, 그 아래에 수입 · 수지와 한 줄 요약들.
class _Hero extends StatelessWidget {
  const _Hero({required this.summary, required this.current});

  final MonthSummary summary;

  /// 오늘이 든 달을 보고 있는지.
  final bool current;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final sub = theme.colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            current ? '이번 달 지출' : '${summary.period.month}월 지출',
            style: theme.textTheme.bodyMedium?.copyWith(color: sub),
          ),
          const SizedBox(height: 2),
          // 좁은 화면이나 큰 글자에서 금액이 잘리지 않게 줄여 그린다.
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              won(summary.expense),
              key: const ValueKey('total-expense'),
              maxLines: 1,
              style: tokens.amountStyle(
                TextStyle(
                  fontSize: tokens.bigAmountSize,
                  fontWeight: FontWeight.w600,
                  height: 1.15,
                  letterSpacing: -0.5,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 20,
            runSpacing: 4,
            children: [
              _LabeledAmount(
                label: '수입',
                value: won(summary.income),
                color: tokens.income,
                valueKey: const ValueKey('total-income'),
              ),
              _LabeledAmount(
                label: '수지',
                value: signedWon(summary.net),
                color: theme.colorScheme.onSurface,
                valueKey: const ValueKey('total-net'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _Insights(summary: summary),
        ],
      ),
    );
  }
}

class _LabeledAmount extends StatelessWidget {
  const _LabeledAmount({
    required this.label,
    required this.value,
    required this.color,
    required this.valueKey,
  });

  final String label;
  final String value;
  final Color color;
  final Key valueKey;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            value,
            key: valueKey,
            maxLines: 1,
            style: context.tokens
                .amountStyle(theme.textTheme.bodyLarge)
                .copyWith(color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _Insights extends StatelessWidget {
  const _Insights({required this.summary});

  final MonthSummary summary;

  @override
  Widget build(BuildContext context) {
    final change = summary.expenseChange;
    final String compare;
    if (summary.previousExpense == 0 && summary.expense == 0) {
      compare = '아직 지출이 없습니다';
    } else if (change == 0) {
      compare = '지난달과 지출이 같습니다';
    } else if (change > 0) {
      compare = '지난달보다 ${won(change)} 더 썼습니다';
    } else {
      compare = '지난달보다 ${won(-change)} 덜 썼습니다';
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _InsightChip(icon: Icons.compare_arrows, text: compare),
        _InsightChip(
          icon: Icons.today_outlined,
          text: '하루 평균 ${won(summary.dailyAverageExpense)}',
        ),
        _InsightChip(
          icon: Icons.savings_outlined,
          text: '무지출 ${summary.noSpendDays}일',
        ),
      ],
    );
  }
}

class _InsightChip extends StatelessWidget {
  const _InsightChip({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(20),
        border: Border.fromBorderSide(context.tokens.surfaceBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Flexible(child: Text(text, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}

/// 전체 예산의 진행 막대. 누르면 예산 화면으로 간다.
class _BudgetCard extends StatelessWidget {
  const _BudgetCard({required this.budget, required this.daysLeft});

  final MonthBudget budget;

  /// 이 달에서 오늘 뒤로 남은 날 수.
  final int daysLeft;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final sub = theme.colorScheme.onSurfaceVariant;
    final over = budget.isOver;

    final String status;
    String? advice;
    if (over) {
      status = '${won(budget.overBy)} 넘음';
    } else {
      status = '${won(budget.remaining)} 남았습니다';
      if (daysLeft > 0 && budget.remaining > 0) {
        advice =
            '하루 ${won(budget.remaining ~/ daysLeft)}씩 쓸 수 있습니다 · $daysLeft일 남음';
      }
    }

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: const ValueKey('home-budget'),
        onTap: () => context.go('/budget'),
        child: Semantics(
          // 막대의 값을 글로 읽어 준다.
          label:
              '예산 ${won(budget.amount)} 가운데 ${won(budget.spent)} 사용, '
              '${percent(budget.ratio)}. $status',
          button: true,
          excludeSemantics: true,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text('예산', style: theme.textTheme.titleMedium),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerRight,
                              child: Text(
                                '${won(budget.amount)} 중 ${percent(budget.ratio)}',
                                key: const ValueKey('home-budget-ratio'),
                                maxLines: 1,
                                style: tokens.amountStyle(
                                  theme.textTheme.bodyMedium?.copyWith(
                                    color: sub,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(5),
                        child: LinearProgressIndicator(
                          value: budget.ratio.clamp(0, 1).toDouble(),
                          minHeight: 10,
                          // 넘기면 지출색이 아니라 경고색이다(6.1: 둘을 나눈다).
                          color: over ? tokens.warn : theme.colorScheme.primary,
                          backgroundColor:
                              theme.colorScheme.surfaceContainerHighest,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          if (over) ...[
                            // 색만으로 알리지 않는다.
                            Icon(
                              Icons.warning_amber_rounded,
                              size: 18,
                              color: tokens.warn,
                            ),
                            const SizedBox(width: 4),
                          ],
                          Flexible(
                            child: Text(
                              status,
                              key: const ValueKey('home-budget-status'),
                              style: tokens
                                  .amountStyle(theme.textTheme.bodyMedium)
                                  .copyWith(
                                    color: over ? tokens.warn : null,
                                    fontWeight: over ? FontWeight.w600 : null,
                                  ),
                            ),
                          ),
                        ],
                      ),
                      if (advice != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          advice,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: sub,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: sub),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "확인 필요 N건". 누르면 확인이 필요한 것만 거른 내역으로 간다.
class _NeedsReview extends StatelessWidget {
  const _NeedsReview({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    return Align(
      alignment: Alignment.centerLeft,
      child: Material(
        color: tokens.warnSoft,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: const ValueKey('home-needs-review'),
          onTap: () => context.go('/transactions?review=1'),
          child: ConstrainedBox(
            // 누름 영역 48dp.
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 6, 8, 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    size: 20,
                    color: tokens.warn,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      '확인 필요 $count건',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: tokens.warn,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Icon(Icons.chevron_right, size: 20, color: tokens.warn),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 분류별 지출 상위 5.
class _CategoryCard extends ConsumerWidget {
  const _CategoryCard({required this.summary});

  final MonthSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visuals = ref.watch(categoryVisualsProvider);
    final top = summary.byCategory.take(5).toList();
    return SectionCard(
      title: '분류별 지출',
      trailing: TextButton(
        onPressed: () => context.go('/stats'),
        child: const Text('통계'),
      ),
      child: top.isEmpty
          ? const EmptyState(
              icon: Icons.pie_chart_outline,
              message: '이 달에는 지출이 없습니다',
            )
          : Column(
              children: [
                for (final c in top)
                  CategoryBarRow(
                    key: ValueKey('home-category-${c.categoryId ?? 'none'}'),
                    name: c.name,
                    amount: c.amount,
                    ratio: summary.expense <= 0
                        ? 0
                        : c.amount / summary.expense,
                    visual: visuals[c.categoryId],
                    onTap: c.categoryId == null
                        ? null
                        : () => context.go(
                            '/transactions?category=${c.categoryId}',
                          ),
                  ),
              ],
            ),
    );
  }
}

/// 최근 내역 5건.
class _RecentCard extends StatelessWidget {
  const _RecentCard({required this.transactions});

  final AsyncValue<List<TransactionView>> transactions;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: '최근 내역',
      trailing: TextButton(
        onPressed: () => context.go('/transactions'),
        child: const Text('전체 보기'),
      ),
      child: LoadBody<List<TransactionView>>(
        value: transactions,
        what: '내역을',
        builder: (list) => Column(
          children: [
            for (final view in list.take(5))
              _RecentRow(
                key: ValueKey('home-recent-${view.row.id}'),
                view: view,
              ),
          ],
        ),
      ),
    );
  }
}

/// 최근 내역의 한 줄: 분류 표시, 제목과 설명, 금액. 누르면 그 거래를 내역에서 연다.
///
/// 목록의 줄(`TransactionTile`)을 쓰지 않는 것은, 홈의 좁은 카드에서 글자를 키우면 금액이
/// 줄을 다 차지해 버리기 때문이다. 여기서는 금액을 줄여 그린다.
class _RecentRow extends ConsumerWidget {
  const _RecentRow({super.key, required this.view});

  final TransactionView view;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final transfer = view.row.type == TxType.transfer;
    final visual = ref.watch(categoryVisualsProvider)[view.row.categoryId];
    return InkWell(
      onTap: () => context.go('/transactions?id=${view.row.id}'),
      borderRadius: BorderRadius.circular(
        tokens.radius < 12 ? tokens.radius : 12,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: tokens.rowHeight < 48 ? 48 : tokens.rowHeight,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          child: LayoutBuilder(
            builder: (context, constraints) => Row(
              children: [
                CategoryBadge(
                  visual: visual,
                  icon: transfer ? Icons.swap_horiz : null,
                  color: transfer ? tokens.transfer : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        view.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${monthDay(view.row.occurredOn)} · '
                        '${transactionSubtitle(view)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: constraints.maxWidth * 0.5,
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: AmountText(view),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 이 달에 내역이 하나도 없을 때.
class _EmptyCard extends StatelessWidget {
  const _EmptyCard();

  @override
  Widget build(BuildContext context) {
    return const Card(
      key: ValueKey('home-empty'),
      margin: EdgeInsets.zero,
      child: EmptyState(
        icon: Icons.receipt_long_outlined,
        message:
            '아직 내역이 없습니다.\n'
            '입력창에 결제 문자를 붙여넣거나 "점심 9000원"처럼 적어 보세요.',
      ),
    );
  }
}
