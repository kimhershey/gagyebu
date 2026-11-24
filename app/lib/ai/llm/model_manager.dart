/// 모델 파일을 내려받고, 확인하고, 지운다(`docs/SPEC.md` 5.4의 "모델 관리").
///
/// 여기서 밖으로 나가는 요청은 모델 파일을 받는 GET뿐이다. 보내는 내용은 없다.
library;

import 'dart:async';

import 'package:http/http.dart' as http;

import 'model_catalog.dart';
import 'model_file_store.dart';

/// 모델 파일의 상태. `model_files.status`에 적는 값과 같다.
enum ModelFileStatus {
  downloading('downloading'),
  ready('ready'),
  failed('failed');

  const ModelFileStatus(this.code);
  final String code;

  static ModelFileStatus fromCode(String code) =>
      values.firstWhere((v) => v.code == code, orElse: () => failed);
}

/// 기기에 있는 모델 파일 하나(`model_files`의 한 줄).
class ModelFileRecord {
  const ModelFileRecord({
    required this.id,
    required this.kind,
    required this.fileName,
    required this.path,
    required this.sizeBytes,
    required this.downloadedBytes,
    required this.sha256,
    required this.status,
    required this.updatedAt,
  });

  /// 카탈로그의 ID.
  final String id;
  final ModelKind kind;
  final String fileName;

  /// 다 받은 파일이 놓이는 경로.
  final String path;

  /// 전체 크기(바이트). 아직 모르면 0.
  final int sizeBytes;
  final int downloadedBytes;
  final String sha256;
  final ModelFileStatus status;
  final DateTime updatedAt;

  bool get isReady => status == ModelFileStatus.ready;

  /// 받다 만 것이 남아 있어 이어받을 수 있는지.
  bool get canResume => status == ModelFileStatus.failed && downloadedBytes > 0;

  ModelFileRecord copyWith({
    int? sizeBytes,
    int? downloadedBytes,
    ModelFileStatus? status,
    DateTime? updatedAt,
  }) => ModelFileRecord(
    id: id,
    kind: kind,
    fileName: fileName,
    path: path,
    sizeBytes: sizeBytes ?? this.sizeBytes,
    downloadedBytes: downloadedBytes ?? this.downloadedBytes,
    sha256: sha256,
    status: status ?? this.status,
    updatedAt: updatedAt ?? this.updatedAt,
  );
}

/// 모델 파일의 상태를 적어 두는 곳. 앱에서는 로컬 DB의 `model_files` 표다.
abstract interface class ModelFileRegistry {
  Future<List<ModelFileRecord>> all();
  Future<ModelFileRecord?> byId(String id);
  Future<void> put(ModelFileRecord record);
  Future<void> remove(String id);
}

/// 내려받기가 실패한 까닭.
enum ModelDownloadFailure {
  /// 카탈로그에 주소나 해시가 없어 받을 수 없다.
  notAvailable,

  /// 저장 공간이 모자란다. 받기 전에 알린다.
  insufficientSpace,

  /// 서버에 닿지 못했거나 중간에 끊겼다. 받은 데까지는 남아 있다.
  network,

  /// 서버가 파일을 주지 않았다(없는 주소 등).
  server,

  /// 받은 파일이 카탈로그의 해시와 다르다. 파일은 지웠다.
  hashMismatch,

  /// 파일을 쓰지 못했다(공간이 찼거나 권한이 없다).
  storage,

  /// 사용자가 멈췄다. 받은 데까지는 남아 있다.
  cancelled,
}

class ModelDownloadException implements Exception {
  const ModelDownloadException(this.failure, [this.detail]);

  final ModelDownloadFailure failure;

  /// 개발자용 설명. 화면에 그대로 보이지 않는다.
  final String? detail;

  @override
  String toString() =>
      'ModelDownloadException(${failure.name}${detail == null ? '' : ': $detail'})';
}

/// 내려받기를 멈추는 손잡이.
class ModelDownloadCancelToken {
  bool _cancelled = false;
  void Function()? _onCancel;

  bool get isCancelled => _cancelled;

  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    _onCancel?.call();
  }
}

/// 진행 상황. [total]은 전체 크기를 아직 모르면 null이다.
typedef ModelDownloadProgress = void Function(int received, int? total);

/// 모델 파일을 관리한다.
class ModelManager {
  ModelManager({
    required this.store,
    required this.registry,
    required this.client,
    DateTime Function()? clock,
    this.stallTimeout = const Duration(seconds: 60),
    this.registryStep = 8 * 1024 * 1024,
  }) : _clock = clock ?? DateTime.now;

