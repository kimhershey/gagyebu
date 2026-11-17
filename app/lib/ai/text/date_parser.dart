/// 날짜 표기를 달력 날짜로 바꾸는 규칙.
///
/// 날짜 계산은 LLM에 맡기지 않는다. 결제 문자는 대부분 연도 없이 MM/DD로 오므로
/// 오늘을 기준으로 가장 가까운 과거 날짜로 채운다.
library;

import '../../core/local_date.dart';

/// 연도 없는 월 · 일을 날짜로 푼다.
///
/// [today] 이후의 날짜는 지난해로 본다. 다만 시간대 차이로 하루 앞선 표기가 올 수 있어
/// 내일까지는 올해로 받아들인다. 없는 날짜(2월 30일)면 null.
LocalDate? resolveMonthDay(int month, int day, LocalDate today) {
  final limit = today.addDays(1);
  for (var year = today.year; year >= today.year - 4; year--) {
    final candidate = LocalDate.tryCreate(year, month, day);
    // 2월 29일처럼 그 해에 없는 날짜면 이전 해를 더 본다.
    if (candidate == null) continue;
    if (candidate <= limit) return candidate;
  }
  return null;
}

/// 시와 분을 'HH:mm'으로 만든다. 범위를 벗어나면 null.
String? formatTime(int hour, int minute) {
  if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
  return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}

/// 문장에서 찾은 날짜 표현.
class DateExpression {
  const DateExpression({
    required this.date,
    required this.start,
    required this.end,
    required this.text,
  });

  final LocalDate date;
  final int start;
  final int end;
  final String text;
}

/// 자연어 문장에서 날짜 표현을 하나 찾는다. 없으면 null.
///
/// 받아들이는 표현: 오늘 · 어제 · 그제 · 그저께 · 엊그제 · 그끄저께, 'N일 전',
/// '지난주 금요일', '이번 주 월요일', '토요일', '지난달 25일', 'M월 D일', 'M/D',
/// 'YYYY-MM-DD'.
DateExpression? findDateExpression(String text, LocalDate today) {
  final all = findDateExpressions(text, today);
  return all.isEmpty ? null : all.first;
}

/// 문장의 날짜 표현을 모두 찾아 나온 순서대로 돌려준다. 겹치는 표현은 먼저 시작한 것을 쓴다.
///
/// 결제 문자의 'MM/DD', 'MM.DD HH:MM', 'YYYY/MM/DD'도 여기서 읽는다. 날짜를 읽는 일은
/// 규칙이 하고, 모델은 후보가 여럿일 때 고르기만 한다.
List<DateExpression> findDateExpressions(String text, LocalDate today) {
  final found = <DateExpression>[];

  void offer(Match m, LocalDate? date) {
    if (date == null) return;
    found.add(
      DateExpression(date: date, start: m.start, end: m.end, text: m.group(0)!),
    );
  }

  for (final m in _isoDate.allMatches(text)) {
    offer(
      m,
      LocalDate.tryCreate(
        int.parse(m.group(1)!),
        int.parse(m.group(2)!),
        int.parse(m.group(3)!),
      ),
    );
  }

  for (final m in _relativeWord.allMatches(text)) {
    offer(m, today.addDays(-_relativeWords[m.group(0)!]!));
  }

  for (final m in _daysAgo.allMatches(text)) {
    final n = _parseCount(m.group(1)!);
    if (n != null && n <= 3660) offer(m, today.addDays(-n));
  }

  for (final m in _weekdayOfWeek.allMatches(text)) {
    final weekOffset = _weekOffsets[m.group(1)!.replaceAll(' ', '')]!;
    final weekday = _weekdays[m.group(2)!]!;
    // 그 주의 월요일을 찾고 요일만큼 더한다.
    final monday = today.addDays(-(today.weekday - 1) + weekOffset * 7);
    offer(m, monday.addDays(weekday - 1));
  }

  // 주를 밝히지 않은 요일('토요일에 미용실')은 오늘 이전의 가장 가까운 그 요일이다.
  for (final m in _bareWeekday.allMatches(text)) {
    final weekday = _weekdays[m.group(1)!]!;
    offer(m, today.addDays(-((today.weekday - weekday) % 7)));
  }

  for (final m in _dayOfLastMonth.allMatches(text)) {
    final monthOffset = _monthOffsets[m.group(1)!.replaceAll(' ', '')]!;
    final day = int.parse(m.group(2)!);
    final base = LocalDate(today.year, today.month, 1).addMonths(monthOffset);
    offer(m, LocalDate.tryCreate(base.year, base.month, day));
  }

  for (final m in _monthDayKorean.allMatches(text)) {
    final year = m.group(1);
    final month = int.parse(m.group(2)!);
    final day = int.parse(m.group(3)!);
    if (year != null) {
      offer(m, LocalDate.tryCreate(int.parse(year), month, day));
    } else {
      offer(m, resolveMonthDay(month, day, today));
    }
  }

  for (final m in _monthDaySlash.allMatches(text)) {
    offer(
      m,
      resolveMonthDay(int.parse(m.group(1)!), int.parse(m.group(2)!), today),
    );
  }

  // 앱 알림의 '11.09 16:41'. 소수(220.00)와 헷갈리지 않게 뒤에 시각이 올 때만 읽는다.
  for (final m in _monthDayDot.allMatches(text)) {
    offer(
      m,
      resolveMonthDay(int.parse(m.group(1)!), int.parse(m.group(2)!), today),
    );
  }

  // 먼저 시작한 것부터, 같은 자리면 긴 것부터. 앞의 것과 겹치면 버린다.
  found.sort((a, b) {
    final byStart = a.start.compareTo(b.start);
    return byStart != 0 ? byStart : b.end.compareTo(a.end);
  });
  final result = <DateExpression>[];
  for (final e in found) {
    if (result.isEmpty || e.start >= result.last.end) result.add(e);
  }
  return result;
}

