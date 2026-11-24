import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:gagyebu/ai/parsed_transaction.dart';
import 'package:gagyebu/ai/vision/vision_engine.dart';
import 'package:gagyebu/ai/vision/vision_prompt.dart';
import 'package:gagyebu/ai/vision/vision_rows.dart';
import 'package:gagyebu/ai/vision/vision_text_parser.dart';
import 'package:gagyebu/core/local_date.dart';

/// 정해 둔 답을 차례로 돌려주는 가짜 엔진. 받은 요청을 기록한다.
class ScriptedVisionEngine implements VisionEngine {
  ScriptedVisionEngine(this.answers);

  final List<Object> answers;
  final List<({String system, String user, String? grammar, int maxTokens})>
  requests = [];

  @override
  String get modelName => 'fake-vlm';

  @override
  Future<String> generateJsonFromImage({
    required Uint8List image,
    required String system,
    required String user,
    required Map<String, Object?> schema,
    String? grammar,
    int maxTokens = 1024,
  }) async {
    requests.add((
      system: system,
      user: user,
      grammar: grammar,
      maxTokens: maxTokens,
    ));
    final answer = answers[requests.length - 1];
    return answer is String ? answer : jsonEncode(answer);
  }
}

Map<String, Object?> row({
  String? d = '11.15',
  String? t,
  String? a = '10,000',
  String? io = 'out',
  String? who = '한빛서점',
  String? bal,
}) => {'d': d, 't': t, 'a': a, 'io': io, 'who': who, 'bal': bal};

Map<String, Object?> statement(List<Map<String, Object?>> rows) => {
  'kind': 'statement',
  'shop': null,
  'rows': rows,
  'total': null,
};

Map<String, Object?> receipt(
  List<Map<String, Object?>> rows, {
  String? shop = '새봄커피',
  String? total,
}) => {'kind': 'receipt', 'shop': shop, 'rows': rows, 'total': total};

final _image = Uint8List.fromList([1, 2, 3]);