  final ModelFileStore store;
  final ModelFileRegistry registry;

  /// 모델 파일을 받는 HTTP 클라이언트. 시험에서는 가짜를 준다.
  final http.Client client;
  final DateTime Function() _clock;

  /// 이만큼 아무것도 오지 않으면 끊긴 것으로 본다.
  final Duration stallTimeout;

  /// 이만큼 받을 때마다 진행을 [registry]에 적는다. 조각마다 적으면 DB가 바쁘다.
  final int registryStep;

  /// 받기 전에 남겨 둘 여유 공간. 꽉 채우면 앱의 DB도 쓰지 못한다.
  static const spaceMargin = 64 * 1024 * 1024;

  final _active = <String, ModelDownloadCancelToken>{};

  /// 받고 있는 것이 끝나면(성공이든 실패든) 끝나는 것. 지우기가 이것을 기다린다.
  final _settled = <String, Future<void>>{};

  bool isDownloading(String id) => _active.containsKey(id);

  DateTime _now() => _clock().toUtc();

  /// 받는 동안 쓰는 임시 파일. 다 받아 확인한 뒤에 제 이름으로 바꾼다.
  String _partPath(String path) => '$path.part';

  /// [entry]를 내려받는다.
  ///
  /// 받다 만 파일이 있으면 그 뒤부터 이어받는다(HTTP Range). 다 받으면 SHA-256을
  /// 카탈로그의 값과 맞춰 보고, 다르면 지우고 실패로 둔다. 진행과 결과는
  /// [registry]에 적는다. 실패하면 [ModelDownloadException]을 던진다.
  Future<ModelFileRecord> download(
    ModelCatalogEntry entry, {
    ModelDownloadProgress? onProgress,
    ModelDownloadCancelToken? cancelToken,
  }) async {
    final url = entry.url;
    final expectedHash = entry.sha256;
    if (url == null || expectedHash == null) {
      throw const ModelDownloadException(ModelDownloadFailure.notAvailable);
    }
    if (_active.containsKey(entry.id)) {
      throw StateError('${entry.id}를 이미 받고 있다');
    }
    final token = cancelToken ?? ModelDownloadCancelToken();
    final settled = Completer<void>();
    _active[entry.id] = token;
    _settled[entry.id] = settled.future;
    try {
      return await _download(entry, url, expectedHash, token, onProgress);
    } finally {
      _active.remove(entry.id);
      _settled.remove(entry.id);
      settled.complete();
    }
  }

