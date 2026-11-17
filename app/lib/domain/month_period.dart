import '../core/local_date.dart';

/// 가계부의 한 달. 월 시작일 설정을 반영한 기간이다.
///
/// 월 시작일이 1이면 달력의 한 달과 같다. 급여일에 맞춰 25일로 두면
/// 10월 25일부터 11월 24일까지가 '11월'이다(기간이 끝나는 달의 이름을 쓴다).
/// 시작일이 15일 이하면 기간이 시작하는 달의 이름을 쓴다.
class MonthPeriod {
  const MonthPeriod._(this.year, this.month, this.start, this.endExclusive);

  /// 이름이 [year]년 [month]월인 기간.
  factory MonthPeriod(int year, int month, {int startDay = 1}) {
    _checkStartDay(startDay);
    final first = LocalDate(year, month, 1);
    final LocalDate start;
    if (startDay == 1) {
      start = first;
    } else if (startDay > 15) {
      final previous = first.addMonths(-1);
      start = LocalDate(previous.year, previous.month, startDay);
    } else {
      start = LocalDate(year, month, startDay);
    }
    return MonthPeriod._(year, month, start, start.addMonths(1));
  }

  /// [date]가 속한 기간.
  factory MonthPeriod.containing(LocalDate date, {int startDay = 1}) {
    _checkStartDay(startDay);
    // 기간의 첫날: date 이전(당일 포함)의 가장 가까운 시작일
    final thisMonthStart = LocalDate(date.year, date.month, startDay);
    final start = date >= thisMonthStart
        ? thisMonthStart
        : thisMonthStart.addMonths(-1);
    final labelMonth = startDay > 15 ? start.addMonths(1) : start;
    return MonthPeriod._(
      labelMonth.year,
      labelMonth.month,
      start,
      start.addMonths(1),
    );
  }

  static void _checkStartDay(int startDay) {
    if (startDay < 1 || startDay > 28) {
      throw ArgumentError.value(startDay, 'startDay', '1–28이어야 한다');
    }
  }

  /// 기간의 이름(연, 월).
  final int year;
  final int month;

  /// 첫날(포함).
  final LocalDate start;

  /// 마지막 날의 다음 날(제외).
  final LocalDate endExclusive;

  /// 마지막 날(포함).
  LocalDate get last => endExclusive.addDays(-1);

  int get days => endExclusive.differenceInDays(start);

  int get _startDay => start.day;

  MonthPeriod get previous => _shift(-1);
  MonthPeriod get next => _shift(1);

  MonthPeriod _shift(int months) {
    final label = LocalDate(year, month, 1).addMonths(months);
    return MonthPeriod(label.year, label.month, startDay: _startDay);
  }

  bool contains(LocalDate date) => date >= start && date < endExclusive;

  /// 'YYYY-MM'.
  String get key => LocalDate(year, month, 1).yearMonth;

  @override
  bool operator ==(Object other) =>
      other is MonthPeriod &&
      other.start == start &&
      other.endExclusive == endExclusive;

  @override
  int get hashCode => Object.hash(start, endExclusive);

  @override
  String toString() => 'MonthPeriod($key, $start…$last)';
}
