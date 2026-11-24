import 'package:collection/collection.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/local_date.dart';
import '../../domain/enums.dart';
import '../db/converters.dart';
import '../db/database.dart';
import '../sync/row_codec.dart';
import '../sync/sync_tables.dart';
import 'ledger_repository.dart';

/// 진 쪽과 지금 값이 다른 칸 하나.
class ConflictField {
  const ConflictField({
    required this.column,
    required this.loser,
    required this.current,
  });

  /// 표의 열 이름.
  final String column;

  /// 진 쪽의 값.
  final Object? loser;

  /// 지금 기기에 있는(이긴 쪽의) 값.
  final Object? current;
}

/// 충돌 기록 한 건을 화면에 보이기 좋게 푼 것.
class ConflictView {
  const ConflictView({
    required this.row,
    required this.loser,
    required this.current,
    required this.loserIsDeletion,
    required this.changed,
  });

  final SyncConflictRow row;

  /// 진 쪽의 값(표의 열만). 진 쪽이 '삭제'였거나 읽지 못했으면 비어 있다.
  final Map<String, Object?> loser;

  /// 지금 기기에 있는 값. 행이 없거나 지워졌으면 null이다.
  final Map<String, Object?>? current;

  /// 진 쪽이 '삭제'였는지.
  final bool loserIsDeletion;

  /// 진 쪽과 지금 값이 다른 칸.
  final List<ConflictField> changed;

  /// 이 기기에서 고친 것이 졌는지. 아니면 다른 기기에서 고친 것이 졌다.
  bool get localLost => row.loserSide == 'local';

  /// 진 값으로 다시 쓸 수 있는지. 거래만 된다.
  bool get canRestore => row.targetTable == 'transactions';
}

