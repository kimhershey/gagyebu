import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/providers.dart';
import '../../core/breakpoints.dart';
import '../../core/formatters.dart';
import '../../data/repositories/ledger_repository.dart';
import '../../domain/month_summary.dart';
import '../common/widgets.dart';
import '../shell/app_shell.dart';
import '../transactions/transaction_tile.dart';

/// 홈: 이번 달 수입 · 지출 · 수지, 분류별 지출, 최근 내역.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(monthSummaryProvider);
    final recent = ref.watch(monthTransactionsProvider);
    final wide = WindowSize.of(context).isExpanded;

    return SafeArea(
      child: AsyncBody<MonthSummary>(
        value: summary,
        builder: (s) {
          final overview = [
            _Totals(summary: s),
            const SizedBox(height: 12),
            _Insights(summary: s),
            const SizedBox(height: 12),
            _CategoryCard(summary: s),
          ];
          final recentCard = _RecentCard(transactions: recent);
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              const Align(
                alignment: Alignment.centerLeft,
                child: MonthSwitcher(),
              ),
              const SizedBox(height: 8),
              if (wide)
                Row(
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
                    Expanded(flex: 4, child: recentCard),
                  ],
                )
              else ...[
                ...overview,
                const SizedBox(height: 12),
                recentCard,
              ],
            ],
          );
        },
      ),
    );
  }
}

class _Totals extends StatelessWidget {
  const _Totals({required this.summary});

  final MonthSummary summary;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final income = _TotalCard(
      label: '수입',
      value: won(summary.income),
      color: scheme.income,
      valueKey: const ValueKey('total-income'),
    );
    final expense = _TotalCard(
      label: '지출',
      value: won(summary.expense),
      color: scheme.expense,
      valueKey: const ValueKey('total-expense'),
    );
    final net = _TotalCard(
      label: '수지',
      value: signedWon(summary.net),
      color: scheme.onSurface,
      valueKey: const ValueKey('total-net'),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        // 좁으면 수입 · 지출을 한 줄에, 수지를 그 아래 한 줄에 둔다. 세 칸으로 나누면
        // 금액마다 글자 크기가 달라져 들쭉날쭉해 보인다.
        if (constraints.maxWidth < 480) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(child: income),
                  const SizedBox(width: 8),
                  Expanded(child: expense),
                ],
              ),
              const SizedBox(height: 8),
              net,
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: income),
            const SizedBox(width: 8),
            Expanded(child: expense),
            const SizedBox(width: 8),
            Expanded(child: net),
          ],
        );
      },
    );
  }
}

class _TotalCard extends StatelessWidget {
  const _TotalCard({
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
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 6),
            // 좁은 화면에서 큰 금액이 잘리지 않게 줄여 그린다.
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                key: valueKey,
                maxLines: 1,
                style: theme.textTheme.titleLarge?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
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
      compare = '아직 지출이 없다';
    } else if (change == 0) {
      compare = '지난달과 지출이 같다';
    } else if (change > 0) {
      compare = '지난달보다 ${won(change)} 더 썼다';
    } else {
      compare = '지난달보다 ${won(-change)} 덜 썼다';
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
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
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

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({required this.summary});

  final MonthSummary summary;

  @override
  Widget build(BuildContext context) {
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
              message: '이번 달 지출이 아직 없다',
            )
          : Column(
              children: [
                for (final c in top)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: CategoryBarRow(
                      name: c.name,
                      amount: c.amount,
                      ratio: summary.expense <= 0
                          ? 0
                          : c.amount / summary.expense,
                    ),
                  ),
              ],
            ),
    );
  }
}

/// 분류 이름, 금액, 비중 막대를 한 줄로.
class CategoryBarRow extends StatelessWidget {
  const CategoryBarRow({
    super.key,
    required this.name,
    required this.amount,
    required this.ratio,
  });

  final String name;
  final int amount;
  final double ratio;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            Text(
              percent(ratio),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 12),
            Text(won(amount), style: theme.textTheme.bodyMedium),
          ],
        ),
        const SizedBox(height: 4),
        RatioBar(ratio: ratio),
      ],
    );
  }
}

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
      child: AsyncBody<List<TransactionView>>(
        value: transactions,
        builder: (list) {
          if (list.isEmpty) {
            return EmptyState(
              icon: Icons.receipt_long_outlined,
              message: '이번 달 내역이 없다.\n결제 문자를 붙여넣거나 직접 입력해 보자.',
              action: FilledButton.tonal(
                onPressed: () => openInput(context),
                child: const Text('입력하기'),
              ),
            );
          }
          return Column(
            children: [
              for (final view in list.take(6))
                TransactionTile(
                  view: view,
                  showDate: true,
                  onTap: () => context.go('/transactions?id=${view.row.id}'),
                ),
            ],
          );
        },
      ),
    );
  }
}
