import 'dart:typed_data';

/// 이미지를 읽는 모델(`docs/SPEC.md` 5.5).
abstract interface class VisionEngine {
  /// 거래의 ai_model에 적는 이름.
  String get modelName;

  /// [image]를 보고 [schema]에 맞는 JSON 글을 돌려준다.
  Future<String> generateJsonFromImage({
    required Uint8List image,
    required String system,
    required String user,
    required Map<String, Object?> schema,
    String? grammar,
    int maxTokens = 1024,
  });
}
