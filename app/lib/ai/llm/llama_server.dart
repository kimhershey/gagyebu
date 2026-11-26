/// 앱이 스스로 띄우는 모델 서버(llama.cpp의 `llama-server`). Windows에서 쓴다.
///
/// 사용자가 손댈 것이 없게 한다: 빈 포트를 골라 이 컴퓨터(127.0.0.1)에만 띄우고,
/// 준비될 때까지 기다렸다가 쓰고, 쉬면 내리고, 죽어 있으면 다음 요청에서 다시 띄운다.
/// 주소와 키는 띄울 때마다 새로 정해지고 어디에도 적어 두지 않는다.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:http/http.dart' as http;

import 'llm_engine.dart';
import 'local_model_engine.dart';
import 'local_model_runtime.dart';
import 'openai_compatible_engine.dart';

/// 서버의 실행 파일 하나. [backend]는 화면에 보이는 이름이다('Vulkan', 'CPU').
typedef LlamaServerExecutable = ({String backend, String path});

enum LlamaServerPhase { stopped, starting, running, failed }

/// 서버의 지금 상태. 설정 → AI 모델의 엔진 카드가 보여 준다.
class LlamaServerStatus {
  const LlamaServerStatus(
    this.phase, {
    this.backend,
    this.uri,
    this.modelName,
    this.message,
  });

  final LlamaServerPhase phase;
  final String? backend;
  final Uri? uri;
  final String? modelName;

  /// 실패한 까닭(화면용). 서버가 찍은 글을 그대로 담지 않는다.
  final String? message;
}

/// 프로세스를 띄우는 함수. 시험에서 바꿔 끼운다.
typedef ProcessStarter = Future<Process> Function(
  String executable,
  List<String> arguments,
);

Future<Process> _startProcess(String executable, List<String> arguments) =>
    Process.start(
      executable,
      arguments,
      // 함께 온 DLL을 찾게 실행 파일의 폴더에서 띄운다.
      workingDirectory: File(executable).parent.path,
    );

/// 설치 폴더에 함께 들어 있는 서버 실행 파일들(`engines/vulkan`, `engines/cpu`).
/// 없는 것은 뺀다. 하나도 없으면 앱 안의 엔진을 쓴다.
List<LlamaServerExecutable> findLlamaServerExecutables() {
  final root = File(Platform.resolvedExecutable).parent.path;
  final separator = Platform.pathSeparator;
  final name = Platform.isWindows ? 'llama-server.exe' : 'llama-server';
  return [
    for (final (backend, folder) in const [
      ('Vulkan', 'vulkan'),
      ('CPU', 'cpu'),
    ])
      if (File('$root${separator}engines$separator$folder$separator$name')
          .existsSync())
        (
          backend: backend,
          path: '$root${separator}engines$separator$folder$separator$name',
        ),
  ];
}

class LlamaServerManager {
  LlamaServerManager({
    required this.executables,
    this.idleTimeout = const Duration(minutes: 15),
    this.readyTimeout = const Duration(minutes: 2),
    ProcessStarter? start,
    http.Client? client,
  }) : _start = start ?? _startProcess,
       _client = client ?? http.Client();

  /// 띄워 볼 순서대로(Vulkan 먼저, 안 되면 CPU).
  final List<LlamaServerExecutable> executables;

  /// 이만큼 쓰지 않으면 서버를 내린다. 다음 요청에서 다시 띄운다.
  final Duration idleTimeout;

  /// 띄운 뒤 이만큼 안에 준비되지 않으면 그 실행 파일은 포기한다.
  final Duration readyTimeout;

  final ProcessStarter _start;
  final http.Client _client;
  final _changes = StreamController<LlamaServerStatus>.broadcast();

  LlamaServerStatus _status = const LlamaServerStatus(LlamaServerPhase.stopped);
  LlamaServerStatus get status => _status;
  Stream<LlamaServerStatus> get statusChanges => _changes.stream;

