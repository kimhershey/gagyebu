/// 가계부에 묻는 문장에서 읽어 낸 조건(`docs/SPEC.md` 7.15).
///
/// 조건은 기호와 이름뿐이다. 날짜 범위는 코드가 계산하고, 숫자는 SQL이 센다. 모델은
/// 조건을 고르는 데까지만 쓰인다.
library;

import '../../core/local_date.dart';
import '../../domain/enums.dart';
import '../../domain/month_period.dart';

/// 날짜 범위. [from] 이상 [toExclusive] 미만.
class DateRange {
  const DateRange(this.from, this.toExclusive);

  final LocalDate from;
  final LocalDate toExclusive;

  /// 마지막 날(포함).
  LocalDate get last => toExclusive.addDays(-1);

  int get days => toExclusive.differenceInDays(from);

  @override
  bool operator ==(Object other) =>
      other is DateRange &&
      other.from == from &&
      other.toExclusive == toExclusive;

  @override
  int get hashCode => Object.hash(from, toExclusive);

  @override
  String toString() => '$from…$last';
}

/// 기간의 종류.
enum QueryPeriodKind {
  today,
  yesterday,
  thisWeek,
  lastWeek,
  thisMonth,
  lastMonth,
  thisYear,
  lastYear,

  /// 'N월'. 연도가 없으면 오늘 이전의 가장 가까운 N월이다.
  month,

  /// 오늘까지 N일.
  recentDays,

  /// 오늘까지 N개월.
  recentMonths,

  /// 하루('11월 5일', '그저께').
  day,
}

/// 기간을 가리키는 기호. 날짜 범위는 [resolve]가 오늘과 월 시작일로 계산한다.
///
/// 모델도 기간을 날짜가 아니라 이 기호로 답한다. 소형 모델에 날짜 계산을 시키면
/// 틀리기 때문이다(`eval/README.md`).
class QueryPeriod {
  const QueryPeriod._(this.kind, {this.number, this.year, this.date});

  const QueryPeriod.today() : this._(QueryPeriodKind.today);
  const QueryPeriod.yesterday() : this._(QueryPeriodKind.yesterday);
  const QueryPeriod.thisWeek() : this._(QueryPeriodKind.thisWeek);
  const QueryPeriod.lastWeek() : this._(QueryPeriodKind.lastWeek);
  const QueryPeriod.thisMonth() : this._(QueryPeriodKind.thisMonth);
  const QueryPeriod.lastMonth() : this._(QueryPeriodKind.lastMonth);
  const QueryPeriod.thisYear() : this._(QueryPeriodKind.thisYear);
  const QueryPeriod.lastYear() : this._(QueryPeriodKind.lastYear);

  /// [month]월. [year]를 주지 않으면 오늘 이전의 가장 가까운 그 달이다.
  const QueryPeriod.month(int month, {int? year})
    : this._(QueryPeriodKind.month, number: month, year: year);

  /// 오늘을 넣어 [days]일.
  const QueryPeriod.recentDays(int days)
    : this._(QueryPeriodKind.recentDays, number: days);

  /// 오늘을 넣어 [months]개월.
  const QueryPeriod.recentMonths(int months)
    : this._(QueryPeriodKind.recentMonths, number: months);

  /// 하루.
  const QueryPeriod.day(LocalDate date)
    : this._(QueryPeriodKind.day, date: date);

  final QueryPeriodKind kind;

  /// 달 이름(1–12)이나 날 수 · 개월 수.
  final int? number;

  /// [QueryPeriodKind.month]의 연도. 문장에 연도가 있었을 때만 있다.
  final int? year;

  /// [QueryPeriodKind.day]의 날짜.
  final LocalDate? date;

  /// 모델에 고르게 하는 기호. 모두 [fromSymbol]이 읽는다.
  static const modelSymbols = <String>[
    'today',
    'yesterday',
    'this_week',
    'last_week',
    'this_month',
    'last_month',
    'this_year',
    'last_year',
    'last_7_days',
    'last_30_days',
    'last_90_days',
    'month_1',
    'month_2',
    'month_3',
    'month_4',
    'month_5',
    'month_6',
    'month_7',
    'month_8',
    'month_9',
    'month_10',
    'month_11',
    'month_12',
  ];

