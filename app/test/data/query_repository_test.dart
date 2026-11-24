import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gagyebu/ai/query/ledger_query.dart';
import 'package:gagyebu/ai/query/query_parser.dart';
import 'package:gagyebu/core/local_date.dart';
import 'package:gagyebu/data/db/database.dart';
import 'package:gagyebu/data/repositories/ledger_repository.dart';
import 'package:gagyebu/data/repositories/query_repository.dart';
import 'package:gagyebu/domain/enums.dart';

void main() {
  late AppDatabase db;
  late LedgerRepository ledger;
  late String ledgerId;
  late String cashId;
  late Map<String, String> categoryIds;
  late List<QueryCategory> categories;
  final today = LocalDate(2026, 11, 17);

  Future<String> add(
    int amount,
    String on, {
    TxType type = TxType.expense,
    String? party,
    String? category,
    String? memo,
    String? toAccountId,
    bool canceled = false,
  }) => ledger.addTransaction(
    ledgerId,
    TransactionInput(
      type: type,
      occurredOn: LocalDate.parse(on),
      amount: amount,
      accountId: cashId,
      toAccountId: toAccountId,
      counterparty: party,
      categoryId: category == null ? null : categoryIds[category],
      memo: memo,
      canceled: canceled,
    ),
  );

  Future<QueryResult> ask(String text, {int startDay = 1, int limit = 50}) {
    final query = parseQuery(
      text,
      today: today,
      categories: categories,
      startDay: startDay,
    );
    expect(query, isNotNull, reason: '"$text"를 읽지 못했다');
    return runQuery(ledger, ledgerId, query!, today: today, listLimit: limit);
  }

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    ledger = LedgerRepository(db);
    ledgerId = await ledger.ensureLocalLedger();
    cashId = (await ledger.accounts(ledgerId)).first.id;
    final rows = await ledger.categories(ledgerId);
    categoryIds = {for (final c in rows) c.name: c.id};
    categories = [for (final c in rows) QueryCategory(c.name, c.kind)];

    // 10월
    await add(9000, '2026-10-03', party: '김밥천국', category: '식비');
    await add(21000, '2026-10-20', party: '한식당', category: '식비');
    await add(4500, '2026-10-21', party: '스타벅스 강남점', category: '카페·간식');
    await add(30000, '2026-10-28', party: '쿠팡', category: '쇼핑');
    await add(
      3000000,
      '2026-10-25',
      type: TxType.income,
      party: '(주)회사',
      category: '급여',
    );
    // 11월
    await add(12000, '2026-11-03', party: '김밥천국', category: '식비');
    await add(5000, '2026-11-16', party: '스타벅스 역삼점', category: '카페·간식');
    await add(6000, '2026-11-17', party: '편의점', memo: '스타벅스 병커피');
    // 취소한 거래는 세지 않는다.
    await add(
      70000,
      '2026-11-10',
      party: '취소한 식당',
      category: '식비',
      canceled: true,
    );
  });
  tearDown(() => db.close());

  test('지난달 식비의 합계 · 건수 · 평균', () async {
    final sum = await ask('지난달 식비 얼마야?');
    expect(sum.total, 30000);
    expect(sum.count, 2);
    expect(sum.average, 15000);
    expect(sum.rows.map((r) => r.title), ['한식당', '김밥천국']);
    expect(sum.rows.first.categoryName, '식비');

    expect((await ask('지난달 식비 몇 번?')).count, 2);
    expect((await ask('10월 식비 평균')).average, 15000);
  });

  test('상대방은 상대방과 내용에 그 말이 든 거래를 찾는다', () async {
    final all = await ask('올해 스타벅스에서 얼마 썼어?');
    expect(all.total, 4500 + 5000 + 6000);
    expect(all.count, 3);
    final october = await ask('지난달 스타벅스 몇 번 갔어?');
    expect(october.count, 1);
  });

  test('수입과 지출을 가려 센다', () async {
    final income = await ask('지난달 수입 합계');
    expect(income.total, 3000000);
    expect(income.count, 1);
    final expense = await ask('지난달 얼마 썼어?');
    expect(expense.total, 9000 + 21000 + 4500 + 30000);
    // 종류를 말하지 않은 목록은 수입과 지출을 다 보여 준다.
    final list = await ask('지난달 내역 보여줘');
    expect(list.query.type, isNull);
    expect(list.count, 5);
  });

  test('취소한 거래와 지운 거래는 세지 않는다', () async {
    final november = await ask('이번 달 식비 얼마야?');
    expect(november.total, 12000);
    final id = november.rows.single.row.id;
    await ledger.deleteTransaction(id);
    final after = await ask('이번 달 식비 얼마야?');
    expect(after.isEmpty, isTrue);
    expect(after.total, 0);
    expect(after.average, 0);
  });

  test('월 시작일이 25일이면 그 기간으로 센다', () async {
    // '11월'은 10/25–11/24다. 10월 28일의 쿠팡과 10월 25일의 급여가 이번 달에 든다.
    final spent = await ask('이번 달 얼마 썼어?', startDay: 25);
    expect(spent.query.range.from, LocalDate(2026, 10, 25));
    expect(spent.total, 30000 + 12000 + 5000 + 6000);
    final income = await ask('이번 달 수입 얼마야?', startDay: 25);
    expect(income.total, 3000000);
    final last = await ask('지난달 얼마 썼어?', startDay: 25);
    expect(last.total, 9000 + 21000 + 4500);
  });

  test('하루 평균은 오늘까지 지난 날로 나눈다', () async {
    final result = await ask('이번 달 하루 평균 얼마 썼어?');
    expect(result.query.perDay, isTrue);
    expect(result.averageDays, 17);
    expect(result.average, (23000 / 17).round());
    // 지난 기간은 전체 날 수로 나눈다.
    final october = await ask('지난달 하루 평균 지출');
    expect(october.averageDays, 31);
  });

  test('대분류를 물으면 소분류의 거래도 센다', () async {
    final lunch = await ledger.addCategory(
      ledgerId: ledgerId,
      kind: CategoryKind.expense,
      name: '점심',
      parentId: categoryIds['식비'],
    );
    await ledger.addTransaction(
      ledgerId,
      TransactionInput(
        type: TxType.expense,
        occurredOn: LocalDate(2026, 11, 11),
        amount: 8000,
        accountId: cashId,
        categoryId: lunch,
      ),
    );
    expect((await ask('이번 달 식비 얼마야?')).total, 12000 + 8000);
  });

  test('목록은 최근 순이고 한도를 넘으면 남은 건수를 알려 준다', () async {
    final result = await ask('올해 지출 내역 보여줘', limit: 3);
    expect(result.count, 7);
    expect(result.rows, hasLength(3));
    expect(result.hiddenCount, 4);
    expect(result.rows.map((r) => r.row.occurredOn.toString()), [
      '2026-11-17',
      '2026-11-16',
      '2026-11-03',
    ]);
  });

  test('이체만 센다', () async {
    final bank = await ledger.addAccount(
      ledgerId: ledgerId,
      name: '은행',
      kind: AccountKind.bank,
    );
    await add(500000, '2026-11-05', type: TxType.transfer, toAccountId: bank);
    final result = await ask('이번 달 이체 얼마 했어?');
    expect(result.total, 500000);
    expect(result.count, 1);
  });

  test('없는 분류나 다른 가계부를 물으면 비어 있다', () async {
    final query = LedgerQuery(
      period: const QueryPeriod.thisYear(),
      range: const QueryPeriod.thisYear().resolve(today: today),
      aggregation: QueryAggregation.sum,
      category: '없는 분류',
      type: TxType.expense,
    );
    expect((await runQuery(ledger, ledgerId, query)).isEmpty, isTrue);

    final other = await ask('올해 얼마 썼어?');
    expect(other.count, greaterThan(0));
    final elsewhere = await runQuery(ledger, '다른-가계부', other.query);
    expect(elsewhere.isEmpty, isTrue);
  });

  test('상대방의 글자는 값으로만 쓰인다(와일드카드와 따옴표)', () async {
    await add(1000, '2026-11-02', party: "O'Reilly 100% 할인_가게");
    LedgerQuery partyQuery(String party) => LedgerQuery(
      period: const QueryPeriod.thisMonth(),
      range: const QueryPeriod.thisMonth().resolve(today: today),
      aggregation: QueryAggregation.sum,
      party: party,
      type: TxType.expense,
    );
    // %와 _는 글자 그대로 맞춘다. 아무 글자에나 맞지 않는다.
    expect((await runQuery(ledger, ledgerId, partyQuery('%'))).count, 1);
    expect((await runQuery(ledger, ledgerId, partyQuery('_'))).count, 1);
    expect((await runQuery(ledger, ledgerId, partyQuery("O'Re"))).count, 1);
    expect(
      (await runQuery(ledger, ledgerId, partyQuery("' OR 1=1 --"))).isEmpty,
      isTrue,
    );
  });
}
