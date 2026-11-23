import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/providers.dart';
import '../../core/breakpoints.dart';
import '../../core/formatters.dart';
import '../../core/local_date.dart';
import '../../domain/month_summary.dart';
import '../common/widgets.dart';
import '../home/home_screen.dart' show CategoryBarRow;

/// 통계: 분류별 비중, 날짜별 지출, 상대방 순위, 큰 지출.
class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(monthSummaryProvider);
    final wide = WindowSize.of(context).isExpanded;
    return SafeArea(
      child: AsyncBody<MonthSummary>(
        value: summary,
        builder: (s) {
          final categories = _Categories(summary: s);
          final daily = _DailyChart(summary: s);
          final parties = _Counterparties(summary: s);
          final largest = _Largest(summary: s);
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              const Align(
                alignment: Alignment.centerLeft,
                child: MonthSwitcher(),
              ),
              const SizedBox(height: 8),
              if (wide) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: categories),
                    const SizedBox(width: 16),
                    Expanded(child: daily),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: parties),
                    const SizedBox(width: 16),
                    Expanded(child: largest),
                  ],
                ),
              ] else ...[
                categories,
                const SizedBox(height: 12),
                daily,
                const SizedBox(height: 12),
                parties,
                const SizedBox(height: 12),
                largest,
              ],
            ],
          );
        },
      ),
    );
  }
}

class _Categories extends StatelessWidget {
  const _Categories({required this.summary});

  final MonthSummary summary;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: '분류별 지출 · ${won(summary.expense)}',
      child: summary.byCategory.isEmpty
          ? const EmptyState(icon: Icons.pie_chart_outline, message: '지출이 없습니다')
          : Column(
              children: [
                for (final c in summary.byCategory)
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

/// 날짜별 지출 막대.
class _DailyChart extends StatelessWidget {
  const _DailyChart({required this.summary});

  final MonthSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final period = summary.period;
    final days = [
      for (var i = 0; i < period.days; i++) period.start.addDays(i),
    ];
    final max = summary.dailyExpense.values.fold<int>(
      0,
      (m, v) => v > m ? v : m,
    );
    LocalDate? peakDay;
    summary.dailyExpense.forEach((day, value) {
      if (value == max && max > 0) peakDay ??= day;
    });

    return SectionCard(
      title: '날짜별 지출',
      child: max <= 0
          ? const EmptyState(icon: Icons.bar_chart, message: '지출이 없습니다')
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 120,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (final day in days)
                        Expanded(
                          child: Tooltip(
                            message:
                                '${monthDay(day)} ${won(summary.dailyExpense[day] ?? 0)}',
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 1,
                              ),
                              child: FractionallySizedBox(
                                heightFactor:
                                    ((summary.dailyExpense[day] ?? 0) / max)
                                        .clamp(0.015, 1)
                                        .toDouble(),
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: (summary.dailyExpense[day] ?? 0) > 0
                                        ? theme.colorScheme.primary
                                        : theme
                                              .colorScheme
                                              .surfaceContainerHighest,
                                    borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(2),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      monthDay(period.start),
                      style: theme.textTheme.bodySmall,
                    ),
                    Text(
                      monthDay(period.last),
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '가장 많이 쓴 날은 ${dayLabel(peakDay!)} ${won(max)}입니다. '
                  '하루 평균은 ${won(summary.dailyAverageExpense)}, 무지출은 ${summary.noSpendDays}일입니다.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
    );
  }
}

class _Counterparties extends StatelessWidget {
  const _Counterparties({required this.summary});

  final MonthSummary summary;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: '많이 쓴 곳',
      child: summary.topCounterparties.isEmpty
          ? const EmptyState(
              icon: Icons.storefront_outlined,
              message: '지출이 없습니다',
            )
          : Column(
              children: [
                for (final c in summary.topCounterparties)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      c.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text('${c.count}건'),
                    trailing: Text(won(c.amount)),
                  ),
              ],
            ),
    );
  }
}

class _Largest extends StatelessWidget {
  const _Largest({required this.summary});

  final MonthSummary summary;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: '큰 지출',
      child: summary.largestExpenses.isEmpty
          ? const EmptyState(icon: Icons.receipt_outlined, message: '지출이 없습니다')
          : Column(
              children: [
                for (final e in summary.largestExpenses)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      e.name.isEmpty ? '내용 없음' : e.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(dayLabel(e.date)),
                    trailing: Text(won(e.amount)),
                  ),
              ],
            ),
    );
  }
}
