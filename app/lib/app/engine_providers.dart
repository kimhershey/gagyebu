import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ai/llm/llm_engine.dart';
import '../ai/llm/local_model_engine.dart';
import '../ai/llm/local_model_runtime.dart';
import '../ai/llm/local_model_runtime_factory.dart';
import '../ai/llm/model_catalog.dart';
import '../ai/llm/model_manager.dart';
import '../ai/llm/model_tier.dart';
import '../ai/llm/openai_compatible_engine.dart';
import '../ai/vision/vision_engine.dart';
import '../features/models/model_providers.dart';

/// 기기 안의 모델을 돌릴 런타임을 만드는 함수. 런타임이 없는 플랫폼(웹)에서는 null.
/// 시험에서 가짜로 바꿔 끼운다.
final localModelRuntimeFactoryProvider = Provider<LocalModelRuntimeFactory?>(
  (ref) => localModelRuntimeAvailable ? createLocalModelRuntime : null,
);

/// 지금 쓸 수 있는 모델: 글을 읽는 것과 이미지를 읽는 것.
typedef LocalModelSpecs = ({LocalModelSpec? text, LocalModelSpec? vision});

/// 내려받아 둔 파일에서 올릴 모델을 고른다.
///
/// - 글: 준비된 글 모델. Windows에서 그 모델의 mmproj도 준비돼 있으면 이미지도 읽는다.
/// - 이미지(Windows): 이미지 전용 모델과 그 mmproj가 준비돼 있으면 그것, 아니면
///   mmproj가 붙은 글 모델.
final localModelSpecsProvider = Provider<LocalModelSpecs>((ref) {
  const none = (text: null, vision: null);
  final platform = ref.watch(devicePlatformProvider);
  if (!platform.runsLocalModels) return none;
  if (ref.watch(localModelRuntimeFactoryProvider) == null) return none;

  // 같은 일을 하는 모델이 여럿 준비돼 있으면 나중에 받은 것을 쓴다.
  final ready = [
    for (final file
        in ref.watch(modelFilesProvider).value ?? const <ModelFileRecord>[])
      if (file.isReady) file,
  ]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  if (ready.isEmpty) return none;
  ModelFileRecord? readyById(String? id) {
    for (final file in ready) {
      if (file.id == id) return file;
    }
    return null;
  }

  // 어느 mmproj가 어느 모델의 것인지는 카탈로그에 적혀 있다. 이미지는 Windows에서만 쓴다.
  final catalog = platform == DevicePlatform.windows
      ? ref.watch(modelCatalogProvider).value
      : null;
  LocalModelSpec specOf(ModelFileRecord file) => LocalModelSpec(
    name: file.id,
    modelPath: file.path,
    projectorPath: readyById(catalog?.byId(file.id)?.mmproj)?.path,
  );

  LocalModelSpec? text;
  LocalModelSpec? vision;
  for (final file in ready) {
    if (file.kind == ModelKind.text) {
      text ??= specOf(file);
    } else if (file.kind == ModelKind.vision) {
      final spec = specOf(file);
      if (spec.readsImages) vision ??= spec;
    }
  }
  if (vision == null && text != null && text.readsImages) vision = text;
  return (text: text, vision: vision);
});

/// 모델 하나를 돌리는 엔진. 같은 모델을 글과 이미지에 함께 쓰면 엔진도 하나다
/// (메모리에 두 번 올리지 않는다). 쓰는 곳이 없어지면 모델을 내린다.
final _localEngineProvider = Provider.autoDispose
    .family<LocalModelEngine, LocalModelSpec>((ref, spec) {
      final engine = LocalModelEngine(
        spec: spec,
        runtimeFactory: ref.watch(localModelRuntimeFactoryProvider)!,
      );
      ref.onDispose(engine.dispose);
      return engine;
    });

/// 기기 내 LLM. 모델이 없는 기기(웹 앱, 저사양 폰)와 모델을 내려받기 전에는 null이고,
/// 그때는 규칙만으로 해석한다.
///
/// 사용자가 로컬 엔진 주소를 적어 두었으면(Windows, 선택) 그 서버를 쓴다. 아니면
/// 내려받아 둔 모델을 기기 안에서 돌린다.
final llmEngineProvider = Provider<LlmEngine?>((ref) {
  final platform = ref.watch(devicePlatformProvider);
  if (platform == DevicePlatform.web) return null;

  final endpoint = ref.watch(modelEndpointProvider);
  if (endpoint != null) {
    final engine = OpenAiCompatibleEngine(
      endpoint: endpoint.uri,
      modelName: endpoint.modelName ?? 'local-server',
    );
    ref.onDispose(engine.close);
    return engine;
  }

  final spec = ref.watch(localModelSpecsProvider.select((s) => s.text));
  return spec == null ? null : ref.watch(_localEngineProvider(spec));
});

/// 이미지를 읽는 모델. 없으면 null이고 이미지 입력을 쓸 수 없다.
final visionEngineProvider = Provider<VisionEngine?>((ref) {
  final spec = ref.watch(localModelSpecsProvider.select((s) => s.vision));
  return spec == null ? null : ref.watch(_localEngineProvider(spec));
});
