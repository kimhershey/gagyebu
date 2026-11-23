import 'package:drift/wasm.dart';

import 'opened_database.dart';
import 'single_tab_web.dart';

/// 웹: SQLite WebAssembly를 웹 워커에서 돌린다.
///
/// `web/sqlite3.wasm`과 `web/drift_worker.js`가 필요하다(`tool/prepare_web_assets.dart`).
/// 저장소는 브라우저가 지원하는 것 가운데 가장 좋은 것을 drift가 고른다
/// (OPFS → IndexedDB → 메모리).
Future<OpenedDatabase> openAppDatabase() async {
  // DB를 읽기 전에 이 탭이 주인임을 알린다. 먼저 열려 있던 탭은 이 신호를 받는다.
  final claim = await claimSingleTab('gagyebu-db');

  final result = await WasmDatabase.open(
    databaseName: 'gagyebu',
    sqlite3Uri: Uri.parse('sqlite3.wasm'),
    driftWorkerUri: Uri.parse('drift_worker.js'),
  );
  final implementation = result.chosenImplementation;

  // 공유 워커가 없는 브라우저(Samsung Internet, 앱 안의 웹뷰 등)에서는 탭마다 DB 사본을
  // 따로 들고 IndexedDB에 덮어쓴다. 탭이 둘이면 오래된 탭이 저장할 때 다른 탭에서 저장한
  // 내용이 사라진다. 이때는 나중에 연 탭만 쓰게 하고, 먼저 열려 있던 탭은 멈춘다.
  // 그 밖의 방식은 탭들이 DB 하나를 함께 쓰므로 막지 않는다.
  final oneTabOnly =
      implementation == WasmStorageImplementation.unsafeIndexedDb;

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
    takenOver: oneTabOnly ? claim?.takenOver : null,
  );
}
