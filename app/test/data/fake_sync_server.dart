import 'package:gagyebu/data/sync/sync_gateway.dart';
import 'package:gagyebu/data/sync/sync_tables.dart';
import 'package:gagyebu/domain/default_seed.dart';
import 'package:gagyebu/domain/enums.dart';

/// 서버의 동기화 규약(`supabase/README.md`)을 메모리에서 흉내 낸다.
///
/// 실제 SQL 함수는 `supabase/tests/`가 PostgreSQL에서 따로 검증한다. 이 가짜 서버는
/// 기기 쪽 엔진을 서버 없이 시험하는 데 쓴다.
class FakeSyncServer implements SyncGateway {
  FakeSyncServer({required this.clock});

  /// 서버 시각.
  DateTime Function() clock;

  final Map<String, Map<String, Map<String, Object?>>> _tables = {
    for (final t in syncTables) t.name: {},
  };
  final Map<String, PushResponse> _batches = {};
  int _seq = 0;
  int _idCounter = 0;

  /// 실제로 적용한 push 묶음 수(같은 묶음의 재전송은 세지 않는다).
  int appliedBatches = 0;
  int pushCalls = 0;
  int pullCalls = 0;

  int get maxSeq => _seq;

  Map<String, Object?>? row(String table, String id) => _tables[table]![id];

  Iterable<Map<String, Object?>> rows(String table) => _tables[table]!.values;

  /// 삭제 표시가 있는 행을 실제로 지운다(서버의 purge_tombstones를 흉내 낸다).
  int purgeTombstones() {
    var removed = 0;
    for (final rows in _tables.values) {
      final before = rows.length;
      rows.removeWhere((id, row) => row['deleted_at'] != null);
      removed += before - rows.length;
    }
    return removed;
  }

  String _nextId() =>
      '00000000-0000-4000-8000-${(++_idCounter).toString().padLeft(12, '0')}';

  String _now() => clock().toUtc().toIso8601String();

  /// 가입 트리거처럼 가계부, 프로필, 기본 분류, 현금 자산을 만든다.
  String seedLedger({String ownerId = 'user-1'}) {
    final ledgerId = _nextId();
    _insert('ledgers', ledgerId, null, {
      'owner_id': ownerId,
      'name': defaultLedgerName,
      'currency': 'KRW',
    });
    final cashId = _nextId();
    _insert('accounts', cashId, ledgerId, {
      'name': defaultCashAccountName,
      'kind': 'cash',
      'institution': null,
      'match_hints': <String>[],
      'opening_balance': 0,
      'billing_day': null,
      'payment_account_id': null,
      'sort_order': 0,
    });
    for (final kind in CategoryKind.values) {
      var order = 10;
      for (final name in defaultCategoryNames(kind)) {
        _insert('categories', _nextId(), ledgerId, {
          'kind': kind.code,
          'name': name,
          'parent_id': null,
          'icon': null,
          'sort_order': order,
        });
        order += 10;
      }
    }
    _insert('profiles', ownerId, ledgerId, {
      'display_name': null,
      'month_start_day': 1,
      'default_account_id': cashId,
    });
    return ledgerId;
  }

  void _insert(
    String table,
    String id,
    String? ledgerId,
    Map<String, Object?> data,
  ) {
    final now = _now();
    _tables[table]![id] = {
      'id': id,
      'ledger_id': ?ledgerId,
      ...data,
      'version': 1,
      'server_seq': ++_seq,
      'client_updated_at': now,
      'created_at': now,
      'updated_at': now,
      'deleted_at': null,
    };
  }

  @override
  Future<PushResponse> push({
    required String ledgerId,
    required String deviceId,
    required String batchId,
    required List<PushChange> changes,
  }) async {
    pushCalls++;
    if (!_tables['ledgers']!.containsKey(ledgerId)) {
      throw StateError('42501: 가계부의 소유자가 아니다');
    }
    final key = '$ledgerId/$batchId';
    final stored = _batches[key];
    if (stored != null) return stored;

    // 테이블 의존 순서로 적용하되, 결과는 보낸 순서로 돌려준다.
    final order = [for (final t in syncTables) t.name];
    final indexed = [for (var i = 0; i < changes.length; i++) i]
      ..sort((a, b) {
        final byTable = order
            .indexOf(changes[a].table)
            .compareTo(order.indexOf(changes[b].table));
        return byTable != 0 ? byTable : a.compareTo(b);
      });
    final results = List<PushResult?>.filled(changes.length, null);
    int? maxSeq;
    for (final i in indexed) {
      final result = _apply(ledgerId, changes[i]);
      results[i] = result;
      final seq = result.serverSeq;
      if (seq != null && (maxSeq == null || seq > maxSeq)) maxSeq = seq;
    }
    final response = PushResponse(
      results: results.cast<PushResult>(),
      maxServerSeq: maxSeq,
    );
    _batches[key] = response;
    appliedBatches++;
    return response;
  }

