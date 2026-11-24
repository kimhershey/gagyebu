import 'package:drift/drift.dart';

import 'db/database.dart';

/// 이 기기에만 남기는 표시. 서버로 올라가지 않는다.
///
/// 동기화 상태를 적는 `sync_state` 표에 함께 둔다. 계정을 바꾸며 기기의 가계부를 지울 때도
/// 남는다(`sync/ledger_adoption.dart`).
class DeviceFlags {
  const DeviceFlags(this._db);

  final AppDatabase _db;

  /// 로그인 안내 화면에서 '로그인하지 않고 사용'을 골랐는지를 적는 키.
  static const loginSkippedKey = 'login_skipped';

  /// 로그인 안내 화면에서 '로그인하지 않고 사용'을 골랐는지.
  Future<bool> loginSkipped() async {
    final row = await (_db.select(
      _db.syncState,
    )..where((s) => s.key.equals(loginSkippedKey))).getSingleOrNull();
    return row != null;
  }

  /// 로그인하지 않고 쓰기로 했다고 적는다. 다음부터는 시작할 때 로그인을 권하지 않는다.
  Future<void> markLoginSkipped() => _db
      .into(_db.syncState)
      .insert(
        SyncStateCompanion.insert(key: loginSkippedKey, value: '1'),
        mode: InsertMode.insertOrReplace,
      );
}
