import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/providers.dart';
import '../../app/theme/tokens.dart';
import '../../core/breakpoints.dart';
import '../../core/formatters.dart';
import '../../core/local_date.dart';
import '../../data/repositories/summary_repository.dart';
import '../../domain/month_period.dart';
import '../../domain/month_summary.dart';
import '../common/summary_parts.dart';
import '../common/widgets.dart';
import 'charts.dart';
import 'narrative_provider.dart';

/// 통계에서 보는 쪽.
enum StatsFlow {
  expense('지출', '많이 쓴 곳', '쓴'),
  income('수입', '많이 받은 곳', '받은');

  const StatsFlow(this.noun, this.partiesTitle, this.verb);

  /// '지출' · '수입'
  final String noun;

  /// 상대방 순위의 제목.
  final String partiesTitle;

  /// "가장 많이 …"에 넣는 말.
  final String verb;
}

/// 통계 화면이 지출을 보는지 수입을 보는지. 다른 탭에 다녀와도 남는다.
class StatsFlowSelection extends Notifier<StatsFlow> {
  @override
  StatsFlow build() => StatsFlow.expense;

  void set(StatsFlow flow) => state = flow;
}

final statsFlowProvider = NotifierProvider<StatsFlowSelection, StatsFlow>(
  StatsFlowSelection.new,
);

/// 통계(`docs/SPEC.md` 7.10): 지출 · 수입 전환, 분류 비중, 날짜별 추이, 최근 6개월 추이,
/// 상대방 상위 5, 큰 거래 5. 지난달 이전을 볼 때는 총평을 맨 위에 보여 준다.
class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final flow = ref.watch(statsFlowProvider);
    final period = ref.watch(selectedPeriodProvider);
    final today = ref.watch(todayProvider);
    final compact = WindowSize.of(context).isCompact;

    final toggle = SegmentedButton<StatsFlow>(
      key: const ValueKey('stats-flow'),
      showSelectedIcon: false,
      segments: [
        for (final f in StatsFlow.values)
          ButtonSegment(
            value: f,
            label: Text(f.noun, key: ValueKey('stats-flow-${f.name}')),
          ),
      ],
      selected: {flow},
      onSelectionChanged: (selection) =>
          ref.read(statsFlowProvider.notifier).set(selection.first),
    );

    // 지출 쪽은 기본 집계에서, 수입 쪽은 따로 읽은 것에서 얻는다.
    final AsyncValue<FlowBreakdown> breakdown = switch (flow) {
      StatsFlow.expense =>
        ref.watch(monthSummaryProvider).whenData(FlowBreakdown.expenseOf),
      StatsFlow.income => ref.watch(incomeBreakdownProvider),
    };

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          if (compact) ...[
            const Align(
              alignment: Alignment.centerLeft,
              child: MonthSwitcher(),
            ),
            const SizedBox(height: 4),
            Align(alignment: Alignment.centerLeft, child: toggle),
          ] else
            Row(
              children: [
                const Expanded(child: MonthSwitcher()),
                const SizedBox(width: 12),
                toggle,
              ],
            ),
          const SizedBox(height: 12),
          // 총평은 끝난 달에만 만든다. 이번 달은 숫자만 보여 준다.
          if (today >= period.endExclusive) _Narrative(period: period),
          LoadBody<FlowBreakdown>(
            value: breakdown,
            what: '이 달의 통계를',
            onRetry: () {
              ref.invalidate(monthSummaryProvider);
              ref.invalidate(incomeBreakdownProvider);
            },
            // 달을 넘기는 동안 앞 달의 값이 잠깐 남는다. 그 값으로 그리면 날짜가 맞지
            // 않으므로 고른 달의 값이 올 때까지 기다린다.
            builder: (data) => data.period == period
                ? _StatsBody(flow: flow, data: data)
                : const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  ),
          ),
        ],
      ),
    );
  }
}

class _StatsBody extends StatelessWidget {
  const _StatsBody({required this.flow, required this.data});

