// 조회 문장을 조건으로 읽는 정확도를 잰다.
//
//   dart run tool/query_eval.dart --mode=rules
//   dart run tool/query_eval.dart --model=/경로/Qwen3.5-2B-Q4_K_M.gguf
//   dart run tool/query_eval.dart --endpoint=http://127.0.0.1:8088 --name=qwen3.5-2b-q4_k_m --mode=app
//
// --mode
//   llm    모델만으로 읽는다(기본).
//   rules  규칙만으로 읽는다. 모델이 필요 없다.
//   app    앱과 같은 순서: 규칙 먼저, 규칙이 못 읽은 것만 모델.
// 표본: eval/golden/holdout_queries.jsonl (규칙을 다듬는 데 쓰지 않은 것)
import 'dart:convert';
import 'dart:io';

import 'package:gagyebu/ai/llm/llm_engine.dart';
import 'package:gagyebu/ai/llm/local_model_engine.dart';
import 'package:gagyebu/ai/llm/local_model_runtime.dart';
import 'package:gagyebu/ai/llm/local_model_runtime_factory.dart';
import 'package:gagyebu/ai/llm/openai_compatible_engine.dart';
import 'package:gagyebu/ai/query/ledger_query.dart';
import 'package:gagyebu/ai/query/llm_query_parser.dart';
import 'package:gagyebu/ai/query/query_parser.dart';
import 'package:gagyebu/core/local_date.dart';
import 'package:gagyebu/domain/default_seed.dart';
import 'package:gagyebu/domain/enums.dart';

String? _arg(List<String> args, String name) {
  for (final a in args) {
    if (a.startsWith('--$name=')) return a.substring(name.length + 3);
  }
  return null;
}

String _squeeze(String? text) =>
    (text ?? '').replaceAll(RegExp(r'\s+'), '').toLowerCase();

Future<void> main(List<String> args) async {
  final mode = _arg(args, 'mode') ?? 'llm';
  final endpoint = _arg(args, 'endpoint');
  final modelPath = _arg(args, 'model');
  final name =
      _arg(args, 'name') ??
      modelPath?.split('/').last.replaceAll('.gguf', '').toLowerCase();
  final needsModel = mode != 'rules';
  final hasModel = modelPath != null || (endpoint != null && name != null);
  if (!{'llm', 'rules', 'app'}.contains(mode) || (needsModel && !hasModel)) {
    stderr.writeln(
      '사용법: dart run tool/query_eval.dart [--mode=llm|rules|app] '
      '[--endpoint=http://127.0.0.1:8088 --name=<모델 이름> | --model=<GGUF 경로>]',
    );
    exit(2);
  }

  LocalModelEngine? local;
  OpenAiCompatibleEngine? server;
  if (needsModel && modelPath != null) {
    local = LocalModelEngine(
      spec: LocalModelSpec(name: name!, modelPath: modelPath),
      runtimeFactory: createLocalModelRuntime,
    );
  } else if (needsModel) {
    server = OpenAiCompatibleEngine(
      endpoint: Uri.parse(endpoint!),
      modelName: name!,
    );
  }
  final LlmEngine? engine = local ?? server;
  final llm = engine == null ? null : LlmQueryParser(engine);

  final today = LocalDate(2026, 11, 17);
  final categories = [
    for (final c in defaultExpenseCategories)
      QueryCategory(c, CategoryKind.expense),
    for (final c in defaultIncomeCategories)
      QueryCategory(c, CategoryKind.income),
  ];

  final lines = File('../eval/golden/holdout_queries.jsonl')
      .readAsLinesSync()
      .where((l) => l.trim().isNotEmpty);
  final fields = <String, List<int>>{};
  void record(String field, bool ok) {
    final s = fields.putIfAbsent(field, () => [0, 0]);
    if (ok) s[0]++;
    s[1]++;
  }

  final misses = <String>[];
  final millis = <int>[];
  var unread = 0;
  for (final line in lines) {
    final c = jsonDecode(line) as Map<String, Object?>;
    final question = c['q']! as String;
    final watch = Stopwatch()..start();
    LedgerQuery? got;
    if (mode != 'llm') {
      got = parseQuery(question, today: today, categories: categories);
    }
    if (got == null && llm != null) {
      got = await llm.parse(question, today: today, categories: categories);
    }
    millis.add(watch.elapsedMilliseconds);

    if (got == null) {
      unread++;
      misses.add('$question: 읽지 못함');
      stdout.write('x');
      continue;
    }
    final party = c['party'] as String?;
    final checks = <String, bool>{
      if (c['period'] != null) '기간': got.period.kind.name == c['period'],
      '분류': got.category == c['category'],
      '종류': got.type?.name == c['type'],
      '집계': got.aggregation.code == c['agg'],
      if (party != null) '상대': _squeeze(got.party).contains(_squeeze(party)),
    };
    checks.forEach(record);
    final allRight = checks.values.every((v) => v);
    record('모든 조건', allRight);
    if (!allRight) {
      final wrong = [
        for (final e in checks.entries)
          if (!e.value) e.key,
      ];
      misses.add(
        '$question: ${wrong.join(', ')} 틀림 → ${got.period.kind.name} '
        '${got.category} ${got.party} ${got.type?.name} ${got.aggregation.code}',
      );
    }
    stdout.write(allRight ? '.' : 'x');
  }

  final how = switch (mode) {
    'llm' => '모델만',
    'rules' => '규칙만',
    _ => '앱과 같은 순서(규칙 → 모델)',
  };
  stdout.writeln('\n== 조회 문장 · $how${name == null ? '' : ' · $name'}');
  for (final e in fields.entries) {
    stdout.writeln('  ${e.key.padRight(8)} ${e.value[0]}/${e.value[1]}');
  }
  stdout.writeln('  읽지 못함    $unread');
  if (millis.isNotEmpty) {
    final sorted = [...millis]..sort();
    stdout.writeln(
      '  시간(ms)   평균 ${millis.reduce((a, b) => a + b) ~/ millis.length} · '
      '중앙 ${sorted[sorted.length ~/ 2]} · 최대 ${sorted.last}',
    );
  }
  if (misses.isNotEmpty) {
    stdout.writeln('  틀린 것');
    for (final m in misses) {
      stdout.writeln('    $m');
    }
  }

  server?.close();
  await local?.dispose();
}
