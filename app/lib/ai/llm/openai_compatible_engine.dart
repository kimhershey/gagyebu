import 'dart:convert';

import 'package:http/http.dart' as http;

import 'llm_engine.dart';

/// OpenAI 호환 주소로 로컬 추론 서버를 부르는 엔진.
///
/// PC에서 사용자가 따로 띄운 로컬 서버(llama.cpp의 `llama-server` 등)에 연결하는 선택
/// 기능이고, 모델과 프롬프트를 평가하는 도구(`tool/llm_eval.dart`)도 이 엔진을 쓴다.
/// 기기 밖의 서버에 보내는 용도가 아니다. 주소는 이 컴퓨터(127.0.0.1)여야 한다.
class OpenAiCompatibleEngine implements LlmEngine {
  OpenAiCompatibleEngine({
    required Uri endpoint,
    required this.modelName,
    http.Client? client,
    this.timeout = const Duration(minutes: 3),
    this.useGrammar = true,
    this.apiKey,
  }) : _url = endpoint.resolve('/v1/chat/completions'),
       _client = client ?? http.Client();

  final Uri _url;
  final http.Client _client;
  final Duration timeout;

  /// 서버가 키를 요구하면 보낸다. 앱이 스스로 띄운 서버는 띄울 때 정한 키를 받는다.
  final String? apiKey;

  /// 서버가 `grammar` 필드(GBNF)를 받는지. llama.cpp 서버는 받는다.
  final bool useGrammar;

  @override
  final String modelName;

  @override
  Future<String> generateJson({
    required String system,
    required String user,
    required Map<String, Object?> schema,
    String? grammar,
    int maxTokens = 512,
  }) async {
    final response = await _client
        .post(
          _url,
          headers: {
            'Content-Type': 'application/json',
            if (apiKey != null) 'Authorization': 'Bearer $apiKey',
          },
          body: jsonEncode({
            'model': modelName,
            'messages': [
              {'role': 'system', 'content': system},
              {'role': 'user', 'content': user},
            ],
            'temperature': 0,
            'max_tokens': maxTokens,
            // llama.cpp 서버는 GBNF 문법을 받는다. 없으면 JSON 스키마로 묶는다.
            if (grammar != null && useGrammar)
              'grammar': grammar
            else
              'response_format': {
                'type': 'json_schema',
                'json_schema': {
                  'name': 'ledger_extraction',
                  'strict': true,
                  'schema': schema,
                },
              },
            // 생각 과정을 내는 모델은 그 기능을 끈다. 답은 JSON뿐이어야 한다.
            'chat_template_kwargs': {'enable_thinking': false},
          }),
        )
        .timeout(timeout);
    if (response.statusCode != 200) {
      throw StateError(
        '추론 서버가 ${response.statusCode}로 답했다: '
        '${utf8.decode(response.bodyBytes, allowMalformed: true)}',
      );
    }
    final body = jsonDecode(utf8.decode(response.bodyBytes)) as Map;
    final choices = body['choices'] as List;
    final message = (choices.first as Map)['message'] as Map;
    return (message['content'] as String?) ?? '';
  }

  void close() => _client.close();
}
