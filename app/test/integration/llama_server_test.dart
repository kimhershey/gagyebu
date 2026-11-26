// 앱이 띄우는 모델 서버(llama-server)를 실제 실행 파일과 모델로 돌려 본다.
//
// 평소에는 건너뛴다. 돌리려면:
//   GAGYEBU_TEST_LLAMA_SERVER=/경로/llama-server GAGYEBU_TEST_MODEL=/경로/모델.gguf \
//     flutter test test/integration/llama_server_test.dart
@Timeout(Duration(minutes: 20))
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gagyebu/ai/llm/extraction_prompt.dart';
import 'package:gagyebu/ai/llm/llama_server.dart';
import 'package:gagyebu/ai/llm/llm_engine.dart';
import 'package:gagyebu/ai/llm/local_model_engine.dart';
import 'package:gagyebu/ai/llm/local_model_runtime.dart';
import 'package:gagyebu/core/local_date.dart';
import 'package:gagyebu/domain/default_seed.dart';

final _server = Platform.environment['GAGYEBU_TEST_LLAMA_SERVER'];
final _model = Platform.environment['GAGYEBU_TEST_MODEL'];

Future<int?> _amount(LlmEngine engine, String text) async {
  final request = buildExtractionRequest(
    text: text,
    today: LocalDate(2026, 11, 17),
    expenseCategories: defaultExpenseCategories,
    incomeCategories: defaultIncomeCategories,
  );
  final raw = await engine.generateJson(
    system: request.system,
    user: request.user,
    schema: request.schema,
    grammar: request.grammar,
    maxTokens: 400,
  );
  final tx = (jsonDecode(raw) as Map)['tx'] as List;
  return ((tx.first as Map)['a'] as num?)?.toInt();
}

class _Fixed implements LlmEngine {
  int calls = 0;

  @override
  String get modelName => 'fallback';

  @override
  Future<String> generateJson({
    required String system,
    required String user,
    required Map<String, Object?> schema,
    String? grammar,
    int maxTokens = 512,
  }) async {
    calls++;
    return '{"tx":[{"a":1}]}';
  }
}

void main() {
  final skip = _server == null || _model == null
      ? 'GAGYEBU_TEST_LLAMA_SERVER와 GAGYEBU_TEST_MODEL을 주면 돈다'
      : null;

  group('앱이 띄우는 모델 서버', skip: skip, () {
    late LocalModelSpec spec;
    setUpAll(
      () => spec = LocalModelSpec(name: 'test-model', modelPath: _model!),
    );

    test('스스로 띄우고, 읽고, 멈추고, 쉬면 내렸다가 다시 띄운다', () async {
      final manager = LlamaServerManager(
        // 첫 실행 파일은 없는 것이다. 다음 것으로 넘어가야 한다.
        executables: [
          (backend: 'Vulkan', path: '/없는/llama-server'),
          (backend: 'CPU', path: _server!),
        ],
        idleTimeout: const Duration(seconds: 3),
      );
      addTearDown(manager.dispose);
      final engine = LlamaServerEngine(manager: manager, spec: spec);
      expect(manager.status.phase, LlamaServerPhase.stopped);

      expect(
        await _amount(engine, '새마을 11/15 19:02 결제완료 23,000원 동네치킨 잔액 410,000원'),
        23000,
      );
      final running = manager.status;
      expect(running.phase, LlamaServerPhase.running);
      expect(running.backend, 'CPU');
      expect(running.uri!.host, '127.0.0.1');
      expect(running.uri!.port, greaterThan(0));

      // 키 없이 묻는 다른 프로그램은 거절된다.
      final client = HttpClient();
      final request = await client.postUrl(
        running.uri!.resolve('/v1/chat/completions'),
      );
      request.headers.contentType = ContentType.json;
      request.write('{"messages":[{"role":"user","content":"hi"}]}');
      final refused = await request.close();
      expect(refused.statusCode, 401);
      await refused.drain<void>();
      client.close();

      // 도는 중에 멈춘다.
      final stopped = _amount(
        engine,
        '수협 11/14 08:30 출금 15,000원 버스충전 잔액 95,000원',
      ).then<Object?>((v) => v, onError: (Object e) => e);
      await Future<void>.delayed(const Duration(seconds: 1));
      engine.cancelAll();
      expect(await stopped, isA<GenerationCancelled>());

      // 그 뒤 요청은 다시 답한다.
      expect(
        await _amount(engine, '수협 11/14 08:30 출금 15,000원 버스충전 잔액 95,000원'),
        15000,
      );

      // 쉬면 내린다. 다음 요청에서 다시 띄운다(주소는 달라질 수 있다).
      await Future<void>.delayed(const Duration(seconds: 6));
      expect(manager.status.phase, LlamaServerPhase.stopped);
      expect(
        await _amount(engine, '우체국 11/13 12:10 체크카드승인 8,900원 김밥나라 잔액 77,100원'),
        8900,
      );
      expect(manager.status.phase, LlamaServerPhase.running);
      engine.close();
    });

    test('띄울 실행 파일이 없으면 앱 안의 엔진으로 물러난다', () async {
      final manager = LlamaServerManager(
        executables: [(backend: 'CPU', path: '/없는/llama-server')],
      );
      addTearDown(manager.dispose);
      final fallback = _Fixed();
      final engine = LlamaServerEngine(
        manager: manager,
        spec: spec,
        fallback: fallback,
      );
      expect(await _amount(engine, '아무 글'), 1);
      expect(fallback.calls, 1);
      expect(manager.status.phase, LlamaServerPhase.failed);
    });
  });
}
