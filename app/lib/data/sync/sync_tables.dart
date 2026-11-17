/// 동기화하는 테이블과 컬럼의 목록.
///
/// 서버(`supabase/migrations/0001_schema.sql`), 기기(`db/tables.dart`)와 같은 컬럼을
/// 가리킨다. 행을 JSON으로 바꾸거나 JSON을 행으로 옮길 때 이 목록을 따른다.
/// `test/data/schema_contract_test.dart`가 셋이 어긋나지 않는지 확인한다.
library;

/// 컬럼 값의 종류. 기기의 SQLite 표현과 JSON 표현을 정한다.
enum ColumnKind {
  /// SQLite TEXT ↔ JSON 문자열
  text,

  /// SQLite INTEGER ↔ JSON 숫자
  integer,

  /// SQLite REAL ↔ JSON 숫자
  real,

  /// SQLite INTEGER(0 · 1) ↔ JSON true · false
  boolean,

  /// 'YYYY-MM-DD'
  date,

  /// 기기는 'HH:mm', 서버는 'HH:MM:SS'
  time,

  /// ISO 8601(UTC)
  timestamp,

  /// SQLite TEXT(JSON 배열) ↔ JSON 문자열 배열
  textArray,

  /// SQLite TEXT(JSON 객체) ↔ JSON 객체
  json,
}

class SyncTable {
  const SyncTable(this.name, this.columns, {this.hasLedgerId = true});

  /// 서버와 기기에서 같은 테이블 이름.
  final String name;

  /// 테이블마다 다른 컬럼. 공통 컬럼은 [commonColumns]에 있다.
  final Map<String, ColumnKind> columns;

  /// ledgers는 id가 곧 가계부 ID라서 ledger_id가 없다.
  final bool hasLedgerId;

  /// 기기 테이블의 모든 컬럼.
  Map<String, ColumnKind> get allColumns => {
    'id': ColumnKind.text,
    if (hasLedgerId) 'ledger_id': ColumnKind.text,
    ...columns,
    ...commonColumns,
  };
}

/// 서버가 관리하는 공통 컬럼. push할 때 data에 넣지 않는다.
const commonColumns = <String, ColumnKind>{
  'version': ColumnKind.integer,
  'server_seq': ColumnKind.integer,
  'client_updated_at': ColumnKind.timestamp,
  'created_at': ColumnKind.timestamp,
  'updated_at': ColumnKind.timestamp,
  'deleted_at': ColumnKind.timestamp,
};

/// 서버에만 있는 컬럼. 내려받을 때 버린다.
const serverOnlyColumns = {'counterparty'};

/// 동기화 테이블. 순서는 서버가 push를 적용하는 의존 순서와 같다.
const syncTables = <SyncTable>[
  SyncTable('ledgers', {
    'owner_id': ColumnKind.text,
    'name': ColumnKind.text,
    'currency': ColumnKind.text,
  }, hasLedgerId: false),
  SyncTable('profiles', {
    'display_name': ColumnKind.text,
    'month_start_day': ColumnKind.integer,
    'default_account_id': ColumnKind.text,
  }),
  SyncTable('accounts', {
    'name': ColumnKind.text,
    'kind': ColumnKind.text,
    'institution': ColumnKind.text,
    'match_hints': ColumnKind.textArray,
    'opening_balance': ColumnKind.integer,
    'billing_day': ColumnKind.integer,
    'payment_account_id': ColumnKind.text,
    'sort_order': ColumnKind.integer,
  }),
  SyncTable('categories', {
    'kind': ColumnKind.text,
    'name': ColumnKind.text,
    'parent_id': ColumnKind.text,
    'icon': ColumnKind.text,
    'sort_order': ColumnKind.integer,
  }),
  SyncTable('transactions', {
    'type': ColumnKind.text,
    'occurred_on': ColumnKind.date,
    'occurred_time': ColumnKind.time,
    'amount': ColumnKind.integer,
    'currency': ColumnKind.text,
    'original_amount': ColumnKind.real,
    'account_id': ColumnKind.text,
    'to_account_id': ColumnKind.text,
    'sender': ColumnKind.text,
    'receiver': ColumnKind.text,
    'category_id': ColumnKind.text,
    'memo': ColumnKind.text,
    'tags': ColumnKind.textArray,
    'installment_months': ColumnKind.integer,
    'balance_after': ColumnKind.integer,
    'canceled_at': ColumnKind.timestamp,
    'source': ColumnKind.text,
    'ai_model': ColumnKind.text,
    'status': ColumnKind.text,
    'dedup_key': ColumnKind.text,
  }),
  SyncTable('budgets', {
    'month': ColumnKind.text,
    'category_id': ColumnKind.text,
    'amount': ColumnKind.integer,
  }),
  SyncTable('recurring_rules', {
    'template': ColumnKind.json,
    'frequency': ColumnKind.text,
    'interval_count': ColumnKind.integer,
    'next_run_on': ColumnKind.date,
    'end_on': ColumnKind.date,
    'auto_post': ColumnKind.boolean,
    'is_active': ColumnKind.boolean,
  }),
  SyncTable('category_rules', {
    'pattern': ColumnKind.text,
    'category_id': ColumnKind.text,
    'hit_count': ColumnKind.integer,
  }),
  SyncTable('monthly_summaries', {
    'month': ColumnKind.text,
    'stats': ColumnKind.json,
    'narrative': ColumnKind.text,
    'data_hash': ColumnKind.text,
    'ai_model': ColumnKind.text,
  }),
];

SyncTable? syncTableByName(String name) {
  for (final table in syncTables) {
    if (table.name == name) return table;
  }
  return null;
}
