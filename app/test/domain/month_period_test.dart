import 'package:flutter_test/flutter_test.dart';
import 'package:gagyebu/core/local_date.dart';
import 'package:gagyebu/domain/month_period.dart';

void main() {
  group('월 시작일 1일', () {
    test('달력의 한 달과 같다', () {
      final p = MonthPeriod(2026, 11);
      expect(p.start, LocalDate(2026, 11, 1));
      expect(p.endExclusive, LocalDate(2026, 12, 1));
      expect(p.last, LocalDate(2026, 11, 30));
      expect(p.days, 30);
      expect(p.key, '2026-11');
    });
    test('연말을 넘어 이동한다', () {
      final p = MonthPeriod(2026, 12);
      expect(p.next.key, '2027-01');
      expect(p.next.start, LocalDate(2027, 1, 1));
      expect(MonthPeriod(2026, 1).previous.key, '2025-12');
    });
    test('날짜가 속한 기간', () {
      final p = MonthPeriod.containing(LocalDate(2026, 2, 28));
      expect(p, MonthPeriod(2026, 2));
      expect(p.days, 28);
    });
  });

  group('월 시작일 25일(급여일 기준)', () {
    test('기간이 끝나는 달의 이름을 쓴다', () {
      final p = MonthPeriod(2026, 11, startDay: 25);
      expect(p.start, LocalDate(2026, 10, 25));
      expect(p.last, LocalDate(2026, 11, 24));
      expect(p.key, '2026-11');
    });
    test('날짜가 속한 기간', () {
      expect(
        MonthPeriod.containing(LocalDate(2026, 11, 24), startDay: 25).key,
        '2026-11',
      );
      expect(
        MonthPeriod.containing(LocalDate(2026, 11, 25), startDay: 25).key,
        '2026-12',
      );
      expect(
        MonthPeriod.containing(LocalDate(2026, 12, 31), startDay: 25).key,
        '2027-01',
      );
    });
    test('앞뒤 기간이 빈틈없이 이어진다', () {
      var p = MonthPeriod(2026, 1, startDay: 25);
      for (var i = 0; i < 24; i++) {
        final next = p.next;
        expect(next.start, p.endExclusive, reason: '$p → $next');
        expect(next.previous, p);
        p = next;
      }
    });
  });

  group('월 시작일 10일', () {
    test('기간이 시작하는 달의 이름을 쓴다', () {
      final p = MonthPeriod(2026, 11, startDay: 10);
      expect(p.start, LocalDate(2026, 11, 10));
      expect(p.last, LocalDate(2026, 12, 9));
      expect(
        MonthPeriod.containing(LocalDate(2026, 11, 9), startDay: 10).key,
        '2026-10',
      );
    });
  });

  test('모든 날짜는 정확히 한 기간에 속한다', () {
    for (final startDay in [1, 5, 15, 16, 25, 28]) {
      var date = LocalDate(2025, 12, 1);
      final end = LocalDate(2027, 2, 1);
      while (date < end) {
        final p = MonthPeriod.containing(date, startDay: startDay);
        expect(p.contains(date), isTrue, reason: '$date in $p');
        expect(p.previous.contains(date), isFalse);
        expect(p.next.contains(date), isFalse);
        expect(MonthPeriod(p.year, p.month, startDay: startDay), p);
        date = date.addDays(1);
      }
    }
  });

  test('시작일은 1–28만 받는다', () {
    expect(() => MonthPeriod(2026, 1, startDay: 0), throwsArgumentError);
    expect(() => MonthPeriod(2026, 1, startDay: 29), throwsArgumentError);
  });
}
