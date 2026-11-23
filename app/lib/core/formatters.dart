/// 금액과 날짜를 화면에 보이는 글로 바꾼다.
library;

import '../domain/month_period.dart';
import 'local_date.dart';

/// 12500 → '12,500'
String formatNumber(int value) {
  final digits = value.abs().toString();
  final buffer = StringBuffer(value < 0 ? '-' : '');
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}

/// 12500 → '12,500원'
String won(int value) => '${formatNumber(value)}원';

/// 수지처럼 부호가 뜻을 갖는 금액. 12500 → '+12,500원'
String signedWon(int value) =>
    value > 0 ? '+${formatNumber(value)}원' : '${formatNumber(value)}원';

/// 입력란의 글자에서 금액을 읽는다. '12,500원' → 12500. 숫자가 없으면 null.
int? parseAmountInput(String text) {
  final digits = text.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.isEmpty) return null;
  return int.tryParse(digits);
}

const _weekdays = ['월', '화', '수', '목', '금', '토', '일'];

/// '월' … '일'
String weekdayName(LocalDate date) => _weekdays[date.weekday - 1];

/// '11월 16일'
String monthDay(LocalDate date) => '${date.month}월 ${date.day}일';

/// '11월 16일 (월)'
String dayLabel(LocalDate date) => '${monthDay(date)} (${weekdayName(date)})';

/// '2026년 11월 16일 (월)'
String fullDateLabel(LocalDate date) => '${date.year}년 ${dayLabel(date)}';

/// '2026년 11월'
String periodLabel(MonthPeriod period) => '${period.year}년 ${period.month}월';

/// 기간이 달력의 한 달과 다르면 '10월 25일 – 11월 24일', 같으면 null.
String? periodRangeLabel(MonthPeriod period) {
  if (period.start.day == 1) return null;
  return '${monthDay(period.start)} – ${monthDay(period.last)}';
}

/// 0.256 → '26%'
String percent(double ratio) => '${(ratio * 100).round()}%';

/// '오후 3:07' 꼴의 시각.
String formatTimeOfDay(DateTime time) {
  final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
  final minute = time.minute.toString().padLeft(2, '0');
  return '${time.hour < 12 ? '오전' : '오후'} $hour:$minute';
}
