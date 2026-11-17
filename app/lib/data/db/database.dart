import 'package:drift/drift.dart';

import '../../core/local_date.dart';
import '../../domain/enums.dart';
import 'converters.dart';
import 'tables.dart';

part 'database.g.dart';

/// 기기의 로컬 DB. 모든 읽기 · 쓰기의 1차 저장소다.
@DriftDatabase(
  tables: [
    Ledgers,
    Profiles,
    Accounts,
    Categories,
    LedgerTransactions,
    Budgets,
    RecurringRules,
    CategoryRules,
    MonthlySummaries,
    Outbox,
    SyncState,
    SyncConflicts,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration =>
      MigrationStrategy(onCreate: (m) => m.createAll());
}
