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
      expect(tx.counterparty, '김밥천국');
      expect(tx.memo, '점심');
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
      expect(tx.counterparty, '커피');
      expect(tx.memo, '2잔');
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

  group('상대방에는 무엇에 쓴 돈인지만 남긴다', () {
    (String?, String?) names(String text) {
      final tx = parse(text)!;
      return (tx.counterparty, tx.memo);
    }

    test('동작과 조사를 버리고 끼니는 메모로 보낸다', () {
      expect(names('어제 점심 김천감 밥먹음 만원에'), ('김천감', '점심'));
      expect(names('저녁 치킨 시켜먹음 2만원'), ('치킨', '저녁'));
      expect(names('만원 주고 김밥 사먹음'), ('김밥', null));
      expect(names('택시 탔음 8천원'), ('택시', null));
      expect(names('다이소 가서 5천원 씀'), ('다이소', null));
      expect(names('토요일에 미용실 4만원'), ('미용실', null));
    });

    test('결제 · 이체 같은 말은 다른 이름이 있으면 버린다', () {
      expect(names('넷플릭스 구독료 17,000원 결제'), ('넷플릭스 구독료', null));
      expect(names('지난달 25일 월세 55만원 이체'), ('월세', null));
      expect(names('넷플릭스 구독료 17,000원 자동결제됨'), ('넷플릭스 구독료', null));
      expect(names('11월 10일 월급 320만원 들어옴'), ('월급', null));
      expect(names('송금 5만원'), ('송금', null));
    });

    test('끼니만 있으면 그것이 상대방이다', () {
      expect(names('점심 12000'), ('점심', null));
      expect(names('어제 저녁 배달 2만원'), ('저녁 배달', null));
    });

    test('수량과 함께한 사람은 메모로 보낸다', () {
      expect(names('책 두 권 2만 7천원'), ('책', '두 권'));
      expect(names('곶감 한 박스 3만원 샀다'), ('곶감', '한 박스'));
      expect(names('오늘 헬스장 3개월 27만원'), ('헬스장', '3개월'));
      expect(names('어제 저녁에 친구랑 삼겹살 먹었다 4만원'), ('삼겹살', '저녁 친구랑'));
    });

    test('가게와 사람이 드러나면 그것을 상대방으로 둔다', () {
      expect(names('오늘 스타벅스에서 커피마심 4500원'), ('스타벅스', '커피'));
      expect(names('엄마한테 용돈 10만원 받음'), ('엄마', '용돈'));
      expect(names('친구가 밥값 1만 5천원 보내줌'), ('친구', '밥값'));
      expect(names('그저께 엄마가 20만원 보내주심'), ('엄마', null));
    });

    test('동작처럼 끝나는 이름은 건드리지 않는다', () {
      expect(names('수납함 2개 4천원'), ('수납함', '2개'));
      expect(names('홍삼 5만원 삼'), ('홍삼', null));
      expect(names('감 한 박스 2만원'), ('감', '한 박스'));
      expect(names('떡볶이 4천원'), ('떡볶이', null));
      expect(names('요가 수업 12만원'), ('요가 수업', null));
      expect(names('교통카드 충전 5만원'), ('교통카드 충전', null));
    });

    test('남는 말이 없으면 상대방이 없다고 알린다', () {
      final tx = parse('어제 5천원 씀')!;
      expect(tx.counterparty, isNull);
      expect(tx.warnings, contains(ParseWarning.noCounterparty));
    });
  });
}
