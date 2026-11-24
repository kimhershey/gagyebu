import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gagyebu/app/providers.dart';
import 'package:gagyebu/core/local_date.dart';
import 'package:gagyebu/data/repositories/budget_repository.dart';
import 'package:gagyebu/data/repositories/ledger_repository.dart';
import 'package:gagyebu/domain/enums.dart';
import 'package:go_router/go_router.dart';

import 'test_app.dart';

/// 홈 · 통계 화면 시험이 함께 쓰는 거래. '지금'은 2026-11-17이다(`testNow`).
///
/// 11월 지출은 1,860,250원(식비 20,000 · 쇼핑 50,000 · 주거·통신 550,000 ·
/// 교통 1,250 · 경조사·선물 1,234,500 · 분류 없음 4,500), 수입은 3,000,000원이다.
/// 주거·통신은 반복 거래가 만든 것이고, 교통은 확인이 필요한 것이다.
class Seed {
  Seed(this.services, this.cashId, this.categoryIds);

  final AppServices services;
  final String cashId;
  final Map<String, String> categoryIds;

  static const novemberExpense = 1860250;
  static const novemberIncome = 3000000;

  static Future<Seed> empty(AppServices services) async {
    final repo = services.repository;
    return Seed(services, (await repo.accounts(services.ledgerId)).first.id, {
      for (final c in await repo.categories(services.ledgerId)) c.name: c.id,
    });
  }

  static Future<Seed> filled(AppServices services) async {
    final seed = await empty(services);
    await seed.add(
      3000000,
      LocalDate(2026, 11, 10),
      type: TxType.income,
      party: '(주)회사',
      category: '급여',
    );
    await seed.add(
      12000,
      LocalDate(2026, 11, 3),
      party: '김밥천국',
      category: '식비',
    );
    await seed.add(8000, LocalDate(2026, 11, 5), party: '김밥천국', category: '식비');
    await seed.add(50000, LocalDate(2026, 11, 5), party: '쿠팡', category: '쇼핑');
    await seed.add(4500, LocalDate(2026, 11, 16), party: '분류없는가게');
    await seed.add(
      550000,
      LocalDate(2026, 11, 1),
      party: '월세',
      category: '주거·통신',
      source: TxSource.recurring,
    );
    await seed.add(
      1250,
      LocalDate(2026, 11, 12),
      party: '버스',
      category: '교통',
      status: TxStatus.needsReview,
    );
    await seed.add(
      1234500,
      LocalDate(2026, 11, 14),
      party: '이름이 아주아주 긴 상대방 가게 강남역삼테헤란로점',
      category: '경조사·선물',
    );
    // 지난 달들
    await seed.add(40000, LocalDate(2026, 10, 20), party: '지난달 가게');
    await seed.add(300000, LocalDate(2026, 9, 15), party: '구월 가게');
    await seed.add(
      2500000,
      LocalDate(2026, 9, 25),
      type: TxType.income,
      party: '(주)회사',
      category: '급여',
    );
    await seed.add(120000, LocalDate(2026, 6, 1), party: '유월 가게');
    await seed.add(999, LocalDate(2026, 5, 31), party: '여섯 달 밖');
    return seed;
  }

  Future<String> add(
    int amount,
    LocalDate on, {
    TxType type = TxType.expense,
    String? party,
    String? category,
    TxSource source = TxSource.manual,
    TxStatus status = TxStatus.confirmed,
  }) => services.repository.addTransaction(
    services.ledgerId,
    TransactionInput(
      type: type,
      occurredOn: on,
      amount: amount,
      accountId: cashId,
      counterparty: party,
      categoryId: category == null ? null : categoryIds[category],
      source: source,
      status: status,
    ),
  );

  /// [month]('YYYY-MM')의 전체 예산을 정한다.
  Future<void> setTotalBudget(int amount, {String month = '2026-11'}) =>
      BudgetRepository(services.db, services.repository.outbox).setBudget(
        services.ledgerId,
        month: month,
        categoryId: null,
        amount: amount,
      );
}

/// 지금 보고 있는 주소.
Uri currentUri(WidgetTester tester) =>
    GoRouter.of(tester.element(find.byType(Navigator).first))
        .routerDelegate
        .currentConfiguration
        .uri;

/// [screen] 안의 목록을 끝까지 내리며 넘침이 없는지 본다. 아래쪽 카드는 화면에 들어와야
/// 그려지므로, 내려 보지 않으면 넘침을 놓친다.
Future<void> expectNoOverflowWhileScrolling(
  WidgetTester tester,
  Type screen,
) async {
  expect(tester.takeException(), isNull);
  final scrollable = find
      .descendant(of: find.byType(screen), matching: find.byType(Scrollable))
      .first;
  for (var i = 0; i < 40; i++) {
    final position = tester.state<ScrollableState>(scrollable).position;
    if (position.pixels >= position.maxScrollExtent) break;
    position.jumpTo(
      (position.pixels + 300).clamp(0, position.maxScrollExtent).toDouble(),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }
}

const fourSizes = [
  ('소형 폰', phone),
  ('대형 폰', largePhone),
  ('폴더블', foldable),
  ('PC', desktop),
];
