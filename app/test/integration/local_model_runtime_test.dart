// 실제 모델 파일을 올려 앱 안의 런타임(llama.cpp)을 돌려 본다.
//
// 모델 파일이 있어야 하므로 평소에는 건너뛴다. 돌리려면:
//   GAGYEBU_TEST_MODEL=/경로/Qwen3.5-2B-Q4_K_M.gguf \
//     flutter test test/integration/local_model_runtime_test.dart
@Timeout(Duration(minutes: 30))
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gagyebu/ai/llm/extraction_prompt.dart';
import 'package:gagyebu/ai/llm/llamadart_runtime.dart';
import 'package:gagyebu/ai/llm/local_model_engine.dart';
import 'package:gagyebu/ai/llm/local_model_runtime.dart';
import 'package:gagyebu/ai/llm/local_model_runtime_factory.dart';
import 'package:gagyebu/core/local_date.dart';
import 'package:gagyebu/domain/default_seed.dart';

final _modelPath = Platform.environment['GAGYEBU_TEST_MODEL'];

ExtractionRequest _request(String text) => buildExtractionRequest(
  text: text,
  today: LocalDate(2026, 11, 17),
  expenseCategories: defaultExpenseCategories,
  incomeCategories: defaultIncomeCategories,
);

Future<Map<String, Object?>> _ask(LocalModelEngine engine, String text) async {
  final request = _request(text);
  final raw = await engine.generateJson(
    system: request.system,
    user: request.user,
    schema: request.schema,
    grammar: request.grammar,
    maxTokens: 400,
  );
  return jsonDecode(raw) as Map<String, Object?>;
}

int? _amount(Map<String, Object?> answer) {
  final tx = answer['tx'];
  if (tx is! List || tx.isEmpty) return null;
  return ((tx.first as Map)['a'] as num?)?.toInt();
}

void main() {
  final skip = _modelPath == null
      ? 'GAGYEBU_TEST_MODEL에 GGUF 파일의 경로를 주면 돈다'
      : null;

  group('실제 모델', skip: skip, () {
    late LocalModelEngine engine;
    LlamadartRuntime? runtime;

    setUpAll(() {
      engine = LocalModelEngine(
        spec: LocalModelSpec(name: 'test-model', modelPath: _modelPath!),
        runtimeFactory: (spec) => runtime = LlamadartRuntime(spec),
      );
    });

    tearDownAll(() => engine.dispose());

    test('문법으로 묶은 질문에 형식에 맞는 답을 낸다', () async {
      final answer = await _ask(
        engine,
        '새마을 11/15 19:02 결제완료 23,000원 동네치킨 잔액 410,000원',
      );
      expect(engine.isLoaded, isTrue);
      expect(answer['real'], isTrue);
      expect(_amount(answer), 23000);
    });

    test('같은 시스템 글은 다시 읽지 않는다', () async {
      final before = runtime!.restoredRequests;
      final answer = await _ask(
        engine,
        '수협 11/14 08:30 출금 15,000원 버스충전 잔액 95,000원',
      );
      expect(_amount(answer), 15000);
      expect(runtime!.restoredRequests, before + 1);
    });

    test('문법이 없으면 JSON 스키마로 묶는다', () async {
      final raw = await engine.generateJson(
        system: '너는 JSON만 답한다.',
        user: '하늘은 파란가? {"ok": true 또는 false} 로 답해.',
        schema: {
          'type': 'object',
          'properties': {
            'ok': {'type': 'boolean'},
          },
          'required': ['ok'],
          'additionalProperties': false,
        },
        maxTokens: 32,
      );
      final answer = jsonDecode(raw) as Map<String, Object?>;
      expect(answer['ok'], isA<bool>());
    });

    test('요청 둘을 한꺼번에 보내면 차례로 답한다', () async {
      final answers = await Future.wait([
        _ask(engine, '우체국 11/13 12:10 체크카드승인 8,900원 김밥나라 잔액 77,100원'),
        _ask(engine, '신협 11/12 18:40 출금 42,000원 동네마트 잔액 35,100원'),
      ]);
      expect(_amount(answers[0]), 8900);
      expect(_amount(answers[1]), 42000);
    });

    test('도는 중에 멈추면 멈췄다고 알리고, 그 뒤 요청은 다시 답한다', () async {
      final running = _ask(engine, '새마을 11/11 09:15 결제완료 5,500원 빵집 잔액 29,600원');
      final outcome = running.then<Object?>((v) => v, onError: (Object e) => e);
      await Future<void>.delayed(const Duration(seconds: 2));
      engine.cancelAll();
      expect(await outcome, isA<GenerationCancelled>());

      final answer = await _ask(
        engine,
        '새마을 11/11 09:15 결제완료 5,500원 빵집 잔액 29,600원',
      );
      expect(_amount(answer), 5500);
    });

    test('내린 뒤에도 다음 요청에서 다시 올린다', () async {
      await engine.unload();
      expect(engine.isLoaded, isFalse);
      final answer = await _ask(
        engine,
        '수협 11/10 20:05 출금 12,300원 약국 잔액 17,300원',
      );
      expect(engine.isLoaded, isTrue);
      expect(_amount(answer), 12300);
    });

    test('쓰지 않는 시간이 지나면 모델을 내린다', () async {
      final short = LocalModelEngine(
        spec: LocalModelSpec(name: 'test-model', modelPath: _modelPath!),
        runtimeFactory: createLocalModelRuntime,
        idleTimeout: const Duration(seconds: 2),
      );
      addTearDown(short.dispose);
      await short.generateJson(
        system: '너는 JSON만 답한다.',
        user: '{"ok": true} 라고 답해.',
        schema: {
          'type': 'object',
          'properties': {
            'ok': {'type': 'boolean'},
          },
          'required': ['ok'],
        },
        maxTokens: 16,
      );
      expect(short.isLoaded, isTrue);
      await Future<void>.delayed(const Duration(seconds: 5));
      expect(short.isLoaded, isFalse);
    });
  });

  group('모델 파일이 잘못됐을 때', skip: skip, () {
    Future<Object?> failure(String path) async {
      final engine = LocalModelEngine(
        spec: LocalModelSpec(name: 'broken', modelPath: path),
        runtimeFactory: createLocalModelRuntime,
      );
      try {
        await engine.generateJson(
          system: 's',
          user: 'u',
          schema: const {'type': 'object'},
          maxTokens: 8,
        );
        return null;
      } on Object catch (error) {
        return error;
      } finally {
        await engine.dispose();
      }
    }

    test('없는 파일이면 멈추지 않고 오류로 끝난다', () async {
      final error = await failure('/없는/폴더/모델.gguf')
          .timeout(const Duration(minutes: 1));
      expect(error, isNotNull);
    });

    test('모델이 아닌 파일이면 멈추지 않고 오류로 끝난다', () async {
      final dir = Directory.systemTemp.createTempSync('gagyebu-broken-');
      addTearDown(() => dir.deleteSync(recursive: true));
      final file = File('${dir.path}/broken.gguf')
        ..writeAsBytesSync(List<int>.filled(4096, 7));
      final error = await failure(file.path)
          .timeout(const Duration(minutes: 1));
      expect(error, isNotNull);
    });
  });
}
