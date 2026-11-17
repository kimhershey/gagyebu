import 'package:flutter_test/flutter_test.dart';
import 'package:gagyebu/ai/parsed_transaction.dart';
import 'package:gagyebu/ai/text/category_hints.dart';
import 'package:gagyebu/ai/text/quick_entry_parser.dart';
import 'package:gagyebu/core/local_date.dart';

void main() {
  final today = LocalDate(2026, 11, 17);
  ParsedTransaction? parse(String text) => parseQuickEntry(text, today: today);

  group('parseQuickEntry', () {
    test('설계안의 예시 문장', () {
      final tx = parse('어제 점심 김밥천국 8천원 카드로')!;
      expect(tx.date, LocalDate(2026, 11, 16));
      expect(tx.amount, 8000);
      expect(tx.direction, Direction.outgoing);
      expect(tx.accountText, '카드');
      expect(tx.counterparty, '점심 김밥천국');
    });

    test('날짜가 없으면 오늘', () {
      final tx = parse('점심 12000')!;
      expect(tx.date, today);
      expect(tx.amount, 12000);
      expect(tx.counterparty, '점심');
      expect(tx.warnings, contains(ParseWarning.amountWithoutUnit));
    });

    test('택시 문장', () {
      final tx = parse('어제 택시 8500')!;
      expect(tx.date, LocalDate(2026, 11, 16));
      expect(tx.amount, 8500);
      expect(tx.counterparty, '택시');
    });

    test('한글 금액과 장소 조사', () {
      final tx = parse('지난주 금요일 이마트에서 장보기 3만 5천원 현금')!;
      expect(tx.date, LocalDate(2026, 11, 13));
      expect(tx.amount, 35000);
      expect(tx.accountText, '현금');
      expect(tx.counterparty, '이마트');
      expect(tx.memo, '장보기');
    });

    test('수입 문장', () {
      final tx = parse('11월 10일 월급 3,200,000원')!;
      expect(tx.date, LocalDate(2026, 11, 10));
      expect(tx.amount, 3200000);
      expect(tx.direction, Direction.incoming);
      expect(tx.counterparty, '월급');
    });

    test('남이 보내 준 돈은 수입이다', () {
      expect(parse('친구가 밥값 1만 5천원 보내줌')!.direction, Direction.incoming);
      expect(parse('동생한테 5만원 보냄')!.direction, Direction.outgoing);
    });

    test('시각을 읽는다', () {
      final tx = parse('오늘 12:30 스타벅스 4,500원')!;
      expect(tx.time, '12:30');
      expect(tx.counterparty, '스타벅스');
    });

    test('수량이 섞여도 금액을 고른다', () {
      final tx = parse('커피 2잔 9000원')!;
      expect(tx.amount, 9000);
      expect(tx.counterparty, '커피 2잔');
    });

    test('금액이 없으면 null', () {
      expect(parse('어제 김밥천국'), isNull);
      expect(parse(''), isNull);
      expect(parse('백화점 구경'), isNull);
    });

    test('낱말 속 카드 · 현금은 결제수단으로 떼지 않는다', () {
      final tx = parse('카드값 50만원')!;
      expect(tx.accountText, isNull);
      expect(tx.counterparty, '카드값');
      expect(tx.amount, 500000);
    });
  });

  group('suggestCategoryName', () {
    String? out(String text) => suggestCategoryName(text, Direction.outgoing);
    String? income(String text) =>
        suggestCategoryName(text, Direction.incoming);

    test('가맹점 이름으로 짐작한다', () {
      expect(out('김밥천국 강남점'), '식비');
      expect(out('메가엠지씨커피'), '카페·간식');
      expect(out('세븐일레븐 가평목동'), '생활');
      expect(out('코레일유통서울지사'), '교통');
      expect(out('쿠팡(쿠페이)'), '쇼핑');
      expect(out('한국도로교통'), '교통');
    });
    test('긴 낱말이 이긴다', () {
      expect(out('쿠팡이츠'), '식비');
    });
    test('영문은 대소문자를 가리지 않는다', () {
      expect(out('0908_GOOGLE*i'), '문화·여가');
    });
    test('방향에 따라 사전이 다르다', () {
      expect(out('대출이자'), '금융·보험');
      expect(income('예금결산'), '금융수익');
      expect(income('11월 급여'), '급여');
    });
    test('모르면 null', () {
      expect(out('홍길동'), isNull);
      expect(income('홍길동'), isNull);
    });
  });
}