  /// 기호.
  String get symbol => switch (kind) {
    QueryPeriodKind.today => 'today',
    QueryPeriodKind.yesterday => 'yesterday',
    QueryPeriodKind.thisWeek => 'this_week',
    QueryPeriodKind.lastWeek => 'last_week',
    QueryPeriodKind.thisMonth => 'this_month',
    QueryPeriodKind.lastMonth => 'last_month',
    QueryPeriodKind.thisYear => 'this_year',
    QueryPeriodKind.lastYear => 'last_year',
    QueryPeriodKind.month =>
      year == null ? 'month_$number' : 'month_${year}_$number',
    QueryPeriodKind.recentDays => 'last_${number}_days',
    QueryPeriodKind.recentMonths => 'last_${number}_months',
    QueryPeriodKind.day => 'day_$date',
  };

  /// 기호를 읽는다. 모르는 기호면 null.
  static QueryPeriod? fromSymbol(String symbol) {
    switch (symbol) {
      case 'today':
        return const QueryPeriod.today();
      case 'yesterday':
        return const QueryPeriod.yesterday();
      case 'this_week':
        return const QueryPeriod.thisWeek();
      case 'last_week':
        return const QueryPeriod.lastWeek();
      case 'this_month':
        return const QueryPeriod.thisMonth();
      case 'last_month':
        return const QueryPeriod.lastMonth();
      case 'this_year':
        return const QueryPeriod.thisYear();
      case 'last_year':
        return const QueryPeriod.lastYear();
    }
    final month = _monthSymbol.firstMatch(symbol);
    if (month != null) {
      final number = int.parse(month.group(2)!);
      if (number < 1 || number > 12) return null;
      final year = month.group(1);
      return QueryPeriod.month(
        number,
        year: year == null ? null : int.parse(year),
      );
    }
    final recent = _recentSymbol.firstMatch(symbol);
    if (recent != null) {
      final number = int.parse(recent.group(1)!);
      if (number < 1) return null;
      return recent.group(2) == 'days'
          ? QueryPeriod.recentDays(number)
          : QueryPeriod.recentMonths(number);
    }
    if (symbol.startsWith('day_')) {
      final date = LocalDate.tryParse(symbol.substring(4));
      return date == null ? null : QueryPeriod.day(date);
    }
    return null;
  }

  static final _monthSymbol = RegExp(r'^month_(?:(\d{4})_)?(\d{1,2})$');
  static final _recentSymbol = RegExp(r'^last_(\d{1,4})_(days|months)$');

  /// 화면에 보이는 이름.
  String get label => switch (kind) {
    QueryPeriodKind.today => '오늘',
    QueryPeriodKind.yesterday => '어제',
    QueryPeriodKind.thisWeek => '이번 주',
    QueryPeriodKind.lastWeek => '지난주',
    QueryPeriodKind.thisMonth => '이번 달',
    QueryPeriodKind.lastMonth => '지난달',
    QueryPeriodKind.thisYear => '올해',
    QueryPeriodKind.lastYear => '작년',
    QueryPeriodKind.month => year == null ? '$number월' : '$year년 $number월',
    QueryPeriodKind.recentDays => '최근 $number일',
    QueryPeriodKind.recentMonths => '최근 $number개월',
    QueryPeriodKind.day => '${date!.month}월 ${date!.day}일',
  };

