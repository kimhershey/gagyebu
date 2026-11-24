// 이미지(거래내역 화면, 영수증)를 모델로 읽혀 보고, 뽑은 줄과 검산 결과를 찍는다.
//
//   dart run tool/vision_eval.dart --model=/경로/Qwen3.5-2B-Q4_K_M.gguf \
//     --mmproj=/경로/mmproj-F16.gguf 거래내역.png 영수증.png
//
// 앱이 쓰는 것과 같은 런타임(`LocalModelEngine`)과 같은 해석기(`VisionTextParser`)로 돈다.
// 정답과 견주지는 않는다. 눈으로 그림과 맞춰 본다. --raw를 붙이면 모델의 답을 그대로 찍는다.
import 'dart:io';
import 'dart:typed_data';

import 'package:gagyebu/ai/llm/local_model_engine.dart';
import 'package:gagyebu/ai/llm/local_model_runtime.dart';
import 'package:gagyebu/ai/llm/local_model_runtime_factory.dart';
import 'package:gagyebu/ai/vision/vision_engine.dart';
import 'package:gagyebu/ai/vision/vision_rows.dart';
import 'package:gagyebu/ai/vision/vision_text_parser.dart';
import 'package:gagyebu/core/local_date.dart';

String? _arg(List<String> args, String name) {
  for (final a in args) {
    if (a.startsWith('--$name=')) return a.substring(name.length + 3);
  }
  return null;
}

Future<void> main(List<String> args) async {
  final modelPath = _arg(args, 'model');
  final projector = _arg(args, 'mmproj');
  final images = [
    for (final a in args)
      if (!a.startsWith('--')) a,
  ];
  if (modelPath == null || projector == null || images.isEmpty) {
    stderr.writeln(
      '사용법: dart run tool/vision_eval.dart --model=<GGUF 경로> '
      '--mmproj=<mmproj 경로> <그림 파일>...',
    );
    exit(2);
  }
  final name = modelPath.split('/').last.replaceAll('.gguf', '').toLowerCase();
  final engine = LocalModelEngine(
    spec: LocalModelSpec(
      name: name,
      modelPath: modelPath,
      projectorPath: projector,
    ),
    runtimeFactory: createLocalModelRuntime,
  );
  final parser = VisionTextParser(
    args.contains('--raw') ? _Logging(engine) : engine,
  );
  final today = LocalDate(2026, 11, 17);

  for (final path in images) {
    final bytes = File(path).readAsBytesSync();
    final watch = Stopwatch()..start();
    final result = await parser.parse(bytes, today: today);
    stdout.writeln(
      '== ${path.split('/').last} · 물은 횟수 ${result.attempts} · '
      '${watch.elapsedMilliseconds}ms',
    );
    final extraction = result.extraction;
    if (extraction == null) {
      stdout.writeln('   읽지 못함: ${result.failure}');
      continue;
    }
    stdout.writeln(
      '   종류 ${extraction.kind.name} · 줄 ${extraction.rows.length}개'
      '${extraction.receiptTotal == null ? '' : ' · 영수증 합계 ${extraction.receiptTotal}'}'
      '${extraction.items.isEmpty ? '' : ' · 품목의 합 ${extraction.itemSum}'}',
    );
    final checks = extraction.verify();
    for (final (i, row) in extraction.rows.indexed) {
      final check = checks[i];
      stdout.writeln(
        '   ${row.date} ${row.time ?? '--:--'} ${row.direction.code.padRight(3)} '
        '${row.amount.toString().padLeft(9)} 잔액 ${row.balance ?? '-'} '
        '"${row.counterparty}" · ${_verdict(check)}',
      );
    }
    for (final item in extraction.items) {
      stdout.writeln('     품목 ${item.name} ${item.amount}');
    }
  }
  await engine.dispose();
}

String _verdict(VisionCheck check) {
  if (check.verified) return '검산 맞음';
  if (check.issues.isEmpty) return '견줄 것 없음';
  return '확인 필요 ${check.issues.map((e) => e.name).join(',')}';
}

/// 모델의 답을 그대로 찍어 보는 엔진(`--raw`).
class _Logging implements VisionEngine {
  _Logging(this._inner);

  final VisionEngine _inner;

  @override
  String get modelName => _inner.modelName;

  @override
  Future<String> generateJsonFromImage({
    required Uint8List image,
    required String system,
    required String user,
    required Map<String, Object?> schema,
    String? grammar,
    int maxTokens = 1024,
  }) async {
    final answer = await _inner.generateJsonFromImage(
      image: image,
      system: system,
      user: user,
      schema: schema,
      grammar: grammar,
      maxTokens: maxTokens,
    );
    stdout.writeln('   [모델의 답] $answer');
    return answer;
  }
}
