import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gagyebu/core/local_date.dart';
import 'package:gagyebu/data/db/database.dart';
import 'package:gagyebu/data/repositories/ledger_repository.dart';
import 'package:gagyebu/data/repositories/transaction_query.dart';
import 'package:gagyebu/domain/enums.dart';

void main() {
  late AppDatabase db;
  late LedgerRepository repo;
  late String ledgerId;
  late String cashId;
  late String bankId;
  late String cardId;
  late Map<String, String> categoryIds;
  late String diningOutId;
  final ids = <String, String>{};

  final from = LocalDate(2026, 11, 1);
  final to = LocalDate(2026, 12, 1);

  Future<void> add(
    String name, {
    required TxType type,
    required int amount,
    required int day,
    String? account,
    String? toAccount,
    String? categoryId,
    String? memo,
    bool canceled = false,
    TxStatus status = TxStatus.confirmed,
  }) async {
    ids[name] = await repo.addTransaction(
      ledgerId,
      TransactionInput(
        type: type,
        occurredOn: LocalDate(2026, 11, day),
        amount: amount,
        accountId: account ?? cashId,
        toAccountId: toAccount,
        counterparty: type == TxType.transfer ? null : name,
        categoryId: categoryId,
        memo: memo,
        canceled: canceled,
        status: status,
      ),
    );
  }

  /// 필터에 걸린 거래의 이름(넣을 때 붙인 이름)을 돌려준다.
  Future<Set<String>> names(TransactionFilter filter, {String? search}) async {
    final list = await watchFilteredTransactions(
      repo,
      ledgerId,
      from: from,
      toExclusive: to,
      filter: filter,
      search: search,
    ).first;
    final byId = {for (final e in ids.entries) e.value: e.key};
    return {for (final view in list) byId[view.row.id]!};
  }

  setUp(() async {
    ids.clear();
    db = AppDatabase(NativeDatabase.memory());
    repo = LedgerRepository(db, clock: () => DateTime.utc(2026, 11, 17, 3));
    ledgerId = await repo.ensureLocalLedger();
    cashId = (await repo.accounts(ledgerId)).single.id;
    bankId = await repo.addAccount(
      ledgerId: ledgerId,
      name: '월급 통장',
      kind: AccountKind.bank,
    );
    cardId = await repo.addAccount(
      ledgerId: ledgerId,
      name: '신용카드',
      kind: AccountKind.creditCard,
    );
    categoryIds = {
      for (final c in await repo.categories(ledgerId)) c.name: c.id,
    };
    diningOutId = await repo.addCategory(
      ledgerId: ledgerId,
      kind: CategoryKind.expense,
      name: '외식',
      parentId: categoryIds['식비'],
    );

    await add(
      '김밥천국',
      type: TxType.expense,
      amount: 9000,
      day: 3,
      categoryId: categoryIds['식비'],
    );
    await add(
      '파스타집',
      type: TxType.expense,
      amount: 32000,
      day: 5,
      account: cardId,
      categoryId: diningOutId,
      status: TxStatus.needsReview,
    );
    await add(
      '지하철',
      type: TxType.expense,
      amount: 1500,
      day: 5,
      categoryId: categoryIds['교통'],
    );
    await add(
      '마트',
      type: TxType.expense,
      amount: 54000,
      day: 9,
      account: cardId,
      memo: '장보기',
    );
    await add(
      '환불한 신발',
      type: TxType.expense,
      amount: 89000,
      day: 10,
      account: cardId,
      categoryId: categoryIds['쇼핑'],
      canceled: true,
    );
    await add(
      '회사',
      type: TxType.income,
      amount: 3000000,
      day: 10,
      account: bankId,
      categoryId: categoryIds['급여'],
    );
    await add(
      '당근 판매',
      type: TxType.income,
      amount: 20000,
      day: 12,
      status: TxStatus.needsReview,
    );
    await add(
      '카드대금',
      type: TxType.transfer,
      amount: 86000,
      day: 15,
      account: bankId,
      toAccount: cardId,
    );
    // 다른 달의 거래는 어떤 필터에도 걸리지 않는다.
    ids['지난달'] = await repo.addTransaction(
      ledgerId,
      TransactionInput(
        type: TxType.expense,
        occurredOn: LocalDate(2026, 10, 31),
        amount: 9000,
        accountId: cashId,
        counterparty: '지난달',
        categoryId: categoryIds['식비'],
      ),
    );
  });

  tearDown(() => db.close());

  const everything = {'김밥천국', '파스타집', '지하철', '마트', '회사', '당근 판매', '카드대금'};

  group('TransactionFilter', () {
    test('값이 같으면 같은 필터다', () {
      expect(
        TransactionFilter(types: {TxType.expense}, categoryIds: {'a', 'b'}),
        TransactionFilter(types: {TxType.expense}, categoryIds: {'b', 'a'}),
      );
      expect(
        const TransactionFilter(minAmount: 1000),
        isNot(const TransactionFilter(maxAmount: 1000)),
      );
      expect(const TransactionFilter().isEmpty, isTrue);
    });

    test('걸린 조건의 수를 센다', () {
      final filter = TransactionFilter(
        types: {TxType.expense, TxType.income},
        categoryIds: {'a'},
        minAmount: 1000,
        maxAmount: 5000,
        needsReviewOnly: true,
      );
      // 종류 둘 + 분류 하나 + 금액 범위 + 확인 필요
      expect(filter.activeCount, 5);
      expect(filter.isEmpty, isFalse);
    });

    test('copyWith로 금액 범위를 지울 수 있다', () {
      const filter = TransactionFilter(minAmount: 1000, maxAmount: 5000);
      final cleared = filter.copyWith(minAmount: () => null);
      expect(cleared.minAmount, isNull);
      expect(cleared.maxAmount, 5000);
    });
  });

  group('watchFilteredTransactions', () {
    test('필터가 없으면 그 달의 거래를 최근 순으로 주고 취소한 거래는 뺀다', () async {
      final list = await watchFilteredTransactions(
        repo,
        ledgerId,
        from: from,
        toExclusive: to,
      ).first;
      expect(
        [for (final v in list) v.row.occurredOn.day],
        [15, 12, 10, 9, 5, 5, 3],
      );
      expect(await names(const TransactionFilter()), everything);
      // 자산과 분류 이름을 붙여 준다.
      final transfer = list.first;
      expect(transfer.accountName, '월급 통장');
      expect(transfer.toAccountName, '신용카드');
      expect(list.last.categoryName, '식비');
    });

    test('취소 포함', () async {
      expect(await names(const TransactionFilter(includeCanceled: true)), {
        ...everything,
        '환불한 신발',
      });
    });

    test('종류', () async {
      expect(await names(TransactionFilter(types: {TxType.income})), {
        '회사',
        '당근 판매',
      });
      expect(
        await names(TransactionFilter(types: {TxType.income, TxType.transfer})),
        {'회사', '당근 판매', '카드대금'},
      );
    });

    test('분류: 대분류를 고르면 소분류의 거래도 나온다', () async {
      expect(
        await names(TransactionFilter(categoryIds: {categoryIds['식비']!})),
        {'김밥천국', '파스타집'},
      );
      expect(await names(TransactionFilter(categoryIds: {diningOutId})), {
        '파스타집',
      });
      expect(
        await names(
          TransactionFilter(
            categoryIds: {categoryIds['교통']!, categoryIds['급여']!},
          ),
        ),
        {'지하철', '회사'},
      );
    });

    test('분류 없음은 분류를 정하지 않은 수입 · 지출이고 이체는 아니다', () async {
      expect(
        await names(
          const TransactionFilter(categoryIds: {TransactionFilter.noCategory}),
        ),
        {'마트', '당근 판매'},
      );
      expect(
        await names(
          TransactionFilter(
            categoryIds: {TransactionFilter.noCategory, categoryIds['교통']!},
          ),
        ),
        {'마트', '당근 판매', '지하철'},
      );
    });

    test('자산: 이체는 보내는 쪽이든 받는 쪽이든 걸린다', () async {
      expect(await names(TransactionFilter(accountIds: {cardId})), {
        '파스타집',
        '마트',
        '카드대금',
      });
      expect(await names(TransactionFilter(accountIds: {bankId})), {
        '회사',
        '카드대금',
      });
    });

    test('금액 범위는 양 끝을 포함한다', () async {
      expect(
        await names(const TransactionFilter(minAmount: 9000, maxAmount: 32000)),
        {'김밥천국', '파스타집', '당근 판매'},
      );
      expect(await names(const TransactionFilter(minAmount: 86000)), {
        '회사',
        '카드대금',
      });
      expect(await names(const TransactionFilter(maxAmount: 1500)), {'지하철'});
    });

    test('확인 필요만', () async {
      expect(await names(const TransactionFilter(needsReviewOnly: true)), {
        '파스타집',
        '당근 판매',
      });
    });

    test('여러 조건을 함께 건다', () async {
      expect(
        await names(
          TransactionFilter(
            types: {TxType.expense},
            accountIds: {cardId},
            minAmount: 30000,
          ),
        ),
        {'파스타집', '마트'},
      );
      expect(
        await names(
          TransactionFilter(
            types: {TxType.expense},
            accountIds: {cardId},
            minAmount: 30000,
            includeCanceled: true,
          ),
        ),
        {'파스타집', '마트', '환불한 신발'},
      );
      expect(
        await names(
          TransactionFilter(
            types: {TxType.expense},
            categoryIds: {categoryIds['식비']!},
            needsReviewOnly: true,
          ),
        ),
        {'파스타집'},
      );
      // 서로 맞지 않는 조건이면 아무것도 나오지 않는다.
      expect(
        await names(
          TransactionFilter(
            types: {TxType.transfer},
            categoryIds: {categoryIds['식비']!},
          ),
        ),
        isEmpty,
      );
    });

    test('검색어와 함께 건다', () async {
      expect(await names(const TransactionFilter(), search: '장보기'), {'마트'});
      expect(await names(const TransactionFilter(), search: '식비'), {'김밥천국'});
      expect(
        await names(TransactionFilter(accountIds: {cardId}), search: '파스타'),
        {'파스타집'},
      );
      expect(
        await names(TransactionFilter(types: {TxType.income}), search: '파스타'),
        isEmpty,
      );
      // 검색어의 %와 _는 글자 그대로 찾는다.
      expect(await names(const TransactionFilter(), search: '%'), isEmpty);
    });

    test('지운 거래는 나오지 않고, 거래가 바뀌면 다시 흘려보낸다', () async {
      final stream = watchFilteredTransactions(
        repo,
        ledgerId,
        from: from,
        toExclusive: to,
        filter: const TransactionFilter(needsReviewOnly: true),
      );
      final seen = <int>[];
      final sub = stream.listen((list) => seen.add(list.length));
      await pumpEventQueue();
      await repo.deleteTransaction(ids['당근 판매']!);
      await pumpEventQueue();
      await sub.cancel();
      expect(seen, [2, 1]);
    });
  });

  group('dailyTotals', () {
    test('날짜별로 수입과 지출을 더하고 취소 · 이체는 뺀다', () async {
      final list = await watchFilteredTransactions(
        repo,
        ledgerId,
        from: from,
        toExclusive: to,
        filter: const TransactionFilter(includeCanceled: true),
      ).first;
      final totals = dailyTotals(list);
      expect(totals[LocalDate(2026, 11, 3)], const DayTotal(expense: 9000));
      expect(totals[LocalDate(2026, 11, 5)], const DayTotal(expense: 33500));
      // 10일: 취소한 89,000원은 빠지고 급여만 남는다.
      expect(totals[LocalDate(2026, 11, 10)], const DayTotal(income: 3000000));
      expect(totals[LocalDate(2026, 11, 12)], const DayTotal(income: 20000));
      // 15일에는 이체뿐이라 합계가 없다.
      expect(totals.containsKey(LocalDate(2026, 11, 15)), isFalse);
      expect(totals.containsKey(LocalDate(2026, 11, 4)), isFalse);
    });

    test('같은 날의 수입과 지출을 따로 센다', () async {
      await add('점심', type: TxType.expense, amount: 8000, day: 10);
      final list = await watchFilteredTransactions(
        repo,
        ledgerId,
        from: from,
        toExclusive: to,
      ).first;
      expect(
        dailyTotals(list)[LocalDate(2026, 11, 10)],
        const DayTotal(income: 3000000, expense: 8000),
      );
    });
  });
}
