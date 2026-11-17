import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gagyebu/core/local_date.dart';
import 'package:gagyebu/data/db/database.dart';
import 'package:gagyebu/data/repositories/ledger_repository.dart';
import 'package:gagyebu/domain/default_seed.dart';
import 'package:gagyebu/domain/enums.dart';
import 'package:gagyebu/domain/month_period.dart';

void main() {
  late AppDatabase db;
  late LedgerRepository repo;
  late String ledgerId;
  late String cashId;
  late Map<String, String> categoryIds;
  var now = DateTime.utc(2026, 11, 17, 3);

  setUp(() async {
    now = DateTime.utc(2026, 11, 17, 3);
    db = AppDatabase(NativeDatabase.memory());
    repo = LedgerRepository(db, clock: () => now);
    ledgerId = await repo.ensureLocalLedger();
    cashId = (await repo.accounts(ledgerId)).single.id;
    categoryIds = {
      for (final c in await repo.categories(ledgerId)) c.name: c.id,
    };
  });

  tearDown(() => db.close());

  TransactionInput expense(
    int amount,
    String party, {
    LocalDate? on,
    String? category,
    String? accountId,
    bool canceled = false,
  }) => TransactionInput(
    type: TxType.expense,
    occurredOn: on ?? LocalDate(2026, 11, 16),
    amount: amount,
    accountId: accountId ?? cashId,
    counterparty: party,
    categoryId: category == null ? null : categoryIds[category],
    canceled: canceled,
  );

  Future<List<OutboxRow>> outbox() => db.select(db.outbox).get();

  group('ensureLocalLedger', () {
    test('가계부, 기본 분류, 현금 자산, 프로필을 만든다', () async {
      final categories = await repo.categories(ledgerId);
      expect([
        for (final c in categories.where((c) => c.kind == CategoryKind.expense))
          c.name,
      ], defaultExpenseCategories);
      expect([
        for (final c in categories.where((c) => c.kind == CategoryKind.income))
          c.name,
      ], defaultIncomeCategories);
      final account = (await repo.accounts(ledgerId)).single;
      expect(account.name, defaultCashAccountName);
      expect(account.kind, AccountKind.cash);
      final profile = await repo.watchProfile(ledgerId).first;
      expect(profile!.defaultAccountId, account.id);
      expect(profile.monthStartDay, 1);
    });

    test('두 번 불러도 하나만 만든다', () async {
      expect(await repo.ensureLocalLedger(), ledgerId);
      expect(await db.select(db.ledgers).get(), hasLength(1));
      expect(await repo.categories(ledgerId), hasLength(16));
    });

    test('기본 데이터는 대기열에 올리지 않는다', () async {
      expect(await outbox(), isEmpty);
    });
  });

  group('거래', () {
    test('지출을 넣으면 받는 쪽이 상대방, 보낸 쪽이 내 자산이다', () async {
      final id = await repo.addTransaction(
        ledgerId,
        expense(12500, '김밥천국 강남점', category: '식비'),
      );
      final row = (await repo.transactionById(id))!;
      expect(row.type, TxType.expense);
      expect(row.amount, 12500);
      expect(row.receiver, '김밥천국 강남점');
      expect(row.sender, '현금');
      expect(row.version, 0);
      expect(row.dedupKey, '2026-11-16|12500|김밥천국강남점');
    });

    test('수입은 보낸 쪽이 상대방이다', () async {
      final id = await repo.addTransaction(
        ledgerId,
        TransactionInput(
          type: TxType.income,
          occurredOn: LocalDate(2026, 11, 10),
          amount: 3200000,
          accountId: cashId,
          counterparty: '(주)회사',
          categoryId: categoryIds['급여'],
        ),
      );
      final row = (await repo.transactionById(id))!;
      expect(row.sender, '(주)회사');
      expect(row.receiver, '현금');
    });

    test('이체는 두 자산 이름을 적고 분류를 비운다', () async {
      final bankId = await repo.addAccount(
        ledgerId: ledgerId,
        name: '급여통장',
        kind: AccountKind.bank,
        openingBalance: 1000000,
      );
      final id = await repo.addTransaction(
        ledgerId,
        TransactionInput(
          type: TxType.transfer,
          occurredOn: LocalDate(2026, 11, 15),
          amount: 200000,
          accountId: bankId,
          toAccountId: cashId,
          categoryId: categoryIds['식비'],
        ),
      );
      final row = (await repo.transactionById(id))!;
      expect(row.sender, '급여통장');
      expect(row.receiver, '현금');
      expect(row.categoryId, isNull);
    });

    test('잘못된 이체와 금액은 거절한다', () async {
      expect(
        repo.addTransaction(
          ledgerId,
          TransactionInput(
            type: TxType.transfer,
            occurredOn: LocalDate(2026, 11, 15),
            amount: 1000,
            accountId: cashId,
            toAccountId: cashId,
          ),
        ),
        throwsArgumentError,
      );
      expect(
        repo.addTransaction(ledgerId, expense(0, '무엇')),
        throwsArgumentError,
      );
      expect(
        repo.addTransaction(ledgerId, expense(100, '무엇', accountId: 'nope')),
        throwsArgumentError,
      );
    });

    test('목록은 최근 순이고 기간 밖은 빠진다', () async {
      await repo.addTransaction(
        ledgerId,
        expense(1000, '가', on: LocalDate(2026, 11, 1)),
      );
      await repo.addTransaction(
        ledgerId,
        expense(2000, '나', on: LocalDate(2026, 11, 30)),
      );
      await repo.addTransaction(
        ledgerId,
        expense(3000, '다', on: LocalDate(2026, 12, 1)),
      );
      await repo.addTransaction(
        ledgerId,
        expense(4000, '라', on: LocalDate(2026, 10, 31)),
      );
      final period = MonthPeriod(2026, 11);
      final list = await repo
          .watchTransactions(
            ledgerId,
            from: period.start,
            toExclusive: period.endExclusive,
          )
          .first;
      expect([for (final t in list) t.title], ['나', '가']);
      expect(list.first.accountName, '현금');
      expect(list.first.signedAmount, -2000);
    });

    test('검색은 상대방 · 메모 · 분류 이름을 본다', () async {
      await repo.addTransaction(
        ledgerId,
        expense(1000, '스타벅스', category: '카페·간식'),
      );
      await repo.addTransaction(
        ledgerId,
        expense(2000, '김밥천국', category: '식비'),
      );
      await repo.addTransaction(ledgerId, expense(3000, '100%_할인점'));
      Future<List<String>> search(String term) async {
        final list = await repo
            .watchTransactions(
              ledgerId,
              from: LocalDate(2026, 1, 1),
              toExclusive: LocalDate(2027, 1, 1),
              search: term,
            )
            .first;
        return [for (final t in list) t.title];
      }

      expect(await search('스타'), ['스타벅스']);
      expect(await search('식비'), ['김밥천국']);
      expect(await search('%'), ['100%_할인점']);
      expect(await search('_'), ['100%_할인점']);
      expect(await search('없는말'), isEmpty);
    });

    test('고치면 값이 바뀌고 삭제하면 목록에서 빠진다', () async {
      final id = await repo.addTransaction(ledgerId, expense(1000, '가'));
      await repo.updateTransaction(id, expense(1500, '가나다'));
      expect((await repo.transactionById(id))!.amount, 1500);
      expect((await repo.transactionById(id))!.receiver, '가나다');

      await repo.deleteTransaction(id);
      final list = await repo
          .watchTransactions(
            ledgerId,
            from: LocalDate(2026, 1, 1),
            toExclusive: LocalDate(2027, 1, 1),
          )
          .first;
      expect(list, isEmpty);
    });

    test('중복 후보를 찾는다', () async {
      await repo.addTransaction(ledgerId, expense(12500, '김밥천국 강남점'));
      expect(
        await repo.findPossibleDuplicates(
          ledgerId,
          date: LocalDate(2026, 11, 16),
          amount: 12500,
          counterparty: '김밥천국강남점',
        ),
        hasLength(1),
      );
      expect(
        await repo.findPossibleDuplicates(
          ledgerId,
          date: LocalDate(2026, 11, 16),
          amount: 12501,
          counterparty: '김밥천국 강남점',
        ),
        isEmpty,
      );
    });
  });

  group('변경 대기열', () {
    test('넣기와 고치기는 한 항목으로 합치고 처음 버전을 지킨다', () async {
      final id = await repo.addTransaction(ledgerId, expense(1000, '가'));
      now = now.add(const Duration(minutes: 1));
      await repo.updateTransaction(id, expense(2000, '가'));
      final entries = await outbox();
      expect(entries, hasLength(1));
      expect(entries.single.targetTable, 'transactions');
      expect(entries.single.rowId, id);
      expect(entries.single.op, 'upsert');
      expect(entries.single.baseVersion, 0);
      expect(entries.single.clientUpdatedAt, now);
    });

    test('서버에 올라간 적 없는 행을 지우면 흔적이 남지 않는다', () async {
      final id = await repo.addTransaction(ledgerId, expense(1000, '가'));
      await repo.deleteTransaction(id);
      expect(await outbox(), isEmpty);
      expect(await repo.transactionById(id), isNull);
    });

    test('서버에 올라간 행을 지우면 삭제 표시와 delete 항목이 남는다', () async {
      final id = await repo.addTransaction(ledgerId, expense(1000, '가'));
      // 동기화가 끝난 상태를 흉내 낸다.
      await db.delete(db.outbox).go();
      await db.customStatement(
        "UPDATE transactions SET version = 3, server_seq = 40 WHERE id = '$id'",
      );
      await repo.deleteTransaction(id);
      final entry = (await outbox()).single;
      expect(entry.op, 'delete');
      expect(entry.baseVersion, 3);
      expect((await repo.transactionById(id))!.deletedAt, isNotNull);
    });

    test('대기 중인 변경 수를 센다', () async {
      expect(await repo.watchPendingChangeCount().first, 0);
      await repo.addTransaction(ledgerId, expense(1000, '가'));
      await repo.addTransaction(ledgerId, expense(2000, '나'));
      expect(await repo.watchPendingChangeCount().first, 2);
    });
  });

  group('자산과 분류', () {
    test('잔액은 시작 잔액에 수입 · 지출 · 이체를 더한 값이다', () async {
      final bankId = await repo.addAccount(
        ledgerId: ledgerId,
        name: '급여통장',
        kind: AccountKind.bank,
        openingBalance: 1000000,
      );
      await repo.addTransaction(
        ledgerId,
        TransactionInput(
          type: TxType.income,
          occurredOn: LocalDate(2026, 11, 10),
          amount: 500000,
          accountId: bankId,
        ),
      );
      await repo.addTransaction(
        ledgerId,
        expense(30000, '마트', accountId: bankId),
      );
      await repo.addTransaction(
        ledgerId,
        expense(99999, '취소된 결제', accountId: bankId, canceled: true),
      );
      await repo.addTransaction(
        ledgerId,
        TransactionInput(
          type: TxType.transfer,
          occurredOn: LocalDate(2026, 11, 15),
          amount: 200000,
          accountId: bankId,
          toAccountId: cashId,
        ),
      );
      final balances = await repo.watchAccountBalances(ledgerId).first;
      final byName = {for (final b in balances) b.account.name: b.balance};
      expect(byName['급여통장'], 1000000 + 500000 - 30000 - 200000);
      expect(byName['현금'], 200000);
    });

    test('거래가 있는 자산은 지울 수 없다', () async {
      await repo.addTransaction(ledgerId, expense(1000, '가'));
      expect(repo.deleteAccount(cashId), throwsStateError);
    });

    test('분류를 지우면 그 분류의 거래는 분류 없음이 된다', () async {
      final id = await repo.addTransaction(
        ledgerId,
        expense(1000, '가', category: '식비'),
      );
      await repo.deleteCategory(categoryIds['식비']!);
      expect((await repo.transactionById(id))!.categoryId, isNull);
      expect(
        (await repo.categories(ledgerId)).map((c) => c.name),
        isNot(contains('식비')),
      );
    });

    test('새 분류는 같은 종류의 맨 뒤에 놓인다', () async {
      await repo.addCategory(
        ledgerId: ledgerId,
        kind: CategoryKind.expense,
        name: '반려동물',
      );
      final names = [
        for (final c in await repo.categories(ledgerId))
          if (c.kind == CategoryKind.expense) c.name,
      ];
      expect(names.last, '반려동물');
    });
  });

  group('분류 규칙', () {
    test('사용자가 고른 분류를 기억한다', () async {
      await repo.rememberCategory(ledgerId, '세븐일레븐 가평목동', categoryIds['생활']!);
      expect(
        await repo.categoryForCounterparty(ledgerId, '세븐일레븐가평목동'),
        categoryIds['생활'],
      );
    });
    test('잘린 가맹점 이름은 앞부분 일치로 찾는다', () async {
      await repo.rememberCategory(ledgerId, '세븐일레븐영등포점', categoryIds['생활']!);
      expect(
        await repo.categoryForCounterparty(ledgerId, '세븐일레븐영'),
        categoryIds['생활'],
      );
      expect(await repo.categoryForCounterparty(ledgerId, '세븐'), isNull);
    });
    test('다시 고르면 분류를 바꾸고 횟수를 올린다', () async {
      await repo.rememberCategory(ledgerId, '쿠팡', categoryIds['쇼핑']!);
      await repo.rememberCategory(ledgerId, '쿠팡', categoryIds['생활']!);
      final rule = (await db.select(db.categoryRules).get()).single;
      expect(rule.categoryId, categoryIds['생활']);
      expect(rule.hitCount, 2);
    });
  });

  group('월 집계', () {
    final today = LocalDate(2026, 11, 17);
    final period = MonthPeriod(2026, 11);

    setUp(() async {
      await repo.addTransaction(
        ledgerId,
        TransactionInput(
          type: TxType.income,
          occurredOn: LocalDate(2026, 11, 10),
          amount: 3000000,
          accountId: cashId,
          counterparty: '(주)회사',
          categoryId: categoryIds['급여'],
        ),
      );
      await repo.addTransaction(
        ledgerId,
        expense(12000, '김밥천국', on: LocalDate(2026, 11, 3), category: '식비'),
      );
      await repo.addTransaction(
        ledgerId,
        expense(8000, '김밥천국', on: LocalDate(2026, 11, 5), category: '식비'),
      );
      await repo.addTransaction(
        ledgerId,
        expense(50000, '쿠팡', on: LocalDate(2026, 11, 5), category: '쇼핑'),
      );
      await repo.addTransaction(
        ledgerId,
        expense(70000, '취소된 결제', on: LocalDate(2026, 11, 6), canceled: true),
      );
      await repo.addTransaction(
        ledgerId,
        expense(4500, '분류없는가게', on: LocalDate(2026, 11, 16)),
      );
      // 지난달
      await repo.addTransaction(
        ledgerId,
        expense(40000, '지난달 가게', on: LocalDate(2026, 10, 20), category: '식비'),
      );
    });

    test('수입 · 지출 · 수지와 직전 기간', () async {
      final s = await repo.monthSummary(ledgerId, period, today: today);
      expect(s.income, 3000000);
      expect(s.expense, 12000 + 8000 + 50000 + 4500);
      expect(s.net, 3000000 - 74500);
      expect(s.previousExpense, 40000);
      expect(s.previousIncome, 0);
      expect(s.expenseChange, 34500);
      expect(s.transactionCount, 5);
    });

    test('분류별 합계는 큰 순서이고 분류 없음을 포함한다', () async {
      final s = await repo.monthSummary(ledgerId, period, today: today);
      expect(
        [for (final c in s.byCategory) (c.name, c.amount)],
        [('쇼핑', 50000), ('식비', 20000), ('분류 없음', 4500)],
      );
      expect(
        s.byCategory.fold<int>(0, (sum, c) => sum + c.amount),
        s.expense,
        reason: '분류별 합계의 합은 총지출과 같다',
      );
    });

    test('상대방 순위와 큰 지출', () async {
      final s = await repo.monthSummary(ledgerId, period, today: today);
      expect(s.topCounterparties.first.name, '쿠팡');
      expect(s.topCounterparties[1].name, '김밥천국');
      expect(s.topCounterparties[1].amount, 20000);
      expect(s.topCounterparties[1].count, 2);
      expect(s.largestExpenses.first.amount, 50000);
      expect(s.largestExpenses.map((e) => e.name), isNot(contains('취소된 결제')));
    });

    test('무지출 일수와 일평균은 오늘까지 지난 날로 계산한다', () async {
      final s = await repo.monthSummary(ledgerId, period, today: today);
      expect(s.elapsedDays, 17);
      // 지출이 있던 날: 3일, 5일, 16일
      expect(s.noSpendDays, 14);
      expect(s.dailyAverageExpense, (74500 / 17).round());
    });

    test('지난 기간은 전체 일수로 계산한다', () async {
      final s = await repo.monthSummary(
        ledgerId,
        period.previous,
        today: today,
      );
      expect(s.elapsedDays, 31);
      expect(s.noSpendDays, 30);
      expect(s.expense, 40000);
    });

    test('집계 JSON의 숫자는 집계 값과 같다', () async {
      final s = await repo.monthSummary(ledgerId, period, today: today);
      final json = s.toStatsJson();
      expect(json['income'], s.income);
      expect(json['expense'], s.expense);
      expect(json['net'], s.net);
      expect((json['by_category'] as List).length, 3);
    });

    test('거래가 바뀌면 집계가 다시 흘러나온다', () async {
      final expenses = <int>[];
      final subscription = repo
          .watchMonthSummary(ledgerId, period, today: today)
          .listen((s) => expenses.add(s.expense));
      await pumpEventQueue();
      expect(expenses.last, 74500);

      await repo.addTransaction(
        ledgerId,
        expense(1000, '추가', on: LocalDate(2026, 11, 17)),
      );
      await pumpEventQueue();
      expect(expenses.last, 75500);
      await subscription.cancel();
    });
  });

  test('월 시작일을 바꾸면 프로필과 대기열에 반영된다', () async {
    await repo.setMonthStartDay(ledgerId, 25);
    expect((await repo.watchProfile(ledgerId).first)!.monthStartDay, 25);
    expect((await outbox()).single.targetTable, 'profiles');
    expect(repo.setMonthStartDay(ledgerId, 31), throwsArgumentError);
  });
}
