import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gagyebu/core/local_date.dart';
import 'package:gagyebu/data/db/database.dart';
import 'package:gagyebu/data/repositories/budget_repository.dart';
import 'package:gagyebu/data/repositories/ledger_repository.dart';
import 'package:gagyebu/data/repositories/summary_repository.dart';
import 'package:gagyebu/domain/enums.dart';
import 'package:gagyebu/domain/month_period.dart';
import 'package:gagyebu/domain/month_summary.dart';

void main() {
  late AppDatabase db;
  late LedgerRepository ledger;
  late SummaryRepository summaries;
  late BudgetRepository budgets;
  late String ledgerId;
  late String cashId;
  late Map<String, String> categoryIds;
  final now = DateTime.utc(2026, 11, 17, 3);
  final today = LocalDate(2026, 11, 17);
  final november = MonthPeriod(2026, 11);

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    ledger = LedgerRepository(db, clock: () => now);
    summaries = SummaryRepository(ledger);
    budgets = BudgetRepository(db, ledger.outbox);
    ledgerId = await ledger.ensureLocalLedger();
    cashId = (await ledger.accounts(ledgerId)).single.id;
    categoryIds = {
      for (final c in await ledger.categories(ledgerId)) c.name: c.id,
    };
  });

  tearDown(() => db.close());

  Future<String> add(
    int amount,
    LocalDate on, {
    TxType type = TxType.expense,
    String? party,
    String? category,
    TxSource source = TxSource.manual,
    TxStatus status = TxStatus.confirmed,
    bool canceled = false,
  }) => ledger.addTransaction(
    ledgerId,
    TransactionInput(
      type: type,
      occurredOn: on,
      amount: amount,
      accountId: cashId,
      counterparty: party,
      categoryId: category == null ? null : categoryIds[category],
      source: source,
      status: status,
      canceled: canceled,
    ),
  );

  group('고정 지출', () {
    test('반복 거래가 만든 지출만 더한다', () async {
      await add(550000, LocalDate(2026, 11, 1), source: TxSource.recurring);
      await add(17000, LocalDate(2026, 11, 5), source: TxSource.recurring);
      await add(12000, LocalDate(2026, 11, 3)); // 직접 입력
      // 반복 거래가 만든 수입은 지출이 아니다.
      await add(
        3000000,
        LocalDate(2026, 11, 10),
        type: TxType.income,
        source: TxSource.recurring,
      );
      // 취소된 것, 지운 것, 다른 달의 것은 뺀다.
      await add(
        9900,
        LocalDate(2026, 11, 6),
        source: TxSource.recurring,
        canceled: true,
      );
      final deleted = await add(
        8800,
        LocalDate(2026, 11, 7),
        source: TxSource.recurring,
      );
      await ledger.deleteTransaction(deleted);
      await add(550000, LocalDate(2026, 10, 1), source: TxSource.recurring);

      expect(await summaries.fixedExpense(ledgerId, november), 567000);
      expect(await summaries.fixedExpense(ledgerId, november.next), 0);

      final s = await summaries.monthSummary(ledgerId, november, today: today);
      expect(s.fixedExpense, 567000);
      expect(s.expense, 579000);
      expect(s.toStatsJson()['fixed_expense'], 567000);
    });

    test('기본 집계의 다른 숫자는 그대로다', () async {
      await add(12000, LocalDate(2026, 11, 3), party: '김밥천국', category: '식비');
      await add(40000, LocalDate(2026, 10, 20));
      final base = await ledger.monthSummary(ledgerId, november, today: today);
      final full = await summaries.monthSummary(
        ledgerId,
        november,
        today: today,
      );
      expect(full.expense, base.expense);
      expect(full.previousExpense, 40000);
      expect(full.noSpendDays, base.noSpendDays);
      expect(full.byCategory.single.name, '식비');
      expect(full.topCounterparties.single.name, '김밥천국');
    });
  });

  group('예산 대비', () {
    test('전체 예산을 정하지 않은 달은 null이다', () async {
      await add(12000, LocalDate(2026, 11, 3));
      // 분류 예산만 있는 것은 전체 예산이 아니다.
      await budgets.setBudget(
        ledgerId,
        month: '2026-11',
        categoryId: categoryIds['식비'],
        amount: 300000,
      );
      final s = await summaries.monthSummary(ledgerId, november, today: today);
      expect(s.budget, isNull);
      expect(s.toStatsJson()['budget'], isNull);
    });

    test('전체 예산과 그 달의 지출(취소 · 이체 제외)을 짝짓는다', () async {
      await budgets.setBudget(
        ledgerId,
        month: '2026-11',
        categoryId: null,
        amount: 600000,
      );
      // 다른 달의 예산은 섞이지 않는다.
      await budgets.setBudget(
        ledgerId,
        month: '2026-10',
        categoryId: null,
        amount: 111,
      );
      await add(160600, LocalDate(2026, 11, 3));
      await add(70000, LocalDate(2026, 11, 6), canceled: true);
      await add(3000000, LocalDate(2026, 11, 10), type: TxType.income);
      final bankId = await ledger.addAccount(
        ledgerId: ledgerId,
        name: '통장',
        kind: AccountKind.bank,
      );
      await ledger.addTransaction(
        ledgerId,
        TransactionInput(
          type: TxType.transfer,
          occurredOn: LocalDate(2026, 11, 8),
          amount: 500000,
          accountId: cashId,
          toAccountId: bankId,
        ),
      );

      final s = await summaries.monthSummary(ledgerId, november, today: today);
      expect(s.budget, const MonthBudget(amount: 600000, spent: 160600));
      expect(s.budget!.remaining, 439400);
      expect(s.toStatsJson()['budget'], {'amount': 600000, 'spent': 160600});

      final october = await summaries.monthSummary(
        ledgerId,
        november.previous,
        today: today,
      );
      expect(october.budget, const MonthBudget(amount: 111, spent: 0));
    });

    test('예산을 넘기면 넘긴 금액이 나온다', () async {
      await budgets.setBudget(
        ledgerId,
        month: '2026-11',
        categoryId: null,
        amount: 100000,
      );
      await add(112000, LocalDate(2026, 11, 3));
      final s = await summaries.monthSummary(ledgerId, november, today: today);
      expect(s.budget!.isOver, isTrue);
      expect(s.budget!.overBy, 12000);
    });

    test('전체 예산 행이 겹치면 나중에 고친 것을 쓴다', () async {
      // 두 기기가 따로 만든 행을 흉내 낸다.
      Future<void> insert(String id, int amount, DateTime at) => db
          .into(db.budgets)
          .insert(
            BudgetsCompanion.insert(
              id: id,
              ledgerId: ledgerId,
              month: '2026-11',
              amount: amount,
              clientUpdatedAt: at,
              createdAt: at,
              updatedAt: at,
            ),
          );
      await insert('b-old', 500000, DateTime.utc(2026, 11, 1));
      await insert('b-new', 700000, DateTime.utc(2026, 11, 2));
      expect(await summaries.totalBudgetAmount(ledgerId, november), 700000);
    });
  });

  group('여러 달의 추이', () {
    test('보고 있는 달까지 여섯 달을 오래된 달부터 준다', () async {
      await add(999, LocalDate(2026, 5, 31)); // 여섯 달 밖
      await add(100000, LocalDate(2026, 6, 1));
      await add(20000, LocalDate(2026, 6, 30));
      await add(300000, LocalDate(2026, 9, 15));
      await add(2500000, LocalDate(2026, 9, 25), type: TxType.income);
      await add(40000, LocalDate(2026, 10, 20));
      await add(12000, LocalDate(2026, 11, 3));
      await add(8000, LocalDate(2026, 11, 30));
      await add(70000, LocalDate(2026, 11, 6), canceled: true);
      await add(777, LocalDate(2026, 12, 1)); // 다음 달

      final trend = await summaries.monthlyTotals(ledgerId, november);
      expect(
        [for (final m in trend) m.period.key],
        ['2026-06', '2026-07', '2026-08', '2026-09', '2026-10', '2026-11'],
      );
      expect(
        [for (final m in trend) m.expense],
        [120000, 0, 0, 300000, 40000, 20000],
      );
      expect([for (final m in trend) m.income], [0, 0, 0, 2500000, 0, 0]);
    });

    test('해를 넘어가도 이어진다', () async {
      await add(5000, LocalDate(2025, 12, 31));
      await add(7000, LocalDate(2026, 1, 1));
      final trend = await summaries.monthlyTotals(
        ledgerId,
        MonthPeriod(2026, 2),
      );
      expect(
        [for (final m in trend) m.period.key],
        ['2025-09', '2025-10', '2025-11', '2025-12', '2026-01', '2026-02'],
      );
      expect([for (final m in trend) m.expense], [0, 0, 0, 5000, 7000, 0]);
    });

    test('월 시작일이 25일이면 기간대로 나눠 담는다', () async {
      // '11월'은 10월 25일부터 11월 24일까지다.
      final period = MonthPeriod(2026, 11, startDay: 25);
      await add(1000, LocalDate(2026, 10, 24)); // 10월
      await add(2000, LocalDate(2026, 10, 25)); // 11월
      await add(3000, LocalDate(2026, 11, 24)); // 11월
      await add(4000, LocalDate(2026, 11, 25)); // 12월(밖)
      final trend = await summaries.monthlyTotals(ledgerId, period);
      expect(trend.last.period, period);
      expect(trend.last.expense, 5000);
      expect(trend[4].expense, 1000);
    });

    test('달 수를 바꿀 수 있다', () async {
      final trend = await summaries.monthlyTotals(ledgerId, november, count: 3);
      expect(
        [for (final m in trend) m.period.key],
        ['2026-09', '2026-10', '2026-11'],
      );
    });

    test('거래가 바뀌면 다시 흘러나온다', () async {
      final seen = <int>[];
      final subscription = summaries
          .watchMonthlyTotals(ledgerId, november)
          .listen((trend) => seen.add(trend.last.expense));
      await pumpEventQueue();
      expect(seen.last, 0);
      await add(1000, LocalDate(2026, 11, 17));
      await pumpEventQueue();
      expect(seen.last, 1000);
      await subscription.cancel();
    });
  });

  group('확인 필요 건수', () {
    test('그 달의 확인이 필요한 거래만 센다', () async {
      await add(1250, LocalDate(2026, 11, 12), status: TxStatus.needsReview);
      await add(3300, LocalDate(2026, 11, 13), status: TxStatus.needsReview);
      await add(12000, LocalDate(2026, 11, 3)); // 확인됨
      await add(900, LocalDate(2026, 10, 30), status: TxStatus.needsReview);
      final deleted = await add(
        500,
        LocalDate(2026, 11, 14),
        status: TxStatus.needsReview,
      );
      await ledger.deleteTransaction(deleted);

      expect(
        await summaries.watchNeedsReviewCount(ledgerId, november).first,
        2,
      );
      expect(
        await summaries
            .watchNeedsReviewCount(ledgerId, november.previous)
            .first,
        1,
      );
    });

    test('확인하면 줄어든다', () async {
      final id = await add(
        1250,
        LocalDate(2026, 11, 12),
        status: TxStatus.needsReview,
      );
      final seen = <int>[];
      final subscription = summaries
          .watchNeedsReviewCount(ledgerId, november)
          .listen(seen.add);
      await pumpEventQueue();
      expect(seen.last, 1);
      await ledger.updateTransaction(
        id,
        TransactionInput(
          type: TxType.expense,
          occurredOn: LocalDate(2026, 11, 12),
          amount: 1250,
          accountId: cashId,
        ),
      );
      await pumpEventQueue();
      expect(seen.last, 0);
      await subscription.cancel();
    });
  });

  group('수입 쪽 내용', () {
    test('분류별 합계, 날짜별 합계, 보낸 곳, 큰 수입', () async {
      await add(
        3000000,
        LocalDate(2026, 11, 10),
        type: TxType.income,
        party: '(주)회사',
        category: '급여',
      );
      await add(
        50000,
        LocalDate(2026, 11, 10),
        type: TxType.income,
        party: '엄마',
        category: '용돈',
      );
      await add(
        30000,
        LocalDate(2026, 11, 12),
        type: TxType.income,
        party: '엄마',
        category: '용돈',
      );
      await add(1200, LocalDate(2026, 11, 15), type: TxType.income);
      // 지출, 취소된 수입, 다른 달의 수입은 들어가지 않는다.
      await add(12000, LocalDate(2026, 11, 3), party: '김밥천국');
      await add(
        999999,
        LocalDate(2026, 11, 4),
        type: TxType.income,
        canceled: true,
      );
      await add(777, LocalDate(2026, 10, 31), type: TxType.income);

      final flow = await summaries.incomeBreakdown(ledgerId, november);
      expect(flow.period, november);
      expect(flow.total, 3081200);
      expect(
        [for (final c in flow.byCategory) (c.name, c.amount)],
        [('급여', 3000000), ('용돈', 80000), ('분류 없음', 1200)],
      );
      expect(flow.byCategory.first.categoryId, categoryIds['급여']);
      expect(flow.byCategory.last.categoryId, isNull);
      expect(flow.daily, {
        LocalDate(2026, 11, 10): 3050000,
        LocalDate(2026, 11, 12): 30000,
        LocalDate(2026, 11, 15): 1200,
      });
      expect(
        [for (final c in flow.topCounterparties) (c.name, c.amount, c.count)],
        [('(주)회사', 3000000, 1), ('엄마', 80000, 2)],
      );
      expect(
        [for (final e in flow.largest) e.amount],
        [3000000, 50000, 30000, 1200],
      );

      // 수입 쪽 합계는 기본 집계의 수입과 같다.
      final s = await ledger.monthSummary(ledgerId, november, today: today);
      expect(flow.total, s.income);
    });

    test('수입이 없는 달은 비어 있다', () async {
      final flow = await summaries.incomeBreakdown(ledgerId, november);
      expect(flow.total, 0);
      expect(flow.byCategory, isEmpty);
      expect(flow.daily, isEmpty);
      expect(flow.topCounterparties, isEmpty);
      expect(flow.largest, isEmpty);
    });
  });
}
