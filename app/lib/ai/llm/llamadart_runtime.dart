import 'package:llamadart/llamadart.dart';

import 'local_model_runtime.dart';

/// llama.cpp(`llamadart`)로 GGUF 모델을 돌린다(`docs/SPEC.md` 5.4).
///
/// 이 파일은 네이티브 라이브러리를 부르므로 웹 빌드에 들어가면 안 된다.
/// `local_model_runtime_factory.dart`로만 가져온다.
///
/// - 추론은 llamadart가 띄운 별도 격리 영역(isolate)에서 돈다.
/// - Windows는 Vulkan으로 올려 보고 실패하면 CPU로 다시 올린다. Android는
///   llamadart의 기본값이 CPU다.
/// - 생각 과정을 내는 모델은 그 기능을 끈다. 답은 JSON뿐이어야 한다.
class LlamadartRuntime implements LocalModelRuntime {
  LlamadartRuntime(this.spec);

  final LocalModelSpec spec;
  LlamaEngine? _engine;

  @override
  bool get isLoaded => _engine != null;

  @override
  Future<void> load() async {
    if (_engine != null) return;
    final projector = spec.projectorPath;
    final model = LlamaModel(
      ModelSource.path(spec.modelPath),
      projector: projector == null ? null : ModelSource.path(projector),
    );
    try {
      _engine = await LlamaEngine.load(
        model,
        params: ModelParams(contextSize: spec.contextSize),
      );
    } on LlamaException {
      // GPU 드라이버가 없거나 메모리가 모자라 올리지 못했다. CPU로 다시 해 본다.
      _engine = await LlamaEngine.load(
        model,
        params: ModelParams(
          contextSize: spec.contextSize,
          device: ComputeDevice.cpu,
        ),
      );
    }
  }

  @override
  Future<String> generate(LocalGenerationRequest request) {
    final engine = _engine;
    if (engine == null) throw StateError('모델이 올라가 있지 않다');
    final image = request.image;
    final grammar = request.grammar;
    return engine
        .create(
          [
            LlamaChatMessage.fromText(
              role: LlamaChatRole.system,
              text: request.system,
            ),
            if (image == null)
              LlamaChatMessage.fromText(
                role: LlamaChatRole.user,
                text: request.user,
              )
            else
              LlamaChatMessage.withContent(
                role: LlamaChatRole.user,
                content: [
                  LlamaImageContent(bytes: image),
                  LlamaTextContent(request.user),
                ],
              ),
          ],
          params: GenerationParams(
            maxTokens: request.maxTokens,
            // 같은 입력에는 같은 답이 나오게 한다. 평가 때의 설정과 같다.
            temp: 0,
            penalty: 1,
            grammar: grammar,
          ),
          enableThinking: false,
          // 문법이 없으면 JSON 스키마로 묶는다.
          responseFormat: grammar != null
              ? null
              : {
                  'type': 'json_schema',
                  'json_schema': {'schema': request.schema},
                },
        )
        .text();
  }

  @override
  void cancel() => _engine?.cancelGeneration();

  @override
  Future<void> unload() async {
    final engine = _engine;
    _engine = null;
    await engine?.dispose();
  }
}
