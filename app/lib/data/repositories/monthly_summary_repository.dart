import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ai/llm/narrative_writer.dart';
import '../../app/providers.dart';
import '../../core/ids.dart';
import '../../domain/month_period.dart';
import '../db/database.dart';
import 'outbox_writer.dart';

/// 집계 JSON의 SHA-256(`monthly_summaries.data_hash`).
///
/// 키를 정렬한 JSON 글자에서 계산한다. 값이 같으면 어느 기기에서 계산해도 같다.
String statsHash(Map<String, Object?> stats) =>
    sha256.convert(utf8.encode(jsonEncode(_sorted(stats)))).toString();

Object? _sorted(Object? value) {
  if (value is Map) {
    final keys = [for (final key in value.keys) '$key']..sort();
    return {for (final key in keys) key: _sorted(value[key])};
  }
  if (value is List) return [for (final item in value) _sorted(item)];
  return value;
}

/// 월별 요약과 총평의 보관(`docs/SPEC.md` 7.10).
class MonthlySummaryRepository {
  MonthlySummaryRepository(
    this.db,
    this.outbox, {
    String Function()? idGenerator,
  }) : _newId = idGenerator ?? newRowId;

  final AppDatabase db;
  final OutboxWriter outbox;
  final String Function() _newId;

  static const _table = 'monthly_summaries';

  /// [month]('YYYY-MM')의 요약. 같은 달의 행이 겹치면(두 기기가 따로 만든 경우)
  /// 나중에 고친 것을 준다.
  Future<MonthlySummaryRow?> latest(String ledgerId, String month) =>
      (db.select(db.monthlySummaries)
            ..where(
              (s) =>
                  s.ledgerId.equals(ledgerId) &
                  s.month.equals(month) &
                  s.deletedAt.isNull(),
            )
            ..orderBy([
              (s) => OrderingTerm.desc(s.clientUpdatedAt),
              // 같은 때에 고친 행은 ID로 가른다. 어느 기기에서나 같은 행을 고른다.
              (s) => OrderingTerm.desc(s.id),
            ])
            ..limit(1))
          .getSingleOrNull();

  /// [month]의 요약을 적는다. 이미 있으면 그 행을 고치고, 없으면 새로 만든다.
  /// 같은 트랜잭션에서 대기열에 올린다.
  Future<MonthlySummaryRow> save(
    String ledgerId, {
    required String month,
    required Map<String, Object?> stats,
    required String narrative,
    required String dataHash,
    String? aiModel,
  }) => db.transaction(() async {
    final now = outbox.now();
    final existing = await latest(ledgerId, month);
    final String id;
    if (existing != null) {
      id = existing.id;
      await (db.update(
        db.monthlySummaries,
      )..where((s) => s.id.equals(id))).write(
        MonthlySummariesCompanion(
          stats: Value(stats),
          narrative: Value(narrative),
          dataHash: Value(dataHash),
          aiModel: Value(aiModel),
          clientUpdatedAt: Value(now),
          updatedAt: Value(now),
        ),
      );
      await outbox.enqueue(
        ledgerId,
        _table,
        id,
        'upsert',
        existing.version,
        now,
      );
    } else {
      id = _newId();
      await db
          .into(db.monthlySummaries)
          .insert(
            MonthlySummariesCompanion.insert(
              id: id,
              ledgerId: ledgerId,
              month: month,
              stats: stats,
              narrative: Value(narrative),
              dataHash: Value(dataHash),
              aiModel: Value(aiModel),
              clientUpdatedAt: now,
              createdAt: now,
              updatedAt: now,
            ),
          );
      await outbox.enqueue(ledgerId, _table, id, 'upsert', 0, now);
    }
    return (db.select(
      db.monthlySummaries,
    )..where((s) => s.id.equals(id))).getSingle();
  });

  /// 달마다 만들고 있는 총평. 같은 달의 요청을 차례로 처리하는 데 쓴다.
  final _inFlight = <String, Future<void>>{};

  /// [month]의 총평.
  ///
  /// 보관한 것의 `data_hash`가 [stats]의 해시와 같으면 그것을 그대로 준다([write]를
  /// 부르지 않는다). 없거나 집계가 달라졌으면 [write]로 새로 만들어 보관한다.
  ///
  /// 같은 달의 요청이 겹치면 앞의 것이 끝난 뒤에 처리한다. 모델이 글을 쓰는 동안 같은
  /// 달을 또 물어도 모델을 두 번 부르지 않고, 늦게 끝난 옛 집계의 글이 새 글을 덮지 않는다.
  Future<String> narrativeFor(
    String ledgerId, {
    required String month,
    required Map<String, Object?> stats,
    required Future<NarrativeResult> Function(Map<String, Object?> stats) write,
  }) {
    final key = '$ledgerId/$month';
    final result = (_inFlight[key] ?? Future<void>.value()).then(
      (_) => _narrativeFor(ledgerId, month: month, stats: stats, write: write),
    );
    final done = result.then<void>((_) {}, onError: (Object _) {});
    _inFlight[key] = done;
    done.whenComplete(() {
      if (identical(_inFlight[key], done)) _inFlight.remove(key);
    });
    return result;
  }

  Future<String> _narrativeFor(
    String ledgerId, {
    required String month,
    required Map<String, Object?> stats,
    required Future<NarrativeResult> Function(Map<String, Object?> stats) write,
  }) async {
    final hash = statsHash(stats);
    final existing = await latest(ledgerId, month);
    final kept = existing?.narrative?.trim() ?? '';
    if (existing != null && existing.dataHash == hash && kept.isNotEmpty) {
      return kept;
    }
    final result = await write(stats);
    await save(
      ledgerId,
      month: month,
      stats: stats,
      narrative: result.text,
      dataHash: hash,
      aiModel: result.aiModel,
    );
    return result.text;
  }

  /// [period]의 집계에 드는 것(거래 · 예산 · 분류)이 바뀌면 달라지는 표지.
  ///
  /// 총평을 다시 만들어야 하는지 알아보는 데 쓴다. 집계는 전달의 지출도 담으므로
  /// 전달의 거래까지 본다.
  Stream<String> watchDataStamp(String ledgerId, MonthPeriod period) => db
      .customSelect(
        '''
        SELECT
          (SELECT COUNT(*) || ':' || COALESCE(MAX(client_updated_at), '')
             FROM transactions
            WHERE ledger_id = ?1 AND occurred_on >= ?2 AND occurred_on < ?3)
          || '|' ||
          (SELECT COUNT(*) || ':' || COALESCE(MAX(client_updated_at), '')
             FROM budgets WHERE ledger_id = ?1 AND month = ?4)
          || '|' ||
          (SELECT COUNT(*) || ':' || COALESCE(MAX(client_updated_at), '')
             FROM categories WHERE ledger_id = ?1)
          AS stamp
        ''',
        variables: [
          Variable.withString(ledgerId),
          Variable.withString(period.previous.start.toString()),
          Variable.withString(period.endExclusive.toString()),
          Variable.withString(period.key),
        ],
        readsFrom: {db.ledgerTransactions, db.budgets, db.categories},
      )
      .watchSingle()
      .map((row) => row.read<String>('stamp'))
      .distinct();
}

final monthlySummaryRepositoryProvider = Provider<MonthlySummaryRepository>((
  ref,
) {
  final repository = ref.watch(repositoryProvider);
  return MonthlySummaryRepository(repository.db, repository.outbox);
});
