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
}
