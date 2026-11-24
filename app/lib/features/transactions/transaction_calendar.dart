import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../app/theme/tokens.dart';
import '../../core/formatters.dart';
import '../../core/local_date.dart';
import '../../data/repositories/ledger_repository.dart';
import '../../data/repositories/transaction_query.dart';
import '../../domain/month_period.dart';
import 'amount_input.dart';
import 'transaction_tile.dart';

/// 달력의 주. 일요일부터 토요일까지 일곱 날이다.
///
/// [period]의 첫날이 든 주부터 마지막 날이 든 주까지 돌려준다. 기간 밖의 날도 들어 있다
/// (그리는 쪽이 비워 둔다).
List<List<LocalDate>> calendarWeeks(MonthPeriod period) {
  // weekday는 월요일 1 … 일요일 7이다. 일요일을 주의 첫날로 둔다.
  var day = period.start.addDays(-(period.start.weekday % 7));
  final weeks = <List<LocalDate>>[];
  while (day <= period.last) {
    weeks.add([for (var i = 0; i < 7; i++) day.addDays(i)]);
    day = day.addDays(7);
  }
  return weeks;
}

const _weekdayHeads = ['일', '월', '화', '수', '목', '금', '토'];

/// 한 달을 주 단위 격자로 그린다. 날짜 칸에 그날의 수입(+)과 지출(−) 합계를 적는다.
class MonthCalendar extends StatelessWidget {
  const MonthCalendar({
    super.key,
    required this.period,
    required this.totals,
    required this.today,
    required this.selected,
    required this.onSelect,
  });

