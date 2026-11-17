import 'package:flutter_test/flutter_test.dart';
import 'package:gagyebu/ai/text/amount_parser.dart';

void main() {
  group('parseKoreanAmount', () {
    const cases = <String, int?>{
      '12,500원': 12500,
      '12500': 12500,
      '3만 5천원': 35000,
      '3만5천': 35000,
      '8천원': 8000,
      '1.5만': 15000,
      '1.5만원': 15000,
      '2억 3천만': 230000000,
      '2억3천5백만원': 235000000,
      '만원': 10000,
      '천원': 1000,
      '십만원': 100000,
      '삼만오천원': 35000,
      '오천원': 5000,
      '1만 2500원': 12500,
      '1만2,500': 12500,
      '100만': 1000000,
      '₩7,100': 7100,
      // 금액이 아닌 것
      '': null,
      '22.00': null,
      '1.23456만': null,
      '3만 가지': null,
      'abc': null,
    };
    cases.forEach((input, expected) {
      test('"$input" → $expected', () {
        expect(parseKoreanAmount(input), expected);
      });
    });
  });

  group('parseDigits', () {
    test('쉼표를 뗀다', () => expect(parseDigits('1,234,567'), 1234567));
    test('숫자가 아니면 null', () => expect(parseDigits('12a'), isNull));
    test('빈 문자열은 null', () => expect(parseDigits(''), isNull));
  });

  group('findAmountCandidates', () {
    List<int> values(String text) => [
      for (final c in findAmountCandidates(text)) c.value,
    ];

    test('문장 속 한글 금액', () {
      expect(values('어제 점심 김밥천국 8천원 카드로'), [8000]);
      expect(values('택시 3만 5천원'), [35000]);
      expect(values('점심 12000'), [12000]);
    });

    test('낱말 속 단위 글자는 금액이 아니다', () {
      expect(values('백화점에서 천안 가는 길'), isEmpty);
      expect(values('김밥천국 만두'), isEmpty);
    });

    test('날짜 · 시각 · 카드 끝자리는 후보가 아니다', () {
      final found = findAmountCandidates(
        '신한카드(1234)승인 홍*동 12,500원(일시불) 11/16 12:31 김밥천국 누적 345,600원',
      );
      expect([for (final c in found) c.value], [12500, 345600]);
      expect(found[0].role, AmountRole.amount);
      expect(found[1].role, AmountRole.cumulative);
    });

    test('잔액은 역할을 따로 붙인다', () {
      final found = findAmountCandidates('출금100,000 잔액900,000원');
      expect([for (final c in found) c.value], [100000, 900000]);
      expect(found[0].role, AmountRole.amount);
      expect(found[1].role, AmountRole.balance);
    });

    test('수량 · 기간 단위가 붙은 숫자는 금액이 아니다', () {
      expect(values('커피 2잔 9000원'), [9000]);
      expect(values('3개월 할부 120,000원'), [120000]);
      expect(values('11월 16일 5000원'), [5000]);
    });

    test('낱말에 붙은 숫자는 수량이나 이름의 일부다', () {
      expect(values('생수 2박스 18,900원'), [18900]);
      expect(values('11번가 23,000원'), [23000]);
      expect(values('이마트24 4,800원'), [4800]);
      expect(values('24시간 주차 12000'), [12000]);
      expect(values('내용 당근143'), isEmpty);
    });

    test('조사나 거래 낱말이 붙은 숫자는 금액이다', () {
      expect(values('커피 4500에 삼'), [4500]);
      expect(values('커피4500'), [4500]);
      expect(values('10000입금'), [10000]);
      expect(values('입금500 잔액900'), [500, 900]);
    });

    test('포인트는 금액이 아니다', () {
      expect(values('포인트 3,000점이 소멸될 예정입니다'), isEmpty);
      expect(values('500포인트 적립'), isEmpty);
      // '점심'의 '점'은 단위가 아니다.
      expect(values('8000 점심'), [8000]);
    });

    test('원이 붙었는지 알려 준다', () {
      final found = findAmountCandidates('점심 12000 저녁 8,000원');
      expect(found.map((c) => c.hasWonSuffix), [false, true]);
    });
  });
}
