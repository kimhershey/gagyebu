import 'dart:convert';

import 'package:drift/drift.dart';

import '../../core/ids.dart';
import '../db/database.dart';
import 'row_codec.dart';
import 'sync_gateway.dart';
import 'sync_tables.dart';

/// 한 번의 동기화가 한 일.
class SyncReport {
  const SyncReport({
    this.pushed = 0,
    this.pulled = 0,
    this.conflicts = 0,
    this.rejected = 0,
  });

  /// 서버가 받아들인 변경 수.
  final int pushed;

  /// 서버에서 받아 기기에 반영한 행 수.
  final int pulled;

  /// 충돌로 판정된 변경 수(이긴 것과 진 것 모두).
  final int conflicts;

  /// 서버가 오류로 거절한 변경 수.
  final int rejected;

  SyncReport operator +(SyncReport other) => SyncReport(
    pushed: pushed + other.pushed,
    pulled: pulled + other.pulled,
    conflicts: conflicts + other.conflicts,
    rejected: rejected + other.rejected,
  );

  @override
  String toString() =>
      'SyncReport(pushed: $pushed, pulled: $pulled, conflicts: $conflicts, rejected: $rejected)';
}

/// 기기의 변경을 서버로 보내고(push) 서버의 변경을 받아 온다(pull).
///
/// - push: 변경 대기열(outbox)을 묶음으로 보낸다. 묶음은 보내기 전에 기기에 적어 두어,
///   응답을 못 받고 끊겨도 같은 묶음 ID로 다시 보낸다(서버가 한 번만 적용한다).
/// - pull: 마지막으로 받은 server_seq 뒤의 행만 받는다. 커서에 기기 시계를 쓰지 않는다.
/// - 충돌 판정은 서버가 한다. 기기는 결과에 따라 진 쪽 값을 `sync_conflicts`에 남긴다.
class SyncEngine {
  SyncEngine({
    required this.db,
    required this.gateway,
    required this.deviceId,
    DateTime Function()? clock,
    String Function()? batchIdGenerator,
    this.pushBatchSize = 200,
    this.pullPageSize = 500,
    this.maxAttempts = 5,
    this.fullResyncAfter = const Duration(days: 80),
  }) : _clock = clock ?? DateTime.now,
       _newBatchId = batchIdGenerator ?? newRandomId;

  final AppDatabase db;
  final SyncGateway gateway;

  /// 이 기기(설치)의 식별자.
  final String deviceId;
  final int pushBatchSize;
  final int pullPageSize;

  /// 서버가 이 횟수만큼 거절한 변경은 더 보내지 않는다.
  final int maxAttempts;

  /// 마지막으로 받은 지 이만큼 지나면 처음부터 다시 받는다.
  ///
  /// 서버는 삭제 표시를 90일 뒤에 실제로 지운다. 그보다 오래 쉬었던 기기는 그 삭제를
  /// 받지 못했을 수 있어, 전체를 다시 받고 서버에 없는 행을 지운다.
  final Duration fullResyncAfter;

  final DateTime Function() _clock;
  final String Function() _newBatchId;

  /// push한 뒤 pull한다. 둘 다 남은 것이 없을 때까지 돈다.
  Future<SyncReport> syncOnce(String ledgerId) async {
    var report = const SyncReport();
    report += await pushPending(ledgerId);
    report += await pullChanges(ledgerId);
    return report;
  }

  // ------------------------------------------------------------------ push

  Future<SyncReport> pushPending(String ledgerId) async {
    var report = const SyncReport();
    // 이번 실행에서 서버가 거절한 항목. 같은 실행에서 다시 보내지 않는다.
    final rejectedNow = <int>{};
    while (true) {
      final batch =
          await _pendingBatch(ledgerId) ??
          await _buildBatch(ledgerId, exclude: rejectedNow);
      if (batch == null) return report;

      final response = await gateway.push(
        ledgerId: ledgerId,
        deviceId: deviceId,
        batchId: batch.id,
        changes: batch.changes,
      );
      report += await _applyPushResults(ledgerId, batch, response, rejectedNow);
    }
  }

  /// 응답을 받지 못한 채 남아 있는 묶음.
  Future<_Batch?> _pendingBatch(String ledgerId) async {
    final stored = await _readState(_batchKey(ledgerId));
    if (stored == null) return null;
    return _Batch.fromJson((jsonDecode(stored) as Map).cast<String, Object?>());
  }

