import 'dart:async';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:gagyebu/ai/llm/local_model_runtime.dart';
import 'package:gagyebu/ai/llm/model_catalog.dart';
import 'package:gagyebu/ai/llm/model_file_store.dart';
import 'package:gagyebu/ai/llm/model_manager.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// 메모리에 두는 모델 파일 저장소.
class MemoryModelFileStore implements ModelFileStore {
  final files = <String, List<int>>{};

  /// 남은 공간(바이트). null이면 알 수 없다.
  int? free;

  /// 이만큼 쓴 뒤에는 쓰기가 실패한다(디스크가 찬 경우).
  int? failWritesAfter;

  @override
  Future<String> pathFor(String fileName) async => '/models/$fileName';

  @override
  Future<bool> exists(String path) async => files.containsKey(path);

  @override
  Future<int> length(String path) async => files[path]?.length ?? 0;

  @override
  Future<ModelFileSink> openWrite(String path, {required bool append}) async {
    final buffer = append ? [...?files[path]] : <int>[];
    files[path] = buffer;
    return _MemorySink(this, buffer);
  }

  @override
  Future<String> sha256Of(String path) async =>
      sha256.convert(files[path]!).toString();

  @override
  Future<void> rename(String from, String to) async {
    files[to] = files.remove(from)!;
  }

  @override
  Future<void> delete(String path) async {
    files.remove(path);
  }

  @override
  Future<int?> freeSpace() async => free;
}

class _MemorySink implements ModelFileSink {
  _MemorySink(this._store, this._buffer);

  final MemoryModelFileStore _store;
  final List<int> _buffer;

  @override
  Future<void> add(List<int> bytes) async {
    final limit = _store.failWritesAfter;
    if (limit != null && _buffer.length + bytes.length > limit) {
      throw StateError('디스크가 찼다');
    }
    _buffer.addAll(bytes);
  }

  @override
  Future<void> close() async {}
}

/// 메모리에 두는 기록.
class MemoryModelFileRegistry implements ModelFileRegistry {
  final records = <String, ModelFileRecord>{};

  /// 적힌 상태의 차례. 진행을 적는지 보는 데 쓴다.
  final history = <ModelFileRecord>[];

  @override
  Future<List<ModelFileRecord>> all() async => records.values.toList();

  @override
  Future<ModelFileRecord?> byId(String id) async => records[id];

  @override
  Future<void> put(ModelFileRecord record) async {
    records[record.id] = record;
    history.add(record);
  }

  @override
  Future<void> remove(String id) async {
    records.remove(id);
  }
}

/// 모델 파일을 주는 가짜 서버.
class FakeModelServer {
  FakeModelServer(this.bytes, {this.chunkSize = 1000});

  /// 서버에 있는 파일.
  Uint8List bytes;

  final int chunkSize;

  /// 받은 요청들.
  final requests = <http.BaseRequest>[];

  /// 이만큼(요청마다) 보낸 뒤 연결을 끊는다. null이면 끝까지 보낸다.
  int? cutAfter;

  /// 이만큼 보낸 뒤 더 보내지 않고 멈춰 있는다(끊지도 않는다).
  int? stallAfter;

  /// Range를 듣지 않고 늘 처음부터 준다.
  bool ignoreRange = false;

  /// Content-Range의 시작을 이만큼 어긋나게 답한다.
  int rangeSkew = 0;

  /// Content-Length를 알려 주지 않는다.
  bool hideLength = false;

  /// 이 상태 코드로만 답한다(404 등).
  int? status;

  /// 조각을 하나 보낼 때마다 불린다(보낸 바이트 수). 도중에 멈추는 시험에 쓴다.
  void Function(int sent)? onChunk;

  String get sha256Hex => sha256.convert(bytes).toString();

  List<String?> get ranges => [for (final r in requests) r.headers['Range']];

  http.Client get client => MockClient.streaming(_handle);

