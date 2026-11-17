/// 서버와 주고받는 동기화 호출의 형태.
///
/// 규약은 `supabase/README.md`에 있다. 서버를 바꾸더라도 앱 코드가 흔들리지 않도록
/// 엔진은 이 인터페이스만 본다.
library;

/// 서버로 보내는 변경 한 건.
class PushChange {
  const PushChange({
    required this.table,
    required this.op,
    required this.id,
    required this.baseVersion,
    required this.clientUpdatedAt,
    this.data,
  });

  final String table;

  /// upsert · delete
  final String op;
  final String id;

  /// 기기가 이 변경을 만들 때 알고 있던 서버 버전. 새로 만든 행은 0.
  final int baseVersion;
  final DateTime clientUpdatedAt;

  /// upsert일 때의 행 전체(서버가 관리하는 컬럼 제외).
  final Map<String, Object?>? data;

  Map<String, Object?> toJson() => {
    'table': table,
    'op': op,
    'id': id,
    'base_version': baseVersion,
    'client_updated_at': clientUpdatedAt.toUtc().toIso8601String(),
    if (data != null) 'data': data,
  };

  factory PushChange.fromJson(Map<String, Object?> json) => PushChange(
    table: json['table']! as String,
    op: json['op']! as String,
    id: json['id']! as String,
    baseVersion: (json['base_version']! as num).toInt(),
    clientUpdatedAt: DateTime.parse(json['client_updated_at']! as String),
    data: (json['data'] as Map?)?.cast<String, Object?>(),
  );
}

/// 변경 한 건의 처리 결과.
class PushResult {
  const PushResult({
    required this.table,
    required this.id,
    required this.status,
    this.version,
    this.serverSeq,
    this.serverRow,
    this.error,
  });

  static const applied = 'applied';
  static const conflictWon = 'conflict_won';
  static const conflictLost = 'conflict_lost';
  static const failed = 'error';

  final String table;
  final String id;

  /// applied · conflict_won · conflict_lost · error
  final String status;
  final int? version;
  final int? serverSeq;

  /// conflict_won이면 덮어쓰기 전의 서버 행, conflict_lost면 현재 서버 행.
  final Map<String, Object?>? serverRow;
  final String? error;

  factory PushResult.fromJson(Map<String, Object?> json) => PushResult(
    table: json['table']! as String,
    id: json['id']! as String,
    status: json['status']! as String,
    version: (json['version'] as num?)?.toInt(),
    serverSeq: (json['server_seq'] as num?)?.toInt(),
    serverRow: (json['server_row'] as Map?)?.cast<String, Object?>(),
    error: json['error'] as String?,
  );

  Map<String, Object?> toJson() => {
    'table': table,
    'id': id,
    'status': status,
    'version': version,
    'server_seq': serverSeq,
    'server_row': serverRow,
    'error': error,
  };
}

class PushResponse {
  const PushResponse({required this.results, this.maxServerSeq});

  /// 보낸 변경과 같은 순서다.
  final List<PushResult> results;
  final int? maxServerSeq;

  factory PushResponse.fromJson(Map<String, Object?> json) => PushResponse(
    results: [
      for (final r in json['results']! as List)
        PushResult.fromJson((r as Map).cast<String, Object?>()),
    ],
    maxServerSeq: (json['max_server_seq'] as num?)?.toInt(),
  );
}

/// 서버에서 내려받은 행 한 건.
class PullChange {
  const PullChange({required this.table, required this.row});

  final String table;
  final Map<String, Object?> row;
}

class PullResponse {
  const PullResponse({
    required this.changes,
    required this.nextSeq,
    required this.hasMore,
  });

  /// server_seq 오름차순.
  final List<PullChange> changes;

  /// 다음에 넘길 커서.
  final int nextSeq;
  final bool hasMore;

  factory PullResponse.fromJson(Map<String, Object?> json) => PullResponse(
    changes: [
      for (final c in json['changes']! as List)
        PullChange(
          table: (c as Map)['table']! as String,
          row: (c['row']! as Map).cast<String, Object?>(),
        ),
    ],
    nextSeq: (json['next_seq']! as num).toInt(),
    hasMore: json['has_more']! as bool,
  );
}

/// 서버의 동기화 함수.
abstract interface class SyncGateway {
  /// 변경 묶음을 보낸다. 같은 [batchId]를 다시 보내면 서버는 저장해 둔 결과를 돌려준다.
  Future<PushResponse> push({
    required String ledgerId,
    required String deviceId,
    required String batchId,
    required List<PushChange> changes,
  });

  /// [since] 뒤의 변경을 받는다.
  Future<PullResponse> pull({
    required String ledgerId,
    required int since,
    int limit = 500,
  });
}
