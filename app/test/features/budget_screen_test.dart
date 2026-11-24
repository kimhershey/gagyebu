import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:gagyebu/app/providers.dart';
import 'package:gagyebu/app/theme/tokens.dart';
import 'package:gagyebu/core/local_date.dart';
import 'package:gagyebu/data/db/database.dart';
import 'package:gagyebu/data/repositories/budget_repository.dart';
import 'package:gagyebu/data/repositories/ledger_repository.dart';
import 'package:gagyebu/domain/enums.dart';
import 'package:gagyebu/features/budget/budget_progress.dart';
import 'package:gagyebu/features/budget/budget_screen.dart';
import 'package:material_ui/material_ui.dart';

import 'test_app.dart';

Future<String> categoryId(AppServices services, String name) async =>
    (await services.repository.categories(services.ledgerId))
        .firstWhere((c) => c.name == name)
        .id;

Future<void> spend(
  AppServices services,
  String date,
  int amount, {
  String? category,
  bool canceled = false,
}) async {
  final account = (await services.repository.accounts(services.ledgerId))
      .first
      .id;
  await services.repository.addTransaction(
    services.ledgerId,
    TransactionInput(
      type: TxType.expense,
      occurredOn: LocalDate.parse(date),
      amount: amount,
      accountId: account,
      counterparty: '가게',
      categoryId: category == null
          ? null
          : await categoryId(services, category),
      canceled: canceled,
    ),
  );
}

BudgetRepository budgetsOf(AppServices services) =>
    BudgetRepository(services.db, services.repository.outbox);

/// 11월(오늘은 2026-11-17)에 식비 245,000원, 교통 60,000원, 분류 없이 20,000원을 썼다.
Future<void> seedSpending(AppServices services) async {
  await spend(services, '2026-11-03', 200000, category: '식비');
  await spend(services, '2026-11-10', 45000, category: '식비');
  await spend(services, '2026-11-11', 60000, category: '교통');
  await spend(services, '2026-11-12', 20000);
  // 취소한 거래와 다른 달의 거래는 세지 않는다.
  await spend(services, '2026-11-13', 500000, category: '식비', canceled: true);
  await spend(services, '2026-10-20', 70000, category: '식비');
}

