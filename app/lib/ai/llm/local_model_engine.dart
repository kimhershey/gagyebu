import 'dart:async';
import 'dart:typed_data';

import '../vision/vision_engine.dart';
import 'llm_engine.dart';
import 'local_model_runtime.dart';

/// 생성을 사용자가 멈췄다. 답은 없다.
class GenerationCancelled implements Exception {
  const GenerationCancelled();

  @override
  String toString() => '생성을 멈췄다';
}

/// 돌고 있는 생성을 멈출 수 있는 엔진. 입력창의 "그만" 단추가 쓴다.
///
/// [LlmEngine] · [VisionEngine]의 모양은 그대로 두고, 멈출 수 있는 구현만 이것을
/// 함께 구현한다(`engine is CancellableEngine`으로 알아본다).
abstract interface class CancellableEngine {
  /// 돌고 있는 요청과 기다리는 요청을 모두 멈춘다. 멈춘 요청은
  /// [GenerationCancelled]로 끝난다.
  void cancelAll();
}

/// 기기 안의 모델로 도는 엔진(`docs/SPEC.md` 5.4).
///
/// - 모델은 처음 쓸 때 메모리에 올리고, [idleTimeout] 동안 쓰지 않으면 내린다.
///   OS가 앱을 내렸다가 올린 뒤에도 다음 요청에서 다시 올린다.
/// - 요청은 한 줄로 세워 차례로 돌린다. 런타임은 한 번에 하나만 돌릴 수 있다.
/// - 추론은 런타임이 별도 격리 영역(isolate)에서 한다. 화면이 멈추지 않는다.
/// - mmproj가 있는 모델이면 이미지도 읽는다([VisionEngine]).
class LocalModelEngine implements LlmEngine, VisionEngine, CancellableEngine {
  LocalModelEngine({
    required this.spec,
    required this.runtimeFactory,
    this.idleTimeout = const Duration(minutes: 5),
  });

  final LocalModelSpec spec;

  /// 모델을 돌릴 런타임을 만든다. 시험에서는 가짜를 준다.
  final LocalModelRuntimeFactory runtimeFactory;

  /// 이만큼 쓰지 않으면 모델을 메모리에서 내린다.
  final Duration idleTimeout;

  LocalModelRuntime? _runtime;
  Future<void> _tail = Future<void>.value();
  Timer? _idleTimer;
  int _pending = 0;

  /// [cancelAll]을 부를 때마다 올라간다. 요청은 시작할 때의 값과 달라졌으면 멈춘 것이다.
  int _epoch = 0;
  bool _disposed = false;

  @override
  String get modelName => spec.name;

  /// 이미지를 읽을 수 있는지(mmproj가 있는지).
  bool get readsImages => spec.readsImages;

  /// 모델이 메모리에 올라가 있는지.
  bool get isLoaded => _runtime?.isLoaded ?? false;

  @override
  Future<String> generateJson({
    required String system,
    required String user,
    required Map<String, Object?> schema,
    String? grammar,
    int maxTokens = 512,
  }) => _enqueue(
    LocalGenerationRequest(
      system: system,
      user: user,
      schema: schema,
      grammar: grammar,
      maxTokens: maxTokens,
    ),
  );

  @override
  Future<String> generateJsonFromImage({
    required Uint8List image,
    required String system,
    required String user,
    required Map<String, Object?> schema,
    String? grammar,
    int maxTokens = 1024,
  }) {
    if (!spec.readsImages) {
      throw StateError('${spec.name}에는 이미지를 읽는 mmproj가 없다');
    }
    return _enqueue(
      LocalGenerationRequest(
        system: system,
        user: user,
        schema: schema,
        grammar: grammar,
        image: image,
        maxTokens: maxTokens,
      ),
    );
  }

  Future<String> _enqueue(LocalGenerationRequest request) {
    if (_disposed) throw StateError('엔진을 이미 닫았다');
    final epoch = _epoch;
    _pending++;
    _idleTimer?.cancel();
    final result = _tail.then((_) => _run(request, epoch));
    // 앞의 요청이 실패해도 뒤의 요청은 돈다.
    _tail = result.then<void>((_) {}, onError: (Object _) {}).whenComplete(() {
      _pending--;
      if (_pending == 0) _armIdleTimer();
    });
    return result;
  }

  Future<String> _run(LocalGenerationRequest request, int epoch) async {
    void checkCancelled() {
      if (epoch != _epoch || _disposed) throw const GenerationCancelled();
    }

    checkCancelled();
    final runtime = _runtime ??= runtimeFactory(spec);
    await runtime.load();
    checkCancelled();
    final String text;
    try {
      text = await runtime.generate(request);
    } on Object {
      // 멈춘 생성이 예외로 끝나는 런타임도 있다. 멈춘 것이면 그렇게 알린다.
      checkCancelled();
      rethrow;
    }
    // 멈춘 생성이 그때까지의 글로 끝났으면 버린다. 잘린 JSON이다.
    checkCancelled();
    return text;
  }

  void _armIdleTimer() {
    _idleTimer?.cancel();
    if (_disposed || _runtime == null) return;
    _idleTimer = Timer(idleTimeout, () {
      if (_pending == 0) unawaited(unload());
    });
  }

  @override
  void cancelAll() {
    if (_pending == 0) return;
    _epoch++;
    _runtime?.cancel();
  }

  /// 모델을 메모리에서 내린다. 다음 요청에서 다시 올린다.
  Future<void> unload() async {
    _idleTimer?.cancel();
    _idleTimer = null;
    final runtime = _runtime;
    _runtime = null;
    await runtime?.unload();
  }

  /// 엔진을 닫는다. 돌던 요청은 멈추고 모델을 내린다.
  Future<void> dispose() async {
    if (_disposed) return;
    cancelAll();
    _disposed = true;
    await unload();
  }
}