  /// 대기열에서 새 묶음을 만들어 기기에 적어 둔다. 보낼 것이 없으면 null.
  Future<_Batch?> _buildBatch(String ledgerId, {Set<int> exclude = const {}}) =>
      db.transaction(() async {
        final entries =
            await (db.select(db.outbox)
                  ..where(
                    (o) =>
                        o.ledgerId.equals(ledgerId) &
                        o.attempts.isSmallerThanValue(maxAttempts) &
                        o.seq.isNotIn(exclude),
                  )
                  ..orderBy([(o) => OrderingTerm.asc(o.seq)])
                  ..limit(pushBatchSize))
                .get();
        if (entries.isEmpty) return null;

        final changes = <PushChange>[];
        final stamps = <String, String>{};
        for (final entry in entries) {
          final table = syncTableByName(entry.targetTable);
          if (table == null) {
            // 모르는 테이블의 항목은 보낼 수 없다.
            await (db.delete(
              db.outbox,
            )..where((o) => o.seq.equals(entry.seq))).go();
            continue;
          }
          Map<String, Object?>? data;
          if (entry.op == 'upsert') {
            final row = await _readRow(table, entry.rowId);
            if (row == null) {
              // 행이 없어졌다(서버에 올린 적 없는 행을 지운 경우).
              await (db.delete(
                db.outbox,
              )..where((o) => o.seq.equals(entry.seq))).go();
              continue;
            }
            data = rowToPushData(table, row);
          }
          changes.add(
            PushChange(
              table: entry.targetTable,
              op: entry.op,
              id: entry.rowId,
              baseVersion: entry.baseVersion,
              clientUpdatedAt: entry.clientUpdatedAt,
              data: data,
            ),
          );
          stamps[_entryKey(entry.targetTable, entry.rowId)] = entry
              .clientUpdatedAt
              .toIso8601String();
        }
        if (changes.isEmpty) return null;

        final batch = _Batch(
          id: _newBatchId(),
          changes: changes,
          stamps: stamps,
        );
        await _writeState(_batchKey(ledgerId), jsonEncode(batch.toJson()));
        return batch;
      });

  Future<SyncReport> _applyPushResults(
    String ledgerId,
    _Batch batch,
    PushResponse response,
    Set<int> rejectedNow,
  ) => db.transaction(() async {
    var pushed = 0, conflicts = 0, rejected = 0;
    final now = _clock().toUtc();

    for (var i = 0; i < batch.changes.length; i++) {
      final change = batch.changes[i];
      final result = i < response.results.length ? response.results[i] : null;
      final table = syncTableByName(change.table);
      if (result == null || table == null) continue;

      final entry =
          await (db.select(db.outbox)..where(
                (o) =>
                    o.targetTable.equals(change.table) &
                    o.rowId.equals(change.id),
              ))
              .getSingleOrNull();
      // 묶음을 만든 뒤에 사용자가 같은 행을 또 고쳤는지.
      final editedSince =
          entry != null &&
          entry.clientUpdatedAt.toIso8601String() !=
              batch.stamps[_entryKey(change.table, change.id)];

      switch (result.status) {
        case PushResult.applied || PushResult.conflictWon:
          pushed++;
          final version = result.version ?? 0;
          if (version > 0) {
            await db.customUpdate(
              'UPDATE ${table.name} SET version = ?, server_seq = ? WHERE id = ?',
              variables: [
                Variable.withInt(version),
                Variable<int>(result.serverSeq),
                Variable.withString(change.id),
              ],
              updates: {_driftTable(table.name)},
              updateKind: UpdateKind.update,
            );
          }
          if (result.status == PushResult.conflictWon) {
            conflicts++;
            final loser = result.serverRow;
            if (loser != null) {
              await _recordConflict(ledgerId, change, loser, 'remote', now);
            }
          }
          await _settleEntry(entry, editedSince, version);

        case PushResult.conflictLost:
          conflicts++;
          final winner = result.serverRow;
          await _recordConflict(
            ledgerId,
            change,
            change.data ?? {'deleted': true},
            'local',
            now,
          );
          if (winner != null) {
            if (editedSince) {
              // 그 뒤에 고친 내용은 지키고, 기준 버전만 서버 것으로 올린다.
              await _settleEntry(
                entry,
                true,
                (winner['version'] as num?)?.toInt() ?? 0,
              );
            } else {
              await _writeServerRow(table, winner);
              await _settleEntry(entry, false, 0);
            }
          }

        default:
          rejected++;
          if (entry != null) rejectedNow.add(entry.seq);
          if (entry != null && !editedSince) {
            await (db.update(
              db.outbox,
            )..where((o) => o.seq.equals(entry.seq))).write(
              OutboxCompanion(
                attempts: Value(entry.attempts + 1),
                lastError: Value(result.error ?? '서버가 거절했다'),
              ),
            );
          }
      }
    }

    await (db.delete(
      db.syncState,
    )..where((s) => s.key.equals(_batchKey(ledgerId)))).go();
    return SyncReport(pushed: pushed, conflicts: conflicts, rejected: rejected);
  });

