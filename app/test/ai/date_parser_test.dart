import 'package:flutter_test/flutter_test.dart';
import 'package:gagyebu/ai/text/date_parser.dart';
import 'package:gagyebu/core/local_date.dart';

void main() {
  // 2026-11-17은 화요일이다.
  final today = LocalDate(2026, 11, 17);

  group('resolveMonthDay', () {
    test('지난 날짜는 올해', () {
      expect(resolveMonthDay(11, 16, today), LocalDate(2026, 11, 16));
      expect(resolveMonthDay(1, 9, today), LocalDate(2026, 1, 9));
    });
    test('오늘과 내일까지는 올해', () {
      expect(resolveMonthDay(11, 17, today), LocalDate(2026, 11, 17));
      expect(resolveMonthDay(11, 18, today), LocalDate(2026, 11, 18));
    });
    test('그 뒤 날짜는 지난해', () {
      expect(resolveMonthDay(11, 19, today), LocalDate(2025, 11, 19));
      expect(resolveMonthDay(12, 11, today), LocalDate(2025, 12, 11));
    });
    test('2월 29일은 가장 가까운 윤년', () {
      expect(resolveMonthDay(2, 29, today), LocalDate(2024, 2, 29));
    });
    test('없는 날짜는 null', () {
      expect(resolveMonthDay(2, 30, today), isNull);
      expect(resolveMonthDay(13, 1, today), isNull);
    });
    test('연초에는 지난해 12월로 넘어간다', () {
      expect(
        resolveMonthDay(12, 31, LocalDate(2027, 1, 2)),
        LocalDate(2026, 12, 31),
      );
    });
  });

  group('formatTime', () {
    test('두 자리로 맞춘다', () => expect(formatTime(4, 5), '04:05'));
    test('범위를 벗어나면 null', () {
      expect(formatTime(24, 0), isNull);
      expect(formatTime(12, 60), isNull);
    });
  });

  group('findDateExpression', () {
    LocalDate? find(String text) => findDateExpression(text, today)?.date;

    test('상대 날짜 낱말', () {
      expect(find('오늘 점심'), today);
      expect(find('어제 택시 8500'), LocalDate(2026, 11, 16));
      expect(find('그저께 저녁'), LocalDate(2026, 11, 15));
      expect(find('엊그제 마트'), LocalDate(2026, 11, 15));
    });
    test('N일 전', () {
      expect(find('3일 전 주유'), LocalDate(2026, 11, 14));
      expect(find('사흘 전 주유'), LocalDate(2026, 11, 14));
      expect(find('이틀전'), LocalDate(2026, 11, 15));
    });
    test('주와 요일', () {
      expect(find('지난주 금요일 회식'), LocalDate(2026, 11, 13));
      expect(find('이번 주 월요일'), LocalDate(2026, 11, 16));
      expect(find('지지난주 일요일'), LocalDate(2026, 11, 8));
    });
    test('주를 밝히지 않은 요일은 가장 가까운 지난 그 요일', () {
      // 오늘은 화요일
      expect(find('토요일에 미용실'), LocalDate(2026, 11, 14));
      expect(find('월요일 점심'), LocalDate(2026, 11, 16));
      expect(find('화요일 저녁'), today);
      expect(find('수요일 회식'), LocalDate(2026, 11, 11));
    });
    test('지난달 N일', () {
      expect(find('지난달 25일 월세'), LocalDate(2026, 10, 25));
      expect(find('이번 달 1일'), LocalDate(2026, 11, 1));
      expect(find('지난달 31일'), LocalDate(2026, 10, 31));
    });
    test('월 · 일 표기', () {
      expect(find('11월 3일 병원'), LocalDate(2026, 11, 3));
      expect(find('12월 25일 선물'), LocalDate(2025, 12, 25));
      expect(find('2025년 3월 1일'), LocalDate(2025, 3, 1));
      expect(find('11/3 병원'), LocalDate(2026, 11, 3));
      expect(find('2026-11-01 관리비'), LocalDate(2026, 11, 1));
    });
    test('날짜 표현이 없으면 null', () {
      expect(find('점심 12000'), isNull);
      expect(find('김밥천국 8천원'), isNull);
    });
    test('찾은 위치를 돌려준다', () {
      final found = findDateExpression('점심 어제 8천원', today)!;
      expect(found.text, '어제');
      expect('점심 어제 8천원'.substring(found.start, found.end), '어제');
    });
  });

  group('LocalDate', () {
    test('없는 날짜는 만들 수 없다', () {
      expect(LocalDate.tryCreate(2026, 2, 29), isNull);
      expect(LocalDate.tryCreate(2024, 2, 29), isNotNull);
      expect(() => LocalDate(2026, 4, 31), throwsArgumentError);
    });
    test('문자열 왕복', () {
      expect(LocalDate.parse('2026-01-05').toString(), '2026-01-05');
      expect(LocalDate.tryParse('2026-1-5'), isNull);
      expect(LocalDate.tryParse('2026-02-30'), isNull);
    });
    test('날짜 더하기와 요일', () {
      expect(LocalDate(2026, 12, 31).addDays(1), LocalDate(2027, 1, 1));
      expect(LocalDate(2026, 3, 1).addDays(-1), LocalDate(2026, 2, 28));
      expect(today.weekday, DateTime.tuesday);
    });
    test('달 더하기는 말일로 당긴다', () {
      expect(LocalDate(2026, 1, 31).addMonths(1), LocalDate(2026, 2, 28));
      expect(LocalDate(2026, 11, 15).addMonths(2), LocalDate(2027, 1, 15));
      expect(LocalDate(2026, 1, 15).addMonths(-1), LocalDate(2025, 12, 15));
    });
    test('비교와 차이', () {
      expect(LocalDate(2026, 1, 1) < LocalDate(2026, 1, 2), isTrue);
      expect(LocalDate(2026, 3, 1).differenceInDays(LocalDate(2026, 2, 1)), 28);
      expect(LocalDate(2026, 11, 5).yearMonth, '2026-11');
    });
  });
}