  final MonthPeriod period;
  final Map<LocalDate, DayTotal> totals;
  final LocalDate today;
  final LocalDate? selected;
  final ValueChanged<LocalDate> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scaler = MediaQuery.textScalerOf(context);
    // 글자를 키워도 칸이 끝없이 길어지지 않게 줄 높이에 위를 둔다. 넘는 글자는 줄여 그린다.
    final dayHeight = math.min(scaler.scale(14) * 1.45, 30.0);
    final amountHeight = math.min(scaler.scale(12) * 1.45, 22.0);
    final head = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return LayoutBuilder(
      builder: (context, constraints) => Column(
        mainAxisSize: MainAxisSize.min,
        children: _rows(
          // 칸이 넓으면(PC) 금액을 줄이지 않고 다 적는다.
          roomy: constraints.maxWidth / 7 >= 84,
          dayHeight: dayHeight,
          amountHeight: amountHeight,
          head: head,
        ),
      ),
    );
  }

  List<Widget> _rows({
    required bool roomy,
    required double dayHeight,
    required double amountHeight,
    required TextStyle? head,
  }) => [
    Row(
      children: [
        for (final name in _weekdayHeads)
          Expanded(
            child: SizedBox(
              height: amountHeight + 4,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(name, style: head),
              ),
            ),
          ),
      ],
    ),
    for (final week in calendarWeeks(period))
      Row(
        children: [
          for (final date in week)
            Expanded(
              child: period.contains(date)
                  ? _DayCell(
                      date: date,
                      // 기간의 첫날과 매달 1일에는 달을 함께 적는다.
                      showMonth: date == period.start || date.day == 1,
                      total: totals[date] ?? const DayTotal(),
                      isToday: date == today,
                      selected: date == selected,
                      roomy: roomy,
                      dayHeight: dayHeight,
                      amountHeight: amountHeight,
                      onTap: () => onSelect(date),
                    )
                  : SizedBox(height: dayHeight + amountHeight * 2 + 10),
            ),
        ],
      ),
  ];
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.date,
    required this.showMonth,
    required this.total,
    required this.isToday,
    required this.selected,
    required this.roomy,
    required this.dayHeight,
    required this.amountHeight,
    required this.onTap,
  });

  final LocalDate date;
  final bool showMonth;
  final DayTotal total;
  final bool isToday;
  final bool selected;

  /// 금액을 다 적을 만큼 칸이 넓은지.
  final bool roomy;
  final double dayHeight;
  final double amountHeight;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final scheme = theme.colorScheme;
    final amountStyle = tokens.amountStyle(
      roomy ? theme.textTheme.bodySmall : theme.textTheme.labelSmall,
    );
    String amount(int signed) => roomy
        ? '${signed < 0 ? '-' : '+'}${formatNumber(signed.abs())}'
        : signedCompactAmount(signed);
    // 수입, 지출 순서로 위에서부터 채운다. 한쪽만 있으면 빈 줄을 사이에 두지 않는다.
    final amounts = [
      if (total.income != 0)
        Text(
          amount(total.income),
          key: ValueKey('calendar-income-$date'),
          style: amountStyle.copyWith(color: tokens.income),
        ),
      if (total.expense != 0)
        Text(
          amount(-total.expense),
          key: ValueKey('calendar-expense-$date'),
          style: amountStyle.copyWith(color: tokens.expense),
        ),
    ];
    final radius = BorderRadius.circular(math.min(tokens.radius, 8));

    Widget line(double height, Widget? child) => SizedBox(
      height: height,
      child: child == null
          ? null
          : FittedBox(fit: BoxFit.scaleDown, child: child),
    );

    final label = [
      dayLabel(date),
      if (isToday) '오늘',
      if (total.income != 0) '수입 ${signedWon(total.income)}',
      if (total.expense != 0) '지출 ${signedWon(-total.expense)}',
    ].join(', ');

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.all(1),
        child: Material(
          color: selected ? tokens.accentSoft : Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: radius,
            side: isToday
                ? BorderSide(color: scheme.primary, width: 1.5)
                : BorderSide.none,
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: ValueKey('calendar-day-$date'),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  line(
                    dayHeight,
                    Text(
                      showMonth ? '${date.month}/${date.day}' : '${date.day}',
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: isToday || selected
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                  ),
                  for (var i = 0; i < 2; i++)
                    line(amountHeight, i < amounts.length ? amounts[i] : null),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 달력에서 고른 날의 머리줄: 날짜와 그날의 수입 · 지출 합계.
class DayHeader extends StatelessWidget {
  const DayHeader({super.key, required this.date, required this.total});

  final LocalDate date;
  final DayTotal total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final amount = tokens.amountStyle(theme.textTheme.labelLarge);
    return Container(
      width: double.infinity,
      color: theme.colorScheme.surfaceContainerLow,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      // 글자를 키우면 합계가 다음 줄로 내려간다.
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 2,
        children: [
          Text(
            dayLabel(date),
            key: const ValueKey('calendar-day-title'),
            style: theme.textTheme.labelLarge,
          ),
          Wrap(
            spacing: 12,
            children: [
              if (total.income != 0)
                Text(
                  signedWon(total.income),
                  key: const ValueKey('calendar-day-income'),
                  style: amount.copyWith(color: tokens.income),
                ),
              if (total.expense != 0)
                Text(
                  signedWon(-total.expense),
                  key: const ValueKey('calendar-day-expense'),
                  style: amount.copyWith(color: tokens.expense),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 고른 날의 거래. 머리줄 아래에 그날의 거래를 늘어놓는다.
///
/// 스크롤은 감싸는 쪽이 맡는다(좁은 창은 달력과 함께, 넓은 창은 옆 칸에서 따로 굴린다).
List<Widget> dayTransactionWidgets({
  required LocalDate? day,
  required List<TransactionView> transactions,
  required String? selectedId,
  required ValueChanged<TransactionView> onOpen,
}) {
  if (day == null) {
    return const [_DayNotice('날짜를 고르면 그날의 거래가 보입니다')];
  }
  final ofDay = [
    for (final view in transactions)
      if (view.row.occurredOn == day) view,
  ];
  return [
    DayHeader(date: day, total: dailyTotals(ofDay)[day] ?? const DayTotal()),
    if (ofDay.isEmpty)
      const _DayNotice('이 날의 내역이 없습니다')
    else
      for (final view in ofDay)
        TransactionTile(
          key: ValueKey('row-${view.row.id}'),
          view: view,
          selected: view.row.id == selectedId,
          onTap: () => onOpen(view),
        ),
  ];
}

class _DayNotice extends StatelessWidget {
  const _DayNotice(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