  /// 처리된 대기열 항목을 정리한다.
  ///
  /// 묶음을 만든 뒤에 또 고친 행은 항목을 남기고 기준 버전만 [serverVersion]으로 올린다.
  /// 나중에 고친 내용은 서버가 방금 받아들인 내용 위에서 만든 것이기 때문이다.
  Future<void> _settleEntry(
    OutboxRow? entry,
    bool editedSince,
    int serverVersion,
  ) async {
    if (entry == null) return;
    if (editedSince) {
      await (db.update(db.outbox)..where((o) => o.seq.equals(entry.seq))).write(
        OutboxCompanion(
          baseVersion: Value(serverVersion),
          attempts: const Value(0),
          lastError: const Value(null),
        ),
      );
    } else {
      await (db.delete(db.outbox)..where((o) => o.seq.equals(entry.seq))).go();
    }
  }

  Future<void> _recordConflict(
    String ledgerId,
    PushChange change,
    Map<String, Object?> loser,
    String side,
    DateTime at,
  ) => db
      .into(db.syncConflicts)
      .insert(
        SyncConflictsCompanion.insert(
          ledgerId: ledgerId,
          targetTable: change.table,
          rowId: change.id,
          loser: loser,
          loserSide: side,
          detectedAt: at,
        ),
      );

  // ------------------------------------------------------------------ pull

  Future<SyncReport> pullChanges(String ledgerId) async {
    final now = _clock().toUtc();
    final lastPull = DateTime.tryParse(
      await _readState(_lastPullKey(ledgerId)) ?? '',
    );
    // 오래 쉬었으면 처음부터 다시 받는다.
    final fullResync =
        lastPull != null && now.difference(lastPull) > fullResyncAfter;
    final seen = <String, Set<String>>{};

    var pulled = 0;
    var since = fullResync ? 0 : await cursor(ledgerId);
    while (true) {
      final response = await gateway.pull(
        ledgerId: ledgerId,
        since: since,
        limit: pullPageSize,
      );
      final applied = await db.transaction(() async {
        var count = 0;
        for (final change in response.changes) {
          final table = syncTableByName(change.table);
          if (table == null) continue; // 앱이 아직 모르는 테이블
          final id = change.row['id'];
          if (id is! String) continue;
          if (fullResync) seen.putIfAbsent(table.name, () => {}).add(id);

          // 아직 보내지 않은 내 변경이 있는 행은 덮어쓰지 않는다. 그 변경을 보낼 때
          // 서버가 충돌을 판정하고, 지면 서버 행을 돌려준다.
          final pending =
              await (db.select(db.outbox)..where(
                    (o) =>
                        o.targetTable.equals(table.name) & o.rowId.equals(id),
                  ))
                  .getSingleOrNull();
          if (pending != null) continue;

          await _writeServerRow(table, change.row);
          count++;
        }
        await _writeState(_cursorKey(ledgerId), '${response.nextSeq}');
        return count;
      });
      pulled += applied;
      since = response.nextSeq;
      if (!response.hasMore) break;
    }

    if (fullResync) await _dropRowsMissingOnServer(ledgerId, seen);
    await _writeState(_lastPullKey(ledgerId), now.toIso8601String());
    return SyncReport(pulled: pulled);
  }

