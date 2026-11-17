// 한 줄 문장 골든 세트(eval/golden/sentences.jsonl)로 규칙만 쓰는 한 줄 입력을 잰다.
//
// LLM이 없는 기기(웹 앱, 저사양 폰)가 얻는 정확도의 기준선이다. 틀린 문장을 출력해
// 규칙을 고칠 곳과 모델이 필요한 곳을 가린다.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gagyebu/ai/text/quick_entry_parser.dart';
import 'package:gagyebu/core/local_date.dart';

void main() {
  final cases = [
    for (final line in File('../eval/golden/sentences.jsonl').readAsLinesSync())
      if (line.trim().isNotEmpty) jsonDecode(line) as Map<String, dynamic>,
  ];

  test('규칙만 쓰는 한 줄 입력의 필드별 일치율', () {
    final score = {'amount': 0, 'date': 0, 'direction': 0, 'all': 0};
    final misses = <String>[];
    for (final c in cases) {
      final expected = c['expect'] as Map<String, dynamic>;
      final tx = parseQuickEntry(
        c['text'] as String,
        today: LocalDate.parse(c['today'] as String),
      );
      final amountOk = tx?.amount == expected['amount'];
      final dateOk = tx?.date.toString() == expected['date'];
      final directionOk = tx?.direction.code == expected['direction'];
      if (amountOk) score['amount'] = score['amount']! + 1;
      if (dateOk) score['date'] = score['date']! + 1;
      if (directionOk) score['direction'] = score['direction']! + 1;
      if (amountOk && dateOk && directionOk) {
        score['all'] = score['all']! + 1;
      } else {
        misses.add(
          '  ${c['text']} → 금액 ${tx?.amount} 날짜 ${tx?.date} 방향 ${tx?.direction.code} '
          '(정답 ${expected['amount']} ${expected['date']} ${expected['direction']})',
        );
      }
    }
    final n = cases.length;
    String pct(String key) =>
        '${score[key]}/$n (${(score[key]! * 100 / n).toStringAsFixed(1)}%)';
    // ignore: avoid_print
    print(
      '한 줄 문장 $n건, 규칙만 사용\n'
      '  금액 ${pct('amount')}\n  날짜 ${pct('date')}\n  방향 ${pct('direction')}\n'
      '  셋 다 ${pct('all')}\n틀린 문장\n${misses.join('\n')}',
    );

    // 회귀를 막는 하한선. 규칙을 고쳐 올라가면 함께 올린다.
    expect(score['amount']! / n, greaterThanOrEqualTo(0.9));
    expect(score['date']! / n, greaterThanOrEqualTo(0.9));
    expect(score['direction']! / n, greaterThanOrEqualTo(0.85));
  });
}
