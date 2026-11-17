import 'package:drift/wasm.dart';

import 'opened_database.dart';

/// 웹: SQLite WebAssembly를 웹 워커에서 돌린다.
///
/// `web/sqlite3.wasm`과 `web/drift_worker.js`가 필요하다(`tool/prepare_web_assets.sh`).
/// 저장소는 브라우저가 지원하는 것 가운데 가장 좋은 것을 drift가 고른다
/// (OPFS → IndexedDB → 메모리).
Future<OpenedDatabase> openAppDatabase() async {
  final result = await WasmDatabase.open(
    databaseName: 'gagyebu',
    sqlite3Uri: Uri.parse('sqlite3.wasm'),
    driftWorkerUri: Uri.parse('drift_worker.js'),
  );
  final implementation = result.chosenImplementation;
  return OpenedDatabase(
    executor: result.resolvedExecutor,
    storage: switch (implementation) {
      WasmStorageImplementation.opfsShared ||
      WasmStorageImplementation.opfsLocks => '브라우저 저장소(OPFS)',
      WasmStorageImplementation.sharedIndexedDb ||
      WasmStorageImplementation.unsafeIndexedDb => '브라우저 저장소(IndexedDB)',
      WasmStorageImplementation.inMemory => '메모리(닫으면 사라짐)',
    },
    persistent: implementation != WasmStorageImplementation.inMemory,
  );
}