  /// 전체를 다시 받은 뒤, 서버에 없는 행을 기기에서 지운다.
  ///
  /// 서버에 올린 적이 있고(version > 0) 보낼 변경이 없는 행만 지운다. 기기에서 새로 만든
  /// 행과 고치는 중인 행은 그대로 둔다.
  Future<void> _dropRowsMissingOnServer(
    String ledgerId,
    Map<String, Set<String>> seen,
  ) => db.transaction(() async {
    await db.customStatement(
      'CREATE TEMP TABLE IF NOT EXISTS _seen (id TEXT NOT NULL PRIMARY KEY)',
    );
    for (final table in syncTables) {
      await db.customStatement('DELETE FROM _seen');
      for (final id in seen[table.name] ?? const <String>{}) {
        await db.customStatement('INSERT INTO _seen (id) VALUES (?)', [id]);
      }
      final scope = table.hasLedgerId ? 'ledger_id = ?1' : 'id = ?1';
      await db.customUpdate(
        'DELETE FROM ${table.name} WHERE $scope AND version > 0 '
        'AND id NOT IN (SELECT id FROM _seen) '
        'AND id NOT IN (SELECT row_id FROM outbox WHERE target_table = ?2)',
        variables: [
          Variable.withString(ledgerId),
          Variable.withString(table.name),
        ],
        updates: {_driftTable(table.name)},
        updateKind: UpdateKind.delete,
      );
    }
    await db.customStatement('DROP TABLE _seen');
  });

  /// 가계부의 pull 커서(마지막으로 받은 server_seq).
  ///
  /// push 결과의 server_seq로는 커서를 옮기지 않는다. 다른 기기가 쓴 더 작은 번호의 행을
  /// 아직 받지 않았을 수 있다.
  Future<int> cursor(String ledgerId) async =>
      int.tryParse(await _readState(_cursorKey(ledgerId)) ?? '') ?? 0;

  /// 이 설치의 기기 ID(UUID)를 읽는다. 없으면 만들어 적어 둔다.
  ///
  /// 서버는 기기 ID와 묶음 ID를 UUID로 받는다.
  static Future<String> ensureDeviceId(AppDatabase db) async {
    const key = 'device_id';
    final row = await (db.select(
      db.syncState,
    )..where((s) => s.key.equals(key))).getSingleOrNull();
    if (row != null) return row.value;
    final id = newRandomId();
    await db
        .into(db.syncState)
        .insertOnConflictUpdate(SyncStateCompanion.insert(key: key, value: id));
    return id;
  }

  // ------------------------------------------------------------------ 공통

  Future<Map<String, Object?>?> _readRow(SyncTable table, String id) async {
    final rows = await db
        .customSelect(
          'SELECT * FROM ${table.name} WHERE id = ?',
          variables: [Variable.withString(id)],
        )
        .get();
    return rows.isEmpty ? null : rows.single.data;
  }

  /// 서버 행을 기기 테이블에 그대로 쓴다(있으면 바꾸고 없으면 넣는다).
  Future<void> _writeServerRow(
    SyncTable table,
    Map<String, Object?> json,
  ) async {
    final row = jsonToLocalRow(table, json);
    final columns = row.keys.toList();
    final placeholders = List.filled(columns.length, '?').join(', ');
    await db.customInsert(
      'INSERT OR REPLACE INTO ${table.name} (${columns.join(', ')}) '
      'VALUES ($placeholders)',
      variables: [for (final c in columns) Variable<Object>(row[c])],
      updates: {_driftTable(table.name)},
    );
  }

  TableInfo _driftTable(String name) =>
      db.allTables.firstWhere((t) => t.actualTableName == name);

  Future<String?> _readState(String key) async {
    final row = await (db.select(
      db.syncState,
    )..where((s) => s.key.equals(key))).getSingleOrNull();
    return row?.value;
  }

  Future<void> _writeState(String key, String value) => db
      .into(db.syncState)
      .insertOnConflictUpdate(
        SyncStateCompanion.insert(key: key, value: value),
      );

  static String _cursorKey(String ledgerId) => 'cursor:$ledgerId';
  static String _lastPullKey(String ledgerId) => 'last_pull_at:$ledgerId';
  static String _batchKey(String ledgerId) => 'pending_batch:$ledgerId';
  static String _entryKey(String table, String id) => '$table/$id';
}

/// 서버로 보내려고 묶어 둔 변경.
class _Batch {
  const _Batch({required this.id, required this.changes, required this.stamps});

  final String id;
  final List<PushChange> changes;

  /// 묶음을 만들 때 각 대기열 항목의 수정 시각. 그 뒤에 또 고쳤는지 가리는 데 쓴다.
  final Map<String, String> stamps;

  Map<String, Object?> toJson() => {
    'id': id,
    'changes': [for (final c in changes) c.toJson()],
    'stamps': stamps,
  };

  factory _Batch.fromJson(Map<String, Object?> json) => _Batch(
    id: json['id']! as String,
    changes: [
      for (final c in json['changes']! as List)
        PushChange.fromJson((c as Map).cast<String, Object?>()),
    ],
    stamps: (json['stamps']! as Map).cast<String, String>(),
  );
}
