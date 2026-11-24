import 'package:flutter_test/flutter_test.dart';
import 'package:gagyebu/core/breakpoints.dart';
import 'package:material_ui/material_ui.dart';

import 'package:gagyebu/features/budget/budget_screen.dart';
import 'package:gagyebu/features/settings/settings_screen.dart';

import 'test_app.dart';

void main() {
  group('WindowSize', () {
    test('너비 등급의 경계', () {
      expect(WindowSize.fromWidth(359), WindowSize.compact);
      expect(WindowSize.fromWidth(599.9), WindowSize.compact);
      expect(WindowSize.fromWidth(600), WindowSize.medium);
      expect(WindowSize.fromWidth(839.9), WindowSize.medium);
      expect(WindowSize.fromWidth(840), WindowSize.expanded);
      expect(WindowSize.fromWidth(1920), WindowSize.expanded);
    });
  });

  group('바깥 틀은 창 너비에 따라 메뉴 자리를 바꾼다', () {
    testWidgets('좁음: 하단 탭 네 개와 그 위의 입력창', (tester) async {
      final services = await createTestServices();
      await pumpApp(tester, services, size: phone);
      expect(find.byKey(const ValueKey('nav-bottom')), findsOneWidget);
      expect(find.byKey(const ValueKey('nav-rail')), findsNothing);
      expect(find.byKey(const ValueKey('nav-side')), findsNothing);
      // 떠 있는 단추는 목록의 금액을 가리므로 쓰지 않는다.
      expect(find.byType(FloatingActionButton), findsNothing);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('nav-bottom')),
          matching: find.byType(NavigationDestination),
        ),
        findsNWidgets(4),
      );
      // 입력창은 탭 바로 위에 있다.
      final composer = tester.getRect(
        find.byKey(const ValueKey('composer-input')),
      );
      final tabs = tester.getRect(find.byKey(const ValueKey('nav-bottom')));
      expect(composer.bottom, lessThanOrEqualTo(tabs.top));
      expect(tabs.top - composer.bottom, lessThan(16));
      expect(find.text('2026년 11월'), findsOneWidget);
      await disposeApp(tester, services);
    });

    testWidgets('중간: 옆 메뉴(레일)', (tester) async {
      final services = await createTestServices();
      await pumpApp(tester, services, size: foldable);
      expect(find.byKey(const ValueKey('nav-rail')), findsOneWidget);
      expect(find.byKey(const ValueKey('nav-bottom')), findsNothing);
      expect(find.byKey(const ValueKey('nav-side')), findsNothing);
      // 입력창은 내용 위쪽에 있다.
      expect(
        tester.getRect(find.byKey(const ValueKey('composer-input'))).top,
        lessThan(60),
      );
      await disposeApp(tester, services);
    });

    testWidgets('넓음: 이름이 보이는 왼쪽 메뉴', (tester) async {
      final services = await createTestServices();
      await pumpApp(tester, services, size: desktop);
      expect(find.byKey(const ValueKey('nav-side')), findsOneWidget);
      expect(find.byKey(const ValueKey('nav-bottom')), findsNothing);
      expect(find.byKey(const ValueKey('nav-rail')), findsNothing);
      expect(find.text('이 기기에 저장됨'), findsOneWidget);
      expect(find.byKey(const ValueKey('composer-input')), findsOneWidget);

      // 옆 메뉴에는 탭에 없는 자산 · 예산도 있다.
      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey('nav-side')),
          matching: find.text('예산'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(BudgetScreen), findsOneWidget);
      await disposeApp(tester, services);
    });

    testWidgets('창을 넓히면 배치가 바뀌고 보던 화면은 그대로다', (tester) async {
      final services = await createTestServices();
      await pumpApp(tester, services, size: phone, location: '/stats');
      expect(find.byKey(const ValueKey('nav-bottom')), findsOneWidget);
      expect(find.text('날짜별 지출'), findsOneWidget);

      tester.view.physicalSize = desktop;
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('nav-side')), findsOneWidget);
      expect(find.text('날짜별 지출'), findsOneWidget);
      await disposeApp(tester, services);
    });
  });

  group('월 표시는 어느 너비에서도 한 줄이다', () {
    for (final width in [360.0, 599.0, 600.0, 700.0, 839.0, 840.0, 1280.0]) {
      testWidgets('내역 화면 ${width.toInt()}dp', (tester) async {
        final services = await createTestServices();
        await pumpApp(
          tester,
          services,
          size: Size(width, 800),
          location: '/transactions',
        );
        final label = find.byKey(const ValueKey('period-label'));
        expect(label, findsOneWidget);
        // 한 줄이면 높이가 글자 한 줄 남짓이다. 줄이 바뀌면 두 배 이상이 된다.
        expect(tester.getSize(label).height, lessThan(40));
        expect(tester.takeException(), isNull);
        await disposeApp(tester, services);
      });
    }
  });

  group('탭 이동', () {
    for (final (name, size) in [
      ('좁음', phone),
      ('중간', foldable),
      ('넓음', desktop),
    ]) {
      testWidgets('$name 창에서 네 화면을 오간다', (tester) async {
        final services = await createTestServices();
        await pumpApp(tester, services, size: size);

        await tester.tap(find.text('내역').last);
        await tester.pumpAndSettle();
        expect(find.text('이 달의 내역이 없습니다'), findsOneWidget);

        await tester.tap(find.text('통계').last);
        await tester.pumpAndSettle();
        expect(find.text('날짜별 지출'), findsOneWidget);

        await tester.tap(find.text('설정').last);
        await tester.pumpAndSettle();
        expect(find.text('설정'), findsWidgets);
        // 자산과 분류는 설정에서 고치지 않는다. '관리'의 목록에서 그 화면으로 간다.
        expect(find.text('월 시작일'), findsOneWidget);
        // 아래쪽 카드는 화면을 내려야 그려진다.
        // 입력창의 글 칸도 스크롤되는 위젯이라, 설정 화면 안의 것을 고른다.
        await tester.scrollUntilVisible(
          find.text('시험용 메모리'),
          200,
          scrollable: find
              .descendant(
                of: find.byType(SettingsScreen),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        expect(find.text('시험용 메모리'), findsOneWidget);

        await tester.tap(find.text('홈').last);
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('total-expense')), findsOneWidget);
        await disposeApp(tester, services);
      });
    }
  });

  group('글자를 200%로 키워도 넘치지 않는다', () {
    for (final location in [
      '/',
      '/transactions',
      '/stats',
      '/settings',
      '/input',
    ]) {
      testWidgets('소형 폰 $location', (tester) async {
        final services = await createTestServices();
        await pumpApp(
          tester,
          services,
          size: phone,
          location: location,
          textScale: 2,
        );
        // 넘침은 시험에서 예외로 잡힌다.
        expect(tester.takeException(), isNull);
        await disposeApp(tester, services);
      });
    }

    testWidgets('소형 폰을 가로로 돌려도 넘치지 않는다', (tester) async {
      final services = await createTestServices();
      await pumpApp(tester, services, size: const Size(640, 360));
      expect(tester.takeException(), isNull);
      await disposeApp(tester, services);
    });
  });
}
