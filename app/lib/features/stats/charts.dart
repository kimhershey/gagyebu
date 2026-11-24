/// 통계 화면의 막대 그림. 새 의존성 없이 기본 위젯으로 그린다.
///
/// 그림마다 값을 글로 읽어 주는 `Semantics` 설명을 단다(`docs/SPEC.md` 6.4). 막대의 색은
/// 한 가지(지출색이나 수입색)이고, 글자는 글자색을 쓴다.
library;

import 'package:material_ui/material_ui.dart';

import '../../app/theme/tokens.dart';
import '../../core/formatters.dart';
import '../../core/local_date.dart';
import '../../domain/month_period.dart';
import '../../domain/month_summary.dart';

/// 막대 위에 적는 짧은 금액. 74,500 → '7.5만', 1,234,500 → '123만', 9,500 → '9,500'.
///
/// 정확한 값은 막대의 풍선말과 읽어 주는 설명에 있다.
String compactAmount(int value) {
  final abs = value.abs();
  final sign = value < 0 ? '-' : '';
  if (abs < 10000) return '$sign${formatNumber(abs)}';
  if (abs < 100000000) {
    final man = abs / 10000;
    if (man < 100) return '$sign${_oneDecimal(man)}만';
    return '$sign${formatNumber(man.round())}만';
  }
  return '$sign${_oneDecimal(abs / 100000000)}억';
}

/// 7.45 → '7.5', 7.0 → '7'
String _oneDecimal(double value) {
  final text = value.toStringAsFixed(1);
  return text.endsWith('.0') ? text.substring(0, text.length - 2) : text;
}

/// 달의 날짜별 금액 막대.
class DailyBars extends StatelessWidget {
  const DailyBars({
    super.key,
    required this.period,
    required this.values,
    required this.color,
    required this.noun,
    this.height = 120,
  });

  final MonthPeriod period;
  final Map<LocalDate, int> values;
  final Color color;

  /// '지출'이나 '수입'. 읽어 주는 설명에 쓴다.
  final String noun;
  final double height;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final days = [
      for (var i = 0; i < period.days; i++) period.start.addDays(i),
    ];
    var max = 0;
    LocalDate? peak;
    var activeDays = 0;
    for (final day in days) {
      final value = values[day] ?? 0;
      if (value > 0) activeDays++;
      if (value > max) {
        max = value;
        peak = day;
      }
    }
    final label = peak == null
        ? '날짜별 $noun 막대 그림. $noun이 없습니다.'
        : '날짜별 $noun 막대 그림. $noun이 있는 날은 $activeDays일이고, '
              '가장 많은 날은 ${dayLabel(peak)} ${won(max)}입니다.';
    final labelStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          // 카드의 다른 글과 섞이지 않게 그림 하나를 따로 읽게 한다.
          container: true,
          label: label,
          // 막대 하나하나의 풍선말 대신 위의 설명 하나를 읽게 한다.
          child: ExcludeSemantics(
            child: Container(
              height: height,
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: theme.colorScheme.outlineVariant),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final day in days)
                    Expanded(
                      child: Tooltip(
                        message: '${monthDay(day)} ${won(values[day] ?? 0)}',
                        // 막대가 낮아도 그 날의 칸 전체에서 풍선말이 뜬다.
                        child: SizedBox.expand(
                          child: _Bar(
                            fraction: max <= 0 ? 0 : (values[day] ?? 0) / max,
                            color: color,
                            gap: 1,
                            radius: 2,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        ExcludeSemantics(
          child: Row(
            children: [
              Expanded(
                child: Text(
                  monthDay(period.start),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: labelStyle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  monthDay(period.last),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: labelStyle,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 여러 달의 금액 막대. 마지막 달(보고 있는 달)을 진하게 그린다.
class TrendBars extends StatelessWidget {
  const TrendBars({
    super.key,
    required this.months,
    required this.valueOf,
    required this.color,
    required this.noun,
    this.height = 120,
  });

  /// 오래된 달부터.
  final List<MonthTotal> months;

  /// 그릴 값(수입이나 지출).
  final int Function(MonthTotal month) valueOf;
  final Color color;

  /// '지출'이나 '수입'.
  final String noun;
  final double height;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final values = [for (final m in months) valueOf(m)];
    final max = values.fold<int>(0, (m, v) => v > m ? v : m);
    final label = StringBuffer('최근 ${months.length}개월 $noun 막대 그림.');
    for (var i = 0; i < months.length; i++) {
      label.write(' ${_monthName(i)} ${won(values[i])}');
      label.write(i == months.length - 1 ? '.' : ',');
    }
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final strong = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurface,
      fontWeight: FontWeight.w600,
    );

    Widget labels(String Function(int i) text, {required bool amount}) => Row(
      children: [
        for (var i = 0; i < months.length; i++)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              // 여섯 칸에 글자가 다 들어가지 않으면 줄여 그린다(글자 200%).
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  text(i),
                  maxLines: 1,
                  style: amount
                      ? tokens.amountStyle(
                          i == months.length - 1 ? strong : muted,
                        )
                      : (i == months.length - 1 ? strong : muted),
                ),
              ),
            ),
          ),
      ],
    );

    return Semantics(
      container: true,
      label: label.toString(),
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            labels((i) => compactAmount(values[i]), amount: true),
            const SizedBox(height: 4),
            Container(
              height: height,
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: theme.colorScheme.outlineVariant),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (var i = 0; i < months.length; i++)
                    Expanded(
                      child: Tooltip(
                        message:
                            '${periodLabel(months[i].period)} ${won(values[i])}',
                        child: SizedBox.expand(
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 44),
                              child: SizedBox.expand(
                                child: _Bar(
                                  key: ValueKey(
                                    'trend-bar-${months[i].period.key}',
                                  ),
                                  fraction: max <= 0 ? 0 : values[i] / max,
                                  // 보고 있는 달만 진하게, 나머지는 같은 색을 옅게.
                                  color: i == months.length - 1
                                      ? color
                                      : color.withValues(alpha: 0.45),
                                  gap: 4,
                                  radius: 4,
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
            labels(_monthName, amount: false),
          ],
        ),
      ),
    );
  }

  /// 'N월'. 해가 바뀌는 자리와 첫 칸에는 해를 붙인다('26년 1월').
  String _monthName(int i) {
    final period = months[i].period;
    final newYear = i == 0 || months[i - 1].period.year != period.year;
    return newYear && months.first.period.year != months.last.period.year
        ? "${period.year % 100}년 ${period.month}월"
        : '${period.month}월';
  }
}

/// 바닥에 붙어 위로 자라는 막대 하나. 값이 0이면 그리지 않는다.
class _Bar extends StatelessWidget {
  const _Bar({
    super.key,
    required this.fraction,
    required this.color,
    required this.gap,
    required this.radius,
  });

  /// 0–1
  final double fraction;
  final Color color;

  /// 이웃 막대와의 사이(양쪽에 절반씩).
  final double gap;

  /// 위쪽 모서리의 반지름. 바닥은 각지게 둔다.
  final double radius;

  @override
  Widget build(BuildContext context) {
    if (fraction <= 0) return const SizedBox.expand();
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: gap / 2),
      child: FractionallySizedBox(
        alignment: Alignment.bottomCenter,
        // 아주 작은 값도 있다는 것은 보이게 한다.
        heightFactor: fraction.clamp(0.02, 1).toDouble(),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.vertical(top: Radius.circular(radius)),
          ),
        ),
      ),
    );
  }
}
