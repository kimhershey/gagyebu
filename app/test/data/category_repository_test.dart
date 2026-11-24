import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gagyebu/core/local_date.dart';
import 'package:gagyebu/data/db/database.dart';
import 'package:gagyebu/data/repositories/category_repository.dart';
import 'package:gagyebu/data/repositories/ledger_repository.dart';
import 'package:gagyebu/domain/enums.dart';

void main() {
  late AppDatabase db;
  late LedgerRepository ledger;
  late CategoryRepository categories;
  late String ledgerId;
  var now = DateTime.utc(2026, 11, 17, 3);

  setUp(() async {
    now = DateTime.utc(2026, 11, 17, 3);
    db = AppDatabase(NativeDatabase.memory());
    ledger = LedgerRepository(db, clock: () => now);
    categories = CategoryRepository(ledger);
    ledgerId = await ledger.ensureLocalLedger();
  });
  tearDown(() => db.close());

  Future<CategoryRow> row(String id) =>
      (db.select(db.categories)..where((c) => c.id.equals(id))).getSingle();

  Future<List<OutboxRow>> queued([String table = 'categories']) =>
      (db.select(db.outbox)..where((o) => o.targetTable.equals(table))).get();

  /// 서버에 올라간 적이 있는 행처럼 만든다.
  Future<void> markSynced(String id, int version) =>
      (db.update(db.categories)..where((c) => c.id.equals(id))).write(
        CategoriesCompanion(version: Value(version)),
      );

  Future<String> add(
    String name, {
    CategoryKind kind = CategoryKind.expense,
    String? parentId,
  }) => ledger.addCategory(
    ledgerId: ledgerId,
    kind: kind,
    name: name,
    parentId: parentId,
  );

  Future<List<CategoryRow>> expenses() async => [
    for (final c in await ledger.categories(ledgerId))
      if (c.kind == CategoryKind.expense) c,
  ];

  test('이름과 아이콘을 고치면 그 행의 판 번호로 대기열에 올라간다', () async {
    final food = (await expenses()).first;
    await markSynced(food.id, 7);

    now = DateTime.utc(2026, 11, 18);
    await categories.updateCategory(food.id, name: ' 먹는 것 ', icon: 'grocery');

    final saved = await row(food.id);
    expect(saved.name, '먹는 것');
    expect(saved.icon, 'grocery');
    expect(saved.clientUpdatedAt, now);
    expect(saved.updatedAt, now);
    final entry = (await queued()).single;
    expect(entry.rowId, food.id);
    expect(entry.op, 'upsert');
    expect(entry.baseVersion, 7);

    // 아이콘을 비우면 기본 아이콘으로 돌아간다.
    await categories.updateCategory(food.id, name: '먹는 것', icon: null);
    expect((await row(food.id)).icon, isNull);
    expect(await queued(), hasLength(1), reason: '같은 행의 변경은 한 줄로 합친다');

    await expectLater(
      categories.updateCategory(food.id, name: ' ', icon: null),
      throwsArgumentError,
    );
    await expectLater(
      categories.updateCategory('missing', name: '이름', icon: null),
      throwsStateError,
    );
  });

  test('순서를 바꾸면 옮긴 줄만 가운데 값으로 고쳐 올린다', () async {
    final list = await expenses();
    final ids = [for (final c in list) c.id];
    // 맨 뒤의 분류를 둘째 자리로
    final moved = ids.removeLast();
    ids.insert(1, moved);
    await markSynced(moved, 3);

    expect(await categories.reorderCategories(ledgerId, ids), 1);
    expect((await row(moved)).sortOrder, 15);
    final entry = (await queued()).single;
    expect(entry.rowId, moved);
    expect(entry.baseVersion, 3);
    expect([for (final c in await expenses()) c.id], ids);

    // 같은 자리에 또 끼우면 12, 11을 거쳐 자리가 없어지고, 그때 전체를 다시 매긴다.
    for (var i = 0; i < 3; i++) {
      final last = ids.removeLast();
      ids.insert(1, last);
      await categories.reorderCategories(ledgerId, ids);
    }
    final saved = await expenses();
    expect([for (final c in saved) c.id], ids);
    expect(
      [for (final c in saved) c.sortOrder],
      [for (var i = 1; i <= ids.length; i++) i * 10],
    );
  });

  group('setParent', () {
    test('대분류 아래에 두고 다시 뺀다', () async {
      final list = await expenses();
      final food = list[0].id, cafe = list[1].id;
      await categories.setParent(cafe, food);
      expect((await row(cafe)).parentId, food);
      expect((await queued()).single.rowId, cafe);

      await categories.setParent(cafe, null);
      expect((await row(cafe)).parentId, isNull);
    });

    test('한 단계만 둔다', () async {
      final list = await expenses();
      final food = list[0].id, cafe = list[1].id, transit = list[2].id;
      final income = (await ledger.categories(ledgerId))
          .firstWhere((c) => c.kind == CategoryKind.income)
          .id;
      await categories.setParent(cafe, food);
      await db.delete(db.outbox).go();

      // 소분류 아래에는 둘 수 없다.
      await expectLater(
        categories.setParent(transit, cafe),
        throwsArgumentError,
      );
      // 소분류가 있는 분류는 다른 분류 아래로 갈 수 없다.
      await expectLater(
        categories.setParent(food, transit),
        throwsArgumentError,
      );
      // 자기 자신, 다른 종류
      await expectLater(
        categories.setParent(transit, transit),
        throwsArgumentError,
      );
      await expectLater(
        categories.setParent(transit, income),
        throwsArgumentError,
      );
      expect(await queued(), isEmpty);
    });
  });

  group('deleteCategory', () {
    test('소분류가 있는 대분류를 지우면 소분류는 대분류 없는 분류가 된다', () async {
      final food = (await expenses()).first.id;
      final lunch = await add('점심', parentId: food);
      final dinner = await add('저녁', parentId: food);
      // 서버에 올라간 행으로 만든다(올라간 적이 없는 행은 흔적 없이 지워진다).
      for (final id in [food, lunch, dinner]) {
        await markSynced(id, 1);
      }
      await db.delete(db.outbox).go();

      now = DateTime.utc(2026, 11, 19);
      await categories.deleteCategory(food);

      expect((await row(food)).deletedAt, isNotNull);
      for (final id in [lunch, dinner]) {
        final child = await row(id);
        expect(child.parentId, isNull);
        expect(child.deletedAt, isNull);
        expect(child.clientUpdatedAt, now);
      }
      final ops = {for (final entry in await queued()) entry.rowId: entry.op};
      expect(ops, {food: 'delete', lunch: 'upsert', dinner: 'upsert'});

      final names = [for (final c in await expenses()) c.name];
      expect(names, isNot(contains('식비')));
      expect(names, containsAll(['점심', '저녁']));
    });

    test('그 분류를 쓰던 거래는 분류 없음이 된다', () async {
      final food = (await expenses()).first.id;
      final lunch = await add('점심', parentId: food);
      final account = (await ledger.accounts(ledgerId)).single.id;
      final txId = await ledger.addTransaction(
        ledgerId,
        TransactionInput(
          type: TxType.expense,
          occurredOn: LocalDate(2026, 11, 17),
          amount: 9000,
          accountId: account,
          categoryId: lunch,
        ),
      );

      await categories.deleteCategory(lunch);

      expect((await ledger.transactionById(txId))!.categoryId, isNull);
      expect((await queued('transactions')).single.rowId, txId);
      expect((await row(food)).deletedAt, isNull);
    });
  });
}
