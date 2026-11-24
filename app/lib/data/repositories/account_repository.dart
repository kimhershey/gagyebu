import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/enums.dart';
import '../db/database.dart';
import 'outbox_writer.dart';

/// 순서를 매기는 간격. 사이에 끼워 넣을 자리를 남긴다.
const sortOrderStep = 10;

/// 순서를 바꿀 때 `sort_order`를 고쳐야 하는 행과 새 값을 정한다(`docs/SPEC.md` 7.2).
///
/// [current]는 지금의 값(ID → `sort_order`), [orderedIds]는 바라는 순서다.
/// 한 줄만 옮겼고 이웃 사이에 빈 값이 있으면 그 줄만 가운데 값으로 고친다(올릴 변경이
/// 한 건이면 다른 기기와 부딪칠 일이 적다). 자리가 없거나 여러 줄이 바뀌었으면 전체를
/// [sortOrderStep] 간격으로 다시 매기고, 값이 달라진 줄만 돌려준다.
Map<String, int> planSortOrders(
  Map<String, int> current,
  List<String> orderedIds,
) {
  if (orderedIds.toSet().length != orderedIds.length ||
      orderedIds.any((id) => !current.containsKey(id))) {
    throw ArgumentError('순서에 없는 행이나 겹친 행이 있습니다');
  }
  bool increasing(List<int> values) {
    for (var i = 1; i < values.length; i++) {
      if (values[i - 1] >= values[i]) return false;
    }
    return true;
  }

  final values = [for (final id in orderedIds) current[id]!];
  if (increasing(values)) return const {};

  // 한 줄만 빼면 나머지가 이미 순서대로인 자리를 찾는다. 그 줄이 옮긴 줄이다.
  for (var i = 0; i < orderedIds.length; i++) {
    final rest = [...values]..removeAt(i);
    if (!increasing(rest)) continue;
    final int? value;
    if (rest.isEmpty) {
      value = sortOrderStep;
    } else if (i == 0) {
      value = rest.first - sortOrderStep;
    } else if (i == rest.length) {
      value = rest.last + sortOrderStep;
    } else {
      final low = rest[i - 1], high = rest[i];
      value = high - low >= 2 ? low + (high - low) ~/ 2 : null;
    }
    // 서버의 정수 범위를 넘지 않게, 0보다 작아지면 다시 매긴다.
    if (value != null && value > 0) return {orderedIds[i]: value};
  }

  final changes = <String, int>{};
  for (var i = 0; i < orderedIds.length; i++) {
    final value = (i + 1) * sortOrderStep;
    if (current[orderedIds[i]] != value) changes[orderedIds[i]] = value;
  }
  return changes;
}

/// 자산의 수정과 순서 바꾸기(`docs/SPEC.md` 7.2 · 7.12).
///
/// 추가 · 삭제 · 조회는 `LedgerRepository`에 있다.
class AccountRepository {
  AccountRepository(this.db, this.outbox);

  final AppDatabase db;
  final OutboxWriter outbox;

  /// 자산 [id]의 내용을 고친다. 넘긴 값이 그대로 새 값이 된다.
  ///
  /// 결제일과 결제 계좌는 카드에만 둔다. 다른 종류로 바꾸면 비운다.
  Future<void> updateAccount(
    String id, {
    required String name,
    required AccountKind kind,
    String? institution,
    List<String> matchHints = const [],
    int openingBalance = 0,
    int? billingDay,
    String? paymentAccountId,
  }) => db.transaction(() async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) throw ArgumentError('이름이 비어 있습니다');
    if (billingDay != null && (billingDay < 1 || billingDay > 31)) {
      throw ArgumentError.value(billingDay, 'billingDay', '1–31이어야 한다');
    }
    if (paymentAccountId == id) {
      throw ArgumentError('자기 자신을 결제 계좌로 둘 수 없습니다');
    }
    final existing = await (db.select(
      db.accounts,
    )..where((a) => a.id.equals(id) & a.deletedAt.isNull())).getSingleOrNull();
    if (existing == null) throw StateError('없는 자산입니다: $id');

    final isCard =
        kind == AccountKind.creditCard || kind == AccountKind.checkCard;
    final institutionText = institution?.trim() ?? '';
    final now = outbox.now();
    await (db.update(db.accounts)..where((a) => a.id.equals(id))).write(
      AccountsCompanion(
        name: Value(trimmed),
        kind: Value(kind),
        institution: Value(institutionText.isEmpty ? null : institutionText),
        matchHints: Value([
          for (final hint in matchHints)
            if (hint.trim().isNotEmpty) hint.trim(),
        ]),
        openingBalance: Value(openingBalance),
        // 결제일은 신용카드에만 뜻이 있다. 체크카드는 연결 계좌만 둔다.
        billingDay: Value(kind == AccountKind.creditCard ? billingDay : null),
        paymentAccountId: Value(isCard ? paymentAccountId : null),
        clientUpdatedAt: Value(now),
        updatedAt: Value(now),
      ),
    );
    await outbox.enqueue(
      existing.ledgerId,
      'accounts',
      id,
      'upsert',
      existing.version,
      now,
    );
  });

  /// 자산의 순서를 [orderedIds]대로 바꾼다. 화면이 묶어 보이는 한 종류의 자산을 넘긴다.
  ///
  /// 고친 행의 수를 돌려준다.
  Future<int> reorderAccounts(String ledgerId, List<String> orderedIds) =>
      db.transaction(() async {
        final rows =
            await (db.select(db.accounts)..where(
                  (a) =>
                      a.ledgerId.equals(ledgerId) &
                      a.deletedAt.isNull() &
                      a.id.isIn(orderedIds),
                ))
                .get();
        final byId = {for (final row in rows) row.id: row};
        final changes = planSortOrders({
          for (final row in rows) row.id: row.sortOrder,
        }, orderedIds);
        final now = outbox.now();
        for (final MapEntry(key: id, value: order) in changes.entries) {
          await (db.update(db.accounts)..where((a) => a.id.equals(id))).write(
            AccountsCompanion(
              sortOrder: Value(order),
              clientUpdatedAt: Value(now),
              updatedAt: Value(now),
            ),
          );
          await outbox.enqueue(
            ledgerId,
            'accounts',
            id,
            'upsert',
            byId[id]!.version,
            now,
          );
        }
        return changes.length;
      });
}

final accountRepositoryProvider = Provider<AccountRepository>((ref) {
  final repository = ref.watch(repositoryProvider);
  return AccountRepository(repository.db, repository.outbox);
});
