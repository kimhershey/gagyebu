import 'package:flutter_test/flutter_test.dart';
import 'package:gagyebu/app/providers.dart';
import 'package:gagyebu/data/db/database.dart';
import 'package:gagyebu/domain/enums.dart';
import 'package:material_ui/material_ui.dart';

import 'test_app.dart';

const _cardSms = '''
[Web발신]
신한카드(1234)승인 홍*동
12,500원(일시불) 11/16 12:31
김밥천국 강남점 누적 345,600원''';

void main() {
  // 시험 안에서는 스트림의 첫 값을 기다리지 않고 바로 조회한다.
  Future<List<TxRow>> allTransactions(AppServices services) =>
      services.db.select(services.db.ledgerTransactions).get();

  for (final (name, size) in [
    ('좁음', phone),
    ('중간', foldable),
    ('넓음', desktop),
  ]) {
    testWidgets('$name 창: 결제 문자를 붙여넣어 검토하고 저장한다', (tester) async {
      final services = await createTestServices();
      await pumpApp(tester, services, size: size);

      await tester.tap(find.byKey(const ValueKey('input-fab')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('input-text')),
        _cardSms,
      );
      await tester.tap(find.byKey(const ValueKey('input-analyze')));
      await tester.pumpAndSettle();

      // 검토 카드: 읽어 낸 값과 근거
      expect(find.byKey(const ValueKey('review-0')), findsOneWidget);
      expect(find.widgetWithText(TextField, '김밥천국 강남점'), findsOneWidget);
      expect(find.widgetWithText(TextField, '12,500'), findsOneWidget);
      expect(find.text('11월 16일 (월) 12:31'), findsOneWidget);
      // 올해로 채운 연도는 따로 알리지 않는다.
      expect(find.textContaining('연도가 없어'), findsNothing);
      expect(find.text('1건 저장'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('input-save')));
      await tester.pumpAndSettle();

      // 저장 뒤 홈의 합계에 반영된다.
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('total-expense'))).data,
        '12,500원',
      );
      expect(find.text('김밥천국 강남점'), findsOneWidget);

      final saved = await allTransactions(services);
      expect(saved, hasLength(1));
      expect(saved.single.amount, 12500);
      expect(saved.single.source, TxSource.paste);
      expect(saved.single.occurredTime, '12:31');
      expect(saved.single.receiver, '김밥천국 강남점');
      final categories = await services.repository.categories(
        services.ledgerId,
      );
      expect(
        categories.firstWhere((c) => c.id == saved.single.categoryId).name,
        '식비',
      );
      await disposeApp(tester, services);
    });
  }

  testWidgets('지난해로 채운 날짜는 알린다', (tester) async {
    final services = await createTestServices();
    await pumpApp(tester, services, size: desktop, location: '/input');
    // 오늘은 2026-11-17이므로 12월 11일은 지난해다.
    await tester.enterText(
      find.byKey(const ValueKey('input-text')),
      '[카카오뱅크] 홍*동(1234) 12/11 15:42 출금 7,250원 세븐일레븐 가평목동 잔액 4,123,123원',
    );
    await tester.tap(find.byKey(const ValueKey('input-analyze')));
    await tester.pumpAndSettle();
    expect(find.text('연도가 없어 2025년으로 채웠다'), findsOneWidget);
    await disposeApp(tester, services);
  });

  testWidgets('한 줄 문장을 규칙으로 읽는다', (tester) async {
    final services = await createTestServices();
    await pumpApp(tester, services, size: phone, location: '/input');

    await tester.enterText(
      find.byKey(const ValueKey('input-text')),
      '어제 점심 김밥천국 8천원 카드로',
    );
    await tester.tap(find.byKey(const ValueKey('input-analyze')));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextField, '점심 김밥천국'), findsOneWidget);
    expect(find.widgetWithText(TextField, '8,000'), findsOneWidget);
    expect(find.text('11월 16일 (월)'), findsOneWidget);
    await disposeApp(tester, services);
  });

  testWidgets('안내문과 읽지 못한 줄은 저장 대상에서 뺀다', (tester) async {
    final services = await createTestServices();
    await pumpApp(tester, services, size: desktop, location: '/input');

    await tester.enterText(find.byKey(const ValueKey('input-text')), '''
삼성1234승인 홍*동 100원 일시불 01/09 20:07 세븐일레븐아산음 누적80,090원
[롯데카드]11/16출금예정2,668,841원
오늘 저녁은 뭐 먹지''');
    await tester.tap(find.byKey(const ValueKey('input-analyze')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('review-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('review-1')), findsNothing);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('unknown')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('거래가 아닌 안내문 1건은 뺐다'), findsOneWidget);
    expect(find.text('읽지 못한 내용 1건'), findsOneWidget);
    expect(find.text('1건 저장'), findsOneWidget);
    await disposeApp(tester, services);
  });

  testWidgets('해외 결제는 원화 금액을 넣어야 저장된다', (tester) async {
    final services = await createTestServices();
    await pumpApp(tester, services, size: desktop, location: '/input');

    await tester.enterText(
      find.byKey(const ValueKey('input-text')),
      '신한(1234)해외승인 홍*동 220.00 달러 (US)11/11 22:34 ANTHROPIC* 누적2,027,221원',
    );
    await tester.tap(find.byKey(const ValueKey('input-analyze')));
    await tester.pumpAndSettle();

    expect(find.text('저장할 거래가 없다'), findsOneWidget);
    expect(find.textContaining('원화 금액을 넣어야 저장된다'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('review-amount')),
      '312000',
    );
    await tester.pumpAndSettle();
    expect(find.text('1건 저장'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('input-save')));
    await tester.pumpAndSettle();
    final saved = await allTransactions(services);
    expect(saved.single.amount, 312000);
    expect(saved.single.currency, 'USD');
    expect(saved.single.originalAmount, 220.0);
    await disposeApp(tester, services);
  });
}
