/// 시각과 시간대가 없는 달력 날짜.
///
/// 거래 날짜는 사용자 현지 날짜로 저장한다. [DateTime]을 그대로 쓰면 시간대 변환으로
/// 하루가 밀릴 수 있어 날짜 전용 타입을 둔다.
class LocalDate implements Comparable<LocalDate> {
  const LocalDate._(this.year, this.month, this.day);

  /// 존재하는 날짜만 만든다. 2월 30일 같은 값은 [ArgumentError].
  factory LocalDate(int year, int month, int day) {
    final date = tryCreate(year, month, day);
    if (date == null) {
      throw ArgumentError('존재하지 않는 날짜: $year-$month-$day');
    }
    return date;
  }

  /// 존재하지 않는 날짜면 null.
  static LocalDate? tryCreate(int year, int month, int day) {
    if (year < 1 || year > 9999) return null;
    if (month < 1 || month > 12) return null;
    if (day < 1 || day > daysInMonth(year, month)) return null;
    return LocalDate._(year, month, day);
  }

  factory LocalDate.fromDateTime(DateTime dt) =>
      LocalDate._(dt.year, dt.month, dt.day);

  /// 'YYYY-MM-DD'. 형식이 다르거나 없는 날짜면 null.
  static LocalDate? tryParse(String text) {
    final m = _iso.firstMatch(text);
    if (m == null) return null;
    return tryCreate(
      int.parse(m.group(1)!),
      int.parse(m.group(2)!),
      int.parse(m.group(3)!),
    );
  }

  factory LocalDate.parse(String text) {
    final date = tryParse(text);
    if (date == null) throw FormatException('날짜 형식이 아니다', text);
    return date;
  }

  static final _iso = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');

  final int year;
  final int month;
  final int day;

  static int daysInMonth(int year, int month) {
    const days = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
    if (month == 2 && isLeapYear(year)) return 29;
    return days[month - 1];
  }

  static bool isLeapYear(int year) =>
      (year % 4 == 0 && year % 100 != 0) || year % 400 == 0;

  // UTC 자정 기준으로 계산해 서머타임의 영향을 받지 않게 한다.
  DateTime get _utc => DateTime.utc(year, month, day);

  /// 월요일 1 … 일요일 7 ([DateTime.weekday]와 같다).
  int get weekday => _utc.weekday;

  LocalDate addDays(int days) {
    final d = _utc.add(Duration(days: days));
    return LocalDate._(d.year, d.month, d.day);
  }

  /// 달을 더한다. 그 달에 없는 날은 말일로 당긴다(1월 31일 + 1달 = 2월 28일).
  LocalDate addMonths(int months) {
    final total = year * 12 + (month - 1) + months;
    final y = total ~/ 12;
    final m = total % 12 + 1;
    final last = daysInMonth(y, m);
    return LocalDate._(y, m, day > last ? last : day);
  }

  int differenceInDays(LocalDate other) => _utc.difference(other._utc).inDays;

  /// 현지 자정의 [DateTime].
  DateTime toDateTime() => DateTime(year, month, day);

  /// 'YYYY-MM'.
  String get yearMonth =>
      '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}';

  @override
  int compareTo(LocalDate other) {
    if (year != other.year) return year.compareTo(other.year);
    if (month != other.month) return month.compareTo(other.month);
    return day.compareTo(other.day);
  }

  bool operator <(LocalDate other) => compareTo(other) < 0;
  bool operator <=(LocalDate other) => compareTo(other) <= 0;
  bool operator >(LocalDate other) => compareTo(other) > 0;
  bool operator >=(LocalDate other) => compareTo(other) >= 0;

  @override
  bool operator ==(Object other) =>
      other is LocalDate &&
      other.year == year &&
      other.month == month &&
      other.day == day;

  @override
  int get hashCode => Object.hash(year, month, day);

  /// 'YYYY-MM-DD'.
  @override
  String toString() =>
      '${year.toString().padLeft(4, '0')}-'
      '${month.toString().padLeft(2, '0')}-'
      '${day.toString().padLeft(2, '0')}';
}
