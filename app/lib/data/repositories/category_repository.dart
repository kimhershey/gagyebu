import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../db/database.dart';
import 'account_repository.dart' show planSortOrders;
import 'ledger_repository.dart';
import 'outbox_writer.dart';

/// 분류의 수정 · 순서 바꾸기 · 대분류 정하기(`docs/SPEC.md` 7.2).
///
/// 추가와 조회는 `LedgerRepository`에 있다. 삭제는 소분류의 대분류를 비워야 해서 여기의
/// [deleteCategory]를 쓴다.
class CategoryRepository {
  CategoryRepository(this.ledger);

  final LedgerRepository ledger;

  AppDatabase get db => ledger.db;
  OutboxWriter get outbox => ledger.outbox;

  Future<CategoryRow> _live(String id) async {
    final row = await (db.select(
      db.categories,
    )..where((c) => c.id.equals(id) & c.deletedAt.isNull())).getSingleOrNull();
    if (row == null) throw StateError('없는 분류입니다: $id');
    return row;
  }

  Future<void> _write(
    CategoryRow existing,
    CategoriesCompanion values,
    DateTime now,
  ) async {
    await (db.update(
      db.categories,
    )..where((c) => c.id.equals(existing.id))).write(
      values.copyWith(clientUpdatedAt: Value(now), updatedAt: Value(now)),
    );
    await outbox.enqueue(
      existing.ledgerId,
      'categories',
      existing.id,
      'upsert',
      existing.version,
      now,
    );
  }

  /// 분류 [id]의 이름과 아이콘을 고친다. [icon]은 `categoryIconChoices`의 키이고,
  /// null이면 기본 아이콘으로 돌아간다.
  Future<void> updateCategory(
    String id, {
    required String name,
    required String? icon,
  }) => db.transaction(() async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) throw ArgumentError('이름이 비어 있습니다');
    final existing = await _live(id);
    await _write(
      existing,
      CategoriesCompanion(name: Value(trimmed), icon: Value(icon)),
      outbox.now(),
    );
  });

  /// 분류의 순서를 [orderedIds]대로 바꾼다. 같은 자리에 놓이는 분류들(한 종류의 대분류들,
  /// 또는 한 대분류의 소분류들)을 넘긴다. 고친 행의 수를 돌려준다.
  Future<int> reorderCategories(String ledgerId, List<String> orderedIds) =>
      db.transaction(() async {
        final rows =
            await (db.select(db.categories)..where(
                  (c) =>
                      c.ledgerId.equals(ledgerId) &
                      c.deletedAt.isNull() &
                      c.id.isIn(orderedIds),
                ))
                .get();
        final byId = {for (final row in rows) row.id: row};
        final changes = planSortOrders({
          for (final row in rows) row.id: row.sortOrder,
        }, orderedIds);
        final now = outbox.now();
        for (final MapEntry(key: id, value: order) in changes.entries) {
          await _write(
            byId[id]!,
            CategoriesCompanion(sortOrder: Value(order)),
            now,
          );
        }
        return changes.length;
      });

  /// 분류 [id]를 대분류 [parentId] 아래에 둔다. null이면 대분류 없는 분류로 돌린다.
  ///
  /// 소분류는 한 단계만 둔다: 소분류 아래에 둘 수 없고, 소분류를 가진 분류는 다른 분류
  /// 아래로 갈 수 없다.
  Future<void> setParent(String id, String? parentId) =>
      db.transaction(() async {
        final existing = await _live(id);
        if (existing.parentId == parentId) return;
        if (parentId != null) {
          if (parentId == id) {
            throw ArgumentError('자기 자신을 대분류로 둘 수 없습니다');
          }
          final parent = await _live(parentId);
          if (parent.ledgerId != existing.ledgerId ||
              parent.kind != existing.kind) {
            throw ArgumentError('종류가 다른 분류 아래에는 둘 수 없습니다');
          }
          if (parent.parentId != null) {
            throw ArgumentError('소분류 아래에는 분류를 둘 수 없습니다');
          }
          if ((await _children(id)).isNotEmpty) {
            throw ArgumentError('소분류가 있는 분류는 다른 분류 아래에 둘 수 없습니다');
          }
        }
        await _write(
          existing,
          CategoriesCompanion(parentId: Value(parentId)),
          outbox.now(),
        );
      });

  /// 분류를 지운다. 대분류였다면 소분류는 대분류 없는 분류가 되고, 이 분류를 쓰던 거래는
  /// 분류 없음이 된다.
  Future<void> deleteCategory(String id) => db.transaction(() async {
    final now = outbox.now();
    for (final child in await _children(id)) {
      await _write(
        child,
        const CategoriesCompanion(parentId: Value(null)),
        now,
      );
    }
    await ledger.deleteCategory(id);
  });

  Future<List<CategoryRow>> _children(String id) => (db.select(
    db.categories,
  )..where((c) => c.parentId.equals(id) & c.deletedAt.isNull())).get();
}

final categoryRepositoryProvider = Provider<CategoryRepository>(
  (ref) => CategoryRepository(ref.watch(repositoryProvider)),
);
