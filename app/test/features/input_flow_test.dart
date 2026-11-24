import 'package:flutter_test/flutter_test.dart';
import 'package:gagyebu/domain/enums.dart';
import 'package:material_ui/material_ui.dart';

import 'composer_support.dart';
import 'test_app.dart';

const _cardSms = '''
[Web발신]
신한카드(1234)승인 홍*동
12,500원(일시불) 11/16 12:31
김밥천국 강남점 누적 345,600원''';

/// 입력창 → 검토함 → 저장으로 이어지는 흐름(`docs/SPEC.md` 7.4–7.6).
void main() {
  for (final (name, size) in [
    ('좁음', phone),
    ('중간', foldable),
    ('넓음', desktop),
  ]) {
    testWidgets('$name 창: 결제 문자를 붙여넣어 검토하고 저장한다', (tester) async {
      final services = await createTestServices();
      await pumpApp(tester, services, size: size);

      // 어느 화면에서나 보이는 입력창에 붙여넣고 보낸다.
      await sendFromComposer(tester, _cardSms);

      // 검토함: 한 줄 요약과 읽어 낸 값
      expect(find.text('1건 읽음'), findsOneWidget);
      expect(find.byKey(const ValueKey('review-0')), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('review-title-0'))).data,
        '김밥천국 강남점',
      );
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('review-amount-label-0')))
            .data,
        '-12,500원',
      );
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('review-subtitle-0')))
            .data,
        '11월 16일 (월) 12:31 · 식비 · 현금',
      );
      // 한 건뿐이면 고칠 칸이 펼쳐져 있다.
      expect(find.widgetWithText(TextField, '김밥천국 강남점'), findsOneWidget);
      expect(find.widgetWithText(TextField, '12,500'), findsOneWidget);
      // 올해로 채운 연도는 따로 알리지 않고, '확인 필요'도 아니다.
      expect(find.textContaining('연도가 없어'), findsNothing);
      expect(find.byKey(const ValueKey('review-flag-0')), findsNothing);
      expect(find.text('모두 승인하고 저장 (1건)'), findsOneWidget);
      // 보낸 글은 입력창에서 비운다. 좁은 창에서는 입력창이 검토함 화면 뒤에 있다.
      expect(
        tester
            .widget<TextField>(find.byKey(composerInput, skipOffstage: false))
            .controller!
            .text,
        isEmpty,
      );

      await tester.tap(find.byKey(const ValueKey('review-save')));
      await tester.pumpAndSettle();

      // 저장하면 검토함이 닫히고 "되돌리기"가 달린 알림이 뜬다.
      expect(find.byKey(const ValueKey('review-0')), findsNothing);
      expect(find.text('1건을 저장했습니다'), findsOneWidget);
      expect(find.text('되돌리기'), findsOneWidget);

      // 저장 뒤 홈의 합계에 반영된다.
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('total-expense'))).data,
        '12,500원',
      );
      // 최근 내역은 좁은 화면에서 아래쪽에 있다.
      await tester.scrollUntilVisible(
        find.text('김밥천국 강남점'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('김밥천국 강남점'), findsOneWidget);

      final saved = await allTransactions(services);
      expect(saved, hasLength(1));
      expect(saved.single.amount, 12500);
      expect(saved.single.source, TxSource.paste);
      expect(saved.single.status, TxStatus.confirmed);
      expect(saved.single.occurredTime, '12:31');
      expect(saved.single.receiver, '김밥천국 강남점');
      final categories = await services.repository.categories(
        services.ledgerId,
      );
      expect(
        categories.firstWhere((c) => c.id == saved.single.categoryId).name,
        '식비',
      );
      // 작업 기록에 묶음이 남는다.
      final batch =
          (await services.db.select(services.db.inputBatches).get()).single;
      expect(batch.source, TxSource.paste);
      expect(batch.itemCount, 1);
      await disposeApp(tester, services);
    });
  }

  testWidgets('지난해로 채운 날짜는 알리고 확인을 청한다', (tester) async {
    final services = await createTestServices();
    await pumpApp(tester, services, size: desktop);
    // 오늘은 2026-11-17이므로 12월 11일은 지난해다.
    await sendFromComposer(
      tester,
      '[카카오뱅크] 홍*동(1234) 12/11 15:42 출금 7,250원 세븐일레븐 가평목동 잔액 4,123,123원',
    );
    expect(find.text('연도가 없어 2025년으로 채웠습니다.'), findsOneWidget);
    expect(find.byKey(const ValueKey('review-flag-0')), findsOneWidget);
    expect(find.text('1건 읽음 · 1건 확인 필요'), findsOneWidget);
    await disposeApp(tester, services);
  });

  testWidgets('한 줄 문장을 규칙으로 읽고 문장 입력으로 적는다', (tester) async {
    final services = await createTestServices();
    await pumpApp(tester, services, size: phone);

    await sendFromComposer(tester, '어제 점심 김밥천국 8천원 카드로');

    // 가맹점 칸에는 가게 이름만, 끼니는 메모로 간다.
    expect(find.widgetWithText(TextField, '김밥천국'), findsOneWidget);
    expect(find.widgetWithText(TextField, '8,000'), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('review-subtitle-0'))).data,
      startsWith('11월 16일 (월)'),
    );
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('review-memo-0')),
      200,
      scrollable: find
          .descendant(
            of: find.byKey(const ValueKey('review-list')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('review-memo-0')))
          .controller!
          .text,
      '점심',
    );

    await tester.tap(find.byKey(const ValueKey('review-save')));
    await tester.pumpAndSettle();
    final saved = (await allTransactions(services)).single;
    expect(saved.source, TxSource.nl);
    expect(saved.memo, '점심');
    expect(saved.receiver, '김밥천국');
    await disposeApp(tester, services);
  });

  testWidgets('안내문과 읽지 못한 줄은 접어 두고 저장 대상에서 뺀다', (tester) async {
    final services = await createTestServices();
    await pumpApp(tester, services, size: desktop);

    await sendFromComposer(tester, '''
삼성1234승인 홍*동 100원 일시불 01/09 20:07 세븐일레븐아산음 누적80,090원
[롯데카드]11/16출금예정2,668,841원
오늘 저녁은 뭐 먹지''');

    expect(find.byKey(const ValueKey('review-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('review-1')), findsNothing);
    expect(find.text('1건 읽음 · 안내문 1건 제외 · 읽지 못함 1건'), findsOneWidget);
    expect(find.text('모두 승인하고 저장 (1건)'), findsOneWidget);

    final list = find
        .descendant(
          of: find.byKey(const ValueKey('review-list')),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('review-unknown')),
      200,
      scrollable: list,
    );
    expect(find.text('거래가 아닌 안내문 1건은 뺐습니다'), findsOneWidget);
    expect(find.text('읽지 못한 내용 1건'), findsOneWidget);
    // 접혀 있어서 원문은 누르기 전에는 보이지 않는다.
    expect(find.text('오늘 저녁은 뭐 먹지'), findsNothing);
    await tester.tap(find.text('읽지 못한 내용 1건'));
    await tester.pumpAndSettle();
    expect(find.text('오늘 저녁은 뭐 먹지'), findsOneWidget);

    // 읽지 못한 것은 직접 입력으로 넘긴다. 검토하던 나머지는 남는다.
    await tester.ensureVisible(find.byKey(const ValueKey('review-manual-0')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('review-manual-0')));
    await tester.pumpAndSettle();
    expect(find.text('새 거래'), findsOneWidget);
    expect(find.byKey(const ValueKey('review-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('review-unknown')), findsNothing);
    await disposeApp(tester, services);
  });

  testWidgets('해외 결제는 원화 금액을 넣어야 저장된다', (tester) async {
    final services = await createTestServices();
    await pumpApp(tester, services, size: desktop);

    await sendFromComposer(
      tester,
      '신한(1234)해외승인 홍*동 220.00 달러 (US)11/11 22:34 ANTHROPIC* 누적2,027,221원',
    );

    // 채울 것이 남은 건이 있으면 저장하지 않는다(조용히 빠뜨리지 않는다).
    expect(find.text('채워야 하는 건이 1건 있습니다'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const ValueKey('review-save')))
          .onPressed,
      isNull,
    );
    expect(find.textContaining('원화 금액을 넣어야 저장됩니다'), findsOneWidget);
    expect(find.text('금액 없음'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('review-amount-0')),
      '312000',
    );
    await tester.pumpAndSettle();
    expect(find.text('모두 승인하고 저장 (1건)'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('review-save')));
    await tester.pumpAndSettle();
    final saved = await allTransactions(services);
    expect(saved.single.amount, 312000);
    expect(saved.single.currency, 'USD');
    expect(saved.single.originalAmount, 220.0);
    // 금액을 직접 넣은 건은 확인한 것으로 본다.
    expect(saved.single.status, TxStatus.confirmed);
    await disposeApp(tester, services);
  });
}
