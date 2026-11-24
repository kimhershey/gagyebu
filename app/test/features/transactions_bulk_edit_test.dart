import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gagyebu/core/local_date.dart';
import 'package:gagyebu/data/db/database.dart';
import 'package:gagyebu/data/repositories/ledger_repository.dart';
import 'package:gagyebu/domain/enums.dart';
import 'package:gagyebu/features/transactions/bulk_edit.dart';

void main() {
  late AppDatabase db;
  late LedgerRepository repo;
  late String ledgerId;
  late String cashId;
  late String bankId;
  late List<CategoryRow> categories;
  var now = DateTime.utc(2026, 11, 17, 3);

  CategoryRow category(String name) =>
      categories.firstWhere((c) => c.name == name);

  Future<TxRow> row(String id) async => (await repo.transactionById(id))!;

  Future<List<OutboxRow>> outbox() => db.select(db.outbox).get();

  /// 서버에 올라간 것처럼 대기열을 비운다. 그 뒤의 변경만 남게 한다.
  Future<void> clearOutbox() => db.delete(db.outbox).go();

  setUp(() async {
    now = DateTime.utc(2026, 11, 17, 3);
    db = AppDatabase(NativeDatabase.memory());
    repo = LedgerRepository(db, clock: () => now);
    ledgerId = await repo.ensureLocalLedger();
    cashId = (await repo.accounts(ledgerId)).single.id;
    bankId = await repo.addAccount(
      ledgerId: ledgerId,
      name: '월급 통장',
      kind: AccountKind.bank,
    );
    categories = await repo.categories(ledgerId);
  });

  tearDown(() => db.close());

  Future<String> add(
    TxType type,
    int amount, {
    String? party,
    String? categoryName,
    String? toAccount,
    String? time,
    String? memo,
    int? installmentMonths,
    bool canceled = false,
    TxStatus status = TxStatus.confirmed,
    TxSource source = TxSource.manual,
  }) => repo.addTransaction(
    ledgerId,
    TransactionInput(
      type: type,
      occurredOn: LocalDate(2026, 11, 16),
      occurredTime: time,
      amount: amount,
      accountId: cashId,
      toAccountId: toAccount,
      counterparty: party,
      categoryId: categoryName == null ? null : category(categoryName).id,
      memo: memo,
      installmentMonths: installmentMonths,
      canceled: canceled,
      status: status,
      source: source,
    ),
  );

  test('inputFromRow는 바꾸지 않은 값을 그대로 옮긴다', () async {
    final id = await add(
      TxType.expense,
      120000,
      party: '가전 매장',
      categoryName: '쇼핑',
      time: '18:20',
      memo: '청소기',
      installmentMonths: 3,
      status: TxStatus.needsReview,
      source: TxSource.paste,
    );
    final before = await row(id);
    now = now.add(const Duration(minutes: 5));
    await repo.updateTransaction(id, inputFromRow(before));
    final after = await row(id);

    expect(after.type, before.type);
    expect(after.occurredOn, before.occurredOn);
    expect(after.occurredTime, '18:20');
    expect(after.amount, 120000);
    expect(after.accountId, cashId);
    expect(after.receiver, '가전 매장');
    expect(after.sender, before.sender);
    expect(after.categoryId, category('쇼핑').id);
    expect(after.memo, '청소기');
    expect(after.installmentMonths, 3);
    expect(after.source, TxSource.paste);
    expect(after.status, TxStatus.needsReview);
    expect(after.canceledAt, isNull);
    expect(after.dedupKey, before.dedupKey);
  });

  test('inputFromRow는 수입의 보낸 쪽과 취소 여부를 지킨다', () async {
    final incomeId = await add(TxType.income, 50000, party: '친구');
    final canceledId = await add(
      TxType.expense,
      9000,
      party: '식당',
      canceled: true,
    );
    await repo.updateTransaction(
      incomeId,
      inputFromRow(await row(incomeId), accountId: bankId),
    );
    await repo.updateTransaction(
      canceledId,
      inputFromRow(await row(canceledId), categoryId: () => null),
    );
    final income = await row(incomeId);
    expect(income.sender, '친구');
    expect(income.receiver, '월급 통장');
    expect(income.accountId, bankId);
    expect((await row(canceledId)).canceledAt, isNotNull);
  });

  group('bulkSetCategory', () {
    test('종류가 맞는 거래만 바꾸고 행마다 대기열에 올린다', () async {
      final lunch = await add(TxType.expense, 9000, party: '식당');
      final cafe = await add(
        TxType.expense,
        5500,
        party: '카페',
        categoryName: '카페·간식',
      );
      final pay = await add(TxType.income, 3000000, categoryName: '급여');
      final move = await add(TxType.transfer, 100000, toAccount: bankId);
      await clearOutbox();

      final rows = [
        for (final id in [lunch, cafe, pay, move]) await row(id),
      ];
      final result = await bulkSetCategory(repo, rows, category('식비'));

      expect(result.done, 2);
      expect(result.skipped, 2);
      expect((await row(lunch)).categoryId, category('식비').id);
      expect((await row(cafe)).categoryId, category('식비').id);
      expect((await row(pay)).categoryId, category('급여').id);
      expect((await row(move)).categoryId, isNull);
      expect({for (final o in await outbox()) o.rowId}, {lunch, cafe});
      expect((await outbox()).every((o) => o.op == 'upsert'), isTrue);
    });

    test('분류 없음으로 바꾼다', () async {
      final cafe = await add(TxType.expense, 5500, categoryName: '카페·간식');
      final pay = await add(TxType.income, 3000000, categoryName: '급여');
      final result = await bulkSetCategory(repo, [
        await row(cafe),
        await row(pay),
      ], null);
      expect(result.done, 2);
      expect(result.skipped, 0);
      expect((await row(cafe)).categoryId, isNull);
      expect((await row(pay)).categoryId, isNull);
    });

    test('이미 그 분류인 거래는 다시 쓰지 않는다', () async {
      final cafe = await add(TxType.expense, 5500, categoryName: '카페·간식');
      await clearOutbox();
      final result = await bulkSetCategory(repo, [
        await row(cafe),
      ], category('카페·간식'));
      expect(result.done, 1);
      expect(await outbox(), isEmpty);
    });
  });

  group('bulkSetAccount', () {
    test('자산을 바꾸고, 받는 자산이 같은 이체는 그대로 둔다', () async {
      final lunch = await add(TxType.expense, 9000, party: '식당');
      final pay = await add(TxType.income, 3000000, party: '회사');
      final move = await add(TxType.transfer, 100000, toAccount: bankId);
      await clearOutbox();

      final result = await bulkSetAccount(repo, [
        for (final id in [lunch, pay, move]) await row(id),
      ], bankId);

      expect(result.done, 2);
      expect(result.skipped, 1);
      final expense = await row(lunch);
      expect(expense.accountId, bankId);
      // 지출의 보낸 쪽은 자산 이름이다.
      expect(expense.sender, '월급 통장');
      expect(expense.receiver, '식당');
      expect((await row(pay)).accountId, bankId);
      final transfer = await row(move);
      expect(transfer.accountId, cashId);
      expect(transfer.toAccountId, bankId);
      expect({for (final o in await outbox()) o.rowId}, {lunch, pay});
    });

    test('이체는 보내는 자산을 바꾼다', () async {
      final cardId = await repo.addAccount(
        ledgerId: ledgerId,
        name: '카드',
        kind: AccountKind.creditCard,
      );
      final move = await add(TxType.transfer, 100000, toAccount: cardId);
      final result = await bulkSetAccount(repo, [await row(move)], bankId);
      expect(result.done, 1);
      final transfer = await row(move);
      expect(transfer.accountId, bankId);
      expect(transfer.toAccountId, cardId);
    });
  });

  test('bulkConfirm은 확인이 필요한 거래만 확인한 것으로 바꾼다', () async {
    final a = await add(TxType.expense, 9000, status: TxStatus.needsReview);
    final b = await add(TxType.expense, 5500);
    await clearOutbox();
    final done = await bulkConfirm(repo, [await row(a), await row(b)]);
    expect(done, 1);
    expect((await row(a)).status, TxStatus.confirmed);
    expect({for (final o in await outbox()) o.rowId}, {a});
  });

  test('bulkDelete는 행마다 지운다', () async {
    final a = await add(TxType.expense, 9000);
    final b = await add(TxType.expense, 5500);
    final keep = await add(TxType.expense, 1000);
    final done = await bulkDelete(repo, [await row(a), await row(b)]);
    expect(done, 2);
    // 서버에 올린 적이 없는 거래는 흔적 없이 지워진다.
    expect(await repo.transactionById(a), isNull);
    expect(await repo.transactionById(b), isNull);
    expect(await repo.transactionById(keep), isNotNull);
  });
}
