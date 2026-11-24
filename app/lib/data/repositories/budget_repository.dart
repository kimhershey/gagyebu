import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/ids.dart';
import '../db/database.dart';
import 'outbox_writer.dart';

/// 예산의 읽기와 쓰기(`docs/SPEC.md` 7.11).
class BudgetRepository {
  BudgetRepository(this.db, this.outbox, {String Function()? idGenerator})
    : _newId = idGenerator ?? newRowId;

  final AppDatabase db;
  final OutboxWriter outbox;
  final String Function() _newId;

  /// [month]('YYYY-MM')의 예산. 같은 분류의 행이 겹치면 나중에 고친 것 하나만 준다.
  /// `categoryId`가 null인 행이 전체 예산이다.
  Stream<List<BudgetRow>> watchBudgets(String ledgerId, String month) {
    final query = db.select(db.budgets)
      ..where(
        (b) =>
            b.ledgerId.equals(ledgerId) &
            b.month.equals(month) &
            b.deletedAt.isNull(),
      )
      ..orderBy([(b) => OrderingTerm.desc(b.clientUpdatedAt)]);
    return query.watch().map((rows) {
      final seen = <String?>{};
      return [
        for (final row in rows)
          if (seen.add(row.categoryId)) row,
      ];
    });
  }

  /// [month]의 [categoryId](null이면 전체) 예산을 [amount]로 정한다.
  Future<void> setBudget(
    String ledgerId, {
    required String month,
    required String? categoryId,
    required int amount,
  }) => db.transaction(() async {
    if (amount < 0) throw ArgumentError('예산은 0 이상이어야 합니다');
    final now = outbox.now();
    final existing =
        await (db.select(db.budgets)
              ..where(
                (b) =>
                    b.ledgerId.equals(ledgerId) &
                    b.month.equals(month) &
                    b.deletedAt.isNull() &
                    (categoryId == null
                        ? b.categoryId.isNull()
                        : b.categoryId.equals(categoryId)),
              )
              ..orderBy([(b) => OrderingTerm.desc(b.clientUpdatedAt)])
              ..limit(1))
            .getSingleOrNull();
    if (existing != null) {
      await (db.update(
        db.budgets,
      )..where((b) => b.id.equals(existing.id))).write(
        BudgetsCompanion(
          amount: Value(amount),
          clientUpdatedAt: Value(now),
          updatedAt: Value(now),
        ),
      );
      await outbox.enqueue(
        ledgerId,
        'budgets',
        existing.id,
        'upsert',
        existing.version,
        now,
      );
      return;
    }
    final id = _newId();
    await db
        .into(db.budgets)
        .insert(
          BudgetsCompanion.insert(
            id: id,
            ledgerId: ledgerId,
            month: month,
            categoryId: Value(categoryId),
            amount: amount,
            clientUpdatedAt: now,
            createdAt: now,
            updatedAt: now,
          ),
        );
    await outbox.enqueue(ledgerId, 'budgets', id, 'upsert', 0, now);
  });
}

final budgetRepositoryProvider = Provider<BudgetRepository>((ref) {
  final repository = ref.watch(repositoryProvider);
  return BudgetRepository(repository.db, repository.outbox);
});
