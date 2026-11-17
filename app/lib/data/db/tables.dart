/// 기기의 SQLite 테이블.
///
/// 동기화하는 9개 테이블은 서버의 `supabase/migrations/0001_schema.sql`과 같은 컬럼을
/// 갖는다. 컬럼을 더하거나 고치면 양쪽과 `sync/sync_tables.dart`를 함께 고친다
/// (`test/data/schema_contract_test.dart`가 어긋남을 잡는다).
///
/// 서버와 달리 외래 키 제약은 두지 않는다. 서버에서 내려받는 순서(server_seq)는 쓰기
/// 순서라서, 새 기기가 처음 받을 때 자식 행이 부모 행보다 먼저 올 수 있다.
library;

import 'package:drift/drift.dart';

import 'converters.dart';

/// 동기화하는 테이블의 공통 컬럼.
mixin SyncColumns on Table {
  /// 기기에서 만드는 UUIDv7.
  TextColumn get id => text()();

  /// 마지막으로 확인한 서버 버전. 서버에 올린 적이 없으면 0.
  IntColumn get version => integer().withDefault(const Constant(0))();

  /// 서버가 매긴 변경 순번. 서버에 올린 적이 없으면 null.
  IntColumn get serverSeq => integer().nullable()();

  /// 기기에서 마지막으로 고친 시각.
  TextColumn get clientUpdatedAt => text().map(const UtcDateTimeConverter())();
  TextColumn get createdAt => text().map(const UtcDateTimeConverter())();
  TextColumn get updatedAt => text().map(const UtcDateTimeConverter())();

  /// 삭제 표시. 삭제도 다른 기기로 전파된다.
  TextColumn get deletedAt =>
      text().map(const UtcDateTimeConverter()).nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// 가계부에 속한 테이블의 공통 컬럼.
mixin LedgerScoped on Table {
  TextColumn get ledgerId => text()();
}

@DataClassName('LedgerRow')
class Ledgers extends Table with SyncColumns {
  @override
  String get tableName => 'ledgers';

  /// 인증 사용자 ID. 로그인 전의 로컬 가계부는 null.
  TextColumn get ownerId => text().nullable()();
  TextColumn get name => text()();
  TextColumn get currency => text().withDefault(const Constant('KRW'))();
}

@DataClassName('ProfileRow')
class Profiles extends Table with SyncColumns, LedgerScoped {
  @override
  String get tableName => 'profiles';

  TextColumn get displayName => text().nullable()();

  /// 월 시작일(1–28).
  IntColumn get monthStartDay => integer().withDefault(const Constant(1))();
  TextColumn get defaultAccountId => text().nullable()();
}

@DataClassName('AccountRow')
class Accounts extends Table with SyncColumns, LedgerScoped {
  @override
  String get tableName => 'accounts';

  TextColumn get name => text()();
  TextColumn get kind => text().map(const AccountKindConverter())();
  TextColumn get institution => text().nullable()();

  /// 원문의 카드 · 계좌 표기와 맞춰 보는 식별 문구.
  TextColumn get matchHints => text()
      .map(const StringListConverter())
      .withDefault(const Constant('[]'))();
  IntColumn get openingBalance => integer().withDefault(const Constant(0))();
  IntColumn get billingDay => integer().nullable()();
  TextColumn get paymentAccountId => text().nullable()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
}

@DataClassName('CategoryRow')
class Categories extends Table with SyncColumns, LedgerScoped {
  @override
  String get tableName => 'categories';

  TextColumn get kind => text().map(const CategoryKindConverter())();
  TextColumn get name => text()();
  TextColumn get parentId => text().nullable()();
  TextColumn get icon => text().nullable()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
}

@DataClassName('TxRow')
@TableIndex(name: 'transactions_ledger_date', columns: {#ledgerId, #occurredOn})
@TableIndex(name: 'transactions_ledger_dedup', columns: {#ledgerId, #dedupKey})
class LedgerTransactions extends Table with SyncColumns, LedgerScoped {
  @override
  String get tableName => 'transactions';

  TextColumn get type => text().map(const TxTypeConverter())();
  TextColumn get occurredOn => text().map(const LocalDateConverter())();

  /// 'HH:mm'. 원문에 없으면 null.
  TextColumn get occurredTime => text().nullable()();

  /// 원 단위 정수. 방향은 type이 정하고 값은 양수다. 부분 취소와 환불만 음수다.
  IntColumn get amount => integer()();
  TextColumn get currency => text().nullable()();
  RealColumn get originalAmount => real().nullable()();
  TextColumn get accountId => text()();
  TextColumn get toAccountId => text().nullable()();
  TextColumn get sender => text().nullable()();
  TextColumn get receiver => text().nullable()();
  TextColumn get categoryId => text().nullable()();
  TextColumn get memo => text().nullable()();
  TextColumn get tags => text()
      .map(const StringListConverter())
      .withDefault(const Constant('[]'))();
  IntColumn get installmentMonths => integer().nullable()();
  IntColumn get balanceAfter => integer().nullable()();
  TextColumn get canceledAt =>
      text().map(const UtcDateTimeConverter()).nullable()();
  TextColumn get source => text()
      .map(const TxSourceConverter())
      .withDefault(const Constant('manual'))();
  TextColumn get aiModel => text().nullable()();
  TextColumn get status => text()
      .map(const TxStatusConverter())
      .withDefault(const Constant('confirmed'))();
  TextColumn get dedupKey => text().nullable()();
}

@DataClassName('BudgetRow')
class Budgets extends Table with SyncColumns, LedgerScoped {
  @override
  String get tableName => 'budgets';

  /// 'YYYY-MM'
  TextColumn get month => text()();

  /// 비면 전체 예산.
  TextColumn get categoryId => text().nullable()();
  IntColumn get amount => integer()();
}

@DataClassName('RecurringRuleRow')
class RecurringRules extends Table with SyncColumns, LedgerScoped {
  @override
  String get tableName => 'recurring_rules';

  TextColumn get template => text().map(const JsonMapConverter())();

  /// weekly · monthly · yearly
  TextColumn get frequency => text()();
  IntColumn get intervalCount => integer().withDefault(const Constant(1))();
  TextColumn get nextRunOn => text().map(const LocalDateConverter())();
  TextColumn get endOn => text().map(const LocalDateConverter()).nullable()();
  BoolColumn get autoPost => boolean().withDefault(const Constant(false))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
}

@DataClassName('CategoryRuleRow')
class CategoryRules extends Table with SyncColumns, LedgerScoped {
  @override
  String get tableName => 'category_rules';

  /// 상대방 문자열(정규화한 값)
  TextColumn get pattern => text()();
  TextColumn get categoryId => text()();
  IntColumn get hitCount => integer().withDefault(const Constant(0))();
}

@DataClassName('MonthlySummaryRow')
class MonthlySummaries extends Table with SyncColumns, LedgerScoped {
  @override
  String get tableName => 'monthly_summaries';

  /// 'YYYY-MM'
  TextColumn get month => text()();
  TextColumn get stats => text().map(const JsonMapConverter())();
  TextColumn get narrative => text().nullable()();
  TextColumn get dataHash => text().nullable()();
  TextColumn get aiModel => text().nullable()();
}

// ---------------------------------------------------------------------------
// 기기 전용 테이블. 서버로 올리지 않는다.
// ---------------------------------------------------------------------------

/// 서버로 보낼 변경 대기열. 한 행의 변경은 항목 하나로 합친다.
@DataClassName('OutboxRow')
class Outbox extends Table {
  @override
  String get tableName => 'outbox';

  IntColumn get seq => integer().autoIncrement()();
  TextColumn get ledgerId => text()();

  /// 서버 테이블 이름.
  TextColumn get targetTable => text()();
  TextColumn get rowId => text()();

  /// upsert · delete
  TextColumn get op => text()();

  /// 이 변경을 만들 때 알고 있던 서버 버전.
  IntColumn get baseVersion => integer()();
  TextColumn get clientUpdatedAt => text().map(const UtcDateTimeConverter())();

  /// 서버가 거절한 횟수. 여러 번 거절된 변경은 보내기를 멈추고 설정 화면에 알린다.
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  TextColumn get lastError => text().nullable()();

  @override
  List<Set<Column>> get uniqueKeys => [
    {targetTable, rowId},
  ];
}

/// 동기화 상태(가계부별 커서 등).
@DataClassName('SyncStateRow')
class SyncState extends Table {
  @override
  String get tableName => 'sync_state';

  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

/// 충돌에서 진 쪽 값. 설정 화면에서 확인하고 되살릴 수 있다.
@DataClassName('SyncConflictRow')
class SyncConflicts extends Table {
  @override
  String get tableName => 'sync_conflicts';

  IntColumn get seq => integer().autoIncrement()();
  TextColumn get ledgerId => text()();
  TextColumn get targetTable => text()();
  TextColumn get rowId => text()();

  /// 진 쪽 행(JSON).
  TextColumn get loser => text().map(const JsonMapConverter())();

  /// local: 이 기기의 값이 졌다. remote: 다른 기기의 값이 졌다.
  TextColumn get loserSide => text()();
  TextColumn get detectedAt => text().map(const UtcDateTimeConverter())();
}