/// 동기화 충돌 기록의 조회 · 정리 · 되살리기(`docs/SPEC.md` 4.6).
class ConflictRepository {
  ConflictRepository(this.db, this.ledger, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final AppDatabase db;
  final LedgerRepository ledger;
  final DateTime Function() _clock;

  /// 기록을 두는 기간.
  static const maxAge = Duration(days: 30);

  /// 남겨 두는 기록 수.
  static const maxCount = 200;

  /// 화면에 견줘 보여 주지 않는 열. 다른 열에서 계산한 값이라 따로 보일 것이 없다.
  static const _derivedColumns = {'dedup_key'};

  /// [ledgerId]의 충돌 기록을 최근 것부터.
  Stream<List<ConflictView>> watchConflicts(String ledgerId) {
    final query = db.select(db.syncConflicts)
      ..where((c) => c.ledgerId.equals(ledgerId))
      ..orderBy([(c) => OrderingTerm.desc(c.seq)]);
    return query.watch().asyncMap(
      (rows) async => [for (final row in rows) await _view(row)],
    );
  }

  Future<ConflictView> _view(SyncConflictRow row) async {
    final table = syncTableByName(row.targetTable);
    final loserIsDeletion = _isDeletion(row.loser);
    var loser = const <String, Object?>{};
    Map<String, Object?>? current;
    if (table != null) {
      if (!loserIsDeletion) {
        try {
          // 서버가 준 행과 기기가 올린 행의 표기(시각의 초, 시간대)를 하나로 맞춘다.
          loser = rowToPushData(table, jsonToLocalRow(table, row.loser));
        } on Object {
          // 앱이 모르는 꼴의 값이다. 값 없이 기록만 보여 준다.
          loser = const {};
        }
      }
      // 표 이름은 [syncTableByName]이 아는 것만 온다.
      final found = await db
          .customSelect(
            'SELECT * FROM ${table.name} WHERE id = ?',
            variables: [Variable.withString(row.rowId)],
          )
          .getSingleOrNull();
      if (found != null && found.data['deleted_at'] == null) {
        current = rowToPushData(table, found.data);
      }
    }
    const equality = DeepCollectionEquality();
    final changed = <ConflictField>[
      if (table != null)
        for (final column in table.columns.keys)
          // 기록에 실려 있던 칸만 견준다.
          if (!_derivedColumns.contains(column) &&
              loser.containsKey(column) &&
              row.loser.containsKey(column) &&
              !equality.equals(loser[column], current?[column]))
            ConflictField(
              column: column,
              loser: loser[column],
              current: current?[column],
            ),
    ];
    return ConflictView(
      row: row,
      loser: loser,
      current: current,
      loserIsDeletion: loserIsDeletion,
      changed: changed,
    );
  }

  /// 기록 한 건을 지운다. 행은 건드리지 않는다.
  Future<void> deleteConflict(int seq) =>
      (db.delete(db.syncConflicts)..where((c) => c.seq.equals(seq))).go();

  /// [maxAge]가 지난 기록과, 최근 [maxCount]건을 넘는 오래된 기록을 지운다.
  /// 지운 건수를 돌려준다.
  Future<int> pruneConflicts() => db.transaction(() async {
    final cutoff = const UtcDateTimeConverter().toSql(
      _clock().toUtc().subtract(maxAge),
    );
    var removed = await (db.delete(
      db.syncConflicts,
    )..where((c) => c.detectedAt.isSmallerThanValue(cutoff))).go();
    removed += await db.customUpdate(
      'DELETE FROM sync_conflicts WHERE seq NOT IN '
      '(SELECT seq FROM sync_conflicts ORDER BY seq DESC LIMIT ?)',
      variables: [Variable.withInt(maxCount)],
      updates: {db.syncConflicts},
      updateKind: UpdateKind.delete,
    );
    return removed;
  });

  /// 진 값으로 그 거래를 다시 쓴다. 새 변경으로 대기열에 올라간다. 다 쓰면 기록을 지운다.
  ///
  /// - 진 쪽이 '삭제'였으면 그 거래를 다시 지운다.
  /// - 지금 지워져 있는 거래면 삭제 표시를 풀고 진 값으로 쓴다.
  ///
  /// 거래가 아닌 표의 기록이면 [UnsupportedError], 진 값을 읽지 못하면 [FormatException],
  /// 그 거래가 쓰던 자산이 없어졌으면 [ArgumentError]를 던진다.
  Future<void> restore(SyncConflictRow conflict) => db.transaction(() async {
    if (conflict.targetTable != 'transactions') {
      throw UnsupportedError('거래의 충돌만 되살릴 수 있다');
    }
    final id = conflict.rowId;
    if (_isDeletion(conflict.loser)) {
      await ledger.deleteTransaction(id);
    } else {
      final input = transactionInputFromLoser(conflict.loser);
      final existing = await ledger.transactionById(id);
      if (existing == null) {
        await ledger.addTransaction(conflict.ledgerId, input, id: id);
      } else {
        if (existing.deletedAt != null) {
          // 삭제 표시를 푼다. 바로 아래의 수정이 같은 트랜잭션에서 대기열에 올리고,
          // 서버는 삭제 표시가 있던 행에 온 수정을 되살리기로 받아들인다.
          await (db.update(db.ledgerTransactions)
                ..where((t) => t.id.equals(id)))
              .write(const LedgerTransactionsCompanion(deletedAt: Value(null)));
        }
        await ledger.updateTransaction(id, input);
      }
    }
    await deleteConflict(conflict.seq);
  });

  /// 진 쪽이 '삭제'였는지. 기기의 삭제가 졌으면 `{'deleted': true}`가, 다른 기기의 삭제가
  /// 졌으면 `deleted_at`이 찬 서버 행이 남아 있다.
  static bool _isDeletion(Map<String, Object?> loser) =>
      loser['deleted'] == true || loser['deleted_at'] != null;

  /// 진 쪽의 거래 행(JSON)을 저장소에 넘길 입력값으로 바꾼다.
  /// 꼭 있어야 하는 값이 없거나 꼴이 다르면 [FormatException].
  static TransactionInput transactionInputFromLoser(
    Map<String, Object?> loser,
  ) {
    try {
      String? text(String key) => loser[key] as String?;
      int? integer(String key) => (loser[key] as num?)?.toInt();
      final type = TxType.fromCode(loser['type']! as String);
      final time = text('occurred_time');
      return TransactionInput(
        type: type,
        occurredOn: LocalDate.parse(loser['occurred_on']! as String),
        // 서버는 'HH:MM:SS'로 준다.
        occurredTime: time != null && time.length > 5
            ? time.substring(0, 5)
            : time,
        amount: integer('amount')!,
        accountId: loser['account_id']! as String,
        toAccountId: text('to_account_id'),
        counterparty: switch (type) {
          TxType.expense => text('receiver'),
          TxType.income => text('sender'),
          TxType.transfer => null,
        },
        categoryId: text('category_id'),
        memo: text('memo'),
        installmentMonths: integer('installment_months'),
        balanceAfter: integer('balance_after'),
        currency: text('currency'),
        originalAmount: (loser['original_amount'] as num?)?.toDouble(),
        source: TxSource.fromCode(text('source') ?? TxSource.manual.code),
        aiModel: text('ai_model'),
        canceled: loser['canceled_at'] != null,
        status: TxStatus.fromCode(text('status') ?? TxStatus.confirmed.code),
      );
    } on FormatException {
      rethrow;
    } on Object catch (e) {
      // 열이 빠졌거나(null 확인 실패) 모르는 종류 값이다.
      throw FormatException('충돌 기록의 값을 읽지 못했다: $e');
    }
  }
}

final conflictRepositoryProvider = Provider<ConflictRepository>((ref) {
  final repository = ref.watch(repositoryProvider);
  return ConflictRepository(
    repository.db,
    repository,
    clock: ref.watch(clockProvider),
  );
});

/// 지금 가계부의 충돌 기록.
final conflictsProvider = StreamProvider<List<ConflictView>>(
  (ref) => ref
      .watch(conflictRepositoryProvider)
      .watchConflicts(ref.watch(ledgerIdProvider)),
);
