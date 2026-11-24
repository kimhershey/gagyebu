import 'package:flutter_test/flutter_test.dart';
import 'package:gagyebu/ai/query/ledger_query.dart';
import 'package:gagyebu/ai/query/query_intent.dart';
import 'package:gagyebu/ai/query/query_parser.dart';
import 'package:gagyebu/core/local_date.dart';
import 'package:gagyebu/domain/default_seed.dart';
import 'package:gagyebu/domain/enums.dart';

/// 2026-11-17은 화요일이다.
final today = LocalDate(2026, 11, 17);

final categories = <QueryCategory>[
  for (final name in defaultExpenseCategories)
    QueryCategory(name, CategoryKind.expense),
  for (final name in defaultIncomeCategories)
    QueryCategory(name, CategoryKind.income),
];

/// 문장 하나에서 읽혀야 하는 조건.
class _Case {
  const _Case(
    this.text, {
    required this.period,
    required this.agg,
    this.category,
    this.party,
    this.type = TxType.expense,
    this.perDay = false,
    this.assumed = false,
  });

  final String text;
  final String period;
  final QueryAggregation agg;
  final String? category;
  final String? party;
  final TxType? type;
  final bool perDay;
  final bool assumed;
}

const _sum = QueryAggregation.sum;
const _count = QueryAggregation.count;
const _avg = QueryAggregation.average;
const _list = QueryAggregation.list;

const _cases = <_Case>[
  _Case('지난달 식비 얼마야?', period: 'last_month', agg: _sum, category: '식비'),
  _Case(
    '이번 달 카페 몇 번 갔어?',
    period: 'this_month',
    agg: _count,
    category: '카페·간식',
  ),
  _Case('어제 뭐 샀지?', period: 'yesterday', agg: _list),
  _Case('올해 수입 합계', period: 'this_year', agg: _sum, type: TxType.income),
  _Case('오늘 얼마 썼어', period: 'today', agg: _sum),
  _Case('이번 주 교통비 얼마 나갔어?', period: 'this_week', agg: _sum, category: '교통'),
  _Case('지난주 지출 내역 보여줘', period: 'last_week', agg: _list),
  _Case(
    '작년 월급 합계 알려줘',
    period: 'last_year',
    agg: _sum,
    category: '급여',
    type: TxType.income,
  ),
  _Case('10월 식비 평균', period: 'month_10', agg: _avg, category: '식비'),
  _Case('3월 쇼핑 얼마 썼지?', period: 'month_3', agg: _sum, category: '쇼핑'),
  _Case('12월에 얼마 썼어?', period: 'month_12', agg: _sum),
  _Case('최근 7일 지출 합계', period: 'last_7_days', agg: _sum),
  _Case(
    '최근 30일 스타벅스에서 얼마 썼어?',
    period: 'last_30_days',
    agg: _sum,
    party: '스타벅스',
  ),
  _Case('지난달 쿠팡 몇 건?', period: 'last_month', agg: _count, party: '쿠팡'),
  _Case('이번달 통신비 얼마', period: 'this_month', agg: _sum, category: '주거·통신'),
  _Case('저번 달 병원비 얼마 나왔어', period: 'last_month', agg: _sum, category: '의료·건강'),
  _Case('올해 경조사 몇 번이야?', period: 'this_year', agg: _count, category: '경조사·선물'),
  _Case('어제 내역 보여 줘', period: 'yesterday', agg: _list, type: null),
  _Case('2025년 3월 식비 얼마였어?', period: 'month_2025_3', agg: _sum, category: '식비'),
  _Case(
    '작년 12월 수입 얼마야',
    period: 'month_2025_12',
    agg: _sum,
    type: TxType.income,
  ),
  _Case('이번 달 하루 평균 얼마 썼어?', period: 'this_month', agg: _avg, perDay: true),
  _Case('지난달 이마트에서 쓴 돈 합계', period: 'last_month', agg: _sum, party: '이마트'),
  _Case('11월 5일에 뭐 샀어?', period: 'day_2026-11-05', agg: _list),
  _Case('그저께 지출 보여줘', period: 'day_2026-11-15', agg: _list),
  _Case(
    '최근 3개월 문화생활 얼마',
    period: 'last_3_months',
    agg: _sum,
    category: '문화·여가',
  ),
  _Case(
    '용돈 얼마 받았어?',
    period: 'this_month',
    agg: _sum,
    category: '용돈',
    type: TxType.income,
    assumed: true,
  ),
  _Case(
    '식비 얼마 썼어',
    period: 'this_month',
    agg: _sum,
    category: '식비',
    assumed: true,
  ),
  _Case(
    '지난달 이체 얼마 했어?',
    period: 'last_month',
    agg: _sum,
    type: TxType.transfer,
  ),
  _Case(
    '이번 주 배달의민족 몇 번 시켰어?',
    period: 'this_week',
    agg: _count,
    party: '배달의민족',
  ),
  _Case(
    '최근 일주일 카페에서 얼마 썼어?',
    period: 'last_7_days',
    agg: _sum,
    category: '카페·간식',
  ),
  _Case('올해 넷플릭스 얼마 나갔어?', period: 'this_year', agg: _sum, party: '넷플릭스'),
  // '오늘의집'의 '오늘'은 기간이 아니다.
  _Case(
    '오늘의집에서 얼마 썼어?',
    period: 'this_month',
    agg: _sum,
    party: '오늘의집',
    assumed: true,
  ),
];

