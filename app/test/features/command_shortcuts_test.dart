import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gagyebu/app/providers.dart';
import 'package:gagyebu/domain/month_period.dart';
import 'package:gagyebu/features/command/commands.dart';
import 'package:material_ui/material_ui.dart';

import 'command_run_test.dart';
import 'test_app.dart';

KeyEvent _down(
  LogicalKeyboardKey logical, {
  PhysicalKeyboardKey physical = PhysicalKeyboardKey.fn,
  String? character,
}) => KeyDownEvent(
  logicalKey: logical,
  physicalKey: physical,
  character: character,
  timeStamp: Duration.zero,
);

AppShortcut? _resolve(
  KeyEvent event, {
  bool inTextField = false,
  bool control = false,
  bool meta = false,
  bool alt = false,
  bool shift = false,
}) => resolveAppShortcut(
  event,
  inTextField: inTextField,
  control: control,
  meta: meta,
  alt: alt,
  shift: shift,
);

/// 보조키를 누른 채로 [key]를 누른다.
Future<bool> _chord(
  WidgetTester tester,
  LogicalKeyboardKey modifier,
  LogicalKeyboardKey key,
) async {
  await tester.sendKeyDownEvent(modifier);
  final handled = await tester.sendKeyEvent(key);
  await tester.sendKeyUpEvent(modifier);
  await tester.pumpAndSettle();
  return handled;
}

/// '?'를 누른다. 시험의 자판에는 '?' 키가 따로 없어 Shift+/ 로 누른다.
Future<bool> _question(WidgetTester tester) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
  final handled = await tester.sendKeyEvent(
    LogicalKeyboardKey.slash,
    character: '?',
  );
  await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
  return handled;
}

