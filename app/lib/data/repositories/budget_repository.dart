import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/ids.dart';
import '../../core/local_date.dart';
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
      ..orderBy(_latestFirst);
    return query.watch().map(_pickLatest);
  }

  /// 나중에 고친 행이 먼저 오는 순서. 고친 때가 같으면 ID로 갈라, 어느 기기에서나 같은
  /// 행이 뽑히게 한다.
  static final _latestFirst = <OrderingTerm Function($BudgetsTable)>[
    (b) => OrderingTerm.desc(b.clientUpdatedAt),
    (b) => OrderingTerm.desc(b.id),
  ];

  /// 분류마다 맨 앞의 행 하나만 남긴다. [rows]는 [_latestFirst] 순서여야 한다.
  static List<BudgetRow> _pickLatest(List<BudgetRow> rows) {
    final seen = <(String, String?)>{};
    return [
      for (final row in rows)
        if (seen.add((row.month, row.categoryId))) row,
    ];
  }

  Future<List<BudgetRow>> _liveRows(String ledgerId, {String? month}) {
    final query = db.select(db.budgets)
      ..where(
        (b) =>
            b.ledgerId.equals(ledgerId) &
            b.deletedAt.isNull() &
            (month == null ? const Constant(true) : b.month.equals(month)),
      )
      ..orderBy(_latestFirst);
    return query.get();
  }

  /// [month]의 예산을 한 번 읽는다. 겹친 행은 [watchBudgets]와 같은 규칙으로 고른다.
  Future<List<BudgetRow>> budgets(String ledgerId, String month) async =>
      _pickLatest(await _liveRows(ledgerId, month: month));

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
              ..orderBy(_latestFirst)
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

  /// [month]의 [categoryId](null이면 전체) 예산을 없앤다. 겹친 행이 있으면 모두 지운다.
  Future<void> deleteBudget(
    String ledgerId, {
    required String month,
    required String? categoryId,
  }) => db.transaction(() async {
    for (final row in await _liveRows(ledgerId, month: month)) {
      if (row.categoryId != categoryId) continue;
      await outbox.softDelete('budgets', ledgerId, row.id, row.version);
    }
  });

  /// [month]의 앞 달 예산을 [month]로 복사한다. 복사한 건수를 돌려준다.
  ///
  /// [month]에 이미 정한 예산(전체든 분류든)은 건드리지 않고, 지워진 분류의 예산은
  /// 가져오지 않는다.
  Future<int> copyFromPreviousMonth(String ledgerId, String month) =>
      db.transaction(() async {
        final previous = await budgets(ledgerId, previousMonth(month));
        final have = {
          for (final row in await _liveRows(ledgerId, month: month))
            row.categoryId,
        };
        final liveCategories = {
          for (final c
              in await (db.select(db.categories)..where(
                    (c) => c.ledgerId.equals(ledgerId) & c.deletedAt.isNull(),
                  ))
                  .get())
            c.id,
        };
        final now = outbox.now();
        var copied = 0;
        for (final row in previous) {
          final categoryId = row.categoryId;
          if (have.contains(categoryId)) continue;
          if (categoryId != null && !liveCategories.contains(categoryId)) {
            continue;
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
                  amount: row.amount,
                  clientUpdatedAt: now,
                  createdAt: now,
                  updatedAt: now,
                ),
              );
          await outbox.enqueue(ledgerId, 'budgets', id, 'upsert', 0, now);
          copied++;
        }
        return copied;
      });

  /// 같은 달 · 같은 분류의 행이 둘 이상이면(두 기기가 따로 만든 경우) 나중에 고친 것만
  /// 남기고 나머지를 삭제 표시한다. [month]를 주면 그 달만 본다. 지운 행의 수를 돌려준다.
  ///
  /// 서버는 이 유일성을 지키지 않는다. 어느 기기가 정리해도 같은 행이 남는다.
  Future<int> cleanDuplicates(String ledgerId, {String? month}) =>
      db.transaction(() async {
        final rows = await _liveRows(ledgerId, month: month);
        final keep = {for (final row in _pickLatest(rows)) row.id};
        var removed = 0;
        for (final row in rows) {
          if (keep.contains(row.id)) continue;
          await outbox.softDelete('budgets', ledgerId, row.id, row.version);
          removed++;
        }
        return removed;
      });

  /// 'YYYY-MM'의 앞 달. '2026-01' → '2025-12'.
  static String previousMonth(String month) {
    final match = RegExp(r'^(\d{4})-(\d{2})$').firstMatch(month);
    if (match == null) throw FormatException('YYYY-MM 꼴이 아니다', month);
    return LocalDate(
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      1,
    ).addMonths(-1).yearMonth;
  }
}

final budgetRepositoryProvider = Provider<BudgetRepository>((ref) {
  final repository = ref.watch(repositoryProvider);
  return BudgetRepository(repository.db, repository.outbox);
});
