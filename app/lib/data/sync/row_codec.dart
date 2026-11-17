/// 기기의 행(SQLite 값)과 서버의 행(JSON) 사이의 변환.
library;

import 'dart:convert';

import 'sync_tables.dart';

/// SQLite에서 읽은 행을 push용 JSON으로 바꾼다. 서버가 관리하는 컬럼은 뺀다.
Map<String, Object?> rowToPushData(SyncTable table, Map<String, Object?> row) {
  final data = <String, Object?>{};
  table.columns.forEach((name, kind) {
    data[name] = _toJson(kind, row[name]);
  });
  return data;
}

/// 서버에서 받은 JSON 행을 SQLite에 넣을 값으로 바꾼다.
///
/// 이 목록에 없는 키(서버 전용 컬럼, 앱이 아직 모르는 새 컬럼)는 버린다.
Map<String, Object?> jsonToLocalRow(
  SyncTable table,
  Map<String, Object?> json,
) {
  final row = <String, Object?>{};
  table.allColumns.forEach((name, kind) {
    row[name] = _toLocal(kind, json[name]);
  });
  return row;
}

Object? _toJson(ColumnKind kind, Object? value) {
  if (value == null) return null;
  return switch (kind) {
    ColumnKind.boolean => value == 1 || value == true,
    ColumnKind.textArray ||
    ColumnKind.json => _withoutNul(jsonDecode(value as String)),
    _ => _withoutNul(value),
  };
}

/// 문자열에서 NUL 문자(U+0000)를 뺀다.
///
/// PostgreSQL의 jsonb는 이 문자를 받지 않는다. 한 글자 때문에 묶음 전체가 거절되면
/// 다시 보내도 계속 거절돼 대기열이 막힌다.
Object? _withoutNul(Object? value) => switch (value) {
  final String text =>
    text.contains('\u0000') ? text.replaceAll('\u0000', '') : text,
  final List<Object?> list => [for (final v in list) _withoutNul(v)],
  final Map<Object?, Object?> map => {
    for (final e in map.entries) e.key: _withoutNul(e.value),
  },
  _ => value,
};

Object? _toLocal(ColumnKind kind, Object? value) {
  if (value == null) return null;
  return switch (kind) {
    ColumnKind.boolean => (value == true || value == 1) ? 1 : 0,
    ColumnKind.textArray ||
    ColumnKind.json => value is String ? value : jsonEncode(value),
    ColumnKind.integer => (value as num).toInt(),
    ColumnKind.real => (value as num).toDouble(),
    // 서버는 'HH:MM:SS'로 준다.
    ColumnKind.time =>
      (value as String).length >= 5 ? value.substring(0, 5) : value,
    // 표기를 하나로 맞춘다(서버는 '+00:00'과 마이크로초로 준다).
    ColumnKind.timestamp => DateTime.parse(
      value as String,
    ).toUtc().toIso8601String(),
    ColumnKind.text || ColumnKind.date => value as String,
  };
}