  Future<ModelFileRecord> _download(
    ModelCatalogEntry entry,
    Uri url,
    String expectedHash,
    ModelDownloadCancelToken token,
    ModelDownloadProgress? onProgress,
  ) async {
    final path = await store.pathFor(entry.fileName);
    final part = _partPath(path);
    var have = await store.length(part);
    var total = entry.sizeBytes;
    // 카탈로그의 크기보다 많이 받아 둔 것은 다른 파일이다. 처음부터 받는다.
    if (total != null && have > total) {
      await store.delete(part);
      have = 0;
    }

    var record = ModelFileRecord(
      id: entry.id,
      kind: entry.kind,
      fileName: entry.fileName,
      path: path,
      sizeBytes: total ?? 0,
      downloadedBytes: have,
      sha256: expectedHash,
      status: ModelFileStatus.downloading,
      updatedAt: _now(),
    );

    Future<Never> fail(
      ModelDownloadFailure failure, {
      String? detail,
      bool keepPart = true,
    }) async {
      if (!keepPart) await store.delete(part);
      final kept = keepPart ? await store.length(part) : 0;
      await registry.put(
        record.copyWith(
          status: ModelFileStatus.failed,
          downloadedBytes: kept,
          updatedAt: _now(),
        ),
      );
      throw ModelDownloadException(failure, detail);
    }

    Future<void> checkSpace(int? size, int already) async {
      if (size == null) return;
      final free = await store.freeSpace();
      if (free != null && free < size - already + spaceMargin) {
        // 아무것도 받기 전에 알린다. 받아 둔 것은 그대로 둔다.
        throw ModelDownloadException(
          ModelDownloadFailure.insufficientSpace,
          '${size - already}바이트가 필요한데 $free바이트가 남았다',
        );
      }
    }

    await checkSpace(total, have);
    await registry.put(record);

    // 다 받아 둔 것이면 요청 없이 확인으로 간다.
    if (total == null || have < total) {
      final http.StreamedResponse response;
      try {
        if (token.isCancelled) throw const _Cancelled();
        final request = http.Request('GET', url);
        if (have > 0) request.headers['Range'] = 'bytes=$have-';
        response = await client.send(request).timeout(stallTimeout);
      } on _Cancelled {
        return fail(ModelDownloadFailure.cancelled);
      } on Object catch (error) {
        return fail(ModelDownloadFailure.network, detail: '$error');
      }

      var append = false;
      switch (response.statusCode) {
        case 206:
          // 서버가 우리가 청한 자리에서 이어 주는지 확인한다. 아니면 처음부터 쓴다.
          final range = _ContentRange.tryParse(
            response.headers['content-range'],
          );
          if (range != null && range.start == have) {
            append = true;
            total ??= range.total;
          } else {
            await _drain(response);
            return fail(
              ModelDownloadFailure.server,
              detail: '청한 자리와 다른 조각이 왔다',
              keepPart: false,
            );
          }
        case 200:
          // 서버가 Range를 듣지 않았다. 처음부터 다시 받는다.
          have = 0;
          total ??= response.contentLength;
        case 416:
          // 받아 둔 것이 서버의 파일보다 길다. 지우고 다음에 처음부터 받게 한다.
          await _drain(response);
          return fail(
            ModelDownloadFailure.server,
            detail: '이어받을 자리가 서버의 파일 밖이다',
            keepPart: false,
          );
        default:
          await _drain(response);
          return fail(
            ModelDownloadFailure.server,
            detail: 'HTTP ${response.statusCode}',
          );
      }

      if (total != null && total != record.sizeBytes) {
        record = record.copyWith(sizeBytes: total);
        try {
          await checkSpace(total, have);
        } on ModelDownloadException {
          await _drain(response);
          await registry.put(
            record.copyWith(status: ModelFileStatus.failed, updatedAt: _now()),
          );
          rethrow;
        }
      }

      final ModelFileSink sink;
      try {
        sink = await store.openWrite(part, append: append);
      } on Object catch (error) {
        await _drain(response);
        return fail(ModelDownloadFailure.storage, detail: '$error');
      }

      var received = have;
      var sinceSaved = 0;
      onProgress?.call(received, total);
      Object? problem;
      try {
        await _pipe(response.stream, sink, token, stallTimeout, (count) async {
          received += count;
          sinceSaved += count;
          onProgress?.call(received, total);
          if (sinceSaved >= registryStep) {
            sinceSaved = 0;
            await registry.put(
              record.copyWith(downloadedBytes: received, updatedAt: _now()),
            );
          }
        });
      } on Object catch (error) {
        problem = error;
      } finally {
        try {
          await sink.close();
        } on Object catch (error) {
          problem ??= _WriteError(error);
        }
      }
      if (problem != null) {
        return fail(switch (problem) {
          _Cancelled() => ModelDownloadFailure.cancelled,
          _WriteError() => ModelDownloadFailure.storage,
          _ => ModelDownloadFailure.network,
        }, detail: '$problem');
      }
      if (total != null && received < total) {
        // 서버가 다 주지 않고 끊었다. 다음에 이어받는다.
        return fail(
          ModelDownloadFailure.network,
          detail: '$total 가운데 $received바이트만 왔다',
        );
      }
      have = received;
    }

    // 받은 파일이 카탈로그의 것과 같은지 확인한다. 다르면 쓰지 않는다.
    final actual = await store.sha256Of(part);
    if (actual.toLowerCase() != expectedHash.toLowerCase()) {
      return fail(
        ModelDownloadFailure.hashMismatch,
        detail: '기대 $expectedHash, 실제 $actual',
        keepPart: false,
      );
    }
    await store.rename(part, path);
    final ready = record.copyWith(
      sizeBytes: have,
      downloadedBytes: have,
      status: ModelFileStatus.ready,
      updatedAt: _now(),
    );
    await registry.put(ready);
    onProgress?.call(have, have);
    return ready;
  }

  /// 받고 있는 [id]를 멈춘다. 받은 데까지는 남는다.
  void cancel(String id) => _active[id]?.cancel();

