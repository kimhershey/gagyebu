/// 로그인한 계정의 가계부로 기기를 맞춘다.
///
/// 로그인 전에는 기기가 제 가계부(임의의 ID)를 만들어 쓴다. 서버는 가입할 때 계정의 가계부를
/// 만들고 기본 분류와 현금 자산을 넣어 둔다. 첫 로그인 때 둘을 하나로 합친다.
library;

import 'package:drift/drift.dart';

import '../db/database.dart';
import '../repositories/ledger_repository.dart';
import 'sync_engine.dart';

/// 이 기기에 다른 계정의 가계부가 있다. 섞지 않으려면 기기의 것을 지우고 받아야 한다.
class DifferentAccountException implements Exception {
  const DifferentAccountException();

  @override
  String toString() => '이 기기에는 다른 계정의 가계부가 있습니다';
}

class LedgerAdoption {
  LedgerAdoption({
    required this.db,
    required this.engine,
    required this.repository,
  });

  final AppDatabase db;
  final SyncEngine engine;
  final LedgerRepository repository;

  static const _ownerKey = 'owner_user_id';

  /// 이 기기의 가계부가 속한 계정. 로그인한 적이 없으면 null.
  Future<String?> owner() async {
    final row = await (db.select(
      db.syncState,
    )..where((s) => s.key.equals(_ownerKey))).getSingleOrNull();
    return row?.value;
  }

  /// [userId]의 서버 가계부 [serverLedgerId]를 이 기기의 가계부로 삼는다.
  ///
  /// - 이미 그 가계부를 쓰고 있으면 아무것도 하지 않는다.
  /// - 로그인한 적이 없는 기기면 로컬 가계부 [localLedgerId]의 내용을 서버 가계부로 옮긴다.
  ///   이름이 같은 기본 분류 · 자산은 서버 것으로 맞추고, 나머지는 새 행으로 올린다.
  /// - 다른 계정이 쓰던 기기면 [DifferentAccountException]을 던진다. [replaceLocal]이 true면
  ///   기기의 가계부를 지우고 받는다.
  ///
  /// 돌려주는 값은 가계부가 바뀌었는지다. 바뀌었으면 앱이 화면 상태를 새로 잡아야 한다.
  Future<bool> adopt({
    required String userId,
    required String serverLedgerId,
    required String localLedgerId,
    bool replaceLocal = false,
  }) async {
    final previous = await owner();
    if (previous != null && previous != userId) {
      if (!replaceLocal) throw const DifferentAccountException();
      await _wipe();
      await _setOwner(userId);
      await engine.pullChanges(serverLedgerId);
      return true;
    }
    if (localLedgerId == serverLedgerId) {
      await _setOwner(userId);
      return false;
    }

    // 서버 가계부를 먼저 받아 둔다. 이제 기기에는 두 가계부의 행이 함께 있다.
    await engine.pullChanges(serverLedgerId);
    final monthStartDay = await db.transaction(
      () => _merge(from: localLedgerId, into: serverLedgerId),
    );
    await _setOwner(userId);
    // 로컬에서 바꿔 둔 월 시작일을 계정으로 가져간다.
    if (monthStartDay != null && monthStartDay != 1) {
      final profile = await repository.profile(serverLedgerId);
      if (profile != null && profile.monthStartDay == 1) {
        await repository.setMonthStartDay(serverLedgerId, monthStartDay);
      }
    }
    return true;
  }