int? _parseCount(String text) {
  final digits = int.tryParse(text);
  if (digits != null) return digits;
  return _hangulCounts[text];
}

final _isoDate = RegExp(r'(?<!\d)(\d{4})[-./](\d{1,2})[-./](\d{1,2})(?!\d)');

const _relativeWords = <String, int>{
  '오늘': 0,
  '어제': 1,
  '어저께': 1,
  '그제': 2,
  '그저께': 2,
  '엊그제': 2,
  '엊그저께': 2,
  '그끄제': 3,
  '그끄저께': 3,
};

// 긴 낱말부터 맞춰야 '그저께'가 '그제'보다 먼저 잡힌다.
final _relativeWord = RegExp('엊그저께|그끄저께|그저께|어저께|엊그제|그끄제|그제|어제|오늘');

final _daysAgo = RegExp(
  r'(\d{1,4}|하루|이틀|사흘|나흘|닷새|엿새|이레|여드레|아흐레|열흘)\s?(?:일\s?)?전',
);

const _hangulCounts = <String, int>{
  '하루': 1,
  '이틀': 2,
  '사흘': 3,
  '나흘': 4,
  '닷새': 5,
  '엿새': 6,
  '이레': 7,
  '여드레': 8,
  '아흐레': 9,
  '열흘': 10,
};

final _weekdayOfWeek = RegExp(
  r'(지지난 ?주|저저번 ?주|지난 ?주|저번 ?주|이번 ?주)\s?([월화수목금토일])요일',
);

const _weekOffsets = <String, int>{
  '지지난주': -2,
  '저저번주': -2,
  '지난주': -1,
  '저번주': -1,
  '이번주': 0,
};

const _weekdays = <String, int>{
  '월': 1,
  '화': 2,
  '수': 3,
  '목': 4,
  '금': 5,
  '토': 6,
  '일': 7,
};

// '지난주 금요일'은 위의 규칙이 더 앞에서 시작해 먼저 잡힌다.
final _bareWeekday = RegExp(r'(?<![가-힣])([월화수목금토일])요일');

final _dayOfLastMonth = RegExp(r'(지지난 ?달|지난 ?달|저번 ?달|이번 ?달)\s?(\d{1,2})일');

const _monthOffsets = <String, int>{'지지난달': -2, '지난달': -1, '저번달': -1, '이번달': 0};

final _monthDayKorean = RegExp(r'(?:(\d{4})년\s?)?(\d{1,2})월\s?(\d{1,2})일');

final _monthDaySlash = RegExp(r'(?<![\d/.])(\d{1,2})/(\d{1,2})(?![\d/])');

final _monthDayDot = RegExp(
  r'(?<![\d.])(\d{1,2})\.(\d{1,2})(?=\s+\d{1,2}:\d{2})',
);