  /// [id]의 파일과 기록을 지운다. 받고 있었으면 먼저 멈춘다.
  Future<void> delete(String id) async {
    cancel(id);
    // 멈춘 내려받기가 기록을 마저 적은 뒤에 지운다. 아니면 지운 기록이 되살아난다.
    await _settled[id];
    final record = await registry.byId(id);
    if (record != null) {
      await store.delete(record.path);
      await store.delete(_partPath(record.path));
    }
    await registry.remove(id);
  }

  /// 기록과 파일을 맞춘다. 앱을 켤 때 한 번 부른다.
  ///
  /// - 받는 중이라고 적혀 있는데 받고 있지 않으면(앱이 꺼졌던 것) 실패로 고친다.
  ///   받아 둔 만큼은 이어받을 수 있다.
  /// - 준비됐다고 적혀 있는데 파일이 없으면 기록을 지운다.
  Future<void> reconcile() async {
    for (final record in await registry.all()) {
      switch (record.status) {
        case ModelFileStatus.downloading when !isDownloading(record.id):
          await registry.put(
            record.copyWith(
              status: ModelFileStatus.failed,
              downloadedBytes: await store.length(_partPath(record.path)),
              updatedAt: _now(),
            ),
          );
        case ModelFileStatus.ready when !await store.exists(record.path):
          await registry.remove(record.id);
        default:
          break;
      }
    }
  }
}

/// 응답의 본문을 [sink]에 옮긴다. [token]으로 멈추면 [_Cancelled]로, [stallTimeout]
/// 동안 아무것도 오지 않으면 [TimeoutException]으로 끝난다.
Future<void> _pipe(
  Stream<List<int>> stream,
  ModelFileSink sink,
  ModelDownloadCancelToken token,
  Duration stallTimeout,
  Future<void> Function(int count) onBytes,
) {
  final done = Completer<void>();
  late final StreamSubscription<List<int>> subscription;
  Timer? watchdog;

  void finish([Object? error, StackTrace? stack]) {
    watchdog?.cancel();
    if (done.isCompleted) return;
    if (error == null) {
      done.complete();
    } else {
      // 끊는 일이 끝나기를 기다리지 않는다. 멈춰 버린 연결은 끊는 것도 오래 걸린다.
      unawaited(subscription.cancel());
      done.completeError(error, stack);
    }
  }

  // 받기를 기다리는 동안만 잰다. 디스크에 쓰는 시간은 서버의 탓이 아니다.
  void watch() {
    watchdog?.cancel();
    watchdog = Timer(
      stallTimeout,
      () => finish(TimeoutException('서버가 응답을 멈췄다', stallTimeout)),
    );
  }

  subscription = stream.listen(
    (chunk) async {
      // 쓰는 동안에는 받기를 멈춘다. 디스크보다 빨리 받아 메모리에 쌓이지 않게 한다.
      subscription.pause();
      watchdog?.cancel();
      try {
        await sink.add(chunk);
      } on Object catch (error, stack) {
        finish(_WriteError(error), stack);
        return;
      }
      try {
        await onBytes(chunk.length);
      } on Object catch (error, stack) {
        finish(error, stack);
        return;
      }
      if (done.isCompleted) return;
      watch();
      subscription.resume();
    },
    onError: (Object error, StackTrace stack) => finish(error, stack),
    onDone: finish,
  );
  watch();
  token._onCancel = () => finish(const _Cancelled());
  if (token.isCancelled) finish(const _Cancelled());
  return done.future.whenComplete(() => token._onCancel = null);
}

/// 쓰지 않을 응답을 닫는다. 닫지 않으면 연결이 남는다.
Future<void> _drain(http.StreamedResponse response) async {
  try {
    await response.stream.listen(null).cancel();
  } on Object {
    // 이미 닫힌 연결이다.
  }
}

class _Cancelled implements Exception {
  const _Cancelled();

  @override
  String toString() => '사용자가 멈췄다';
}

class _WriteError implements Exception {
  const _WriteError(this.cause);

  final Object cause;

  @override
  String toString() => '파일을 쓰지 못했다: $cause';
}

/// `Content-Range: bytes 100-199/1000`
class _ContentRange {
  const _ContentRange(this.start, this.total);

  final int start;

  /// 전체 크기. 서버가 `*`로 답했으면 null.
  final int? total;

  static final _pattern = RegExp(r'^bytes (\d+)-(\d+)/(\d+|\*)$');

  static _ContentRange? tryParse(String? header) {
    final m = header == null ? null : _pattern.firstMatch(header.trim());
    if (m == null) return null;
    return _ContentRange(int.parse(m.group(1)!), int.tryParse(m.group(3)!));
  }
}
