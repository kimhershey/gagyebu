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
    InputBatches,
    InputBatchItems,
    ModelFiles,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  /// 스키마 판. 판마다 무엇이 바뀌었는지는 `docs/SPEC.md` 3.1에 적는다.
  ///
  /// - 1: 동기화하는 표 9개와 대기열 · 동기화 상태 · 충돌 기록
  /// - 2: 작업 기록(input_batches, input_batch_items)과 모델 파일(model_files)
  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    // 판을 한 단계씩 올린다. 있던 표의 내용은 건드리지 않는다.
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.createTable(inputBatches);
        await m.createTable(inputBatchItems);
        await m.createTable(modelFiles);
      }
    },
  );
}
