// 서버 SQL, 기기 테이블(Drift), 동기화 컬럼 목록이 서로 어긋나지 않는지 확인한다.
//
// 컬럼을 한쪽에만 더하면 동기화할 때 값이 조용히 빠진다. 이 시험이 그것을 막는다.
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gagyebu/data/db/database.dart';
import 'package:gagyebu/data/sync/sync_tables.dart';
import 'package:gagyebu/domain/default_seed.dart';

const _sqlKinds = <String, ColumnKind>{
  'uuid': ColumnKind.text,
  'text': ColumnKind.text,
  'integer': ColumnKind.integer,
  'bigint': ColumnKind.integer,
  'smallint': ColumnKind.integer,
  'numeric': ColumnKind.real,
  'date': ColumnKind.date,
  'time': ColumnKind.time,
  'timestamptz': ColumnKind.timestamp,
  'boolean': ColumnKind.boolean,
  'jsonb': ColumnKind.json,
  'text[]': ColumnKind.textArray,
};

/// `create table public.<이름> ( … );`에서 컬럼 이름과 타입을 읽는다.
Map<String, Map<String, String>> parseSchema(String sql) {
  final tables = <String, Map<String, String>>{};
  final tablePattern = RegExp(
    r'create table public\.(\w+) \((.*?)\n\);',
    dotAll: true,
  );
  final columnPattern = RegExp(
    r'^\s{2}(\w+)\s+(uuid|text\[\]|text|integer|bigint|smallint|numeric|date|timestamptz|time|boolean|jsonb)(?=[\s,]|$)',
  );
  for (final match in tablePattern.allMatches(sql)) {
    final columns = <String, String>{};
    for (final line in match.group(2)!.split('\n')) {
      if (line.trimLeft().startsWith('--')) continue;
      final column = columnPattern.firstMatch(line);
      if (column != null) columns[column.group(1)!] = column.group(2)!;
    }
    tables[match.group(1)!] = columns;
  }
  return tables;
}

void main() {
  final sql = File('../supabase/migrations/0001_schema.sql').readAsStringSync();
  final server = parseSchema(sql);

  test('동기화 테이블의 집합이 서버와 같다', () {
    expect(server.keys.toSet()..remove('sync_batches'), {
      for (final t in syncTables) t.name,
    });
  });

  for (final table in syncTables) {
    test('${table.name}: 서버 컬럼과 동기화 목록이 같다', () {
      final columns = server[table.name]!;
      final expected = {
        ...table.allColumns.keys,
        if (table.name == 'transactions') ...serverOnlyColumns,
      };
      expect(columns.keys.toSet(), expected);

      table.allColumns.forEach((name, kind) {
        expect(
          _sqlKinds[columns[name]],
          kind,
          reason: '${table.name}.$name: 서버 타입 ${columns[name]}',
        );
      });
    });
  }

  test('기기 테이블의 컬럼이 동기화 목록과 같다', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    const localOnly = {'outbox', 'sync_state', 'sync_conflicts'};
    final local = {
      for (final t in db.allTables)
        t.actualTableName: {for (final c in t.$columns) c.name},
    };
    expect(local.keys.toSet().difference(localOnly), {
      for (final t in syncTables) t.name,
    });
    for (final table in syncTables) {
      expect(
        local[table.name],
        table.allColumns.keys.toSet(),
        reason: table.name,
      );
    }
  });

  test('서버의 가입 시드가 앱의 기본 분류와 같다', () {
    final lifecycle = File('../supabase/migrations/0004_lifecycle.sql')
        .readAsStringSync();
    var cursor = 0;
    for (final name in [
      ...defaultExpenseCategories,
      ...defaultIncomeCategories,
    ]) {
      final at = lifecycle.indexOf("'$name'", cursor);
      expect(at, isNonNegative, reason: "'$name'이 순서대로 있어야 한다");
      cursor = at;
    }
    expect(lifecycle, contains("'$defaultLedgerName'"));
    expect(lifecycle, contains("'$defaultCashAccountName'"));
  });
}
