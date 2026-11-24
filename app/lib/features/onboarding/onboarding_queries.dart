import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../data/repositories/ledger_repository.dart';

/// 첫 실행 안내가 쓰는 조회. 저장소(`LedgerRepository`)를 고치지 않고 여기서 더한다.
extension OnboardingQueries on LedgerRepository {
  /// 가계부에 거래가 한 건이라도 있는지.
  Stream<bool> watchHasTransactions(String ledgerId) {
    final t = db.ledgerTransactions;
    final count = t.id.count();
    final query = db.selectOnly(t)
      ..addColumns([count])
      ..where(t.ledgerId.equals(ledgerId) & t.deletedAt.isNull());
    return query.map((row) => (row.read(count) ?? 0) > 0).watchSingle();
  }

  /// 기기에 다 내려받은 모델이 있는지.
  Stream<bool> watchHasReadyModel() {
    final m = db.modelFiles;
    final count = m.id.count();
    final query = db.selectOnly(m)
      ..addColumns([count])
      ..where(m.status.equals('ready'));
    return query.map((row) => (row.read(count) ?? 0) > 0).watchSingle();
  }
}

/// 가계부에 거래가 한 건이라도 있는지.
final hasTransactionsProvider = StreamProvider<bool>(
  (ref) => ref
      .watch(repositoryProvider)
      .watchHasTransactions(ref.watch(ledgerIdProvider)),
);

/// 기기에 다 내려받은 모델이 있는지.
final hasReadyModelProvider = StreamProvider<bool>(
  (ref) => ref.watch(repositoryProvider).watchHasReadyModel(),
);
