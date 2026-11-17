import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gagyebu/ai/parsed_transaction.dart';
import 'package:gagyebu/ai/text/paste_parser.dart';
import 'package:gagyebu/ai/text/text_normalizer.dart';
import 'package:gagyebu/core/local_date.dart';

void main() {
  final parser = PasteParser();
  final today = LocalDate(2026, 11, 17);

  List<Map<String, dynamic>> goldenTransactions() => [
    for (final line in File('../eval/golden/paste.jsonl').readAsLinesSync())
      if (line.trim().isNotEmpty)
        if ((jsonDecode(line) as Map<String, dynamic>)['kind'] == 'transaction')
          jsonDecode(line) as Map<String, dynamic>,
  ];

  group('normalizeText', () {
    test('전각 문자와 보이지 않는 문자를 정리한다', () {
      expect(normalizeText('토스　홍길동'), '토스 홍길동');
      expect(normalizeText('１２，５００원'), '12,500원');
      expect(normalizeText('가​나﻿다'), '가나다');
      expect(normalizeText('a\r\nb\rc'), 'a\nb\nc');
      expect(normalizeText('식비・카페'), '식비·카페');
      expect(normalizeText('  앞뒤   공백  '), '앞뒤 공백');
    });
    test('줄바꿈을 접는다', () {
      expect(foldWhitespace('a\n b\t\tc'), 'a b c');
    });
  });

  group('여러 건 붙여넣기', () {
    test('빈 줄로 나뉜 문자를 건별로 읽는다', () {
      final items = parser.parse('''
[Web발신]
신한카드(1234)승인 홍*동
12,500원(일시불) 11/16 12:31
김밥천국 강남점 누적 345,600원

[Web발신]
우리 06/20 11:20 *123456 입금 472원 예금결산 잔액 1,199,234원
''', today: today);
      expect(items, hasLength(2));
      final first = (items[0] as TransactionItem).transaction;
      final second = (items[1] as TransactionItem).transaction;
      expect(first.amount, 12500);
      expect(first.counterparty, '김밥천국 강남점');
      expect(second.amount, 472);
      expect(second.direction, Direction.incoming);
    });

    test('한 줄짜리 문자가 빈 줄 없이 이어져도 섞이지 않는다', () {
      final items = parser.parse('''
우리 06/20 11:20 *123456 입금 472원 예금결산 잔액 1,199,234원
우리 02/23 11:32 *123456 출금 900원 SMS수수료 잔액 41,903,664원
농협 출금701,000원 08/22 22:35 352-****-0000-00 한패스오픈뱅 잔액4,308,001원
''', today: today);
      expect(items, hasLength(3));
      expect(
        [for (final i in items) (i as TransactionItem).transaction.amount],
        [472, 900, 701000],
      );
      expect(
        [
          for (final i in items)
            (i as TransactionItem).transaction.counterparty,
        ],
        ['예금결산', 'SMS수수료', '한패스오픈뱅'],
      );
    });

    test('골든 세트의 거래 표본을 빈 줄 없이 모두 이어 붙여도 건별로 읽는다', () {
      final cases = goldenTransactions();
      final text = cases.map((c) => c['text'] as String).join('\n');
      final items = parser.parse(text, today: today);

      expect(
        items.whereType<UnrecognizedItem>().map((i) => i.raw),
        isEmpty,
        reason: '읽지 못한 줄이 없어야 한다',
      );
      final parsed = [
        for (final i in items.whereType<TransactionItem>()) i.transaction,
      ];
      expect(parsed, hasLength(cases.length));
      for (var k = 0; k < cases.length; k++) {
        final expect_ = cases[k]['expect'] as Map<String, dynamic>;
        expect(
          parsed[k].amount,
          expect_['amount'],
          reason: '${cases[k]['id']} 금액',
        );
        expect(
          parsed[k].counterparty,
          expect_['counterparty'],
          reason: '${cases[k]['id']} 상대방',
        );
        expect(
          parsed[k].direction.code,
          expect_['direction'],
          reason: '${cases[k]['id']} 방향',
        );
      }
    });

    test('줄바꿈이 모두 공백으로 바뀐 문자도 같은 결과를 낸다', () {
      for (final c in goldenTransactions()) {
        final oneLine = (c['text'] as String).replaceAll('\n', ' ');
        final items = parser.parse(
          oneLine,
          today: LocalDate.parse(c['today'] as String),
        );
        expect(items, hasLength(1), reason: c['id'] as String);
        final tx = (items.single as TransactionItem).transaction;
        final expect_ = c['expect'] as Map<String, dynamic>;
        expect(tx.amount, expect_['amount'], reason: c['id'] as String);
        expect(tx.date.toString(), expect_['date'], reason: c['id'] as String);
        expect(
          tx.counterparty,
          expect_['counterparty'],
          reason: c['id'] as String,
        );
      }
    });

    test('CRLF 줄바꿈도 같은 결과를 낸다', () {
      for (final c in goldenTransactions()) {
        final crlf = (c['text'] as String).replaceAll('\n', '\r\n');
        final items = parser.parse(
          crlf,
          today: LocalDate.parse(c['today'] as String),
        );
        expect(items, hasLength(1), reason: c['id'] as String);
        expect(items.single, isA<TransactionItem>(), reason: c['id'] as String);
      }
    });

    test('거래 사이에 낀 안내문과 모르는 줄을 구분한다', () {
      final items = parser.parse('''
삼성1234승인 홍*동 100원 일시불 01/09 20:07 세븐일레븐아산음 누적80,090원
[롯데카드]11/16출금예정2,668,841원
오늘 저녁은 뭐 먹지
하나,09/10 11:17 123******45607 출금13,958원 0908_GOOGLE*i 잔액669,942원
''', today: today);
      expect(items.map((i) => i.runtimeType).toList(), [
        TransactionItem,
        NonTransactionItem,
        UnrecognizedItem,
        TransactionItem,
      ]);
      expect(
        (items[1] as NonTransactionItem).reason,
        NonTransactionReason.scheduled,
      );
      expect(items[2].raw, '오늘 저녁은 뭐 먹지');
    });

    test('빈 입력은 빈 결과', () {
      expect(parser.parse('', today: today), isEmpty);
      expect(parser.parse('  \n\n ', today: today), isEmpty);
    });
  });

  group('검토 카드에 띄울 경고', () {
    ParsedTransaction one(String text) =>
        (parser.parse(text, today: today).single as TransactionItem)
            .transaction;

    test('연도를 채웠음을 알린다', () {
      final tx = one('우리 06/20 11:20 *123456 입금 472원 예금결산 잔액 1,199,234원');
      expect(tx.warnings, contains(ParseWarning.yearInferred));
    });
    test('연도가 있으면 알리지 않는다', () {
      final tx = one(
        '2021/08/19 04:55 출금 11,000원 잔액 1,003,145원 HONGGILD_아 123***45678901 기업',
      );
      expect(tx.warnings, isNot(contains(ParseWarning.yearInferred)));
    });
    test('날짜가 없으면 오늘로 채우고 알린다', () {
      final tx = one('₩7,100 결제 완료\n씨유 휘경행복점');
      expect(tx.date, today);
      expect(tx.warnings, contains(ParseWarning.dateFromNow));
    });
    test('해외 결제는 원화 금액을 비워 둔다', () {
      final tx = one(
        '신한(1234)해외승인 홍*동 220.00 달러 (US)11/11 22:34 ANTHROPIC* 누적2,027,221원',
      );
      expect(tx.amount, isNull);
      expect(tx.currency, 'USD');
      expect(tx.originalAmount, 220.0);
      expect(tx.warnings, contains(ParseWarning.needsKrwAmount));
    });
    test('카드대금 출금은 이체 후보로 표시한다', () {
      final tx = one('우리 11/14 09:00 *123456 출금 1,250,000원 신한카드 잔액 2,000,000원');
      expect(tx.warnings, contains(ParseWarning.possibleCardPayment));
    });
    test('누적 사용액은 금액과 따로 둔다', () {
      final tx = one('삼성1234승인 홍*동 100원 일시불 01/09 20:07 세븐일레븐아산음 누적80,090원');
      expect(tx.amount, 100);
      expect(tx.cumulative, 80090);
      expect(tx.balanceAfter, isNull);
    });
    test('할부 개월을 읽는다', () {
      final tx = one(
        'KB국민카드1234승인 홍*동님 600,000원 6개월 02/08 22:39 하이마트 누적800,000원',
      );
      expect(tx.installmentMonths, 6);
    });
    test('체크카드 표시는 메모로 옮긴다', () {
      final tx = one(
        '[KB]11/15 14:58 123456**789 과일놀이터 체크카드출금 18,000 잔액238,281',
      );
      expect(tx.memo, '체크카드');
      expect(tx.direction, Direction.outgoing);
    });
  });
}
