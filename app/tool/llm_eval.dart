// 골든 세트로 해석 경로의 정확도와 시간을 잰다.
//
//   dart run tool/llm_eval.dart --mode=rules --set=holdout
//   dart run tool/llm_eval.dart --endpoint=http://127.0.0.1:8088 --name=qwen3.5-2b-q4_k_m
//   dart run tool/llm_eval.dart --endpoint=… --name=… --mode=app --set=holdout --out=x.json
//
// --mode
//   llm    형식 규칙을 끄고 모델만으로 읽는다(기본). 규칙이 모르는 금융사의 문자를 모델이
//          얼마나 읽는지 본다.
//   rules  규칙만으로 읽는다. 모델이 필요 없다.
//   app    앱과 같은 순서로 읽는다: 규칙 먼저, 규칙이 못 읽은 것만 모델.
// --set
//   paste · sentences · all(기본, 앞의 둘) · holdout(규칙을 다듬는 데 쓰지 않은 표본)
// --limit=N  세트마다 앞의 N건만
//
// 모델을 쓰는 모드는 먼저 llama.cpp 서버를 이 컴퓨터에 띄운다(예).
//   llama-server -m Qwen3.5-2B-Q4_K_M.gguf --host 127.0.0.1 --port 8088 -c 4096 --reasoning-budget 0
import 'dart:convert';
import 'dart:io';

import 'package:gagyebu/ai/input_interpreter.dart';
import 'package:gagyebu/ai/llm/extraction_prompt.dart';
import 'package:gagyebu/ai/llm/llm_text_parser.dart';
import 'package:gagyebu/ai/llm/openai_compatible_engine.dart';
import 'package:gagyebu/ai/parsed_transaction.dart';
import 'package:gagyebu/core/local_date.dart';
import 'package:gagyebu/domain/default_seed.dart';

String? _arg(List<String> args, String name) {
  for (final a in args) {
    if (a.startsWith('--$name=')) return a.substring(name.length + 3);
  }
  return null;
}

String _squeeze(String? text) =>
    (text ?? '').replaceAll(RegExp(r'\s+'), '').toLowerCase();

/// 한 건을 읽은 결과.
class _Read {
  const _Read(this.transactions, {this.failure, this.retried = false});

  final List<ParsedTransaction> transactions;
  final String? failure;
  final bool retried;
}

typedef _Reader = Future<_Read> Function(String text, LocalDate today);

class _Score {
  final Map<String, List<int>> fields = {};
  final List<String> misses = [];
  final List<int> millis = [];
  int retries = 0;
  int failures = 0;

  void record(String field, bool ok) {
    final s = fields.putIfAbsent(field, () => [0, 0]);
    if (ok) s[0]++;
    s[1]++;
  }

  Map<String, Object?> toJson() {
    final sorted = [...millis]..sort();
    int at(double q) =>
        sorted.isEmpty ? 0 : sorted[((sorted.length - 1) * q).round()];
    return {
      'fields': {
        for (final e in fields.entries)
          e.key: {
            'correct': e.value[0],
            'total': e.value[1],
            'accuracy': e.value[1] == 0 ? null : e.value[0] / e.value[1],
          },
      },
      'latency_ms': {
        'mean': sorted.isEmpty
            ? 0
            : sorted.reduce((a, b) => a + b) ~/ sorted.length,
        'p50': at(0.5),
        'p90': at(0.9),
        'max': sorted.isEmpty ? 0 : sorted.last,
      },
      'retries': retries,
      'failures': failures,
      'misses': misses,
    };
  }