  /// [from] 가계부의 행을 [into] 가계부로 옮긴다. 옮기기 전의 월 시작일을 돌려준다.
  Future<int?> _merge({required String from, required String into}) async {
    Future<List<QueryRow>> rows(String sql, List<Object?> args) => db
        .customSelect(sql, variables: [for (final a in args) Variable(a)])
        .get();
    Future<void> run(String sql, List<Object?> args) =>
        db.customStatement(sql, args);

    final profile = await rows(
      'select month_start_day from profiles where ledger_id = ?',
      [from],
    );
    final monthStartDay = profile.isEmpty
        ? null
        : profile.first.read<int>('month_start_day');

    // 1) 이름과 종류가 같은 자산 · 분류는 서버 것을 쓴다. 가리키는 곳을 고치고 로컬 것은 지운다.
    Future<void> unify(String table, List<(String, String)> references) async {
      final pairs = await rows(
        'select l.id as local_id, '
        '  (select s.id from $table s where s.ledger_id = ? and s.deleted_at is null '
        '     and s.kind = l.kind and s.name = l.name order by s.created_at limit 1) as server_id '
        'from $table l where l.ledger_id = ?',
        [into, from],
      );
      for (final pair in pairs) {
        final serverId = pair.readNullable<String>('server_id');
        if (serverId == null) continue;
        final localId = pair.read<String>('local_id');
        for (final (refTable, column) in references) {
          await run('update $refTable set $column = ? where $column = ?', [
            serverId,
            localId,
          ]);
        }
        await run('delete from $table where id = ?', [localId]);
      }
    }

    await unify('accounts', const [
      ('transactions', 'account_id'),
      ('transactions', 'to_account_id'),
      ('accounts', 'payment_account_id'),
    ]);
    await unify('categories', const [
      ('transactions', 'category_id'),
      ('budgets', 'category_id'),
      ('category_rules', 'category_id'),
      ('categories', 'parent_id'),
    ]);

    // 2) 서버에 같은 것이 이미 있으면 서버 쪽을 따른다(다른 기기가 먼저 올린 경우).
    await run(
      'delete from category_rules where ledger_id = ? and pattern in '
      '(select pattern from category_rules where ledger_id = ? and deleted_at is null)',
      [from, into],
    );
    await run(
      'delete from budgets where ledger_id = ? and exists ('
      '  select 1 from budgets s where s.ledger_id = ? and s.deleted_at is null '
      '    and s.month = budgets.month and s.category_id is budgets.category_id)',
      [from, into],
    );
    // 월 요약은 거래에서 다시 만들 수 있다.
    await run('delete from monthly_summaries where ledger_id = ?', [from]);

    // 3) 남은 행을 서버 가계부로 옮기고, 새 행으로 올리도록 대기열에 넣는다.
    await run('delete from outbox where ledger_id = ?', [from]);
    for (final table in const [
      'accounts',
      'categories',
      'transactions',
      'budgets',
      'recurring_rules',
      'category_rules',
    ]) {
      await run(
        'insert into outbox (ledger_id, target_table, row_id, op, base_version, client_updated_at) '
        "select ?, ?, id, 'upsert', 0, client_updated_at from $table where ledger_id = ?",
        [into, table, from],
      );
      await run(
        'update $table set ledger_id = ?, version = 0 where ledger_id = ?',
        [into, from],
      );
    }

    // 4) 로컬 가계부의 껍데기를 지운다.
    await run('delete from profiles where ledger_id = ?', [from]);
    await run('delete from ledgers where id = ?', [from]);
    await run('delete from sync_conflicts where ledger_id = ?', [from]);
    await run("delete from sync_state where key like '%:' || ?", [from]);
    return monthStartDay;
  }

  /// 기기의 가계부와 동기화 상태를 모두 지운다. 기기 ID는 남긴다.
  Future<void> _wipe() => db.transaction(() async {
    for (final table in const [
      'monthly_summaries',
      'category_rules',
      'recurring_rules',
      'budgets',
      'transactions',
      'categories',
      'accounts',
      'profiles',
      'ledgers',
      'outbox',
      'sync_conflicts',
    ]) {
      await db.customStatement('delete from $table');
    }
    await db.customStatement("delete from sync_state where key <> 'device_id'");
  });

  Future<void> _setOwner(String userId) => db
      .into(db.syncState)
      .insertOnConflictUpdate(
        SyncStateCompanion.insert(key: _ownerKey, value: userId),
      );
}
