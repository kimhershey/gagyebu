import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gagyebu/data/db/database.dart';
import 'package:gagyebu/data/repositories/budget_repository.dart';
import 'package:gagyebu/data/repositories/ledger_repository.dart';

void main() {
  late AppDatabase db;
  late LedgerRepository ledger;
  late BudgetRepository budgets;
  late String ledgerId;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    ledger = LedgerRepository(db);
    budgets = BudgetRepository(db, ledger.outbox);
    ledgerId = await ledger.ensureLocalLedger();
  });
  tearDown(() => db.close());

  test('전체 예산과 분류 예산을 정하고 고치면 대기열에 한 줄씩 올라간다', () async {
    final food = (await ledger.categories(ledgerId)).first.id;
    await budgets.setBudget(
      ledgerId,
      month: '2026-11',
      categoryId: null,
      amount: 1000000,
    );
    await budgets.setBudget(
      ledgerId,
      month: '2026-11',
      categoryId: food,
      amount: 300000,
    );
    await budgets.setBudget(
      ledgerId,
      month: '2026-11',
      categoryId: null,
      amount: 1200000,
    );

    final rows = await budgets.watchBudgets(ledgerId, '2026-11').first;
    expect(rows, hasLength(2));
    expect(rows.firstWhere((r) => r.categoryId == null).amount, 1200000);
    expect(rows.firstWhere((r) => r.categoryId == food).amount, 300000);
    expect(await budgets.watchBudgets(ledgerId, '2026-12').first, isEmpty);

    final queued = await (db.select(
      db.outbox,
    )..where((o) => o.targetTable.equals('budgets'))).get();
    expect(queued, hasLength(2));
    expect(queued.every((o) => o.op == 'upsert'), isTrue);
  });

  test('음수 예산은 받지 않는다', () {
    expect(
      budgets.setBudget(
        ledgerId,
        month: '2026-11',
        categoryId: null,
        amount: -1,
      ),
      throwsArgumentError,
    );
  });

  /// 다른 기기가 만든 행이 동기화로 들어온 것처럼 직접 넣는다.
  Future<void> insertSynced(
    String id, {
    required String month,
    required String? categoryId,
    required int amount,
    required DateTime at,
    int version = 1,
  }) => db
      .into(db.budgets)
      .insert(
        BudgetsCompanion.insert(
          id: id,
          ledgerId: ledgerId,
          month: month,
          categoryId: Value(categoryId),
          amount: amount,
          version: Value(version),
          clientUpdatedAt: at,
          createdAt: at,
          updatedAt: at,
        ),
      );

  Future<List<OutboxRow>> queued() => (db.select(
    db.outbox,
  )..where((o) => o.targetTable.equals('budgets'))).get();

  Future<BudgetRow> row(String id) =>
      (db.select(db.budgets)..where((b) => b.id.equals(id))).getSingle();

  group('같은 달 · 같은 분류의 행이 겹칠 때', () {
    late String food;

    setUp(() async {
      food = (await ledger.categories(ledgerId)).first.id;
      // 두 기기가 같은 달의 전체 예산과 식비 예산을 따로 만들었다.
      await insertSynced(
        'total-old',
        month: '2026-11',
        categoryId: null,
        amount: 900000,
        at: DateTime.utc(2026, 11, 1, 9),
      );
      await insertSynced(
        'total-new',
        month: '2026-11',
        categoryId: null,
        amount: 1100000,
        at: DateTime.utc(2026, 11, 2, 9),
        version: 3,
      );
      await insertSynced(
        'food-new',
        month: '2026-11',
        categoryId: food,
        amount: 400000,
        at: DateTime.utc(2026, 11, 5),
      );
      await insertSynced(
        'food-old',
        month: '2026-11',
        categoryId: food,
        amount: 250000,
        at: DateTime.utc(2026, 11, 3),
        version: 2,
      );
      // 다른 달의 행은 겹친 것이 아니다.
      await insertSynced(
        'october',
        month: '2026-10',
        categoryId: null,
        amount: 800000,
        at: DateTime.utc(2026, 10, 1),
      );
    });

    test('나중에 고친 행을 쓴다', () async {
      final rows = await budgets.watchBudgets(ledgerId, '2026-11').first;
      expect({for (final r in rows) r.id}, {'total-new', 'food-new'});
      expect(await budgets.budgets(ledgerId, '2026-11'), hasLength(2));
    });

    test('고친 때가 같으면 ID가 큰 행을 쓴다(어느 기기에서나 같은 행)', () async {
      final at = DateTime.utc(2026, 12, 1);
      await insertSynced(
        'b',
        month: '2026-12',
        categoryId: null,
        amount: 2,
        at: at,
      );
      await insertSynced(
        'a',
        month: '2026-12',
        categoryId: null,
        amount: 1,
        at: at,
      );
      final rows = await budgets.watchBudgets(ledgerId, '2026-12').first;
      expect(rows.single.id, 'b');
    });

    test('정리하면 나머지를 삭제 표시하고 대기열에 올린다', () async {
      expect(await budgets.cleanDuplicates(ledgerId, month: '2026-11'), 2);

      expect((await row('total-old')).deletedAt, isNotNull);
      expect((await row('food-old')).deletedAt, isNotNull);
      expect((await row('total-new')).deletedAt, isNull);
      expect((await row('food-new')).deletedAt, isNull);
      expect((await row('october')).deletedAt, isNull);

      final entries = {for (final e in await queued()) e.rowId: e};
      expect(entries.keys, {'total-old', 'food-old'});
      expect(entries.values.every((e) => e.op == 'delete'), isTrue);
      expect(entries['food-old']!.baseVersion, 2);

      // 다시 돌려도 더 지울 것이 없다.
      expect(await budgets.cleanDuplicates(ledgerId), 0);
    });

    test('고치면 고른 행이 바뀌고, 지우면 겹친 행이 모두 사라진다', () async {
      await budgets.setBudget(
        ledgerId,
        month: '2026-11',
        categoryId: null,
        amount: 1500000,
      );
      expect((await row('total-new')).amount, 1500000);
      expect((await row('total-old')).amount, 900000);
      final entry = (await queued()).single;
      expect(entry.rowId, 'total-new');
      expect(entry.baseVersion, 3);

      await budgets.deleteBudget(ledgerId, month: '2026-11', categoryId: food);
      final rows = await budgets.watchBudgets(ledgerId, '2026-11').first;
      expect(rows.single.categoryId, isNull);
      expect((await row('food-new')).deletedAt, isNotNull);
      expect((await row('food-old')).deletedAt, isNotNull);
    });
  });

  group('지난달 예산 가져오기', () {
    test('없는 것만 복사하고 이미 정한 것은 건드리지 않는다', () async {
      final all = await ledger.categories(ledgerId);
      final food = all[0].id, cafe = all[1].id, gone = all[2].id;
      for (final (category, amount) in [
        (null, 1000000),
        (food, 300000),
        (cafe, 80000),
        (gone, 50000),
      ]) {
        await budgets.setBudget(
          ledgerId,
          month: '2026-12',
          categoryId: category,
          amount: amount,
        );
      }
      // 새 달에 식비만 먼저 정해 두었고, 분류 하나는 그사이 지웠다.
      await budgets.setBudget(
        ledgerId,
        month: '2027-01',
        categoryId: food,
        amount: 350000,
      );
      await ledger.deleteCategory(gone);
      await db.delete(db.outbox).go();

      // 1월의 앞 달은 지난해 12월이다.
      expect(await budgets.copyFromPreviousMonth(ledgerId, '2027-01'), 2);

      final rows = await budgets.watchBudgets(ledgerId, '2027-01').first;
      expect(
        {for (final r in rows) r.categoryId: r.amount},
        {null: 1000000, food: 350000, cafe: 80000},
      );
      final entries = await queued();
      expect(entries, hasLength(2));
      expect(
        entries.every((e) => e.op == 'upsert' && e.baseVersion == 0),
        isTrue,
      );

      // 한 번 더 눌러도 늘지 않는다.
      expect(await budgets.copyFromPreviousMonth(ledgerId, '2027-01'), 0);
    });

    test('앞 달에 예산이 없으면 아무것도 하지 않는다', () async {
      expect(await budgets.copyFromPreviousMonth(ledgerId, '2026-11'), 0);
      expect(await queued(), isEmpty);
    });

    test('앞 달 계산', () {
      expect(BudgetRepository.previousMonth('2026-11'), '2026-10');
      expect(BudgetRepository.previousMonth('2026-01'), '2025-12');
      expect(
        () => BudgetRepository.previousMonth('2026-1'),
        throwsFormatException,
      );
    });
  });
}
