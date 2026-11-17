// 붙여넣기 골든 세트(eval/golden/paste.jsonl)로 형식 규칙을 회귀 검사한다.
//
// 표본마다 판정 종류와 필드를 비교하고, 끝에 필드별 일치율을 출력한다.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gagyebu/ai/parsed_transaction.dart';
import 'package:gagyebu/ai/text/paste_parser.dart';
import 'package:gagyebu/core/local_date.dart';

void main() {
  final file = File('../eval/golden/paste.jsonl');
  final cases = [
    for (final line in file.readAsLinesSync())
      if (line.trim().isNotEmpty) jsonDecode(line) as Map<String, dynamic>,
  ];
  final parser = PasteParser();

  // 필드별 (맞은 수, 전체 수)
  final score = <String, List<int>>{};
  void record(String field, bool ok) {
    final s = score.putIfAbsent(field, () => [0, 0]);
    if (ok) s[0]++;
    s[1]++;
  }

  tearDownAll(() {
    final buffer = StringBuffer('골든 세트 ${cases.length}건 필드별 일치율\n');
    for (final entry in score.entries) {
      final ok = entry.value[0];
      final total = entry.value[1];
      final percent = (ok * 100 / total).toStringAsFixed(1);
      buffer.writeln('  ${entry.key.padRight(20)} $ok/$total ($percent%)');
    }
    // ignore: avoid_print
    print(buffer);
  });

  test('골든 세트가 비어 있지 않다', () {
    expect(cases.length, greaterThanOrEqualTo(40));
  });

  for (final c in cases) {
    final id = c['id'] as String;
    test('golden: $id', () {
      final items = parser.parse(
        c['text'] as String,
        today: LocalDate.parse(c['today'] as String),
      );
      final kind = c['kind'] as String;

      switch (kind) {
        case 'non_transaction':
          final ok =
              items.isNotEmpty && items.every((i) => i is NonTransactionItem);
          record('kind', ok);
          expect(ok, isTrue, reason: '안내문으로 걸러야 한다: $items');
        case 'unrecognized':
          final ok =
              items.isNotEmpty && items.every((i) => i is UnrecognizedItem);
          record('kind', ok);
          expect(ok, isTrue, reason: '읽을 수 없는 표본이다: $items');
        case 'transaction':
          final ok = items.length == 1 && items.single is TransactionItem;
          record('kind', ok);
          expect(
            ok,
            isTrue,
            reason: '거래 한 건으로 읽어야 한다: ${items.map((i) => i.runtimeType)}',
          );
          final actual = (items.single as TransactionItem).transaction.toJson();
          final expected = c['expect'] as Map<String, dynamic>;
          final mismatches = <String>[];
          for (final entry in expected.entries) {
            final got = actual[entry.key];
            final want = entry.value;
            final same = (got is num && want is num)
                ? got == want
                : got == want;
            record(entry.key, same);
            if (!same) {
              mismatches.add('${entry.key}: 기대 $want, 실제 $got');
            }
          }
          expect(mismatches, isEmpty, reason: '규칙 ${actual['rule']}');
        default:
          fail('알 수 없는 kind: $kind');
      }
    });
  }
}