  PushResult _apply(String ledgerId, PushChange change) {
    PushResult fail(String message) => PushResult(
      table: change.table,
      id: change.id,
      status: PushResult.failed,
      error: message,
    );

    final table = syncTableByName(change.table);
    if (table == null) return fail('모르는 테이블');
    final rows = _tables[table.name]!;
    final existing = rows[change.id];
    final serverNow = clock().toUtc();
    // 서버 시각보다 앞선 기기 시각은 서버 시각으로 자른다.
    final clientAt = change.clientUpdatedAt.isAfter(serverNow)
        ? serverNow
        : change.clientUpdatedAt.toUtc();

    if (existing != null) {
      final owner = table.hasLedgerId ? existing['ledger_id'] : existing['id'];
      if (owner != ledgerId) return fail('다른 가계부의 행');
    }
    if (table.name == 'ledgers' &&
        (existing == null || change.op == 'delete')) {
      return fail('가계부는 만들거나 지울 수 없다');
    }
    if (change.op == 'upsert') {
      final problem = _validate(table.name, change.data ?? const {});
      if (problem != null) return fail(problem);
    }

    if (existing == null) {
      if (change.op == 'delete') {
        return PushResult(
          table: change.table,
          id: change.id,
          status: PushResult.applied,
          version: 0,
        );
      }
      final now = _now();
      rows[change.id] = {
        'id': change.id,
        if (table.hasLedgerId) 'ledger_id': ledgerId,
        ..._serverData(table, change.data!),
        'version': 1,
        'server_seq': ++_seq,
        'client_updated_at': clientAt.toIso8601String(),
        'created_at': now,
        'updated_at': now,
        'deleted_at': null,
      };
      return PushResult(
        table: change.table,
        id: change.id,
        status: PushResult.applied,
        version: 1,
        serverSeq: _seq,
      );
    }

    final version = existing['version']! as int;
    var status = PushResult.applied;
    Map<String, Object?>? serverRow;
    if (change.baseVersion != version) {
      final storedAt = DateTime.parse(existing['client_updated_at']! as String);
      if (!clientAt.isAfter(storedAt)) {
        return PushResult(
          table: change.table,
          id: change.id,
          status: PushResult.conflictLost,
          version: version,
          serverSeq: existing['server_seq']! as int,
          serverRow: Map.of(existing),
        );
      }
      status = PushResult.conflictWon;
      serverRow = Map.of(existing);
    }

    final updated = Map.of(existing);
    if (change.op == 'delete') {
      updated['deleted_at'] = _now();
    } else {
      final data = _serverData(table, change.data!);
      if (table.name == 'ledgers') {
        updated['name'] = data['name'];
        updated['currency'] = data['currency'];
      } else {
        updated.addAll(data);
      }
      updated['deleted_at'] = null;
    }
    updated['version'] = version + 1;
    updated['server_seq'] = ++_seq;
    updated['client_updated_at'] = clientAt.toIso8601String();
    updated['updated_at'] = _now();
    rows[change.id] = updated;
    return PushResult(
      table: change.table,
      id: change.id,
      status: status,
      version: version + 1,
      serverSeq: _seq,
      serverRow: serverRow,
    );
  }

  /// 서버가 저장하는 형태로 바꾼다. 모르는 키는 버리고, 시각은 'HH:MM:SS'로 둔다.
  Map<String, Object?> _serverData(SyncTable table, Map<String, Object?> data) {
    final out = <String, Object?>{};
    table.columns.forEach((name, kind) {
      var value = data[name];
      if (kind == ColumnKind.time && value is String && value.length == 5) {
        value = '$value:00';
      }
      out[name] = value;
    });
    return out;
  }

  /// check 제약 가운데 시험에 쓰는 것만 흉내 낸다.
  String? _validate(String table, Map<String, Object?> data) {
    if (table == 'transactions') {
      if (!const ['expense', 'income', 'transfer'].contains(data['type'])) {
        return 'transactions_type_check 위반';
      }
      if (data['amount'] is! num) return 'amount는 null일 수 없다';
    }
    return null;
  }

  @override
  Future<PullResponse> pull({
    required String ledgerId,
    required int since,
    int limit = 500,
  }) async {
    pullCalls++;
    if (!_tables['ledgers']!.containsKey(ledgerId)) {
      throw StateError('42501: 가계부의 소유자가 아니다');
    }
    final found = <PullChange>[];
    for (final table in syncTables) {
      for (final row in _tables[table.name]!.values) {
        final owner = table.hasLedgerId ? row['ledger_id'] : row['id'];
        if (owner != ledgerId) continue;
        if ((row['server_seq']! as int) <= since) continue;
        found.add(PullChange(table: table.name, row: Map.of(row)));
      }
    }
    found.sort(
      (a, b) =>
          (a.row['server_seq']! as int).compareTo(b.row['server_seq']! as int),
    );
    final page = found.take(limit).toList();
    return PullResponse(
      changes: page,
      nextSeq: page.isEmpty ? since : page.last.row['server_seq']! as int,
      hasMore: found.length > page.length,
    );
  }
}

/// push가 서버에 적용된 뒤에 끼어드는 게이트웨이. 끊긴 응답과 전송 중 편집을 흉내 낸다.
class InterceptingGateway implements SyncGateway {
  InterceptingGateway(this.inner);

  final SyncGateway inner;

  /// true면 다음 push는 서버에 적용된 뒤 응답이 끊긴 것처럼 예외를 던진다.
  bool dropNextPushResponse = false;

  /// 다음 push가 서버에 적용된 직후, 응답이 돌아오기 전에 한 번 부른다.
  Future<void> Function()? afterNextPush;

  @override
  Future<PushResponse> push({
    required String ledgerId,
    required String deviceId,
    required String batchId,
    required List<PushChange> changes,
  }) async {
    final response = await inner.push(
      ledgerId: ledgerId,
      deviceId: deviceId,
      batchId: batchId,
      changes: changes,
    );
    final hook = afterNextPush;
    if (hook != null) {
      afterNextPush = null;
      await hook();
    }
    if (dropNextPushResponse) {
      dropNextPushResponse = false;
      throw StateError('연결이 끊겼다');
    }
    return response;
  }

  @override
  Future<PullResponse> pull({
    required String ledgerId,
    required int since,
    int limit = 500,
  }) => inner.pull(ledgerId: ledgerId, since: since, limit: limit);
}