  Process? _process;
  LocalModelSpec? _spec;
  String _apiKey = '';
  Timer? _idleTimer;
  Future<void> _queue = Future<void>.value();
  bool _disposed = false;

  /// 지금 떠 있는 서버가 받는 키. 요청마다 보낸다.
  String get apiKey => _apiKey;

  void _set(LlamaServerStatus status) {
    _status = status;
    if (!_changes.isClosed) _changes.add(status);
  }

  /// [spec]의 모델로 서버가 떠 있게 하고 그 주소를 돌려준다. 띄우지 못하면 [StateError].
  Future<Uri> ensureRunning(LocalModelSpec spec) {
    final result = _queue.then((_) => _ensure(spec));
    _queue = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }

  Future<Uri> _ensure(LocalModelSpec spec) async {
    if (_disposed) throw StateError('서버 관리자를 이미 닫았다');
    final uri = _status.uri;
    if (_status.phase == LlamaServerPhase.running &&
        _spec == spec &&
        uri != null) {
      touch();
      return uri;
    }
    await _stop();
    for (final executable in executables) {
      final started = await _tryStart(executable, spec);
      if (started != null) {
        touch();
        return started;
      }
    }
    _set(
      const LlamaServerStatus(
        LlamaServerPhase.failed,
        message: '엔진을 띄우지 못했습니다',
      ),
    );
    throw StateError('llama-server를 띄우지 못했다');
  }

  Future<Uri?> _tryStart(
    LlamaServerExecutable executable,
    LocalModelSpec spec,
  ) async {
    if (!File(executable.path).existsSync()) return null;
    _set(
      LlamaServerStatus(
        LlamaServerPhase.starting,
        backend: executable.backend,
        modelName: spec.name,
      ),
    );
    final port = await _freePort();
    final random = Random.secure();
    _apiKey = base64Url.encode([
      for (var i = 0; i < 24; i++) random.nextInt(256),
    ]);
    final projector = spec.projectorPath;
    final Process process;
    try {
      process = await _start(executable.path, [
        '-m',
        spec.modelPath,
        if (projector != null) ...['--mmproj', projector],
        '--host',
        '127.0.0.1',
        '--port',
        '$port',
        '-c',
        '${spec.contextSize}',
        '--api-key',
        _apiKey,
      ]);
    } on Object {
      return null;
    }
    // 서버가 찍는 글은 읽어서 버린다(디스크에 남기지 않는다). 읽지 않으면 통이 차서 멈춘다.
    unawaited(process.stdout.drain<void>().catchError((Object _) {}));
    unawaited(process.stderr.drain<void>().catchError((Object _) {}));
    var exited = false;
    unawaited(
      process.exitCode.then((_) {
        exited = true;
        if (identical(_process, process)) {
          // 쓰는 도중에 죽었다. 다음 요청에서 다시 띄운다.
          _process = null;
          _idleTimer?.cancel();
          _set(const LlamaServerStatus(LlamaServerPhase.stopped));
        }
      }),
    );

    final uri = Uri.parse('http://127.0.0.1:$port');
    final deadline = DateTime.now().add(readyTimeout);
    while (!exited && DateTime.now().isBefore(deadline)) {
      if (await _healthy(uri)) {
        _process = process;
        _spec = spec;
        _set(
          LlamaServerStatus(
            LlamaServerPhase.running,
            backend: executable.backend,
            uri: uri,
            modelName: spec.name,
          ),
        );
        return uri;
      }
      await Future<void>.delayed(const Duration(milliseconds: 300));
    }
    if (!exited) process.kill();
    return null;
  }

  Future<bool> _healthy(Uri uri) async {
    try {
      final response = await _client
          .get(uri.resolve('/health'))
          .timeout(const Duration(seconds: 2));
      return response.statusCode == 200;
    } on Object {
      return false;
    }
  }

