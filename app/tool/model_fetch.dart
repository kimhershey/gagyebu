// 카탈로그의 모델 파일을 앱과 같은 방법으로 내려받아 본다.
//
//   dart run tool/model_fetch.dart --id=qwen3.5-2b-mmproj --dir=/tmp/models
//   dart run tool/model_fetch.dart --id=qwen3.5-2b-mmproj --dir=/tmp/models --stop-at=100000000
//
// 앱의 `ModelManager`를 그대로 쓴다: 이어받기(HTTP Range), 공간 확인, SHA-256 확인.
// --stop-at=<바이트>를 주면 그만큼 받고 멈춘다. 같은 명령을 --stop-at 없이 다시 돌리면
// 받은 데서 이어받는다. 카탈로그는 저장소의 `catalog/models.json`을 읽는다.
import 'dart:io';

import 'package:gagyebu/ai/llm/model_catalog.dart';
import 'package:gagyebu/ai/llm/model_file_store_factory.dart';
import 'package:gagyebu/ai/llm/model_manager.dart';
import 'package:http/http.dart' as http;

String? _arg(List<String> args, String name) {
  for (final a in args) {
    if (a.startsWith('--$name=')) return a.substring(name.length + 3);
  }
  return null;
}

/// 기록을 메모리에만 두는 등록부. 도구를 다시 돌리면 비어 있지만, 받다 만 파일은
/// 디스크에 남아 있어 이어받는다.
class _MemoryRegistry implements ModelFileRegistry {
  final _records = <String, ModelFileRecord>{};

  @override
  Future<List<ModelFileRecord>> all() async => _records.values.toList();

  @override
  Future<ModelFileRecord?> byId(String id) async => _records[id];

  @override
  Future<void> put(ModelFileRecord record) async =>
      _records[record.id] = record;

  @override
  Future<void> remove(String id) async => _records.remove(id);
}

Future<void> main(List<String> args) async {
  final id = _arg(args, 'id');
  final dir = _arg(args, 'dir');
  final stopAt = int.tryParse(_arg(args, 'stop-at') ?? '');
  final catalog = ModelCatalog.parse(
    File('../catalog/models.json').readAsStringSync(),
  );
  final entry = catalog.byId(id);
  if (entry == null || dir == null) {
    stderr.writeln(
      '사용법: dart run tool/model_fetch.dart --id=<카탈로그의 ID> --dir=<받을 폴더> '
      '[--stop-at=<바이트>]\n'
      '카탈로그의 ID: ${[for (final m in catalog.models) m.id].join(', ')}',
    );
    exit(2);
  }

  final client = http.Client();
  final manager = ModelManager(
    store: createModelFileStore(() async => dir),
    registry: _MemoryRegistry(),
    client: client,
  );
  final token = ModelDownloadCancelToken();
  final watch = Stopwatch()..start();
  int? first;
  var last = 0;
  var shown = 0;
  try {
    final record = await manager.download(
      entry,
      cancelToken: token,
      onProgress: (received, total) {
        first ??= received;
        last = received;
        if (received - shown >= 100 * 1024 * 1024) {
          shown = received;
          stdout.writeln('  $received / ${total ?? '?'}');
        }
        if (stopAt != null && received >= stopAt) token.cancel();
      },
    );
    stdout.writeln(
      '받음: ${record.path}\n'
      '  크기 ${record.sizeBytes}바이트 · SHA-256 ${record.sha256}\n'
      '  이번에 받기 시작한 자리 ${first ?? 0}바이트 · ${watch.elapsed.inSeconds}초',
    );
  } on ModelDownloadException catch (error) {
    stdout.writeln(
      '끝나지 않음: ${error.failure.name} · 받은 데까지 $last바이트 '
      '(시작한 자리 ${first ?? 0}바이트)',
    );
    exitCode = error.failure == ModelDownloadFailure.cancelled ? 0 : 1;
  } finally {
    client.close();
  }
}