  void print_(String title) {
    stdout.writeln('\n== $title');
    for (final e in fields.entries) {
      final pct = e.value[1] == 0
          ? '-'
          : (e.value[0] * 100 / e.value[1]).toStringAsFixed(1);
      stdout.writeln(
        '  ${e.key.padRight(16)} ${e.value[0]}/${e.value[1]} ($pct%)',
      );
    }
    final j = toJson()['latency_ms'] as Map;
    stdout.writeln(
      '  시간(ms)          평균 ${j['mean']} · 중앙 ${j['p50']} · 90% ${j['p90']} · 최대 ${j['max']}',
    );
    stdout.writeln('  다시 물은 횟수 $retries, 포기 $failures');
    if (misses.isNotEmpty) {
      stdout.writeln('  틀린 것');
      for (final m in misses) {
        stdout.writeln('    $m');
      }
    }
  }
}

List<Map<String, dynamic>> _load(String file, int? limit) {
  final rows = [
    for (final line in File('../eval/golden/$file').readAsLinesSync())
      if (line.trim().isNotEmpty) jsonDecode(line) as Map<String, dynamic>,
  ];
  return limit == null ? rows : rows.take(limit).toList();
}

Future<_Read> _timed(_Reader read, Map<String, dynamic> c, _Score score) async {
  final watch = Stopwatch()..start();
  final result = await read(
    c['text'] as String,
    LocalDate.parse(c['today'] as String),
  );
  score.millis.add(watch.elapsedMilliseconds);
  if (result.retried) score.retries++;
  if (result.failure != null) score.failures++;
  return result;
}

String _describe(_Read result, {bool withMemo = false}) {
  if (result.transactions.length != 1) {
    final why = result.failure == null ? '' : ' (${result.failure})';
    return '거래 ${result.transactions.length}건$why';
  }
  final got = result.transactions.single;
  final memo = withMemo ? ' / "${got.memo}"' : '';
  return '${got.date} ${got.amount} ${got.direction.code} "${got.counterparty}"$memo';
}

/// 결제 문자 · 입출금 알림 · 안내문 세트.
Future<_Score> _evalPaste(String file, _Reader read, int? limit) async {
  final score = _Score();
  for (final c in _load(file, limit)) {
    final kind = c['kind'] as String;
    if (kind == 'unrecognized') continue; // 금액이 가려진 표본
    final result = await _timed(read, c, score);
    final id = c['id'] as String;
    if (kind == 'non_transaction') {
      final ok = result.failure == null && result.transactions.isEmpty;
      score.record('안내문 거르기', ok);
      if (!ok) score.misses.add('$id: 안내문인데 거래로 읽음');
      stdout.write(ok ? '.' : 'x');
      continue;
    }
    final expected = c['expect'] as Map<String, dynamic>;
    final got = result.transactions.length == 1
        ? result.transactions.single
        : null;
    score.record('거래 한 건으로 읽기', got != null);
    final checks = <String, bool>{
      '금액': got?.amount == expected['amount'],
      '방향': got?.direction.code == expected['direction'],
      '날짜': got?.date.toString() == expected['date'],
      '상대방':
          _squeeze(got?.counterparty) ==
          _squeeze(expected['counterparty'] as String?),
      if (expected.containsKey('is_cancel'))
        '취소 여부': got?.isCancel == expected['is_cancel'],
    };
    checks.forEach(score.record);
    score.record('모든 항목', got != null && checks.values.every((ok) => ok));
    final wrong = [
      for (final e in checks.entries)
        if (!e.value) e.key,
    ];
    if (wrong.isNotEmpty) {
      score.misses.add('$id: ${wrong.join(', ')} 틀림 → ${_describe(result)}');
    }
    stdout.write(wrong.isEmpty ? '.' : 'x');
  }
  return score;
}