void main() {
  group('키 가리기', () {
    test('글자 한 개짜리 단축키', () {
      expect(_resolve(_down(LogicalKeyboardKey.slash)), AppShortcut.search);
      expect(
        _resolve(_down(LogicalKeyboardKey.question), shift: true),
        AppShortcut.help,
      );
      // 자판에 따라 Shift+/ 로 오기도 한다.
      expect(
        _resolve(_down(LogicalKeyboardKey.slash), shift: true),
        AppShortcut.help,
      );
      expect(
        _resolve(_down(LogicalKeyboardKey.bracketLeft)),
        AppShortcut.previousMonth,
      );
      expect(
        _resolve(_down(LogicalKeyboardKey.bracketRight)),
        AppShortcut.nextMonth,
      );
      expect(_resolve(_down(LogicalKeyboardKey.keyA)), isNull);
      // Shift+[ 는 '{'다.
      expect(
        _resolve(_down(LogicalKeyboardKey.bracketLeft), shift: true),
        isNull,
      );
    });

    test('글 칸 안에서는 글자 한 개짜리 단축키와 되돌리기를 듣지 않는다', () {
      for (final key in [
        LogicalKeyboardKey.slash,
        LogicalKeyboardKey.question,
        LogicalKeyboardKey.bracketLeft,
        LogicalKeyboardKey.bracketRight,
      ]) {
        expect(_resolve(_down(key), inTextField: true), isNull);
      }
      expect(
        _resolve(
          _down(LogicalKeyboardKey.keyZ),
          control: true,
          inTextField: true,
        ),
        isNull,
      );
      // 입력창으로 가는 키는 글 칸 안에서도 듣는다.
      expect(
        _resolve(
          _down(LogicalKeyboardKey.keyK),
          control: true,
          inTextField: true,
        ),
        AppShortcut.focusComposer,
      );
    });

    test('키 이름을 알려 주지 않아도 낸 글자로 알아본다', () {
      // 한글 입력기가 켜진 브라우저는 키 이름 대신 'Process'를 준다.
      expect(
        _resolve(_down(LogicalKeyboardKey.process, character: '[')),
        AppShortcut.previousMonth,
      );
      expect(
        _resolve(_down(LogicalKeyboardKey.unidentified, character: '?')),
        AppShortcut.help,
      );
      // 글자도 없으면 자판의 자리로 본다.
      expect(
        _resolve(
          _down(
            LogicalKeyboardKey.process,
            physical: PhysicalKeyboardKey.bracketRight,
          ),
        ),
        AppShortcut.nextMonth,
      );
      expect(
        _resolve(
          _down(
            LogicalKeyboardKey.process,
            physical: PhysicalKeyboardKey.slash,
          ),
        ),
        AppShortcut.search,
      );
      // 다른 글자를 낸 키는 자리가 같아도 단축키가 아니다(독일어 자판의 'ü').
      expect(
        _resolve(
          _down(
            const LogicalKeyboardKey(0xfc),
            physical: PhysicalKeyboardKey.bracketLeft,
            character: 'ü',
          ),
        ),
        isNull,
      );
    });

    test('한글 자판이 켜져 있어도 Ctrl+K · Ctrl+Z를 알아본다', () {
      // 'ㅏ'(K 자리), 'ㅋ'(Z 자리).
      expect(
        _resolve(
          _down(
            const LogicalKeyboardKey(0x314f),
            physical: PhysicalKeyboardKey.keyK,
          ),
          control: true,
        ),
        AppShortcut.focusComposer,
      );
      expect(
        _resolve(
          _down(
            const LogicalKeyboardKey(0x314b),
            physical: PhysicalKeyboardKey.keyZ,
          ),
          control: true,
        ),
        AppShortcut.undo,
      );
      // 영문 글자로 알려 준 키는 자리로 보지 않는다(드보락의 K 자리는 't'다).
      expect(
        _resolve(
          _down(LogicalKeyboardKey.keyT, physical: PhysicalKeyboardKey.keyK),
          control: true,
        ),
        isNull,
      );
    });

    test('보조키: 브라우저가 쓰는 키와 다른 조합은 건드리지 않는다', () {
      for (final key in [
        LogicalKeyboardKey.keyN,
        LogicalKeyboardKey.keyT,
        LogicalKeyboardKey.keyW,
        LogicalKeyboardKey.keyR,
        LogicalKeyboardKey.keyL,
        LogicalKeyboardKey.keyF,
        LogicalKeyboardKey.keyP,
        LogicalKeyboardKey.keyS,
      ]) {
        expect(_resolve(_down(key), control: true), isNull);
      }
      // 다시 하기(Ctrl+Shift+Z)와 Alt · Ctrl이 낀 글자 키.
      expect(
        _resolve(_down(LogicalKeyboardKey.keyZ), control: true, shift: true),
        isNull,
      );
      expect(_resolve(_down(LogicalKeyboardKey.slash), alt: true), isNull);
      expect(
        _resolve(_down(LogicalKeyboardKey.bracketLeft), control: true),
        isNull,
      );
      expect(
        _resolve(
          const KeyUpEvent(
            logicalKey: LogicalKeyboardKey.slash,
            physicalKey: PhysicalKeyboardKey.slash,
            timeStamp: Duration.zero,
          ),
        ),
        isNull,
      );
    });

    test('누르고 있으면 달은 계속 넘어가고, 검색 · 도움말은 한 번만 한다', () {
      KeyEvent repeat(LogicalKeyboardKey key) => KeyRepeatEvent(
        logicalKey: key,
        physicalKey: PhysicalKeyboardKey.fn,
        timeStamp: Duration.zero,
      );
      expect(
        _resolve(repeat(LogicalKeyboardKey.bracketRight)),
        AppShortcut.nextMonth,
      );
      expect(_resolve(repeat(LogicalKeyboardKey.slash)), isNull);
      expect(_resolve(repeat(LogicalKeyboardKey.question)), isNull);
    });

    test('Mac에서는 ⌘이 보조키다', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      expect(
        _resolve(_down(LogicalKeyboardKey.keyK), meta: true),
        AppShortcut.focusComposer,
      );
      expect(
        _resolve(_down(LogicalKeyboardKey.keyZ), meta: true),
        AppShortcut.undo,
      );
      // Mac의 Ctrl+K는 글 칸에서 줄 끝까지 지우는 키다.
      expect(_resolve(_down(LogicalKeyboardKey.keyK), control: true), isNull);
      expect(modifierShortcut('K'), '⌘K');
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      expect(_resolve(_down(LogicalKeyboardKey.keyK), meta: true), isNull);
      expect(modifierShortcut('K'), 'Ctrl+K');
      debugDefaultTargetPlatformOverride = null;
    });
  });

  group('단축키', () {
    testWidgets('[ 와 ] 로 달을 넘긴다', (tester) async {
      final container = await pumpCommands(tester);
      MonthPeriod period() => container.read(selectedPeriodProvider);

      expect(await tester.sendKeyEvent(LogicalKeyboardKey.bracketLeft), isTrue);
      expect((period().year, period().month), (2026, 10));
      await tester.sendKeyEvent(LogicalKeyboardKey.bracketRight);
      await tester.sendKeyEvent(LogicalKeyboardKey.bracketRight);
      expect((period().year, period().month), (2026, 12));
    });

    testWidgets('글 칸 안에서는 글자 한 개짜리 단축키를 듣지 않는다', (tester) async {
      final container = await pumpCommands(tester);
      final before = container.read(selectedPeriodProvider);
      await tester.tap(find.byKey(const ValueKey('field')));
      await tester.pump();
      expect(focusIsInTextField(), isTrue);

      for (final key in [
        LogicalKeyboardKey.bracketLeft,
        LogicalKeyboardKey.bracketRight,
        LogicalKeyboardKey.slash,
      ]) {
        expect(await tester.sendKeyEvent(key), isFalse, reason: key.keyLabel);
      }
      expect(await _question(tester), isFalse);
      await tester.pumpAndSettle();
      expect(container.read(selectedPeriodProvider).key, before.key);
      expect(locationOf(tester), '/');
      expect(find.byKey(const ValueKey('shortcuts-help')), findsNothing);
      expect(container.read(transactionSearchFocusRequestProvider), isFalse);

      // 글 칸에서 나오면 다시 듣는다.
      FocusManager.instance.primaryFocus!.unfocus();
      await tester.pump();
      expect(focusIsInTextField(), isFalse);
      await tester.sendKeyEvent(LogicalKeyboardKey.bracketLeft);
      expect(container.read(selectedPeriodProvider).key, before.previous.key);
    });

    testWidgets('/ 는 내역 검색으로 간다', (tester) async {
      final container = await pumpCommands(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.slash);
      await tester.pumpAndSettle();
      expect(locationOf(tester), '/transactions');
      // 이 틀에는 내역 화면이 없다. 요청이 올라간 것까지만 본다.
      expect(container.read(transactionSearchFocusRequestProvider), isTrue);
    });

    testWidgets('? 는 도움말을 열고, 대화상자가 떠 있는 동안에는 듣지 않는다', (tester) async {
      final container = await pumpCommands(tester);
      final before = container.read(selectedPeriodProvider);
      expect(await _question(tester), isTrue);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('shortcuts-help')), findsOneWidget);

      // 대화상자 뒤에서 달이 넘어가거나 도움말이 겹쳐 뜨지 않는다.
      await tester.sendKeyEvent(LogicalKeyboardKey.bracketLeft);
      await _question(tester);
      await tester.pumpAndSettle();
      expect(container.read(selectedPeriodProvider).key, before.key);
      expect(find.byKey(const ValueKey('shortcuts-help')), findsOneWidget);
      expect(
        await _chord(
          tester,
          LogicalKeyboardKey.controlLeft,
          LogicalKeyboardKey.keyK,
        ),
        isFalse,
      );
      expect(container.read(composerFocusRequestProvider), 0);

      await tester.tap(find.byKey(const ValueKey('shortcuts-help-close')));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.bracketLeft);
      expect(container.read(selectedPeriodProvider).key, before.previous.key);
    });

    testWidgets('Ctrl+K 는 글 칸 안팎에서 입력창 초점을 청한다', (tester) async {
      final container = await pumpCommands(tester);
      expect(
        await _chord(
          tester,
          LogicalKeyboardKey.controlLeft,
          LogicalKeyboardKey.keyK,
        ),
        isTrue,
      );
      expect(container.read(composerFocusRequestProvider), 1);

      await tester.tap(find.byKey(const ValueKey('field')));
      await tester.pump();
      await _chord(
        tester,
        LogicalKeyboardKey.controlLeft,
        LogicalKeyboardKey.keyK,
      );
      expect(container.read(composerFocusRequestProvider), 2);

      // 보조키 없는 K는 아무 일도 하지 않는다.
      FocusManager.instance.primaryFocus!.unfocus();
      await tester.pump();
      expect(await tester.sendKeyEvent(LogicalKeyboardKey.keyK), isFalse);
      expect(container.read(composerFocusRequestProvider), 2);
    });

    testWidgets('Mac에서는 ⌘K 다', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      final container = await pumpCommands(tester);
      await _chord(
        tester,
        LogicalKeyboardKey.controlLeft,
        LogicalKeyboardKey.keyK,
      );
      expect(container.read(composerFocusRequestProvider), 0);
      await _chord(
        tester,
        LogicalKeyboardKey.metaLeft,
        LogicalKeyboardKey.keyK,
      );
      expect(container.read(composerFocusRequestProvider), 1);

      // 목록의 표기도 ⌘ 이다.
      await tester.enterText(find.byKey(const ValueKey('field')), '>도움말');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('command-shortcuts-help')));
      await tester.pumpAndSettle();
      expect(find.text('⌘K'), findsOneWidget);
      expect(find.text('Ctrl+K'), findsNothing);
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('Ctrl+Z 는 글 칸 밖에서만 마지막 묶음을 되돌린다', (tester) async {
      var undone = 0;
      await pumpCommands(
        tester,
        undo: () async {
          undone++;
          return '2건을 되돌렸습니다';
        },
      );

      // 글 칸 안: 글 고치기의 되돌리기에 맡긴다.
      await tester.tap(find.byKey(const ValueKey('field')));
      await tester.pump();
      await _chord(
        tester,
        LogicalKeyboardKey.controlLeft,
        LogicalKeyboardKey.keyZ,
      );
      expect(undone, 0);

      FocusManager.instance.primaryFocus!.unfocus();
      await tester.pump();
      expect(
        await _chord(
          tester,
          LogicalKeyboardKey.controlLeft,
          LogicalKeyboardKey.keyZ,
        ),
        isTrue,
      );
      expect(undone, 1);
      expect(find.text('2건을 되돌렸습니다'), findsOneWidget);
    });

    testWidgets('되돌리기가 이어지지 않았으면 Ctrl+Z 를 가져가지 않는다', (tester) async {
      await pumpCommands(tester);
      expect(
        await _chord(
          tester,
          LogicalKeyboardKey.controlLeft,
          LogicalKeyboardKey.keyZ,
        ),
        isFalse,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('뼈대가 사라지면 더 듣지 않는다', (tester) async {
      await pumpCommands(tester);
      expect(await tester.sendKeyEvent(LogicalKeyboardKey.bracketLeft), isTrue);
      await tester.pumpWidget(const SizedBox());
      expect(
        await tester.sendKeyEvent(LogicalKeyboardKey.bracketLeft),
        isFalse,
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('실제 뼈대에서', () {
    testWidgets('PC 배치: 단축키로 달을 넘기고 도움말을 연다', (tester) async {
      final services = await createTestServices();
      await pumpApp(tester, services, size: desktop);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(AppShortcuts)),
      );
      final before = container.read(selectedPeriodProvider);

      await tester.sendKeyEvent(LogicalKeyboardKey.bracketRight);
      await tester.pumpAndSettle();
      expect(container.read(selectedPeriodProvider).key, before.next.key);
      await tester.sendKeyEvent(LogicalKeyboardKey.bracketLeft);
      await tester.pumpAndSettle();

      // 입력창에 글을 적는 동안에는 듣지 않는다.
      await tester.tap(find.byKey(const ValueKey('composer-input')));
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.bracketLeft);
      await _question(tester);
      await tester.pumpAndSettle();
      expect(container.read(selectedPeriodProvider).key, before.key);
      expect(find.byKey(const ValueKey('shortcuts-help')), findsNothing);

      FocusManager.instance.primaryFocus!.unfocus();
      await tester.pump();
      await _question(tester);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('shortcuts-help')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('shortcuts-help-close')));
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.slash);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('period-label')), findsWidgets);
      // 내역 화면이 요청을 가져가 검색 칸에 초점을 준다.
      expect(container.read(transactionSearchFocusRequestProvider), isFalse);
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('transaction-search')))
            .focusNode!
            .hasFocus,
        isTrue,
      );
      expect(tester.takeException(), isNull);
      await disposeApp(tester, services);
    });
  });
}
