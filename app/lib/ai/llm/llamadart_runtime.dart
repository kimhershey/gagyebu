import 'dart:io';

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
/// - 시스템 글(지시와 예시, 1,400토큰쯤)은 요청마다 같다. 한 번 읽은 상태를 파일에 두고
///   요청마다 불러와서 다시 읽지 않는다([_PrefixCache]). 질문의 대부분이 시스템 글이라
///   한 건에 걸리는 시간이 3분의 1로 준다.
class LlamadartRuntime implements LocalModelRuntime {
  LlamadartRuntime(this.spec);

  final LocalModelSpec spec;
  LlamaEngine? _engine;
  _PrefixCache? _prefixes;

  @override
  bool get isLoaded => _engine != null;

  /// 시스템 글을 다시 읽지 않고 저장해 둔 상태에서 시작한 요청의 수. 통합 시험이 본다.
  int get restoredRequests => _restoredRequests;
  int _restoredRequests = 0;

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
    _prefixes = _PrefixCache(_engine!, contextSize: spec.contextSize);
  }

  @override
  Future<String> generate(LocalGenerationRequest request) async {
    final engine = _engine;
    if (engine == null) throw StateError('모델이 올라가 있지 않다');
    final image = request.image;
    final grammar = request.grammar;
    // 이미지가 든 요청은 런타임이 앞부분을 재사용하지 않는다.
    final restored = image == null
        ? await _prefixes?.restore(request.system) ?? false
        : false;
    if (restored) _restoredRequests++;
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
            reusePromptPrefix: restored,
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
    final prefixes = _prefixes;
    _prefixes = null;
    await engine?.dispose();
    prefixes?.clear();
  }
}

/// 시스템 글까지 읽은 모델의 상태를 파일에 두었다가 요청마다 불러온다.
///
/// llama.cpp는 앞 요청과 같은 앞부분을 다시 읽지 않는데, 그러려면 기억에서 뒷부분만
/// 지울 수 있어야 한다. Qwen3.5처럼 되감을 수 없는 기억(recurrent)을 쓰는 모델은 그것이
/// 안 되어 매번 전체를 다시 읽는다. 그래서 시스템 글까지만 읽은 상태를 따로 저장해 두고,
/// 요청마다 그 상태에서 시작한다(llama.cpp 서버의 context checkpoint와 같은 생각이다).
///
/// 파일에는 시스템 글을 읽은 상태만 들어간다. 사용자가 넣은 원문은 들어가지 않는다.
/// 모델을 내릴 때 지운다.
class _PrefixCache {
  _PrefixCache(this._engine, {required this.contextSize});

  final LlamaEngine _engine;
  final int contextSize;

  /// 이보다 짧은 앞부분은 저장해 둘 만큼 아끼지 못한다.
  static const _minTokens = 200;

  /// 함께 들고 있는 상태의 수. 문자 읽기 · 조회 · 총평의 시스템 글이 서로 다르다.
  static const _capacity = 3;

  /// 시스템 글 → 상태 파일의 경로. 만들지 못한 것은 null로 적어 다시 해 보지 않는다.
  /// 넣은 순서대로 있어서 맨 앞이 가장 오래 쓰지 않은 것이다.
  final Map<String, String?> _paths = {};
  Directory? _directory;
  int _serial = 0;

  /// [system]까지 읽은 상태로 되돌린다. 되돌렸으면 true이고, 이어지는 요청은 그 뒤만 읽는다.
  /// 어떤 이유로든 못 했으면 false이고, 요청은 처음부터 읽는다.
  Future<bool> restore(String system) async {
    try {
      if (!_paths.containsKey(system)) {
        final path = await _save(system);
        _paths[system] = path;
        while (_paths.length > _capacity) {
          _delete(_paths.remove(_paths.keys.first));
        }
      } else {
        // 방금 쓴 것을 맨 뒤로 보낸다.
        _paths[system] = _paths.remove(system);
      }
      final path = _paths[system];
      if (path == null) return false;
      await _engine.stateLoadFile(path, tokenCapacity: contextSize);
      return true;
    } on Object {
      // 파일이 지워졌거나 런타임이 이 기능을 지원하지 않는다. 느리지만 답은 같다.
      _delete(_paths[system]);
      _paths[system] = null;
      return false;
    }
  }

  /// [system]까지 읽고 그 상태를 파일에 쓴다. 저장할 만하지 않으면 null.
  Future<String?> _save(String system) async {
    if (!_engine.supportsNextTokenScoring ||
        !_engine.supportsStatePersistence) {
      return null;
    }
    // 사용자 글만 다른 두 질문을 틀에 넣어 보고, 토큰이 같은 데까지가 앞부분이다.
    final first = await _tokens(system, 'A');
    final second = await _tokens(system, '가');
    var shared = 0;
    while (shared < first.length &&
        shared < second.length &&
        first[shared] == second[shared]) {
      shared++;
    }
    if (shared < _minTokens) return null;
    final prefix = first.sublist(0, shared);
    final text = await _engine.detokenize(prefix, special: true);
    // 글로 바꿨다가 다시 나눠도 같은 토큰이어야 한다. 아니면 다른 상태를 저장하게 된다.
    final again = await _engine.tokenize(text);
    if (again.length != prefix.length) return null;
    for (var i = 0; i < prefix.length; i++) {
      if (again[i] != prefix[i]) return null;
    }

    // 답을 만들지 않고 읽기만 한다.
    await _engine.scoreNextToken(text, topK: 1, reusePromptPrefix: false);
    final directory = _directory ??= _createDirectory();
    final path = '${directory.path}/prefix-${_serial++}.state';
    final saved = await _engine.stateSaveFile(path, tokens: prefix);
    if (!saved) {
      _delete(path);
      return null;
    }
    return path;
  }

  /// 상태 파일을 둘 임시 폴더를 만든다. 앱이 갑자기 꺼져 남은 옛 폴더는 이때 치운다.
  static Directory _createDirectory() {
    const prefix = 'gagyebu-llm-';
    final limit = DateTime.now().subtract(const Duration(days: 1));
    try {
      for (final entry in Directory.systemTemp.listSync()) {
        final name = entry.uri.pathSegments.lastWhere((s) => s.isNotEmpty);
        if (entry is Directory &&
            name.startsWith(prefix) &&
            entry.statSync().modified.isBefore(limit)) {
          entry.deleteSync(recursive: true);
        }
      }
    } on Object {
      // 치우지 못해도 쓰는 데는 지장이 없다.
    }
    return Directory.systemTemp.createTempSync(prefix);
  }

  Future<List<int>> _tokens(String system, String user) async {
    final rendered = await _engine.chatTemplate(
      [
        LlamaChatMessage.fromText(role: LlamaChatRole.system, text: system),
        LlamaChatMessage.fromText(role: LlamaChatRole.user, text: user),
      ],
      enableThinking: false,
      includeTokenCount: false,
    );
    return _engine.tokenize(rendered.prompt);
  }

  void _delete(String? path) {
    if (path == null) return;
    try {
      File(path).deleteSync();
    } on Object {
      // 이미 없다.
    }
  }

  /// 상태 파일을 모두 지운다.
  void clear() {
    _paths.clear();
    try {
      _directory?.deleteSync(recursive: true);
    } on Object {
      // 이미 없다.
    }
    _directory = null;
  }
}