/// 한 줄 문장 세트.
Future<_Score> _evalSentences(String file, _Reader read, int? limit) async {
  final score = _Score();
  for (final c in _load(file, limit)) {
    final result = await _timed(read, c, score);
    final expected = c['expect'] as Map<String, dynamic>;
    final got = result.transactions.length == 1
        ? result.transactions.single
        : null;
    final wanted = c['counterparty_contains'] as String?;
    final checks = <String, bool>{
      '금액': got?.amount == expected['amount'],
      '날짜': got?.date.toString() == expected['date'],
      '방향': got?.direction.code == expected['direction'],
      // 문장에서는 상대(who)나 내용(memo) 어느 쪽에 적혀도 맞은 것으로 본다.
      if (wanted != null)
        '상대 · 내용': _squeeze('${got?.counterparty ?? ''} ${got?.memo ?? ''}')
            .contains(_squeeze(wanted)),
    };
    checks.forEach(score.record);
    score.record(
      '금액 · 날짜 · 방향 모두',
      checks['금액']! && checks['날짜']! && checks['방향']!,
    );
    final wrong = [
      for (final e in checks.entries)
        if (!e.value) e.key,
    ];
    if (wrong.isNotEmpty) {
      score.misses.add(
        '${c['text']}: ${wrong.join(', ')} 틀림 → '
        '${_describe(result, withMemo: true)}',
      );
    }
    stdout.write(wrong.isEmpty ? '.' : 'x');
  }
  return score;
}

Future<void> main(List<String> args) async {
  final mode = _arg(args, 'mode') ?? 'llm';
  final endpoint = _arg(args, 'endpoint');
  final name = _arg(args, 'name');
  final needsModel = mode != 'rules';
  if (!{'llm', 'rules', 'app'}.contains(mode) ||
      (needsModel && (endpoint == null || name == null))) {
    stderr.writeln(
      '사용법: dart run tool/llm_eval.dart [--mode=llm|rules|app] '
      '[--endpoint=http://127.0.0.1:8088 --name=<모델 이름>] '
      '[--set=paste|sentences|all|holdout] [--limit=N] [--out=파일]',
    );
    exit(2);
  }
  final which = _arg(args, 'set') ?? 'all';
  final limit = int.tryParse(_arg(args, 'limit') ?? '');
  final out = _arg(args, 'out');

  final engine = needsModel
      ? OpenAiCompatibleEngine(endpoint: Uri.parse(endpoint!), modelName: name!)
      : null;

  final _Reader read;
  if (mode == 'llm') {
    final parser = LlmTextParser(engine!);
    read = (text, today) async {
      final result = await parser.parse(
        text,
        today: today,
        expenseCategories: defaultExpenseCategories,
        incomeCategories: defaultIncomeCategories,
      );
      return _Read(
        result.transactions,
        failure: result.failure,
        retried: result.attempts > 1,
      );
    };
  } else {
    read = (text, today) async {
      final result = await interpretInput(
        text,
        today: today,
        engine: engine,
        expenseCategories: defaultExpenseCategories,
        incomeCategories: defaultIncomeCategories,
      );
      return _Read(result.transactions.toList());
    };
  }

  final how = switch (mode) {
    'llm' => '규칙 없이 모델만',
    'rules' => '규칙만',
    _ => '앱과 같은 순서(규칙 → 모델)',
  };
  final report = <String, Object?>{
    'mode': mode,
    'model': name,
    'prompt': needsModel ? extractionPromptVersion : null,
    'endpoint': endpoint,
  };

  final holdout = which == 'holdout';
  if (which == 'paste' || which == 'all' || holdout) {
    final file = holdout ? 'holdout_paste.jsonl' : 'paste.jsonl';
    final score = await _evalPaste(file, read, limit);
    score.print_('${holdout ? '홀드아웃 ' : ''}붙여넣기 표본 · $how');
    report[holdout ? 'holdout_paste' : 'paste'] = score.toJson();
  }
  if (which == 'sentences' || which == 'all' || holdout) {
    final file = holdout ? 'holdout_sentences.jsonl' : 'sentences.jsonl';
    final score = await _evalSentences(file, read, limit);
    score.print_('${holdout ? '홀드아웃 ' : ''}한 줄 문장 · $how');
    report[holdout ? 'holdout_sentences' : 'sentences'] = score.toJson();
  }

  engine?.close();
  if (out != null) {
    File(out)
      ..createSync(recursive: true)
      ..writeAsStringSync(const JsonEncoder.withIndent('  ').convert(report));
    stdout.writeln('\n보고서: $out');
  }
}