  Future<http.StreamedResponse> _handle(
    http.BaseRequest request,
    http.ByteStream body,
  ) async {
    requests.add(request);
    final forced = status;
    if (forced != null) {
      return http.StreamedResponse(const Stream.empty(), forced);
    }
    var start = 0;
    final range = request.headers['Range'];
    if (range != null && !ignoreRange) {
      start = int.parse(RegExp(r'bytes=(\d+)-').firstMatch(range)!.group(1)!);
      if (start >= bytes.length) {
        return http.StreamedResponse(const Stream.empty(), 416);
      }
    }
    final partial = range != null && !ignoreRange;
    final remaining = bytes.length - start;
    return http.StreamedResponse(
      _send(start),
      partial ? 206 : 200,
      contentLength: hideLength ? null : remaining,
      headers: {
        if (partial)
          'content-range':
              'bytes ${start + rangeSkew}-${bytes.length - 1}/${bytes.length}',
      },
    );
  }

  Stream<List<int>> _send(int start) async* {
    var sent = 0;
    for (var at = start; at < bytes.length; at += chunkSize) {
      final cut = cutAfter;
      if (cut != null && sent >= cut) {
        throw http.ClientException('연결이 끊겼다');
      }
      final stall = stallAfter;
      if (stall != null && sent >= stall) {
        await Completer<void>().future;
      }
      final end = at + chunkSize > bytes.length ? bytes.length : at + chunkSize;
      yield bytes.sublist(at, end);
      sent += end - at;
      onChunk?.call(sent);
      // 조각 사이에 다른 일이 끼어들 틈을 준다.
      await Future<void>.delayed(Duration.zero);
    }
  }
}

/// 내용이 정해진 바이트열(0, 1, 2, …를 섞은 것).
Uint8List sampleBytes(int length, {int seed = 7}) => Uint8List.fromList([
  for (var i = 0; i < length; i++) (i * 31 + seed) % 251,
]);

/// 시험용 카탈로그 항목.
ModelCatalogEntry entryFor(
  FakeModelServer server, {
  String id = 'test-model',
  ModelKind kind = ModelKind.text,
  bool withSize = true,
  String? sha256Hex,
  bool withUrl = true,
  bool withHash = true,
}) => ModelCatalogEntry(
  id: id,
  kind: kind,
  name: '시험 모델',
  license: 'Apache-2.0',
  url: withUrl ? Uri.parse('https://models.example/$id.gguf') : null,
  sizeBytes: withSize ? server.bytes.length : null,
  sha256: withHash ? (sha256Hex ?? server.sha256Hex) : null,
  minMemoryGb: 6,
  platforms: const {'android', 'windows'},
);

/// 정해 둔 답을 내는 가짜 런타임.
class FakeRuntime implements LocalModelRuntime {
  FakeRuntime(this.spec, this.log);

  final LocalModelSpec spec;

  /// 일어난 일의 차례('load', 'generate:…', 'cancel', 'unload').
  final List<String> log;

  /// 답을 만드는 함수. 기본은 사용자 글을 그대로 돌려준다.
  Future<String> Function(LocalGenerationRequest request)? onGenerate;

  /// 올리는 데 걸리는 일. 실패하게 할 수도 있다.
  Future<void> Function()? onLoad;

  /// [cancel]이 불리면 끝나는 것. 멈춤을 기다리는 가짜 생성에 쓴다.
  Completer<void> cancelled = Completer<void>();

  var _loaded = false;

  @override
  bool get isLoaded => _loaded;

  @override
  Future<void> load() async {
    if (_loaded) return;
    log.add('load');
    await onLoad?.call();
    _loaded = true;
  }

  @override
  Future<String> generate(LocalGenerationRequest request) async {
    log.add('generate:${request.user}');
    final handler = onGenerate;
    return handler == null ? request.user : handler(request);
  }

  @override
  void cancel() {
    log.add('cancel');
    if (!cancelled.isCompleted) cancelled.complete();
  }

  @override
  Future<void> unload() async {
    log.add('unload');
    _loaded = false;
  }
}
