import 'package:flutter_test/flutter_test.dart';
import 'package:gagyebu/app/providers.dart';
import 'package:gagyebu/data/db/database.dart';
import 'package:gagyebu/data/repositories/category_repository.dart';
import 'package:gagyebu/domain/enums.dart';
import 'package:gagyebu/features/categories/categories_screen.dart';
import 'package:gagyebu/features/categories/category_tree.dart';
import 'package:gagyebu/features/common/category_visual.dart';
import 'package:material_ui/material_ui.dart';

import 'test_app.dart';

Future<List<CategoryRow>> categoriesOf(
  AppServices services,
  CategoryKind kind,
) async => [
  for (final c in await services.repository.categories(services.ledgerId))
    if (c.kind == kind) c,
];

Future<CategoryRow> named(AppServices services, String name) async =>
    (await services.repository.categories(services.ledgerId))
        .firstWhere((c) => c.name == name);

/// [row]를 화면 가운데로 올린다. 맨 아래에 걸치면 방금 뜬 알림에 가려 누를 수 없다.
Future<void> showRow(WidgetTester tester, Finder row) async {
  await Scrollable.ensureVisible(tester.element(row), alignment: 0.5);
  await tester.pumpAndSettle();
}

/// [handle]을 잡고 [from] 줄을 바로 아래의 [to] 줄 밑으로 끌어 놓는다.
Future<void> dragBelow(
  WidgetTester tester,
  Finder handle, {
  required Finder from,
  required Finder to,
}) async {
  final distance = tester.getTopLeft(to).dy - tester.getTopLeft(from).dy;
  final gesture = await tester.startGesture(tester.getCenter(handle));
  await tester.pump(const Duration(milliseconds: 100));
  await gesture.moveBy(Offset(0, distance * 0.4));
  await tester.pump(const Duration(milliseconds: 100));
  await gesture.moveBy(Offset(0, distance * 0.35));
  await tester.pump(const Duration(milliseconds: 100));
  await gesture.up();
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('추가 → 수정(이름 · 아이콘) → 순서 바꾸기 → 삭제', (tester) async {
    final services = await createTestServices();
    await pumpApp(tester, services, size: desktop, location: '/categories');

    expect(find.byType(CategoriesScreen), findsOneWidget);
    expect(find.text('식비'), findsOneWidget);
    // 수입 분류는 수입 탭에 있다.
    expect(find.text('급여'), findsNothing);

    // 추가
    await tester.tap(find.byKey(const ValueKey('categories-add')));
    await tester.pumpAndSettle();
    expect(find.text('지출 분류 추가'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('category-form-name')),
      '반려동물',
    );
    await tester.tap(find.byKey(const ValueKey('category-form-save')));
    await tester.pumpAndSettle();
    await showRow(tester, find.text('반려동물'));
    expect(find.text('반려동물'), findsOneWidget);
    var pet = await named(services, '반려동물');
    expect(pet.kind, CategoryKind.expense);
    expect(pet.icon, isNull);

    // 수정: 이름을 고치고 아이콘을 고른다.
    await tester.tap(find.text('반려동물'));
    await tester.pumpAndSettle();
    expect(find.text('분류 고치기'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('category-form-name')),
      '우리 강아지',
    );
    final petIcon = find.byKey(const ValueKey('category-icon-pet'));
    await showRow(tester, petIcon);
    await tester.tap(petIcon);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('category-form-save')));
    await tester.pumpAndSettle();
    pet = await named(services, '우리 강아지');
    expect(pet.icon, 'pet');
    expect(
      find.descendant(
        of: find.byKey(ValueKey('category-${pet.id}')),
        matching: find.byIcon(categoryIconChoices['pet']!),
      ),
      findsOneWidget,
    );

    // 순서: 맨 위의 식비를 카페·간식 아래로
    await tester.drag(find.byType(CategoriesScreen), const Offset(0, 2000));
    await tester.pumpAndSettle();
    final food = await named(services, '식비');
    await dragBelow(
      tester,
      find.byKey(ValueKey('category-handle-${food.id}')),
      from: find.text('식비'),
      to: find.text('카페·간식'),
    );
    final names = [
      for (final c in await categoriesOf(services, CategoryKind.expense))
        c.name,
    ];
    expect(names.take(3), ['카페·간식', '식비', '교통']);
    expect(
      tester.getTopLeft(find.text('카페·간식')).dy,
      lessThan(tester.getTopLeft(find.text('식비')).dy),
    );

    // 삭제
    await showRow(tester, find.text('우리 강아지'));
    await tester.tap(find.text('우리 강아지'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('category-form-delete')));
    await tester.pumpAndSettle();
    expect(find.textContaining("'분류 없음'이 됩니다"), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('confirm-yes')));
    await tester.pumpAndSettle();
    expect(find.text('우리 강아지'), findsNothing);

    final queued = await services.db.select(services.db.outbox).get();
    expect(
      queued.where((o) => o.targetTable == 'categories').map((o) => o.rowId),
      contains(food.id),
    );
    expect(tester.takeException(), isNull);
    await disposeApp(tester, services);
  });

  testWidgets('수입 탭에서 추가하면 수입 분류가 된다', (tester) async {
    final services = await createTestServices();
    await pumpApp(tester, services, size: phone, location: '/categories');

    await tester.tap(find.byKey(const ValueKey('categories-tab-income')));
    await tester.pumpAndSettle();
    expect(find.text('급여'), findsOneWidget);
    expect(find.text('식비'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('categories-add')));
    await tester.pumpAndSettle();
    expect(find.text('수입 분류 추가'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('category-form-name')),
      '부업',
    );
    await tester.tap(find.byKey(const ValueKey('category-form-save')));
    await tester.pumpAndSettle();

    expect((await named(services, '부업')).kind, CategoryKind.income);
    expect(tester.takeException(), isNull);
    await disposeApp(tester, services);
  });

  testWidgets('대분류를 정하면 소분류가 되고, 대분류를 지우면 대분류 없는 분류로 남는다', (tester) async {
    final services = await createTestServices();
    await pumpApp(tester, services, size: desktop, location: '/categories');
    final food = await named(services, '식비');
    final cafe = await named(services, '카페·간식');

    // 카페·간식을 식비 아래에 둔다.
    await tester.tap(find.text('카페·간식'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('category-form-parent')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('식비').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('category-form-save')));
    await tester.pumpAndSettle();

    expect((await named(services, '카페·간식')).parentId, food.id);
    expect(
      find.descendant(
        of: find.byKey(ValueKey('category-children-${food.id}')),
        matching: find.text('카페·간식'),
      ),
      findsOneWidget,
    );
    expect(find.text('소분류 1'), findsOneWidget);

    // 소분류가 있는 식비는 다른 분류 아래로 보낼 수 없다.
    await tester.tap(find.text('식비'));
    await tester.pumpAndSettle();
    expect(find.text('소분류가 있는 분류는 다른 분류 아래에 둘 수 없습니다'), findsOneWidget);

    // 식비를 지우면 카페·간식은 대분류 없는 분류로 남는다.
    await tester.tap(find.byKey(const ValueKey('category-form-delete')));
    await tester.pumpAndSettle();
    expect(find.textContaining('소분류 1개는 대분류 없는 분류가 됩니다'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('confirm-yes')));
    await tester.pumpAndSettle();

    expect(find.text('식비'), findsNothing);
    expect(find.text('카페·간식'), findsOneWidget);
    expect((await named(services, '카페·간식')).parentId, isNull);
    expect(find.byKey(ValueKey('category-group-${cafe.id}')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await disposeApp(tester, services);
  });

  testWidgets('소분류는 그 대분류 안에서 순서를 바꾼다', (tester) async {
    final services = await createTestServices();
    final food = await named(services, '식비');
    final lunch = await services.repository.addCategory(
      ledgerId: services.ledgerId,
      kind: CategoryKind.expense,
      name: '점심',
      parentId: food.id,
    );
    await services.repository.addCategory(
      ledgerId: services.ledgerId,
      kind: CategoryKind.expense,
      name: '저녁',
      parentId: food.id,
    );
    await pumpApp(tester, services, size: foldable, location: '/categories');

    await dragBelow(
      tester,
      find.byKey(ValueKey('category-handle-$lunch')),
      from: find.text('점심'),
      to: find.text('저녁'),
    );

    final groups = buildCategoryGroups(
      await services.repository.categories(services.ledgerId),
      CategoryKind.expense,
    );
    expect(groups.first.category.name, '식비');
    expect(
      [for (final c in groups.first.children) c.category.name],
      ['저녁', '점심'],
    );
    expect(tester.takeException(), isNull);
    await disposeApp(tester, services);
  });

  test('분류를 대분류와 소분류로 묶고 색의 자리를 순서대로 준다', () {
    final at = DateTime.utc(2026, 11, 1);
    CategoryRow row(
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

    final groups = buildCategoryGroups([
      row('식비', 10),
      row('점심', 20, parent: '식비'),
      row('교통', 30),
      row('저녁', 40, parent: '식비'),
      // 대분류가 지워진 소분류, 소분류의 소분류는 맨 위에 보인다.
      row('떠돌이', 50, parent: '없는 분류'),
      row('손자', 60, parent: '점심'),
      row('급여', 10, kind: CategoryKind.income),
    ], CategoryKind.expense);

    expect([for (final g in groups) g.category.id], ['식비', '교통', '떠돌이', '손자']);
    expect(
      [for (final c in groups.first.children) c.category.id],
      ['점심', '저녁'],
    );
    expect([for (final g in groups) g.colorIndex], [0, 2, 4, 5]);
    expect([for (final c in groups.first.children) c.colorIndex], [1, 3]);
  });

  test('고를 수 있는 아이콘마다 읽어 주는 이름이 있다', () {
    expect(categoryIconLabels.keys.toSet(), categoryIconChoices.keys.toSet());
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
          final food = await named(services, '식비');
          final long = await services.repository.addCategory(
            ledgerId: services.ledgerId,
            kind: CategoryKind.expense,
            name: '이름이 아주 아주 긴 소분류 — 회사 근처에서 먹는 점심과 저녁 식사',
            parentId: food.id,
          );
          await CategoryRepository(services.repository)
              .updateCategory(food.id, name: '식비', icon: 'grocery');
          await pumpApp(
            tester,
            services,
            size: size,
            location: '/categories',
            textScale: scale,
          );
          expect(find.byType(CategoriesScreen), findsOneWidget);
          expect(tester.takeException(), isNull);

          await tester.drag(
            find.byType(CategoriesScreen),
            const Offset(0, -800),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await tester.drag(
            find.byType(CategoriesScreen),
            const Offset(0, 2000),
          );
          await tester.pumpAndSettle();

          // 편집 칸(아이콘 40개)도 넘치지 않는다.
          final row = find.byKey(ValueKey('category-$long'));
          await showRow(tester, row);
          await tester.tap(row);
          await tester.pumpAndSettle();
          expect(find.text('분류 고치기'), findsOneWidget);
          expect(tester.takeException(), isNull);
          await disposeApp(tester, services);
        });
      }
    }
  });

  testWidgets('분류가 없으면 빈 상태를 보여 준다', (tester) async {
    final services = await createTestServices();
    for (final c in await categoriesOf(services, CategoryKind.income)) {
      await services.repository.deleteCategory(c.id);
    }
    await pumpApp(tester, services, size: phone, location: '/categories');
    await tester.tap(find.byKey(const ValueKey('categories-tab-income')));
    await tester.pumpAndSettle();

    expect(find.textContaining('수입 분류가 없습니다'), findsOneWidget);
    expect(find.byKey(const ValueKey('categories-add-first')), findsOneWidget);
    await disposeApp(tester, services);
  });
}