void main() {
  group('문장에서 조건을 읽는다', () {
    test('표본이 30문장 이상이다', () {
      expect(_cases.length, greaterThanOrEqualTo(30));
    });

    for (final c in _cases) {
      test(c.text, () {
        final query = parseQuery(c.text, today: today, categories: categories);
        expect(query, isNotNull, reason: '읽지 못했다');
        expect(query!.period.symbol, c.period, reason: '기간');
        expect(query.category, c.category, reason: '분류');
        expect(query.party, c.party, reason: '상대방');
        expect(query.type, c.type, reason: '종류');
        expect(query.aggregation, c.agg, reason: '집계');
        expect(query.perDay, c.perDay, reason: '하루 평균');
        expect(query.periodAssumed, c.assumed, reason: '기간을 짐작했는지');
        expect(query.aiModel, isNull);
      });
    }

    test('읽을 조건이 없는 문장은 null이다', () {
      for (final text in ['얼마야?', '뭐 먹지', '', '   ', '알려줘']) {
        expect(
          parseQuery(text, today: today, categories: categories),
          isNull,
          reason: text,
        );
      }
    });

    test('풀지 못한 말이 많으면 틀린 조건으로 답하지 않고 null을 준다', () {
      expect(
        parseQuery(
          '이번 달에 친구들이랑 강릉 놀러 가서 쓴 돈이 얼마지',
          today: today,
          categories: categories,
        ),
        isNull,
      );
    });

    test('분류가 없는 가계부에서는 분류 낱말이 상대방이 된다', () {
      final query = parseQuery('지난달 식비 얼마야?', today: today);
      expect(query!.category, isNull);
      expect(query.party, '식비');
    });

    test('조건 JSON은 설계서의 꼴이다', () {
      final query = parseQuery(
        '지난달 식비 얼마야?',
        today: today,
        categories: categories,
      );
      expect(query!.toJson(), {
        'period': 'last_month',
        'category': '식비',
        'party': null,
        'type': 'expense',
        'agg': 'sum',
      });
    });
  });

  group('기간을 날짜 범위로 바꾼다', () {
    DateRange range(String symbol, {LocalDate? on, int startDay = 1}) =>
        QueryPeriod.fromSymbol(symbol)!
            .resolve(today: on ?? today, startDay: startDay);
    DateRange days(String from, String toExclusive) =>
        DateRange(LocalDate.parse(from), LocalDate.parse(toExclusive));

    test('월 시작일이 1일일 때', () {
      expect(range('today'), days('2026-11-17', '2026-11-18'));
      expect(range('yesterday'), days('2026-11-16', '2026-11-17'));
      // 주는 월요일에 시작한다.
      expect(range('this_week'), days('2026-11-16', '2026-11-23'));
      expect(range('last_week'), days('2026-11-09', '2026-11-16'));
      expect(range('this_month'), days('2026-11-01', '2026-12-01'));
      expect(range('last_month'), days('2026-10-01', '2026-11-01'));
      expect(range('this_year'), days('2026-01-01', '2027-01-01'));
      expect(range('last_year'), days('2025-01-01', '2026-01-01'));
      expect(range('month_3'), days('2026-03-01', '2026-04-01'));
      // 아직 오지 않은 달은 작년의 그 달이다.
      expect(range('month_12'), days('2025-12-01', '2026-01-01'));
      expect(range('month_2024_2'), days('2024-02-01', '2024-03-01'));
      expect(range('last_7_days'), days('2026-11-11', '2026-11-18'));
      expect(range('last_3_months'), days('2026-08-18', '2026-11-18'));
      expect(range('day_2026-11-05'), days('2026-11-05', '2026-11-06'));
    });

    test('월 시작일이 25일이면 달과 해가 25일에 바뀐다', () {
      DateRange r(String symbol, {LocalDate? on}) =>
          range(symbol, on: on, startDay: 25);
      // 11월 17일은 '11월'(10/25–11/24)에 든다.
      expect(r('this_month'), days('2026-10-25', '2026-11-25'));
      expect(r('last_month'), days('2026-09-25', '2026-10-25'));
      expect(r('month_3'), days('2026-02-25', '2026-03-25'));
      expect(r('month_12'), days('2025-11-25', '2025-12-25'));
      expect(r('month_2025_3'), days('2025-02-25', '2025-03-25'));
      expect(r('this_year'), days('2025-12-25', '2026-12-25'));
      expect(r('last_year'), days('2024-12-25', '2025-12-25'));
      // 하루 · 주 · 최근 N일은 월 시작일과 상관없다.
      expect(r('today'), days('2026-11-17', '2026-11-18'));
      expect(r('this_week'), days('2026-11-16', '2026-11-23'));
      expect(r('last_7_days'), days('2026-11-11', '2026-11-18'));

      // 11월 25일부터는 '12월'이다. 그때의 '12월'은 이번 달이고 '11월'은 지난달이다.
      final later = LocalDate(2026, 11, 28);
      expect(r('this_month', on: later), days('2026-11-25', '2026-12-25'));
      expect(r('month_12', on: later), days('2026-11-25', '2026-12-25'));
      expect(r('month_11', on: later), r('last_month', on: later));
      // 12월 28일은 이미 다음 해의 1월이다.
      final newYear = LocalDate(2026, 12, 28);
      expect(r('this_year', on: newYear), days('2026-12-25', '2027-12-25'));
      expect(r('month_1', on: newYear), days('2026-12-25', '2027-01-25'));
    });

    test('문장의 기간도 월 시작일을 따른다', () {
      final query = parseQuery(
        '지난달 식비 얼마야?',
        today: today,
        categories: categories,
        startDay: 25,
      );
      expect(query!.range, days('2026-09-25', '2026-10-25'));
      final lastYearMarch = parseQuery(
        '작년 3월 식비',
        today: today,
        categories: categories,
        startDay: 25,
      );
      expect(lastYearMarch!.period.symbol, 'month_2025_3');
      expect(lastYearMarch.range, days('2025-02-25', '2025-03-25'));
    });

    test('아직 오지 않은 날짜는 작년의 그날이다', () {
      final query = parseQuery('12월 25일에 뭐 샀지', today: today);
      expect(query!.range, days('2025-12-25', '2025-12-26'));
      // 없는 날짜는 기간으로 읽지 않는다.
      expect(parseQuery('2월 30일 얼마', today: today)?.period.symbol, 'month_2');
    });

    test('기호는 읽었다가 다시 써도 같다', () {
      for (final symbol in [
        ...QueryPeriod.modelSymbols,
        'month_2025_3',
        'last_3_months',
        'day_2026-11-05',
      ]) {
        expect(QueryPeriod.fromSymbol(symbol)?.symbol, symbol);
      }
      for (final bad in ['month_13', 'month_0', 'last_0_days', 'someday', '']) {
        expect(QueryPeriod.fromSymbol(bad), isNull, reason: bad);
      }
    });
  });

  group('조회로 볼 문장인지', () {
    test('금액이 없고 물음 낱말이나 물음표가 있으면 조회다', () {
      for (final text in [
        '지난달 식비 얼마야?',
        '이번 달 카페 몇 번 갔어',
        '어제 뭐 샀지',
        '올해 수입 합계',
        '10월 식비 평균',
        '지난주 내역 보여줘',
        '최근 7일 지출 알려줘',
        '월급 언제 들어왔어',
        '스타벅스?',
        ..._cases.map((c) => c.text),
      ]) {
        expect(looksLikeQuery(text), isTrue, reason: text);
      }
    });

    test('거래를 적은 문장은 조회가 아니다', () {
      for (final text in [
        '점심 9천원',
        '어제 점심 9천원',
        '스타벅스 4500',
        '택시 12,000원',
        '월급 300만원 들어옴',
        // 금액이 있으면 물음표가 있어도 거래다.
        '점심 9천원?',
        '택시비 얼마였더라 12000원',
        // 물음 낱말도 물음표도 없다.
        '김밥천국',
        '',
        '   ',
      ]) {
        expect(looksLikeQuery(text), isFalse, reason: text);
      }
    });

    test('여러 줄이나 긴 글은 조회가 아니다', () {
      expect(looksLikeQuery('얼마야?\n지난달 식비'), isFalse);
      expect(looksLikeQuery('[Web발신] 인증번호를 알려 드립니다 ${'가' * 80}'), isFalse);
    });
  });
}