  final StatsFlow flow;
  final FlowBreakdown data;

  @override
  Widget build(BuildContext context) {
    final wide = WindowSize.of(context).isExpanded;
    final color = switch (flow) {
      StatsFlow.expense => context.tokens.expense,
      StatsFlow.income => context.tokens.income,
    };
    final categories = _Categories(flow: flow, data: data);
    final daily = _DailyCard(flow: flow, data: data, color: color);
    final trend = _TrendCard(flow: flow, color: color);
    final parties = _Counterparties(flow: flow, data: data);
    final largest = _Largest(flow: flow, data: data);
    const gap = SizedBox(height: 12);

    if (!wide) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          categories,
          gap,
          daily,
          gap,
          trend,
          gap,
          parties,
          gap,
          largest,
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [categories, gap, parties],
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [daily, gap, trend, gap, largest],
          ),
        ),
      ],
    );
  }
}

/// 그 달의 총평. 아직 없거나 만들 수 없으면 아무것도 그리지 않는다.
class _Narrative extends ConsumerWidget {
  const _Narrative({required this.period});

  final MonthPeriod period;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = ref.watch(monthNarrativeProvider(period)).value?.trim();
    if (text == null || text.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SectionCard(
        key: const ValueKey('stats-narrative'),
        title: '${period.month}월 총평',
        child: Text(text, style: theme.textTheme.bodyLarge),
      ),
    );
  }
}

/// 분류 비중. 줄을 누르면 그 분류로 거른 내역으로 간다.
class _Categories extends ConsumerWidget {
  const _Categories({required this.flow, required this.data});