  /// 날짜 범위로 바꾼다. 달과 해는 월 시작일([startDay])을 반영한 가계부의 달로 센다.
  ///
  /// 주는 월요일에 시작한다. 해는 그 해의 이름이 붙은 열두 달이다(월 시작일이 25일이면
  /// 2026년은 2025-12-25부터 2026-12-24까지다).
  DateRange resolve({required LocalDate today, int startDay = 1}) {
    final current = MonthPeriod.containing(today, startDay: startDay);
    DateRange ofMonth(MonthPeriod p) => DateRange(p.start, p.endExclusive);
    DateRange ofYear(int y) => DateRange(
      MonthPeriod(y, 1, startDay: startDay).start,
      MonthPeriod(y, 12, startDay: startDay).endExclusive,
    );
    final tomorrow = today.addDays(1);
    final monday = today.addDays(1 - today.weekday);
    switch (kind) {
      case QueryPeriodKind.today:
        return DateRange(today, tomorrow);
      case QueryPeriodKind.yesterday:
        return DateRange(today.addDays(-1), today);
      case QueryPeriodKind.thisWeek:
        return DateRange(monday, monday.addDays(7));
      case QueryPeriodKind.lastWeek:
        return DateRange(monday.addDays(-7), monday);
      case QueryPeriodKind.thisMonth:
        return ofMonth(current);
      case QueryPeriodKind.lastMonth:
        return ofMonth(current.previous);
      case QueryPeriodKind.thisYear:
        return ofYear(current.year);
      case QueryPeriodKind.lastYear:
        return ofYear(current.year - 1);
      case QueryPeriodKind.month:
        // 연도가 없으면 아직 오지 않은 달은 작년의 그 달로 본다('12월'을 11월에 물으면
        // 작년 12월이다).
        final y =
            year ??
            (number! <= current.month ? current.year : current.year - 1);
        return ofMonth(MonthPeriod(y, number!, startDay: startDay));
      case QueryPeriodKind.recentDays:
        return DateRange(tomorrow.addDays(-number!), tomorrow);
      case QueryPeriodKind.recentMonths:
        return DateRange(today.addMonths(-number!).addDays(1), tomorrow);
      case QueryPeriodKind.day:
        return DateRange(date!, date!.addDays(1));
    }
  }

  @override
  bool operator ==(Object other) =>
      other is QueryPeriod && other.symbol == symbol;

  @override
  int get hashCode => symbol.hashCode;

  @override
  String toString() => 'QueryPeriod($symbol)';
}

/// 집계 방식.
enum QueryAggregation {
  sum('sum', '합계'),
  count('count', '건수'),
  average('avg', '평균'),
  list('list', '목록');

  const QueryAggregation(this.code, this.label);

  /// 조건 JSON의 `agg` 값.
  final String code;

  /// 화면에 보이는 이름.
  final String label;

  static QueryAggregation? fromCode(Object? code) {
    for (final value in values) {
      if (value.code == code) return value;
    }
    return null;
  }
}

/// 조건을 읽을 때 알려 주는 분류 하나. 이름과 종류만 쓴다.
class QueryCategory {
  const QueryCategory(this.name, this.kind);

  final String name;
  final CategoryKind kind;
}

/// 조회 조건.
class LedgerQuery {
  const LedgerQuery({
    required this.period,
    required this.range,
    required this.aggregation,
    this.category,
    this.party,
    this.type,
    this.perDay = false,
    this.periodAssumed = false,
    this.aiModel,
  });

  /// 기간의 기호.
  final QueryPeriod period;

  /// [period]를 오늘과 월 시작일로 푼 날짜 범위.
  final DateRange range;

  /// 분류 이름. 가계부에 있는 이름 가운데 하나다.
  final String? category;

  /// 상대방이나 내용에 들어 있어야 하는 말.
  final String? party;

  /// 거래 종류. null이면 가리지 않는다.
  final TxType? type;

  final QueryAggregation aggregation;

  /// 평균을 건당이 아니라 하루로 나눈다('하루 평균').
  final bool perDay;

  /// 문장에 기간이 없어 이번 달로 봤다.
  final bool periodAssumed;

  /// 모델이 조건을 읽었으면 그 모델의 이름. 규칙이 읽었으면 null.
  final String? aiModel;

  /// 조건 JSON(`docs/SPEC.md` 7.15). 모델이 답하는 꼴과 같다.
  Map<String, Object?> toJson() => {
    'period': period.symbol,
    'category': category,
    'party': party,
    'type': type?.code,
    'agg': aggregation.code,
  };

  @override
  String toString() => 'LedgerQuery(${toJson()}, $range)';
}
