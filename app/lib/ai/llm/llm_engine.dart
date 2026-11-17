/// 기기 안에서 도는 언어 모델을 부르는 창구.
///
/// 구현은 플랫폼마다 다르다. Windows와 Android는 llama.cpp를 앱에 넣어 부르고,
/// PC에서는 사용자가 따로 띄운 로컬 서버(OpenAI 호환 주소)에 연결할 수도 있다.
/// 웹 앱에는 구현이 없다(v1).
abstract interface class LlmEngine {
  /// 모델 이름. AI가 만든 거래의 `ai_model`에 적는다.
  String get modelName;

  /// [schema](JSON 스키마)에 맞는 JSON 문자열을 만든다.
  ///
  /// 구현은 문법 제약 디코딩으로 출력 형태를 스키마에 맞춘다. 그래도 호출하는 쪽은
  /// 결과를 다시 검증한다.
  ///
  /// [grammar]는 같은 형식을 공백 없이 강제하는 GBNF 문법이다. 문법을 받는 엔진
  /// (llama.cpp)은 스키마 대신 이것을 써서 출력 토큰을 줄인다.
  Future<String> generateJson({
    required String system,
    required String user,
    required Map<String, Object?> schema,
    String? grammar,
    int maxTokens = 512,
  });
}