void main() {
  testWidgets('전체 예산 정하기 → 분류 예산 추가 → 수정 → 삭제', (tester) async {
    final services = await createTestServices();
    await seedSpending(services);
    await pumpApp(tester, services, size: desktop, location: '/budget');

    expect(find.byType(BudgetScreen), findsOneWidget);
    expect(find.textContaining('이 달에는 정한 예산이 없습니다'), findsOneWidget);
    // 지난달에 정한 예산이 없으면 가져오기를 권하지 않는다.
    expect(find.byKey(const ValueKey('budget-copy-previous')), findsNothing);

    // 전체 예산
    await tester.tap(find.byKey(const ValueKey('budget-set-total')));
    await tester.pumpAndSettle();
    // 단추와 편집 칸의 제목
    expect(find.text('전체 예산 정하기'), findsNWidgets(2));
    await tester.enterText(
      find.byKey(const ValueKey('budget-form-amount')),
      '1000000',
    );
    await tester.tap(find.byKey(const ValueKey('budget-form-save')));
    await tester.pumpAndSettle();
    final total = find.byKey(const ValueKey('budget-line-total'));
    expect(total, findsOneWidget);
    Finder inTotal(String text) =>
        find.descendant(of: total, matching: find.text(text));
    expect(inTotal('1,000,000원'), findsOneWidget);
    expect(inTotal('쓴 돈 325,000원'), findsOneWidget);
    expect(inTotal('남은 돈 675,000원'), findsOneWidget);

    // 분류 예산: 식비를 20만 원으로 정하면 넘긴 것으로 보인다.
    final food = await categoryId(services, '식비');
    await tester.tap(find.byKey(const ValueKey('budget-add-category')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('budget-form-category')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('식비').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('budget-form-amount')),
      '200000',
    );
    await tester.tap(find.byKey(const ValueKey('budget-form-save')));
    await tester.pumpAndSettle();
    final line = find.byKey(ValueKey('budget-line-$food'));
    Finder inLine(String text) =>
        find.descendant(of: line, matching: find.text(text));
    expect(inLine('200,000원'), findsOneWidget);
    expect(inLine('쓴 돈 245,000원'), findsOneWidget);
    expect(inLine('45,000원 넘음'), findsOneWidget);
    // 넘기면 경고색과 경고 아이콘으로 알린다.
    expect(
      tester.widget<Text>(inLine('45,000원 넘음')).style?.color,
      tester.element(line).tokens.warn,
    );
    expect(
      find.descendant(
        of: line,
        matching: find.byIcon(Icons.warning_amber_rounded),
      ),
      findsOneWidget,
    );

    // 수정: 30만 원으로 올리면 남은 돈이 보인다.
    await tester.tap(line);
    await tester.pumpAndSettle();
    expect(find.text('식비 예산 고치기'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('budget-form-amount')),
      '300000',
    );
    await tester.tap(find.byKey(const ValueKey('budget-form-save')));
    await tester.pumpAndSettle();
    expect(inLine('300,000원'), findsOneWidget);
    expect(inLine('남은 돈 55,000원'), findsOneWidget);

    // 삭제
    await tester.tap(line);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('budget-form-delete')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('confirm-yes')));
    await tester.pumpAndSettle();
    expect(line, findsNothing);
    expect(total, findsOneWidget);

    final rows = await budgetsOf(services)
        .budgets(services.ledgerId, '2026-11');
    expect({for (final r in rows) r.categoryId: r.amount}, {null: 1000000});
    final queued = await services.db.select(services.db.outbox).get();
    expect(queued.where((o) => o.targetTable == 'budgets'), isNotEmpty);
    expect(tester.takeException(), isNull);
    await disposeApp(tester, services);
  });

  testWidgets('분류 예산의 합이 전체 예산을 넘으면 알려만 준다', (tester) async {
    final services = await createTestServices();
    final budgets = budgetsOf(services);
    await budgets.setBudget(
      services.ledgerId,
      month: '2026-11',
      categoryId: null,
      amount: 300000,
    );
    for (final (name, amount) in [('식비', 250000), ('교통', 100000)]) {
      await budgets.setBudget(
        services.ledgerId,
        month: '2026-11',
        categoryId: await categoryId(services, name),
        amount: amount,
      );
    }
    await pumpApp(tester, services, size: phone, location: '/budget');

    expect(find.byKey(const ValueKey('budget-over-allocated')), findsOneWidget);
    expect(
      find.text('분류 예산의 합(350,000원)이 전체 예산보다 50,000원 많습니다.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await disposeApp(tester, services);
  });

  testWidgets('새 달에 예산이 없으면 지난달 예산 가져오기를 권한다', (tester) async {
    final services = await createTestServices();
    await seedSpending(services);
    final budgets = budgetsOf(services);
    final food = await categoryId(services, '식비');
    await budgets.setBudget(
      services.ledgerId,
      month: '2026-10',
      categoryId: null,
      amount: 900000,
    );
    await budgets.setBudget(
      services.ledgerId,
      month: '2026-10',
      categoryId: food,
      amount: 250000,
    );
    await pumpApp(tester, services, size: largePhone, location: '/budget');

    // 저절로 복사하지 않는다.
    expect(await budgets.budgets(services.ledgerId, '2026-11'), isEmpty);
    await tester.tap(find.byKey(const ValueKey('budget-copy-previous')));
    await tester.pumpAndSettle();

    expect(find.text('지난달 예산 2건을 가져왔습니다.'), findsOneWidget);
    expect(find.text('900,000원'), findsOneWidget);
    expect(find.text('쓴 돈 325,000원'), findsOneWidget);
    expect(find.text('250,000원'), findsOneWidget);
    expect(await budgets.budgets(services.ledgerId, '2026-11'), hasLength(2));

    // 달을 넘기면 그 달의 예산과 지출을 본다.
    await tester.tap(find.byTooltip('이전 달'));
    await tester.pumpAndSettle();
    expect(find.text('2026년 10월'), findsOneWidget);
    expect(find.text('900,000원'), findsOneWidget);
    expect(find.text('쓴 돈 70,000원'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
    await disposeApp(tester, services);
  });

  testWidgets('화면을 열면 겹친 행을 정리하고 나중에 고친 것을 보여 준다', (tester) async {
    final services = await createTestServices();
    Future<void> insert(String id, int amount, DateTime at) => services.db
        .into(services.db.budgets)
        .insert(
          BudgetsCompanion.insert(
            id: id,
            ledgerId: services.ledgerId,
            month: '2026-11',
            amount: amount,
            version: const Value(1),
            clientUpdatedAt: at,
            createdAt: at,
            updatedAt: at,
          ),
        );
    await insert('old', 700000, DateTime.utc(2026, 11, 1));
    await insert('new', 800000, DateTime.utc(2026, 11, 2));
    await pumpApp(tester, services, size: foldable, location: '/budget');

    expect(find.text('800,000원'), findsOneWidget);
    expect(find.text('700,000원'), findsNothing);
    final rows = await services.db.select(services.db.budgets).get();
    expect(rows.firstWhere((r) => r.id == 'old').deletedAt, isNotNull);
    expect(rows.firstWhere((r) => r.id == 'new').deletedAt, isNull);
    final queued = await services.db.select(services.db.outbox).get();
    expect(queued.single.rowId, 'old');
    expect(queued.single.op, 'delete');
    await disposeApp(tester, services);
  });

  group('진행 계산', () {
    final at = DateTime.utc(2026, 11, 1);
    CategoryRow category(
      String id,
      int order, {
      String? parent,
      CategoryKind kind = CategoryKind.expense,
    }) => CategoryRow(
      id: id,
      version: 0,
      clientUpdatedAt: at,
      createdAt: at,
      updatedAt: at,
      ledgerId: 'ledger',
      kind: kind,
      name: id,
      parentId: parent,
      sortOrder: order,
    );
    BudgetRow budget(
      String? categoryId,
      int amount, {
      String month = '2026-11',
    }) => BudgetRow(
      id: 'b-$month-$categoryId',
      version: 0,
      clientUpdatedAt: at,
      createdAt: at,
      updatedAt: at,
      ledgerId: 'ledger',
      month: month,
      categoryId: categoryId,
      amount: amount,
    );
    final categories = [
      category('식비', 10),
      category('점심', 20, parent: '식비'),
      category('저녁', 30, parent: '식비'),
      category('교통', 40),
      category('버스', 50, parent: '교통'),
      category('쇼핑', 60),
      category('급여', 10, kind: CategoryKind.income),
    ];
    const spent = <String?, int>{
      '식비': 100000,
      '점심': 60000,
      '저녁': 40000,
      '버스': 30000,
      '쇼핑': 120000,
      null: 5000,
    };

    BudgetProgress progress(List<BudgetRow> budgets) => computeBudgetProgress(
      month: '2026-11',
      budgets: budgets,
      categories: categories,
      totalExpense: 355000,
      expenseByCategory: spent,
    );

    test('남은 돈 = 예산 − 그 달의 지출, 넘기면 넘긴 금액', () {
      final result = progress([budget(null, 400000), budget('쇼핑', 100000)]);
      final total = result.total!;
      expect(total.budget, 400000);
      expect(total.spent, 355000);
      expect(total.remaining, 45000);
      expect(total.isOver, isFalse);
      expect(total.overBy, 0);
      expect(total.ratio, closeTo(0.8875, 1e-9));

      final shopping = result.categories.single;
      expect(shopping.name, '쇼핑');
      expect(shopping.remaining, -20000);
      expect(shopping.isOver, isTrue);
      expect(shopping.overBy, 20000);
      expect(shopping.ratio, greaterThan(1));
    });

    test('대분류의 쓴 돈에는 소분류에 쓴 돈이 든다', () {
      final result = progress([
        budget('식비', 250000),
        budget('점심', 50000),
        budget('버스', 40000),
      ]);
      final lines = {for (final l in result.categories) l.name: l};
      expect([for (final l in result.categories) l.name], ['식비', '점심', '버스']);
      expect(lines['식비']!.spent, 200000);
      expect(lines['식비']!.isChild, isFalse);
      expect(lines['점심']!.spent, 60000);
      expect(lines['점심']!.isChild, isTrue);
      expect(lines['점심']!.overBy, 10000);
      expect(lines['버스']!.spent, 30000);
      // 점심 예산은 식비 예산에 든 것으로 보고, 대분류 예산이 없는 버스는 따로 더한다.
      expect(result.categorySum, 290000);
      expect(result.total, isNull);
      expect(result.overAllocated, 0);
    });

    test('분류 예산의 합이 전체 예산을 넘긴 금액', () {
      expect(
        progress([
          budget(null, 200000),
          budget('식비', 150000),
          budget('쇼핑', 100000),
        ]).overAllocated,
        50000,
      );
      expect(
        progress([budget(null, 250000), budget('식비', 150000)]).overAllocated,
        0,
      );
    });

    test('예산이 0원이면 한 푼이라도 쓰면 다 쓴 것이다', () {
      final result = progress([budget('쇼핑', 0), budget('교통', 0)]);
      final lines = {for (final l in result.categories) l.name: l};
      expect(lines['쇼핑']!.ratio, 1);
      expect(lines['쇼핑']!.isOver, isTrue);
      expect(lines['교통']!.spent, 30000);
      expect(
        computeBudgetProgress(
          month: '2026-11',
          budgets: [budget(null, 0)],
          categories: categories,
          totalExpense: 0,
          expenseByCategory: const {},
        ).total!.ratio,
        0,
      );
    });

    test('다른 달 · 지워진 분류 · 수입 분류의 예산은 보이지 않는다', () {
      final result = progress([
        budget(null, 500000, month: '2026-10'),
        budget('지워진 분류', 10000),
        budget('급여', 10000),
      ]);
      expect(result.isEmpty, isTrue);
      expect(result.categorySum, 0);
    });
  });

  group('넘치지 않는다', () {
    for (final (name, size) in [
      ('360×640', phone),
      ('412×915', largePhone),
      ('700×800', foldable),
      ('1280×800', desktop),
    ]) {
      for (final scale in [1.0, 2.0]) {
        testWidgets('$name, 글자 $scale배', (tester) async {
          final services = await createTestServices();
          await seedSpending(services);
          await spend(services, '2026-11-15', 1234567890, category: '쇼핑');
          final budgets = budgetsOf(services);
          final food = await categoryId(services, '식비');
          final long = await services.repository.addCategory(
            ledgerId: services.ledgerId,
            kind: CategoryKind.expense,
            name: '이름이 아주 아주 긴 소분류 — 회사 근처에서 먹는 점심과 저녁 식사',
            parentId: food,
          );
          for (final (category, amount) in [
            (null, 1000000),
            (food, 200000),
            (long, 987654321),
            (await categoryId(services, '쇼핑'), 1000000),
            (await categoryId(services, '교통'), 100000),
          ]) {
            await budgets.setBudget(
              services.ledgerId,
              month: '2026-11',
              categoryId: category,
              amount: amount,
            );
          }
          await pumpApp(
            tester,
            services,
            size: size,
            location: '/budget',
            textScale: scale,
          );
          expect(find.byType(BudgetScreen), findsOneWidget);
          expect(
            find.byKey(const ValueKey('budget-line-total')),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);

          await tester.drag(find.byType(BudgetScreen), const Offset(0, -800));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);

          final add = find.byKey(const ValueKey('budget-add-category'));
          await Scrollable.ensureVisible(tester.element(add), alignment: 0.5);
          await tester.pumpAndSettle();
          await tester.tap(add);
          await tester.pumpAndSettle();
          expect(find.text('분류 예산 추가'), findsWidgets);
          expect(
            find.byKey(const ValueKey('budget-form-amount')),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
          await disposeApp(tester, services);
        });
      }
    }

    testWidgets('예산이 없을 때의 안내도 넘치지 않는다', (tester) async {
      final services = await createTestServices();
      await budgetsOf(services).setBudget(
        services.ledgerId,
        month: '2026-10',
        categoryId: null,
        amount: 1,
      );
      await pumpApp(
        tester,
        services,
        size: phone,
        location: '/budget',
        textScale: 2,
      );
      expect(
        find.byKey(const ValueKey('budget-copy-previous')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await disposeApp(tester, services);
    });
  });
}
