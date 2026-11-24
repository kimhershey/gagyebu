/// 기기 안에서 모델을 올리고 돌리는 런타임의 창구(`docs/SPEC.md` 5.4).
///
/// 실제 구현은 llama.cpp를 부르는 `llamadart_runtime.dart`다. 그 파일은 네이티브
/// 라이브러리가 있어야 하므로 웹 빌드에는 들어가지 않는다
/// (`local_model_runtime_factory.dart`의 조건부 가져오기). 시험에서는 가짜로 바꾼다.
library;

import 'dart:typed_data';

/// 올릴 모델.
class LocalModelSpec {
  const LocalModelSpec({
    required this.name,
    required this.modelPath,
    this.projectorPath,
    this.contextSize = 4096,
  });

  /// 모델 이름. 거래의 `ai_model`에 적힌다(카탈로그의 ID).
  final String name;

  /// GGUF 파일의 경로.
  final String modelPath;

  /// 이미지를 읽는 데 쓰는 mmproj 파일의 경로. 없으면 글만 읽는다.
  final String? projectorPath;

  /// 문맥 길이(토큰). 평가에서 쓴 값과 같다(`eval/README.md`).
  final int contextSize;

  bool get readsImages => projectorPath != null;

  @override
  bool operator ==(Object other) =>
      other is LocalModelSpec &&
      other.name == name &&
      other.modelPath == modelPath &&
      other.projectorPath == projectorPath &&
      other.contextSize == contextSize;

  @override
  int get hashCode => Object.hash(name, modelPath, projectorPath, contextSize);

  @override
  String toString() => 'LocalModelSpec($name)';
}

/// 생성 요청 하나.
class LocalGenerationRequest {
  const LocalGenerationRequest({
    required this.system,
    required this.user,
    required this.schema,
    this.grammar,
    this.image,
    required this.maxTokens,
  });

  final String system;
  final String user;

  /// 출력의 JSON 스키마. [grammar]가 없을 때 이것으로 출력을 묶는다.
  final Map<String, Object?> schema;

  /// 출력을 강제하는 GBNF 문법.
  final String? grammar;

  /// 함께 보여 줄 이미지(PNG · JPEG 바이트). 원문 이미지는 메모리에서만 다룬다.
  final Uint8List? image;

  final int maxTokens;
}

/// 모델 하나를 메모리에 올리고 돌린다. 한 번에 한 요청만 받는다(부르는 쪽이 줄 세운다).
abstract interface class LocalModelRuntime {
  bool get isLoaded;

  /// 모델을 메모리에 올린다. 이미 올라가 있으면 아무것도 하지 않는다.
  Future<void> load();

  /// 글을 만든다. 생각 과정은 끄고 답만 받는다.
  Future<String> generate(LocalGenerationRequest request);

  /// 돌고 있는 생성을 멈춘다. [generate]는 그때까지 만든 글로 끝나거나 예외로 끝난다.
  void cancel();

  /// 메모리에서 내린다. 다시 [load]하면 쓸 수 있다.
  Future<void> unload();
}

/// [spec]의 모델을 돌릴 런타임을 만든다.
typedef LocalModelRuntimeFactory = LocalModelRuntime Function(
  LocalModelSpec spec,
);
