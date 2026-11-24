import 'package:drift/drift.dart';

import '../db/database.dart';

/// 바꾼 행을 변경 대기열(outbox)에 올린다. 저장소들이 함께 쓴다.
///
/// 행을 쓰는 것과 대기열에 올리는 것은 **같은 트랜잭션**에서 해야 한다. 부르는 쪽이
/// `db.transaction` 안에서 쓴다.
class OutboxWriter {
  OutboxWriter(this.db, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final AppDatabase db;
  final DateTime Function() _clock;

  /// 지금(UTC). 행의 `client_updated_at`과 대기열에 같은 값을 쓴다.
  DateTime now() => _clock().toUtc();

  /// 변경을 대기열에 올린다. 같은 행의 변경이 이미 있으면 하나로 합친다.
  ///
  /// 합칠 때 [baseVersion]은 처음 것을 지킨다. 서버가 충돌을 판정하는 기준이
  /// '기기가 마지막으로 본 서버 버전'이기 때문이다. 새 행이면 0을 준다.
  Future<void> enqueue(
    String ledgerId,
    String table,
    String rowId,
    String op,
    int baseVersion,
    DateTime at,
  ) async {
    await db
        .into(db.outbox)
        .insert(
          OutboxCompanion.insert(
            ledgerId: ledgerId,
            targetTable: table,
            rowId: rowId,
            op: op,
            baseVersion: baseVersion,
            clientUpdatedAt: at,
          ),
          onConflict: DoUpdate(
            (old) => OutboxCompanion(op: Value(op), clientUpdatedAt: Value(at)),
            target: [db.outbox.targetTable, db.outbox.rowId],
          ),
        );
  }

  /// 삭제 표시를 하고 대기열에 올린다.
  ///
  /// 서버에 한 번도 올라가지 않은 행은 흔적 없이 지운다.
  Future<void> softDelete(
    String table,
    String ledgerId,
    String rowId,
    int version,
  ) async {
    final at = now();
    final pending =
        await (db.select(db.outbox)..where(
              (o) => o.targetTable.equals(table) & o.rowId.equals(rowId),
            ))
            .getSingleOrNull();
    final neverPushed =
        version == 0 && (pending == null || pending.baseVersion == 0);
    if (neverPushed) {
      await db.customUpdate(
        'DELETE FROM $table WHERE id = ?',
        variables: [Variable.withString(rowId)],
        updates: {_tableByName(table)},
        updateKind: UpdateKind.delete,
      );
      await (db.delete(db.outbox)
            ..where((o) => o.targetTable.equals(table) & o.rowId.equals(rowId)))
          .go();
      return;
    }
    await db.customUpdate(
      'UPDATE $table SET deleted_at = ?, client_updated_at = ? WHERE id = ?',
      variables: [
        Variable.withString(at.toIso8601String()),
        Variable.withString(at.toIso8601String()),
        Variable.withString(rowId),
      ],
      updates: {_tableByName(table)},
      updateKind: UpdateKind.update,
    );
    await enqueue(ledgerId, table, rowId, 'delete', version, at);
  }

  TableInfo _tableByName(String name) =>
      db.allTables.firstWhere((t) => t.actualTableName == name);
}
