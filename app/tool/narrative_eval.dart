// 월별 총평을 모델에 쓰게 해 보고, 검증을 통과하는지와 걸리는 시간을 본다.
//
//   dart run tool/narrative_eval.dart --model=/경로/Qwen3.5-2B-Q4_K_M.gguf
//   dart run tool/narrative_eval.dart --endpoint=http://127.0.0.1:8088 --name=qwen3.5-2b-q4_k_m
//   --raw를 붙이면 모델의 답을 그대로 찍는다.
//
// 지어낸 다섯 달의 집계를 넣는다. 모델의 글이 검증(집계에 없는 숫자, 문장 수, 말투)을
// 통과하면 그 글을, 두 번 떨어지면 문장 틀을 쓴다. 어느 쪽이 쓰였는지 센다.
import 'dart:io';

import 'package:gagyebu/ai/llm/llm_engine.dart';
import 'package:gagyebu/ai/llm/local_model_engine.dart';
import 'package:gagyebu/ai/llm/local_model_runtime.dart';
import 'package:gagyebu/ai/llm/local_model_runtime_factory.dart';
import 'package:gagyebu/ai/llm/narrative_writer.dart';
import 'package:gagyebu/ai/llm/openai_compatible_engine.dart';

String? _arg(List<String> args, String name) {
  for (final a in args) {
    if (a.startsWith('--$name=')) return a.substring(name.length + 3);
  }
  return null;
}

Map<String, Object?> _month(
  String month, {
  required int income,
  required int expense,
  required int previousIncome,
  required int previousExpense,
  required int count,
  required List<(String, int)> categories,
  int? budget,
  (String, String, int)? largest,
  (String, int, int)? counterparty,
  int fixed = 0,
  int noSpendDays = 0,
}) {
  final days = DateTime(
    int.parse(month.substring(0, 4)),
    int.parse(month.substring(5)) + 1,
    0,
  ).day;
  return {
    'month': month,
    'from': '$month-01',
    'to': '$month-$days',
    'income': income,
    'expense': expense,
    'net': income - expense,
    'previous_income': previousIncome,
    'previous_expense': previousExpense,
    'transaction_count': count,
    'by_category': [
      for (final (name, amount) in categories)
        {
          'name': name,
          'amount': amount,
          'ratio': expense == 0
              ? 0
              : double.parse((amount / expense).toStringAsFixed(4)),
        },
    ],
    'budget': budget == null ? null : {'amount': budget, 'spent': expense},
    'largest': [
      if (largest != null)
        {'date': largest.$1, 'name': largest.$2, 'amount': largest.$3},
    ],
    'counterparties': [
      if (counterparty != null)
        {
          'name': counterparty.$1,
          'amount': counterparty.$2,
          'count': counterparty.$3,
        },
    ],
    'fixed_expense': fixed,
    'daily_average': expense ~/ days,
    'no_spend_days': noSpendDays,
  };
}

final _months = [
  _month(
    '2026-10',
    income: 3000000,
    expense: 1860250,
    previousIncome: 2500000,
    previousExpense: 1980250,
    count: 42,
    categories: [('식비', 595280), ('주거·통신', 550000), ('쇼핑', 314970)],
    budget: 2000000,
    largest: ('2026-10-14', '이마트24', 123400),
    counterparty: ('김밥천국', 56000, 7),
    fixed: 550000,
    noSpendDays: 6,
  ),
  // 예산을 넘긴 달
  _month(
    '2026-08',
    income: 2800000,
    expense: 2431900,
    previousIncome: 2800000,
    previousExpense: 1750300,
    count: 61,
    categories: [('문화·여가', 820000), ('식비', 701400), ('교통', 233500)],
    budget: 2000000,
    largest: ('2026-08-03', '제주항공', 412000),
    counterparty: ('스타벅스', 87400, 14),
    fixed: 480000,
    noSpendDays: 2,
  ),
  // 예산이 없고 수입이 없는 달
  _month(
    '2026-02',
    income: 0,
    expense: 412300,
    previousIncome: 1500000,
    previousExpense: 398000,
    count: 17,
    categories: [('식비', 201300), ('생활', 131000), ('교통', 80000)],
    largest: ('2026-02-11', '다이소', 43000),
    noSpendDays: 13,
  ),
  // 거의 쓰지 않은 달
  _month(
    '2026-05',
    income: 4200000,
    expense: 96500,
    previousIncome: 4200000,
    previousExpense: 1320000,
    count: 5,
    categories: [('카페·간식', 52500), ('교통', 44000)],
    budget: 1500000,
    largest: ('2026-05-20', '스타벅스', 21000),
    noSpendDays: 26,
  ),
  // 아무것도 없는 달
  _month(
    '2026-01',
    income: 0,
    expense: 0,
    previousIncome: 0,
    previousExpense: 0,
    count: 0,
    categories: [],
    noSpendDays: 31,
  ),
];

Future<void> main(List<String> args) async {
  final endpoint = _arg(args, 'endpoint');
  final modelPath = _arg(args, 'model');
  final name =
      _arg(args, 'name') ??
      modelPath?.split('/').last.replaceAll('.gguf', '').toLowerCase();
  if (modelPath == null && (endpoint == null || name == null)) {
    stderr.writeln(
      '사용법: dart run tool/narrative_eval.dart '
      '[--endpoint=http://127.0.0.1:8088 --name=<모델 이름> | --model=<GGUF 경로>]',
    );
    exit(2);
  }
  LocalModelEngine? local;
  OpenAiCompatibleEngine? server;
  if (modelPath != null) {
    local = LocalModelEngine(
      spec: LocalModelSpec(name: name!, modelPath: modelPath),
      runtimeFactory: createLocalModelRuntime,
    );
  } else {
    server = OpenAiCompatibleEngine(
      endpoint: Uri.parse(endpoint!),
      modelName: name!,
    );
  }
  final raw = args.contains('--raw');
  final LlmEngine engine = _Logging(local ?? server!, print: raw);
  final writer = NarrativeWriter(engine);

  var byModel = 0;
  var retried = 0;
  for (final stats in _months) {
    final watch = Stopwatch()..start();
    final result = await writer.write(stats);
    final fromModel = result.aiModel != null;
    if (fromModel) byModel++;
    if (result.attempts > 1) retried++;
    stdout.writeln(
      '== ${stats['month']} · ${fromModel ? '모델의 글' : '문장 틀'} · '
      '물은 횟수 ${result.attempts} · ${watch.elapsedMilliseconds}ms',
    );
    stdout.writeln('   ${result.text.replaceAll('\n', '\n   ')}');
    if (fromModel) {
      final bad = unsupportedNumbers(result.text, stats);
      if (bad.isNotEmpty) stdout.writeln('   !! 집계에 없는 숫자: $bad');
    }
  }
  stdout.writeln('\n모델의 글이 통과한 달 $byModel/${_months.length}, 다시 물은 달 $retried');

  server?.close();
  await local?.dispose();
}

/// 모델의 답을 그대로 찍어 보는 엔진(`--raw`).
class _Logging implements LlmEngine {
  _Logging(this._inner, {required this.print});

  final LlmEngine _inner;
  final bool print;

  @override
  String get modelName => _inner.modelName;

  @override
  Future<String> generateJson({
    required String system,
    required String user,
    required Map<String, Object?> schema,
    String? grammar,
    int maxTokens = 512,
  }) async {
    final answer = await _inner.generateJson(
      system: system,
      user: user,
      schema: schema,
      grammar: grammar,
      maxTokens: maxTokens,
    );
    if (print) stdout.writeln('   [모델의 답] $answer');
    return answer;
  }
}
