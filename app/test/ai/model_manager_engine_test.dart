import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:gagyebu/ai/llm/llm_engine.dart';
import 'package:gagyebu/ai/llm/local_model_engine.dart';
import 'package:gagyebu/ai/llm/local_model_runtime.dart';
import 'package:gagyebu/ai/vision/vision_engine.dart';

import 'model_manager_fakes.dart';

const textSpec = LocalModelSpec(
  name: 'qwen3.5-2b-q4_k_m',
  modelPath: '/models/2b.gguf',
);
const visionSpec = LocalModelSpec(
  name: 'qwen3.5-2b-q4_k_m',
  modelPath: '/models/2b.gguf',
  projectorPath: '/models/2b-mmproj.gguf',
);

void main() {
  late List<String> log;
  late List<FakeRuntime> runtimes;
  late List<LocalGenerationRequest> requests;

  LocalModelEngine engineFor(
    LocalModelSpec spec, {
    Duration idle = const Duration(minutes: 5),
    void Function(FakeRuntime runtime)? setUp,
  }) => LocalModelEngine(
    spec: spec,
    idleTimeout: idle,
    runtimeFactory: (spec) {
      final runtime = FakeRuntime(spec, log);
      runtime.onGenerate = (request) async {
        requests.add(request);
        return '{"답":"${request.user}"}';
      };
      setUp?.call(runtime);
      runtimes.add(runtime);
      return runtime;
    },
  );

  Future<String> ask(LlmEngine engine, String user) => engine.generateJson(
    system: '규칙',
    user: user,
    schema: const {'type': 'object'},
    grammar: 'root ::= "{}"',
    maxTokens: 64,
  );

  setUp(() {
    log = [];
    runtimes = [];
    requests = [];
  });

  test('처음 쓸 때 모델을 올리고, 다음부터는 올려 둔 것을 쓴다', () async {
    final engine = engineFor(textSpec);
    addTearDown(engine.dispose);
    expect(engine.modelName, 'qwen3.5-2b-q4_k_m');
    // 만들기만 해서는 올리지 않는다.
    expect(runtimes, isEmpty);
    expect(engine.isLoaded, isFalse);

    expect(await ask(engine, '하나'), '{"답":"하나"}');
    expect(await ask(engine, '둘'), '{"답":"둘"}');
    expect(log, ['load', 'generate:하나', 'generate:둘']);
    expect(runtimes, hasLength(1));
    expect(engine.isLoaded, isTrue);

    final request = requests.first;
    expect(request.system, '규칙');
    expect(request.grammar, 'root ::= "{}"');
    expect(request.schema, {'type': 'object'});
    expect(request.maxTokens, 64);
    expect(request.image, isNull);
  });

  test('요청은 한 줄로 세워 차례로 돌린다', () async {
    final gates = <String, Completer<void>>{};
    var running = 0;
    var mostAtOnce = 0;
    final engine = engineFor(
      textSpec,
      setUp: (runtime) => runtime.onGenerate = (request) async {
        running++;
        if (running > mostAtOnce) mostAtOnce = running;
        await (gates[request.user] ??= Completer<void>()).future;
        running--;
        return request.user;
      },
    );
    addTearDown(engine.dispose);

    final answers = <String>[];
    final all = Future.wait([
      for (final user in ['가', '나', '다']) ask(engine, user).then(answers.add),
    ]);
    await pumpEventQueue();
    // 첫 요청만 돌고 있다.
    expect(log, ['load', 'generate:가']);
    for (final user in ['가', '나', '다']) {
      (gates[user] ??= Completer<void>()).complete();
      await pumpEventQueue();
    }
    await all;
    expect(answers, ['가', '나', '다']);
    expect(mostAtOnce, 1);
    expect(log, ['load', 'generate:가', 'generate:나', 'generate:다']);
  });

  test('앞의 요청이 실패해도 뒤의 요청은 돈다', () async {
    final engine = engineFor(
      textSpec,
      setUp: (runtime) => runtime.onGenerate = (request) async {
        if (request.user == '고장') throw StateError('추론 실패');
        return request.user;
      },
    );
    addTearDown(engine.dispose);
    final broken = ask(engine, '고장');
    final next = ask(engine, '정상');
    await expectLater(broken, throwsStateError);
    expect(await next, '정상');
  });

  test('쓰지 않고 시간이 지나면 모델을 내리고, 다시 쓰면 다시 올린다', () async {
    final engine = engineFor(textSpec, idle: const Duration(milliseconds: 40));
    addTearDown(engine.dispose);
    await ask(engine, '하나');
    expect(engine.isLoaded, isTrue);

    await Future<void>.delayed(const Duration(milliseconds: 120));
    expect(engine.isLoaded, isFalse);
    expect(log, ['load', 'generate:하나', 'unload']);

    // Android가 앱을 내렸다 올린 뒤처럼, 다음 요청에서 다시 올린다.
    expect(await ask(engine, '둘'), '{"답":"둘"}');
    expect(log, ['load', 'generate:하나', 'unload', 'load', 'generate:둘']);
    expect(runtimes, hasLength(2));
  });

  test('쓰는 동안에는 내리지 않는다', () async {
    final gate = Completer<void>();
    final engine = engineFor(
      textSpec,
      idle: const Duration(milliseconds: 30),
      setUp: (runtime) => runtime.onGenerate = (request) async {
        await gate.future;
        return request.user;
      },
    );
    addTearDown(engine.dispose);
    final answer = ask(engine, '오래 걸리는 것');
    // 내리는 시간보다 오래 돈다.
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(engine.isLoaded, isTrue);
    expect(log, isNot(contains('unload')));
    gate.complete();
    expect(await answer, '오래 걸리는 것');
    // 끝난 뒤부터 다시 센다.
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(engine.isLoaded, isFalse);
  });

  test('멈추면 돌던 요청과 기다리던 요청이 GenerationCancelled로 끝난다', () async {
    late FakeRuntime runtime;
    final engine = engineFor(
      textSpec,
      setUp: (r) {
        runtime = r;
        r.onGenerate = (request) async {
          // 멈출 때까지 돌다가, 그때까지 만든 잘린 글로 끝난다.
          await r.cancelled.future;
          return '{"tx":[{"d":"2026-';
        };
      },
    );
    addTearDown(engine.dispose);
    expect(engine, isA<CancellableEngine>());

    final running = ask(engine, '도는 것');
    final waiting = ask(engine, '기다리는 것');
    final runningDone = expectLater(
      running,
      throwsA(isA<GenerationCancelled>()),
    );
    final waitingDone = expectLater(
      waiting,
      throwsA(isA<GenerationCancelled>()),
    );
    await pumpEventQueue();
    expect(log, ['load', 'generate:도는 것']);

    engine.cancelAll();
    await runningDone;
    await waitingDone;
    // 잘린 글은 버렸고, 기다리던 요청은 런타임에 닿지도 않았다.
    expect(log, ['load', 'generate:도는 것', 'cancel']);

    // 멈춘 뒤에도 다음 요청은 받는다.
    runtime
      ..cancelled = Completer<void>()
      ..onGenerate = (request) async => request.user;
    expect(await ask(engine, '다음'), '다음');
  });

  test('멈춘 생성이 예외로 끝나는 런타임이어도 GenerationCancelled로 알린다', () async {
    final engine = engineFor(
      textSpec,
      setUp: (r) => r.onGenerate = (request) async {
        await r.cancelled.future;
        throw StateError('generation aborted');
      },
    );
    addTearDown(engine.dispose);
    final running = expectLater(
      ask(engine, '도는 것'),
      throwsA(isA<GenerationCancelled>()),
    );
    await pumpEventQueue();
    engine.cancelAll();
    await running;
  });

  test('도는 것이 없을 때 멈추는 것은 아무 일도 하지 않는다', () async {
    final engine = engineFor(textSpec);
    addTearDown(engine.dispose);
    engine.cancelAll();
    expect(await ask(engine, '하나'), '{"답":"하나"}');
    engine.cancelAll();
    expect(log, ['load', 'generate:하나']);
  });

  test('모델을 올리지 못하면 요청이 실패하고, 다음 요청에서 다시 해 본다', () async {
    var attempts = 0;
    final engine = engineFor(
      textSpec,
      setUp: (runtime) => runtime.onLoad = () async {
        attempts++;
        if (attempts == 1) throw StateError('파일이 깨졌다');
      },
    );
    addTearDown(engine.dispose);
    await expectLater(ask(engine, '하나'), throwsStateError);
    expect(engine.isLoaded, isFalse);
    expect(await ask(engine, '둘'), '{"답":"둘"}');
  });

  test('닫으면 모델을 내리고 더 받지 않는다', () async {
    final engine = engineFor(textSpec);
    await ask(engine, '하나');
    await engine.dispose();
    expect(log.last, 'unload');
    expect(engine.isLoaded, isFalse);
    expect(() => ask(engine, '둘'), throwsStateError);
    // 두 번 닫아도 된다.
    await engine.dispose();
  });

  group('이미지', () {
    Future<String> show(VisionEngine engine) => engine.generateJsonFromImage(
      image: Uint8List.fromList([1, 2, 3]),
      system: '규칙',
      user: '이 화면의 거래를 뽑는다',
      schema: const {'type': 'object'},
    );

    test('mmproj가 있는 모델은 이미지를 함께 넘긴다', () async {
      final engine = engineFor(visionSpec);
      addTearDown(engine.dispose);
      expect(engine.readsImages, isTrue);
      await show(engine);
      expect(requests.single.image, [1, 2, 3]);
      expect(requests.single.maxTokens, 1024);
      expect(runtimes.single.spec.projectorPath, '/models/2b-mmproj.gguf');
    });

    test('글과 이미지가 같은 모델이면 한 번만 올린다', () async {
      final engine = engineFor(visionSpec);
      addTearDown(engine.dispose);
      await ask(engine, '글');
      await show(engine);
      expect(log.where((e) => e == 'load'), hasLength(1));
      expect(runtimes, hasLength(1));
    });

    test('mmproj가 없는 모델에 이미지를 주면 받지 않는다', () {
      final engine = engineFor(textSpec);
      addTearDown(engine.dispose);
      expect(engine.readsImages, isFalse);
      expect(() => show(engine), throwsStateError);
      expect(runtimes, isEmpty);
    });
  });
}