  final StatsFlow flow;
  final FlowBreakdown data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visuals = ref.watch(categoryVisualsProvider);
    return SectionCard(
      title: '분류별 ${flow.noun} · ${won(data.total)}',
      child: data.byCategory.isEmpty
          ? _NoData(flow: flow, icon: Icons.pie_chart_outline)
          : Column(
              children: [
                for (final c in data.byCategory)
                  CategoryBarRow(
                    key: ValueKey('stats-category-${c.categoryId ?? 'none'}'),
                    name: c.name,
                    amount: c.amount,
                    ratio: data.total <= 0 ? 0 : c.amount / data.total,
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

/// 날짜별 추이.
class _DailyCard extends ConsumerWidget {
  const _DailyCard({
    required this.flow,
    required this.data,
    required this.color,
  });

  final StatsFlow flow;
  final FlowBreakdown data;
  final Color color;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    var max = 0;
    LocalDate? peak;
    for (final entry in data.daily.entries) {
      if (entry.value <= 0) continue;
      // 같은 금액이면 앞선 날을 든다.
      if (peak == null ||
          entry.value > max ||
          (entry.value == max && entry.key < peak)) {
        max = entry.value;
        peak = entry.key;
      }
    }
    final String caption;
    if (peak == null) {
      caption = '';
    } else if (flow == StatsFlow.expense) {
      // 하루 평균과 무지출 일수는 지출 집계에만 있다.
      final summary = ref.watch(monthSummaryProvider).value;
      final extra = summary == null || summary.period != data.period
          ? ''
          : ' 하루 평균은 ${won(summary.dailyAverageExpense)}, '
                '무지출은 ${summary.noSpendDays}일입니다.';
      caption = '가장 많이 쓴 날은 ${dayLabel(peak)} ${won(max)}입니다.$extra';
    } else {
      caption = '가장 많이 받은 날은 ${dayLabel(peak)} ${won(max)}입니다.';
    }

    return SectionCard(
      title: '날짜별 ${flow.noun}',
      child: peak == null
          ? _NoData(flow: flow, icon: Icons.bar_chart)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DailyBars(
                  period: data.period,
                  values: data.daily,
                  color: color,
                  noun: flow.noun,
                ),
                const SizedBox(height: 8),
                Text(
                  caption,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
    );
  }
}

/// 최근 6개월 추이.
class _TrendCard extends ConsumerWidget {
  const _TrendCard({required this.flow, required this.color});

  final StatsFlow flow;
  final Color color;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final trend = ref.watch(monthTrendProvider);
    int valueOf(MonthTotal m) =>
        flow == StatsFlow.expense ? m.expense : m.income;

    return SectionCard(
      key: const ValueKey('stats-trend'),
      title: '최근 6개월 ${flow.noun}',
      child: LoadBody<List<MonthTotal>>(
        value: trend,
        what: '여섯 달의 추이를',
        onRetry: () => ref.invalidate(monthTrendProvider),
        builder: (months) {
          MonthTotal? top;
          for (final m in months) {
            if (valueOf(m) > 0 && (top == null || valueOf(m) > valueOf(top))) {
              top = m;
            }
          }
          if (top == null) return _NoData(flow: flow, icon: Icons.show_chart);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TrendBars(
                months: months,
                valueOf: valueOf,
                color: color,
                noun: flow.noun,
              ),
              const SizedBox(height: 8),
              Text(
                '여섯 달 가운데 가장 많이 ${flow.verb} 달은 '
                '${top.period.month}월(${won(valueOf(top))})입니다.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// 상대방 상위 5.
class _Counterparties extends StatelessWidget {
  const _Counterparties({required this.flow, required this.data});

  final StatsFlow flow;
  final FlowBreakdown data;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: flow.partiesTitle,
      child: data.topCounterparties.isEmpty
          ? _NoData(flow: flow, icon: Icons.storefront_outlined)
          : Column(
              children: [
                for (final c in data.topCounterparties)
                  _AmountRow(
                    title: c.name,
                    subtitle: '${c.count}건',
                    amount: won(c.amount),
                  ),
              ],
            ),
    );
  }
}

/// 큰 거래 5건. 누르면 그 거래를 내역에서 연다.
class _Largest extends StatelessWidget {
  const _Largest({required this.flow, required this.data});

  final StatsFlow flow;
  final FlowBreakdown data;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final (sign, color) = switch (flow) {
      StatsFlow.expense => ('-', tokens.expense),
      StatsFlow.income => ('+', tokens.income),
    };
    return SectionCard(
      title: '큰 ${flow.noun}',
      child: data.largest.isEmpty
          ? _NoData(flow: flow, icon: Icons.receipt_outlined)
          : Column(
              children: [
                for (final e in data.largest)
                  _AmountRow(
                    title: e.name.isEmpty ? '내용 없음' : e.name,
                    subtitle: dayLabel(e.date),
                    // 거래 하나하나의 금액에는 부호와 색을 함께 쓴다.
                    amount: '$sign${won(e.amount)}',
                    amountColor: color,
                    onTap: () =>
                        context.go('/transactions?id=${e.transactionId}'),
                  ),
              ],
            ),
    );
  }
}

/// 이름 · 덧붙임 · 금액 한 줄. 글자를 키워도 금액이 넘치지 않게 줄여 그린다.
class _AmountRow extends StatelessWidget {
  const _AmountRow({
    required this.title,
    required this.subtitle,
    required this.amount,
    this.amountColor,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final String amount;
  final Color? amountColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final row = LayoutBuilder(
      builder: (context, constraints) => Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: constraints.maxWidth * 0.5),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                amount,
                maxLines: 1,
                style: tokens
                    .amountStyle(theme.textTheme.bodyLarge)
                    .copyWith(
                      color: amountColor,
                      fontWeight: amountColor == null ? null : FontWeight.w600,
                    ),
              ),
            ),
          ),
        ],
      ),
    );
    final padded = Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: row,
    );
    if (onTap == null) return padded;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(
        tokens.radius < 12 ? tokens.radius : 12,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Center(child: padded),
      ),
    );
  }
}

/// 그릴 값이 없을 때.
class _NoData extends StatelessWidget {
  const _NoData({required this.flow, required this.icon});

  final StatsFlow flow;
  final IconData icon;

  @override
  Widget build(BuildContext context) =>
      EmptyState(icon: icon, message: '${flow.noun}이 없습니다');
}
