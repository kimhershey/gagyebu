import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gagyebu/domain/enums.dart';
import 'package:gagyebu/features/composer/composer_bar.dart';
import 'package:gagyebu/features/composer/composer_state.dart';
import 'package:gagyebu/features/image_input/image_input_available.dart';
import 'package:gagyebu/features/image_input/image_input_screen.dart';
import 'package:gagyebu/features/query/query_screen.dart';
import 'package:gagyebu/features/review/review_state.dart';
import 'package:gagyebu/features/shell/app_shell.dart';
import 'package:material_ui/material_ui.dart';

import 'composer_support.dart';
import 'test_app.dart';

const _cardSms = '''
[Web발신]
신한카드(1234)승인 홍*동
12,500원(일시불) 11/16 12:31
김밥천국 강남점 누적 345,600원''';

String _composerText(WidgetTester tester) => tester
    .widget<TextField>(find.byKey(composerInput, skipOffstage: false))
    .controller!
    .text;

/// 입력창(`docs/SPEC.md` 7.5).
void main() {
  group('Enter', () {
    testWidgets('한글을 조합하는 중의 Enter는 보내지 않는다', (tester) async {
      final services = await createTestServices();
      await pumpApp(tester, services, size: desktop);

      await tester.tap(find.byKey(composerInput));
      await tester.pump();
      // '원'을 조합하는 중이다.
      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: '점심 9천원',
          selection: TextSelection.collapsed(offset: 6),
          composing: TextRange(start: 5, end: 6),
        ),
      );
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(containerOf(tester).read(reviewSessionProvider), isNull);
      expect(find.byKey(const ValueKey('review-0')), findsNothing);
      expect(_composerText(tester), '점심 9천원');

      // 조합이 끝난 뒤의 Enter는 보낸다.
      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: '점심 9천원',
          selection: TextSelection.collapsed(offset: 6),
        ),
      );
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('review-0')), findsOneWidget);
      expect(_composerText(tester), isEmpty);
      await disposeApp(tester, services);
    });

    testWidgets('Shift+Enter는 줄바꿈이라 보내지 않는다', (tester) async {
      final services = await createTestServices();
      await pumpApp(tester, services, size: desktop);

      await tester.enterText(find.byKey(composerInput), '점심 9천원');
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pumpAndSettle();

      expect(containerOf(tester).read(reviewSessionProvider), isNull);
      expect(_composerText(tester), '점심 9천원');
      await disposeApp(tester, services);
    });

    testWidgets('보내기 단추는 조합 중이어도 보낸다', (tester) async {
      // 휴대폰의 한글 자판은 마지막 글자를 조합 상태로 둔 채 단추를 누르게 된다.
      final services = await createTestServices();
      await pumpApp(tester, services, size: phone);

      await tester.tap(find.byKey(composerInput));
      await tester.pump();
      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: '점심 9천원',
          selection: TextSelection.collapsed(offset: 6),
          composing: TextRange(start: 5, end: 6),
        ),
      );
      await tester.pump();
      await tester.tap(find.byKey(composerSend));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('review-0')), findsOneWidget);
      await disposeApp(tester, services);
    });

    testWidgets("'>'로 시작하는 글은 명령을 찾는 글이라 거래로 해석하지 않는다", (tester) async {
      final services = await createTestServices();
      await pumpApp(tester, services, size: desktop);

      await tester.enterText(find.byKey(composerInput), '> 점심 9천원');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(containerOf(tester).read(reviewSessionProvider), isNull);
      expect(_composerText(tester), '> 점심 9천원');
      await disposeApp(tester, services);
    });

    testWidgets('다른 곳이 먼저 가져간 키는 처리하지 않는다', (tester) async {
      // 명령 목록이 화살표로 고른 명령을 Enter로 실행할 때 쓰는 자리다.
      final services = await createTestServices();
      await pumpApp(tester, services, size: desktop);
      var taken = 0;
      containerOf(tester)
          .read(composerKeyInterceptorProvider.notifier)
          .set((event) {
            if (event.logicalKey != LogicalKeyboardKey.enter) {
              return KeyEventResult.ignored;
            }
            taken++;
            return KeyEventResult.handled;
          });

      await tester.enterText(find.byKey(composerInput), '점심 9천원');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(taken, greaterThan(0));
      expect(containerOf(tester).read(reviewSessionProvider), isNull);
      await disposeApp(tester, services);
    });
  });

  group('예시 칩과 붙여넣기', () {
    testWidgets('비어 있는 입력창을 누르면 예시 칩이 보이고, 글을 적으면 사라진다', (tester) async {
      final services = await createTestServices();
      await pumpApp(tester, services, size: phone);
      expect(find.byKey(const ValueKey('composer-chips')), findsNothing);

      await tester.tap(find.byKey(composerInput));
      await tester.pumpAndSettle();
      expect(find.text('결제 문자 붙여넣기'), findsOneWidget);
      expect(find.text('어제 점심 9천원'), findsOneWidget);

      // 예시를 누르면 채워 두기만 한다. 보내는 것은 사용자가 한다.
      await tester.tap(find.byKey(const ValueKey('composer-chip-example')));
      await tester.pumpAndSettle();
      expect(_composerText(tester), '어제 점심 9천원');
      expect(find.byKey(const ValueKey('composer-chips')), findsNothing);
      expect(containerOf(tester).read(reviewSessionProvider), isNull);
      await disposeApp(tester, services);
    });

    testWidgets('붙여넣기 칩으로 클립보드의 문자를 채우고 보내면 검토함에 올라간다', (tester) async {
      final services = await createTestServices();
      await pumpApp(tester, services, size: foldable);
      mockClipboard(tester, _cardSms);

      await tester.tap(find.byKey(composerInput));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('composer-chip-paste')));
      await tester.pumpAndSettle();
      expect(_composerText(tester), _cardSms);
      expect(find.byKey(const ValueKey('review-0')), findsNothing);

      await tester.tap(find.byKey(composerSend));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('review-0')), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('review-title-0'))).data,
        '김밥천국 강남점',
      );
      final draft = containerOf(tester)
          .read(reviewSessionProvider)!
          .drafts
          .single;
      expect(draft.source, TxSource.paste);
      await disposeApp(tester, services);
    });

    testWidgets('클립보드가 비어 있으면 그렇게 알린다', (tester) async {
      final services = await createTestServices();
      await pumpApp(tester, services, size: desktop);
      mockClipboard(tester, null);

      await tester.tap(find.byKey(composerInput));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('composer-chip-paste')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('composer-empty-clipboard')),
        findsOneWidget,
      );
      expect(_composerText(tester), isEmpty);
      await disposeApp(tester, services);
    });

    testWidgets('여러 줄 붙여넣기에서 문자를 건마다 읽는다', (tester) async {
      final services = await createTestServices();
      await pumpApp(tester, services, size: desktop);

      await sendFromComposer(tester, '''
$_cardSms

삼성1234승인 홍*동 4,800원 일시불 11/15 09:07 스타벅스 누적80,090원''');

      expect(find.text('2건 읽음'), findsOneWidget);
      expect(find.byKey(const ValueKey('review-0')), findsOneWidget);
      expect(find.byKey(const ValueKey('review-1')), findsOneWidget);
      // 여러 건이면 접어서 한 줄씩 보여 준다.
      expect(find.byKey(const ValueKey('review-amount-0')), findsNothing);
      await disposeApp(tester, services);
    });
  });

  group('못 읽었을 때', () {
    testWidgets('읽지 못했다고 알리고 직접 입력을 권한다. 글은 남긴다', (tester) async {
      final services = await createTestServices();
      await pumpApp(tester, services, size: phone);

      await sendFromComposer(tester, '오늘 저녁은 뭐 먹지');

      expect(find.byKey(const ValueKey('composer-unreadable')), findsOneWidget);
      expect(find.textContaining('읽지 못했습니다'), findsOneWidget);
      expect(containerOf(tester).read(reviewSessionProvider), isNull);
      expect(find.byKey(const ValueKey('review-0')), findsNothing);
      expect(_composerText(tester), '오늘 저녁은 뭐 먹지');

      // 직접 입력: 새 거래 칸이 열린다.
      await tester.tap(find.byKey(const ValueKey('composer-manual')));
      await tester.pumpAndSettle();
      expect(find.text('새 거래'), findsOneWidget);
      expect(find.byKey(const ValueKey('composer-unreadable')), findsNothing);
      await disposeApp(tester, services);
    });

    testWidgets('글을 고치면 안내가 사라진다', (tester) async {
      final services = await createTestServices();
      await pumpApp(tester, services, size: desktop);

      await sendFromComposer(tester, '오늘 저녁은 뭐 먹지');
      expect(find.byKey(const ValueKey('composer-unreadable')), findsOneWidget);

      await tester.enterText(find.byKey(composerInput), '오늘 저녁 2만원');
      await tester.pump();
      expect(find.byKey(const ValueKey('composer-unreadable')), findsNothing);
      await disposeApp(tester, services);
    });

    testWidgets('안내문만 보냈으면 저장할 것이 없다고 알린다', (tester) async {
      final services = await createTestServices();
      await pumpApp(tester, services, size: desktop);

      await sendFromComposer(tester, '[롯데카드]11/16출금예정2,668,841원');

      expect(
        find.byKey(const ValueKey('composer-not-transaction')),
        findsOneWidget,
      );
      expect(containerOf(tester).read(reviewSessionProvider), isNull);
      await disposeApp(tester, services);
    });

    testWidgets('빈 글은 보내지 않는다', (tester) async {
      final services = await createTestServices();
      await pumpApp(tester, services, size: desktop);

      await tester.enterText(find.byKey(composerInput), '   ');
      await tester.tap(find.byKey(composerSend));
      await tester.pumpAndSettle();

      expect(containerOf(tester).read(reviewSessionProvider), isNull);
      expect(find.byKey(const ValueKey('composer-unreadable')), findsNothing);
      await disposeApp(tester, services);
    });
  });

  group('길이 제한', () {
    testWidgets('20,000자를 넘으면 알리고 자른다', (tester) async {
      final services = await createTestServices();
      await pumpApp(tester, services, size: desktop);

      await tester.enterText(find.byKey(composerInput), '가' * 20500);
      await tester.pump();

      expect(_composerText(tester).length, composerMaxLength);
      expect(find.byKey(const ValueKey('composer-truncated')), findsOneWidget);
      expect(find.textContaining('20,000자까지'), findsOneWidget);
      await disposeApp(tester, services);
    });

    testWidgets('밖에서 채운 글도 자른다', (tester) async {
      final services = await createTestServices();
      await pumpApp(tester, services, size: desktop);

      containerOf(tester)
          .read(composerControllerProvider.notifier)
          .fill('나' * 20001);
      await tester.pump();

      expect(_composerText(tester).length, composerMaxLength);
      expect(find.byKey(const ValueKey('composer-truncated')), findsOneWidget);
      await disposeApp(tester, services);
    });

    test('글자의 중간에서 자르지 않는다', () {
      // 가족 이모지는 코드 단위 여러 개로 된 글자 하나다.
      const family = '👨‍👩‍👧';
      final long = family * (composerMaxLength + 5);
      final clipped = clipToMaxLength(long);
      expect(clipped.characters.length, composerMaxLength);
      expect(clipped.endsWith(family), isTrue);
      expect(clipToMaxLength('짧은 글'), '짧은 글');
    });
  });

  group('밖에서 들어온 글', () {
    testWidgets('공유로 받은 글을 채워 두고, 사용자가 보내면 공유로 적는다', (tester) async {
      final services = await createTestServices();
      await pumpApp(tester, services, size: phone);

      containerOf(tester).read(incomingTextProvider.notifier).offer(_cardSms);
      await tester.pumpAndSettle();

      // 채워 두기만 하고 저장하지 않는다.
      expect(_composerText(tester), _cardSms);
      expect(containerOf(tester).read(incomingTextProvider), isNull);
      expect(containerOf(tester).read(reviewSessionProvider), isNull);

      await tester.tap(find.byKey(composerSend));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('review-0')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('review-save')));
      await tester.pumpAndSettle();

      expect((await allTransactions(services)).single.source, TxSource.share);
      expect(
        (await services.db.select(services.db.inputBatches).get())
            .single
            .source,
        TxSource.share,
      );
      await disposeApp(tester, services);
    });
  });

  group('다른 화면으로 보내기', () {
    testWidgets('조회로 보이는 문장은 조회 화면으로 보낸다', (tester) async {
      final services = await createTestServices();
      await pumpAppWith(
        tester,
        services,
        size: desktop,
        overrides: [
          composerQueryDetectorProvider.overrideWithValue(
            (text) => text.contains('얼마'),
          ),
        ],
      );

      await sendFromComposer(tester, '지난달 식비 얼마야?');

      expect(find.byType(QueryScreen), findsOneWidget);
      expect(
        tester.widget<QueryScreen>(find.byType(QueryScreen)).question,
        '지난달 식비 얼마야?',
      );
      expect(containerOf(tester).read(reviewSessionProvider), isNull);
      expect(_composerText(tester), isEmpty);
      await disposeApp(tester, services);
    });

    testWidgets('이미지 입력을 쓸 수 있을 때만 이미지 단추가 붙는다', (tester) async {
      final services = await createTestServices();
      await pumpApp(tester, services, size: desktop);
      expect(find.byKey(const ValueKey('composer-image')), findsNothing);
      await disposeApp(tester, services);

      final second = await createTestServices();
      await pumpAppWith(
        tester,
        second,
        size: desktop,
        overrides: [imageInputAvailableProvider.overrideWithValue(true)],
      );
      expect(find.byTooltip('이미지로 입력'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('composer-image')));
      await tester.pumpAndSettle();
      expect(find.byType(ImageInputScreen), findsOneWidget);
      await disposeApp(tester, second);
    });
  });

  group('세 배치', () {
    for (final (name, size) in [
      ('휴대폰', phone),
      ('큰 휴대폰', largePhone),
      ('태블릿', foldable),
      ('PC', desktop),
    ]) {
      testWidgets('$name: 글자를 200%로 키우고 칩과 안내가 떠도 넘치지 않는다', (tester) async {
        final services = await createTestServices();
        await pumpApp(tester, services, size: size, textScale: 2);

        await tester.tap(find.byKey(composerInput));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('composer-chips')), findsOneWidget);
        expect(tester.takeException(), isNull);

        await sendFromComposer(tester, '오늘 저녁은 뭐 먹지');
        expect(
          find.byKey(const ValueKey('composer-unreadable')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        await disposeApp(tester, services);
      });
    }

    testWidgets('휴대폰: 탭 바로 위에 있고, 칩과 안내는 글 칸 위로 자란다', (tester) async {
      final services = await createTestServices();
      await pumpApp(tester, services, size: phone);

      await tester.tap(find.byKey(composerInput));
      await tester.pumpAndSettle();
      final input = tester.getRect(find.byKey(composerInput));
      final chips = tester.getRect(
        find.byKey(const ValueKey('composer-chips')),
      );
      final tabs = tester.getRect(find.byKey(const ValueKey('nav-bottom')));
      expect(chips.bottom, lessThanOrEqualTo(input.top));
      expect(tabs.top - input.bottom, lessThan(16));
      await disposeApp(tester, services);
    });

    testWidgets('휴대폰: 자판이 올라와 자리가 좁으면 입력창 안에서 스크롤한다', (tester) async {
      final services = await createTestServices();
      await pumpApp(tester, services, size: phone);
      await sendFromComposer(tester, '어제 점심 9천원');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      // 검토하던 것이 남았다는 줄까지 떠 있는 채로 여러 줄을 적는다.
      expect(
        find.byKey(const ValueKey('composer-review-open')),
        findsOneWidget,
      );

      tester.view.viewInsets = const FakeViewPadding(bottom: 420);
      addTearDown(tester.view.resetViewInsets);
      await tester.enterText(
        find.byKey(composerInput),
        List.filled(12, '삼성1234승인 홍*동 100원 일시불 01/09 20:07 편의점').join('\n'),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      // 자판을 뺀 220 가운데 절반 남짓만 쓴다.
      expect(
        tester.getSize(find.byType(ComposerBar)).height,
        lessThanOrEqualTo(150),
      );
      // 글 칸은 보이는 자리에 남는다.
      expect(
        tester.getRect(find.byKey(composerSend)).bottom,
        lessThanOrEqualTo(220),
      );
      await disposeApp(tester, services);
    });

    testWidgets('태블릿 · PC: 내용 위에 있고, 칩은 글 칸 아래에 붙는다', (tester) async {
      for (final size in [foldable, desktop]) {
        final services = await createTestServices();
        await pumpApp(tester, services, size: size);

        await tester.tap(find.byKey(composerInput));
        await tester.pumpAndSettle();
        final input = tester.getRect(find.byKey(composerInput));
        final chips = tester.getRect(
          find.byKey(const ValueKey('composer-chips')),
        );
        expect(input.top, lessThan(60));
        expect(chips.top, greaterThanOrEqualTo(input.bottom));
        await disposeApp(tester, services);
      }
    });

    testWidgets('창 너비를 바꿔 자리가 달라져도 적던 글이 남는다', (tester) async {
      final services = await createTestServices();
      await pumpApp(tester, services, size: desktop);

      await tester.enterText(find.byKey(composerInput), '어제 점심 9천원');
      await tester.pump();

      tester.view.physicalSize = phone;
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('nav-bottom')), findsOneWidget);
      expect(_composerText(tester), '어제 점심 9천원');

      tester.view.physicalSize = foldable;
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('nav-rail')), findsOneWidget);
      expect(_composerText(tester), '어제 점심 9천원');

      await tester.tap(find.byKey(composerSend));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('review-0')), findsOneWidget);
      await disposeApp(tester, services);
    });

    testWidgets('다른 화면의 "입력하기"(openInput)는 입력창으로 보낸다', (tester) async {
      final services = await createTestServices();
      await pumpApp(tester, services, size: desktop);

      await openInput(tester.element(find.byType(AppShell)));
      await tester.pumpAndSettle();
      // 입력창에 초점이 가서 예시 칩이 보인다.
      expect(find.byKey(const ValueKey('composer-chips')), findsOneWidget);

      await openInput(
        tester.element(find.byType(AppShell)),
        initialText: '택시 12000원',
      );
      await tester.pumpAndSettle();
      expect(_composerText(tester), '택시 12000원');
      await disposeApp(tester, services);
    });
  });
}