  static Future<int> _freePort() async {
    final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = socket.port;
    await socket.close();
    return port;
  }

  /// 방금 썼다고 알린다. 쉬는 시간을 처음부터 다시 센다. 요청이 도는 동안에는 세지 않는다.
  void touch() {
    _idleTimer?.cancel();
    if (_disposed || _process == null || _inFlight > 0) return;
    _idleTimer = Timer(idleTimeout, () => unawaited(stop()));
  }

  int _inFlight = 0;

  /// 요청을 보내기 전에 부른다. 끝나면 [release]를 부른다. 그 사이에는 서버를 내리지 않는다.
  void acquire() {
    _inFlight++;
    _idleTimer?.cancel();
  }

  void release() {
    if (_inFlight > 0) _inFlight--;
    touch();
  }

  /// 서버를 내린다. 다음 [ensureRunning]에서 다시 띄운다.
  Future<void> stop() {
    final result = _queue.then((_) => _stop());
    _queue = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }

  Future<void> _stop() async {
    _idleTimer?.cancel();
    final process = _process;
    _process = null;
    _spec = null;
    if (process != null) {
      process.kill();
      await process.exitCode.timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          process.kill(ProcessSignal.sigkill);
          return -1;
        },
      );
    }
    if (_status.phase != LlamaServerPhase.stopped) {
      _set(const LlamaServerStatus(LlamaServerPhase.stopped));
    }
  }

  Future<void> dispose() async {
    if (_disposed) return;
    await stop();
    _disposed = true;
    _client.close();
    await _changes.close();
  }
}

/// 앱이 띄운 서버에 묻는 엔진. 서버를 띄우지 못하면 [fallback](앱 안의 엔진)으로 물러난다.
class LlamaServerEngine implements LlmEngine, CancellableEngine {
  LlamaServerEngine({required this.manager, required this.spec, this.fallback});

  final LlamaServerManager manager;
  final LocalModelSpec spec;
  final LlmEngine? fallback;

  http.Client? _client;
  int _epoch = 0;

  @override
  String get modelName => spec.name;

  /// 서버를 미리 띄워 둔다(앱을 켤 때). 실패해도 조용히 넘어간다.
  Future<void> warmUp() async {
    try {
      await manager.ensureRunning(spec);
    } on Object {
      // 첫 요청에서 다시 해 보고, 그래도 안 되면 물러난다.
    }
  }

  @override
  Future<String> generateJson({
    required String system,
    required String user,
    required Map<String, Object?> schema,
    String? grammar,
    int maxTokens = 512,
  }) async {
    final epoch = _epoch;
    final Uri uri;
    try {
      uri = await manager.ensureRunning(spec);
    } on StateError {
      final other = fallback;
      if (other == null) rethrow;
      return other.generateJson(
        system: system,
        user: user,
        schema: schema,
        grammar: grammar,
        maxTokens: maxTokens,
      );
    }
    if (epoch != _epoch) throw const GenerationCancelled();
    manager.acquire();
    final engine = OpenAiCompatibleEngine(
      endpoint: uri,
      modelName: spec.name,
      client: _client ??= http.Client(),
      apiKey: manager.apiKey,
    );
    try {
      return await engine.generateJson(
        system: system,
        user: user,
        schema: schema,
        grammar: grammar,
        maxTokens: maxTokens,
      );
    } on Object {
      // 멈추려고 연결을 끊은 것이면 멈췄다고 알린다.
      if (epoch != _epoch) throw const GenerationCancelled();
      rethrow;
    } finally {
      manager.release();
    }
  }

  /// 돌고 있는 요청을 멈춘다. 연결이 끊기면 서버도 생성을 멈춘다.
  @override
  void cancelAll() {
    _epoch++;
    _client?.close();
    _client = null;
    final Object? other = fallback;
    if (other is CancellableEngine) other.cancelAll();
  }

  void close() {
    _client?.close();
    _client = null;
  }
}