void main() {
  // 2026-11-17은 화요일이다.
  final today = LocalDate(2026, 11, 17);

  Future<VisionParseResult> parse(List<Object> answers) =>
      VisionTextParser(ScriptedVisionEngine(answers))
          .parse(_image, today: today);

  group('요청', () {
    test('문법과 스키마가 같은 꼴을 강제한다', () {
      final request = buildVisionRequest();
      expect(request.grammar, contains('root ::='));
      expect(request.grammar, contains(r'"\"statement\""'));
      expect(request.system, contains('"kind"'));
      final properties = request.schema['properties']! as Map;
      expect(properties.keys, ['kind', 'shop', 'rows', 'total']);
      // 본보기의 답이 스스로 검증을 통과해야 한다.
      for (final line in request.system.split('\n')) {
        if (line.startsWith('답: ')) {
          expect(() => jsonDecode(line.substring(3)), returnsNormally);
        }
      }
    });

    test('다시 물을 때는 앞선 답의 문제를 붙인다', () {
      final request = buildVisionRequest(feedback: 'JSON이 아니다.');
      expect(request.user, contains('[앞선 답의 문제] JSON이 아니다.'));
    });
  });

  group('글자를 값으로 읽는다', () {
    test('날짜', () {
      expect(
        readVisionDate('2026-11-15', today)!.date,
        LocalDate(2026, 11, 15),
      );
      expect(readVisionDate('2025.12.31', today)!.yearInferred, isFalse);
      expect(readVisionDate('26.11.03', today)!.date, LocalDate(2026, 11, 3));
      expect(readVisionDate('11.15', today)!.date, LocalDate(2026, 11, 15));
      expect(readVisionDate('11.15', today)!.yearInferred, isTrue);
      expect(readVisionDate('11월 5일', today)!.date, LocalDate(2026, 11, 5));
      expect(
        readVisionDate('11/15 14:32', today)!.date,
        LocalDate(2026, 11, 15),
      );
      // 연도가 없고 오늘보다 뒤면 지난해다.
      expect(readVisionDate('12.25', today)!.date, LocalDate(2025, 12, 25));
      expect(readVisionDate('어제', today)!.date, LocalDate(2026, 11, 16));
      expect(readVisionDate('15일 금요일', today), isNull);
      expect(readVisionDate('14:32', today), isNull);
    });

    test('시각', () {
      expect(readVisionTime('14:32'), '14:32');
      expect(readVisionTime('오후 2:05'), '14:05');
      expect(readVisionTime('오전 12:10'), '00:10');
      expect(readVisionTime('11.15 09:00:12'), '09:00');
      expect(readVisionTime('25:99'), isNull);
    });

    test('금액', () {
      expect(readVisionAmount('12,500'), (value: 12500, sign: null));
      expect(readVisionAmount('-12,500원'), (value: 12500, sign: -1));
      expect(readVisionAmount('+ 3,000'), (value: 3000, sign: 1));
      expect(readVisionAmount('−8,000'), (value: 8000, sign: -1));
      expect(readVisionAmount(4500), (value: 4500, sign: null));
      expect(readVisionAmount('12.50'), isNull);
      expect(readVisionAmount(null), isNull);
    });
  });

  group('거래내역 화면', () {
    test('줄마다 한 건으로 읽고 잔액이 이어지면 검산이 맞는다', () async {
      final engine = ScriptedVisionEngine([
        statement([
          // 최근 거래가 위에 있는 화면
          row(t: '19:20', a: '-15,000', who: '한빛서점', bal: '985,000'),
          row(
            t: '09:00',
            a: '+500,000',
            io: 'in',
            who: '김한빛',
            bal: '1,000,000',
          ),
          row(d: '11.14', a: '8,000', who: '새봄분식', bal: '500,000'),
        ]),
      ]);
      final result = await VisionTextParser(engine).parse(_image, today: today);

      expect(result.failed, isFalse);
      expect(result.attempts, 1);
      expect(engine.requests.single.grammar, isNotNull);
      final extraction = result.extraction!;
      expect(extraction.kind, VisionKind.statement);
      expect(extraction.rows, hasLength(3));

      final checks = extraction.verify();
      expect(checks[0].verified, isTrue);
      expect(checks[1].verified, isTrue);
      // 가장 오래된 줄은 견줄 앞 줄이 없다.
      expect(checks[2].verified, isFalse);
      expect(checks.every((c) => !c.needsCheck), isTrue);

      final drafts = result.transactions;
      expect(drafts, hasLength(3));
      expect(drafts[0].date, LocalDate(2026, 11, 15));
      expect(drafts[0].time, '19:20');
      expect(drafts[0].amount, 15000);
      expect(drafts[0].direction, Direction.outgoing);
      expect(drafts[0].counterparty, '한빛서점');
      expect(drafts[0].balanceAfter, 985000);
      expect(drafts[1].direction, Direction.incoming);
      expect(drafts[1].amount, 500000);
      expect(drafts[0].ruleId, 'vlm:fake-vlm');
      expect(drafts[0].warnings, contains(ParseWarning.yearInferred));
    });

    test('오래된 거래가 위에 있는 화면도 검산한다', () async {
      final result = await parse([
        statement([
          row(d: '11.14', a: '8,000', bal: '500,000'),
          row(a: '500,000', io: 'in', bal: '1,000,000'),
          row(a: '15,000', bal: '985,000'),
        ]),
      ]);
      final checks = result.extraction!.verify();
      expect(checks[0].verified, isFalse);
      expect(checks[0].needsCheck, isFalse);
      expect(checks[1].verified, isTrue);
      expect(checks[2].verified, isTrue);
    });

    test('금액을 잘못 읽은 줄만 확인 필요가 된다', () async {
      final result = await parse([
        statement([
          row(a: '15,000', bal: '985,000'),
          // 500,000을 600,000으로 읽었다.
          row(a: '600,000', io: 'in', bal: '1,000,000'),
          row(a: '8,000', bal: '500,000'),
          row(a: '2,000', bal: '508,000'),
        ]),
      ]);
      final extraction = result.extraction!;
      final checks = extraction.verify();
      expect(checks[0].verified, isTrue);
      expect(checks[1].issues, {VisionIssue.balanceBreak});
      expect(checks[1].expected, 1100000);
      expect(checks[1].actual, 1000000);
      expect(checks[2].verified, isTrue);

      // 금액을 고치면 검산이 풀린다.
      final fixed = extraction.withRow(
        1,
        extraction.rows[1].copyWith(amount: 500000),
      );
      expect(fixed.verify()[1].verified, isTrue);
    });

    test('방향을 거꾸로 읽었으면 그렇게 알린다', () async {
      final result = await parse([
        statement([
          row(a: '15,000', bal: '985,000'),
          row(a: '500,000', io: 'out', bal: '1,000,000'),
          row(a: '8,000', bal: '500,000'),
          row(a: '2,000', bal: '508,000'),
        ]),
      ]);
      final extraction = result.extraction!;
      expect(extraction.verify()[1].issues, {VisionIssue.directionReversed});
      final fixed = extraction.withRow(
        1,
        extraction.rows[1].copyWith(direction: Direction.incoming),
      );
      expect(fixed.verify()[1].needsCheck, isFalse);
    });

    test('잔액만 잘못 읽은 줄은 금액을 확인된 것으로 보고 잔액을 붙이지 않는다', () async {
      final result = await parse([
        statement([
          row(a: '15,000', bal: '985,000'),
          // 잔액 1,000,000을 1,008,000으로 읽었다. 금액은 앞뒤 줄과 맞는다.
          row(a: '500,000', io: 'in', bal: '1,008,000'),
          row(a: '8,000', bal: '500,000'),
          row(a: '2,000', bal: '508,000'),
        ]),
      ]);
      final checks = result.extraction!.verify();
      expect(checks.any((c) => c.needsCheck), isFalse);
      expect(checks[0].verified, isTrue);
      expect(checks[1].verified, isTrue);
      expect(checks[1].balanceSuspect, isTrue);
      expect(result.transactions[1].balanceAfter, isNull);
      expect(result.transactions[0].balanceAfter, 985000);
    });

    test('잔액이 없는 화면은 검산하지 못한 채로 둔다', () async {
      final result = await parse([
        statement([row(a: '15,000'), row(a: '8,000')]),
      ]);
      final checks = result.extraction!.verify();
      expect(checks.every((c) => !c.verified && !c.needsCheck), isTrue);
    });

    test('날짜를 읽지 못한 줄은 윗줄의 날짜를 잇고 확인을 청한다', () async {
      final result = await parse([
        statement([
          row(d: null, a: '1,000', who: '첫 줄'),
          row(d: '11.15', a: '2,000'),
          row(d: null, a: '3,000'),
        ]),
      ]);
      final extraction = result.extraction!;
      expect(extraction.rows[0].date, today);
      expect(extraction.rows[0].warnings, contains(ParseWarning.dateFromNow));
      expect(extraction.rows[2].date, LocalDate(2026, 11, 15));
      expect(extraction.rows[2].dateGuessed, isTrue);
      final checks = extraction.verify();
      expect(checks[0].issues, {VisionIssue.dateMissing});
      expect(checks[1].needsCheck, isFalse);
      expect(checks[2].issues, {VisionIssue.dateMissing});
      // 날짜를 정하면 풀린다.
      final fixed = extraction.withRow(
        2,
        extraction.rows[2].copyWith(date: LocalDate(2026, 11, 14)),
      );
      expect(fixed.verify()[2].needsCheck, isFalse);
    });

    test('금액을 읽지 못한 줄은 남기고, 금액도 이름도 없는 줄은 버린다', () async {
      final result = await parse([
        statement([
          row(a: null, who: '금액 없는 줄'),
          row(a: null, who: null),
          row(a: '3,000', who: null),
        ]),
      ]);
      final extraction = result.extraction!;
      expect(extraction.rows, hasLength(2));
      expect(extraction.verify()[0].issues, {VisionIssue.amountMissing});
      expect(
        extraction.rows[1].warnings,
        contains(ParseWarning.noCounterparty),
      );
      expect(result.transactions[1].counterparty, isNull);
    });

    test('부호와 방향이 어긋나면 경고를 붙인다', () async {
      final result = await parse([
        statement([row(a: '+3,000', io: 'out'), row(a: '-2,000', io: null)]),
      ]);
      final rows = result.extraction!.rows;
      expect(rows[0].warnings, contains(ParseWarning.directionMismatch));
      expect(rows[0].direction, Direction.outgoing);
      expect(rows[1].direction, Direction.outgoing);
      expect(rows[1].warnings, isNot(contains(ParseWarning.directionMismatch)));
    });
  });

  group('영수증', () {
    test('품목이 여러 줄이어도 거래 한 건으로 만들고 합을 총액과 견준다', () async {
      final result = await parse([
        receipt([
          row(d: '2026-11-15', t: '13:05', a: '4,500', who: '아메리카노'),
          row(d: null, a: '5,000', who: '카페라떼'),
          row(d: null, a: '-1,000', who: '쿠폰 할인'),
        ], total: '8,500'),
      ]);
      final extraction = result.extraction!;
      expect(extraction.kind, VisionKind.receipt);
      expect(extraction.rows, hasLength(1));
      expect(extraction.items, hasLength(3));
      expect(extraction.itemSum, 8500);
      expect(extraction.verify().single.verified, isTrue);

      final draft = result.transactions.single;
      expect(draft.date, LocalDate(2026, 11, 15));
      expect(draft.time, '13:05');
      expect(draft.amount, 8500);
      expect(draft.direction, Direction.outgoing);
      expect(draft.counterparty, '새봄커피');
      expect(draft.memo, '아메리카노 외 1건');
      expect(draft.ruleId, 'vlm:fake-vlm');
      expect(draft.warnings, isEmpty);
    });

    test('품목의 합이 총액과 다르면 확인 필요가 된다', () async {
      final result = await parse([
        receipt([
          row(d: '2026-11-15', a: '4,500', who: '아메리카노'),
          row(d: null, a: '5,000', who: '카페라떼'),
        ], total: '8,500'),
      ]);
      final extraction = result.extraction!;
      final check = extraction.verify().single;
      expect(check.issues, {VisionIssue.sumMismatch});
      expect(check.expected, 9500);
      expect(check.actual, 8500);
      // 금액은 총액을 쓴다.
      expect(result.transactions.single.amount, 8500);
      // 금액을 품목의 합으로 고치면 풀린다.
      final fixed = extraction.withRow(
        0,
        extraction.rows[0].copyWith(amount: 9500),
      );
      expect(fixed.verify().single.needsCheck, isFalse);
    });

    test('총액을 읽지 못하면 품목의 합을 넣고 확인을 청한다', () async {
      final result = await parse([
        receipt([
          row(d: '11.15', a: '4,500', who: '아메리카노'),
          row(d: null, a: '5,000', who: '카페라떼'),
        ]),
      ]);
      expect(result.transactions.single.amount, 9500);
      expect(result.extraction!.verify().single.issues, {
        VisionIssue.totalMissing,
      });
    });

    test('날짜와 가게를 읽지 못하면 오늘로 두고 경고한다', () async {
      final result = await parse([
        receipt(
          [row(d: null, a: '4,500', who: '아메리카노')],
          shop: null,
          total: '4,500',
        ),
      ]);
      final row0 = result.extraction!.rows.single;
      expect(row0.date, today);
      expect(row0.warnings, {
        ParseWarning.dateFromNow,
        ParseWarning.noCounterparty,
      });
      expect(result.extraction!.verify().single.issues, {
        VisionIssue.dateMissing,
      });
    });
  });

  group('검증과 다시 부르기', () {
    test('거래가 없는 이미지는 빈 결과다', () async {
      final result = await parse([
        {'kind': 'other', 'shop': null, 'rows': <Object?>[], 'total': null},
      ]);
      expect(result.failed, isFalse);
      expect(result.extraction!.kind, VisionKind.other);
      expect(result.transactions, isEmpty);
    });

    test('JSON이 잘렸으면 이유를 붙여 한 번 다시 부른다', () async {
      final engine = ScriptedVisionEngine([
        '{"kind":"statement","shop":null,"rows":[{"d":"11.15","t":null,"a":"15,0',
        statement([row(a: '15,000')]),
      ]);
      final result = await VisionTextParser(engine).parse(_image, today: today);
      expect(result.failed, isFalse);
      expect(result.attempts, 2);
      expect(engine.requests, hasLength(2));
      expect(engine.requests[0].user, isNot(contains('앞선 답의 문제')));
      expect(engine.requests[1].user, contains('[앞선 답의 문제] JSON이 아니다.'));
      expect(result.transactions.single.amount, 15000);
    });

    test('두 번 모두 깨지면 읽지 못함이다', () async {
      final engine = ScriptedVisionEngine([
        '죄송합니다',
        {'kind': 'bank', 'rows': <Object?>[]},
      ]);
      final result = await VisionTextParser(engine).parse(_image, today: today);
      expect(result.failed, isTrue);
      expect(result.attempts, 2);
      expect(result.extraction, isNull);
      expect(result.transactions, isEmpty);
      expect(result.failure, contains('kind'));
    });

    test('줄이 객체가 아니면 다시 부른다', () async {
      final engine = ScriptedVisionEngine([
        {
          'kind': 'statement',
          'rows': ['11.15 한빛서점 15,000'],
        },
        statement([row()]),
      ]);
      final result = await VisionTextParser(engine).parse(_image, today: today);
      expect(result.attempts, 2);
      expect(result.transactions, hasLength(1));
    });
  });
}
