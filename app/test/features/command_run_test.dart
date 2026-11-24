import 'dart:ui' show Tristate;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gagyebu/app/providers.dart';
import 'package:gagyebu/app/sync_controller.dart';
import 'package:gagyebu/app/theme/theme_setting.dart';
import 'package:gagyebu/data/server/server_connection.dart';
import 'package:gagyebu/domain/month_period.dart';
import 'package:gagyebu/features/command/commands.dart';
import 'package:gagyebu/features/composer/composer_state.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import 'test_app.dart';

/// 서버 없이 로그인 · 동기화를 흉내 낸다.
class FakeSync extends SyncController {
  FakeSync({this.signedIn = true});

  final bool signedIn;

  /// true면 동기화가 실패한 것으로 끝난다.
  bool fail = false;
  int synced = 0;
  int signedOut = 0;

  @override
  SyncStatus build() => signedIn
      ? const SyncStatus(SyncPhase.idle, user: AuthUser(id: 'user-1'))
      : const SyncStatus(SyncPhase.unavailable);

  @override
  Future<void> syncNow() async {
    synced++;
    if (fail) state = SyncStatus(SyncPhase.failed, user: state.user);
  }

  @override
  Future<void> signOut() async {
    signedOut++;
    state = const SyncStatus(SyncPhase.signedOut);
  }
}

/// 명령이 가는 화면의 주소.
const commandPaths = [
  '/',
  '/transactions',
  '/stats',
  '/accounts',
  '/categories',
  '/budget',
  '/recurring',
  '/history',
  '/settings',
];

/// 입력창 흉내: 글 칸 아래에 명령 목록을 붙이고 ↑ ↓ Enter Esc를 이어 준다.
class CommandHarness extends ConsumerStatefulWidget {
  const CommandHarness({super.key});

  @override
  ConsumerState<CommandHarness> createState() => _CommandHarnessState();
}

class _CommandHarnessState extends ConsumerState<CommandHarness> {
  final _text = TextEditingController();

  /// Enter가 명령으로 가지 않아 거래 해석으로 넘어간 글.
  String? submitted;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.arrowUp) {
      final delta = key == LogicalKeyboardKey.arrowDown ? 1 : -1;
      return moveCommandSelection(ref, _text.text, delta)
          ? KeyEventResult.handled
          : KeyEventResult.ignored;
    }
    if (key == LogicalKeyboardKey.escape) {
      ref.read(commandSelectionProvider.notifier).clear();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter) {
      if (runSelectedCommand(context, ref, _text.text)) {
        _text.clear();
      } else {
        setState(() => submitted = _text.text);
      }
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Focus(
        onKeyEvent: _onKey,
        child: TextField(key: const ValueKey('field'), controller: _text),
      ),
      ListenableBuilder(
        listenable: _text,
        builder: (context, _) =>
            CommandSuggestionList(query: _text.text, onRun: _text.clear),
      ),
      if (submitted != null) Text('보냄: $submitted'),
    ],
  );
}

/// 명령과 단축키만 올린 작은 앱을 띄운다. 화면은 주소만 보여 준다.
Future<ProviderContainer> pumpCommands(
  WidgetTester tester, {
  Size size = desktop,
  double textScale = 1,
  FakeSync? sync,
  UndoLastBatch? undo,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

  final router = GoRouter(
    initialLocation: '/',
    routes: [
      ShellRoute(
        builder: (context, state, child) => AppShortcuts(
          child: Scaffold(
            body: Column(
              children: [
                const CommandHarness(),
                Text('${state.uri}', key: const ValueKey('location')),
                Expanded(child: child),
              ],
            ),
          ),
        ),
        routes: [
          for (final path in commandPaths)
            GoRoute(path: path, builder: (context, state) => Text('화면 $path')),
        ],
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        clockProvider.overrideWithValue(() => testNow),
        monthStartDayProvider.overrideWithValue(1),
        syncControllerProvider.overrideWith(() => sync ?? FakeSync()),
        if (undo != null) undoLastBatchProvider.overrideWithValue(undo),
      ],
      child: Consumer(
        builder: (context, ref, _) {
          final theme = ref.watch(themeControllerProvider);
          return ListenableBuilder(
            listenable: theme,
            builder: (context, _) => MaterialApp.router(
              theme: theme.light,
              darkTheme: theme.dark,
              themeMode: theme.mode,
              routerConfig: router,
            ),
          );
        },
      ),
    ),
  );
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(CommandHarness)));
}

String locationOf(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const ValueKey('location'))).data!;

/// 글 칸에 '>이름'을 적고 그 명령의 줄을 누른다.
Future<void> runByTap(WidgetTester tester, String query, String id) async {
  await tester.enterText(find.byKey(const ValueKey('field')), query);
  await tester.pump();
  final row = find.byKey(ValueKey('command-$id'));
  await tester.ensureVisible(row);
  await tester.pump();
  await tester.tap(row);
  await tester.pumpAndSettle();
}

/// 시험이 클립보드에 넣어 둔 글. null이면 클립보드가 비어 있다.
void mockClipboard(WidgetTester tester, String? text, {bool denied = false}) {
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async {
      if (call.method != 'Clipboard.getData') return null;
      if (denied) throw PlatformException(code: 'denied');
      return text == null ? null : {'text': text};
    },
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    ),
  );
}

void main() {
  group('목록 위젯', () {
    testWidgets('맞는 명령이 없으면 아무것도 그리지 않는다', (tester) async {
      await pumpCommands(tester);
      final list = find.byKey(const ValueKey('command-list'));
      expect(list, findsNothing);
      expect(tester.getSize(find.byType(CommandSuggestionList)), Size.zero);

      // 거래를 적는 글, 한 글자, 없는 명령.
      for (final text in ['어제 점심 9천원', '홈', '>없는명령']) {
        await tester.enterText(find.byKey(const ValueKey('field')), text);
        await tester.pump();
        expect(list, findsNothing, reason: text);
        expect(tester.getSize(find.byType(CommandSuggestionList)), Size.zero);
      }
    });

    testWidgets('맞는 명령을 아이콘 · 이름 · 단축키와 함께 보여 준다', (tester) async {
      await pumpCommands(tester);
      await tester.enterText(find.byKey(const ValueKey('field')), '이전');
      await tester.pump();

      final row = find.byKey(const ValueKey('command-month-previous'));
      expect(row, findsOneWidget);
      expect(find.descendant(of: row, matching: find.text('이전 달')), findsOne);
      expect(find.descendant(of: row, matching: find.text('[')), findsOne);
      expect(
        find.descendant(of: row, matching: find.byIcon(Icons.chevron_left)),
        findsOne,
      );
      // 목록은 글 칸 바로 아래에 붙는다.
      final field = tester.getRect(find.byKey(const ValueKey('field')));
      final list = tester.getRect(find.byKey(const ValueKey('command-list')));
      expect(list.top, greaterThanOrEqualTo(field.bottom));
      expect(list.top - field.bottom, lessThan(8));
    });

    testWidgets('누르면 실행하고 onRun을 부른다', (tester) async {
      await pumpCommands(tester);
      await runByTap(tester, '예산', 'go-budget');
      expect(locationOf(tester), '/budget');
      // onRun이 글 칸을 비웠고, 목록도 사라졌다.
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('field')))
            .controller!
            .text,
        isEmpty,
      );
      expect(find.byKey(const ValueKey('command-list')), findsNothing);
    });

    testWidgets("'>'만 적으면 전부 보여 주고, 화살표로 가려진 줄까지 간다", (tester) async {
      final container = await pumpCommands(tester);
      final count = container.read(commandsProvider).length;
      await tester.tap(find.byKey(const ValueKey('field')));
      await tester.enterText(find.byKey(const ValueKey('field')), '>');
      await tester.pump();

      // 여섯 줄 남짓의 높이를 넘지 않는다.
      final list = find.byKey(const ValueKey('command-list'));
      expect(tester.getSize(list).height, lessThanOrEqualTo(280));

      // 위로 한 번이면 맨 끝 줄로 넘어가고, 그 줄이 보이게 굴러간다.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();
      expect(
        container.read(commandSelectionProvider),
        CommandPick('>', count - 1),
      );
      final last = tester.getRect(
        find.byKey(const ValueKey('command-sign-out')),
      );
      expect(last.bottom, lessThanOrEqualTo(tester.getRect(list).bottom));
      expect(last.top, greaterThanOrEqualTo(tester.getRect(list).top));
    });

    for (final (name, size) in [
      ('360×640', phone),
      ('412×915', largePhone),
      ('700×800', foldable),
      ('1280×800', desktop),
    ]) {
      testWidgets('글자 크기 200%에서도 넘치지 않는다 ($name)', (tester) async {
        await pumpCommands(
          tester,
          size: size,
          textScale: 2,
          undo: () async => null,
        );
        for (final text in ['>', '>마지막', '>테마', '이동']) {
          await tester.enterText(find.byKey(const ValueKey('field')), text);
          await tester.pumpAndSettle();
          expect(find.byKey(const ValueKey('command-list')), findsOneWidget);
          expect(tester.takeException(), isNull, reason: text);
        }
      });
    }
  });

  group('화살표와 Enter', () {
    testWidgets("'>' 없이 적은 글의 Enter는 명령이 아니라 거래 해석으로 간다", (tester) async {
      await pumpCommands(tester);
      await tester.tap(find.byKey(const ValueKey('field')));
      await tester.enterText(find.byKey(const ValueKey('field')), '예산');
      await tester.pump();
      expect(find.byKey(const ValueKey('command-go-budget')), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(locationOf(tester), '/');
      expect(find.text('보냄: 예산'), findsOneWidget);
    });

    testWidgets('화살표로 고르고 Enter면 그 명령을 실행한다', (tester) async {
      final container = await pumpCommands(tester);
      await tester.tap(find.byKey(const ValueKey('field')));
      await tester.enterText(find.byKey(const ValueKey('field')), '테마');
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(
        container.read(commandSelectionProvider),
        const CommandPick('테마', 2),
      );
      // 고른 줄은 '선택됨'으로 읽힌다.
      expect(
        tester
            .getSemantics(find.byKey(const ValueKey('command-theme-tool')))
            .flagsCollection
            .isSelected,
        Tristate.isTrue,
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(
        container.read(themeControllerProvider).value.tone,
        ThemeTone.tool,
      );
      expect(container.read(commandSelectionProvider), isNull);
      expect(find.byKey(const ValueKey('command-list')), findsNothing);
    });

    testWidgets("'>'로 찾으면 고르지 않아도 Enter가 첫 줄을 실행한다", (tester) async {
      await pumpCommands(tester);
      await tester.tap(find.byKey(const ValueKey('field')));
      await tester.enterText(find.byKey(const ValueKey('field')), '>통계');
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(locationOf(tester), '/stats');
    });

    testWidgets('끝에서 반대쪽으로 넘어가고, Esc는 고른 것을 푼다', (tester) async {
      final container = await pumpCommands(tester);
      await tester.tap(find.byKey(const ValueKey('field')));
      await tester.enterText(find.byKey(const ValueKey('field')), '테마');
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      expect(
        container.read(commandSelectionProvider),
        const CommandPick('테마', 3),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      expect(
        container.read(commandSelectionProvider),
        const CommandPick('테마', 0),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      expect(container.read(commandSelectionProvider), isNull);

      // 목록이 없으면 화살표를 가져가지 않는다(글 칸의 커서가 움직이게 둔다).
      await tester.enterText(find.byKey(const ValueKey('field')), '어제 점심');
      await tester.pump();
      expect(moveCommandSelection(_refOf(tester), '어제 점심', 1), isFalse);
      expect(container.read(commandSelectionProvider), isNull);
    });
  });

  group('명령 실행', () {
    testWidgets('화면 이동 아홉 개', (tester) async {
      await pumpCommands(tester);
      for (final (query, id, path) in [
        ('>내역으로', 'go-transactions', '/transactions'),
        ('>통계', 'go-stats', '/stats'),
        ('>자산', 'go-accounts', '/accounts'),
        ('>분류', 'go-categories', '/categories'),
        ('>예산', 'go-budget', '/budget'),
        ('>반복', 'go-recurring', '/recurring'),
        ('>작업 기록', 'go-history', '/history'),
        ('>설정', 'go-settings', '/settings'),
        ('>홈', 'go-home', '/'),
      ]) {
        await runByTap(tester, query, id);
        expect(locationOf(tester), path, reason: id);
        expect(find.text('화면 $path'), findsOneWidget, reason: id);
      }
    });

    testWidgets('새 지출 · 새 수입 · 새 이체', (tester) async {
      await pumpCommands(tester);
      for (final type in ['expense', 'income', 'transfer']) {
        await runByTap(tester, '>$type', 'new-$type');
        expect(locationOf(tester), '/transactions?new=$type');
      }
    });

    testWidgets('이전 달 · 다음 달 · 이번 달', (tester) async {
      final container = await pumpCommands(tester);
      MonthPeriod period() => container.read(selectedPeriodProvider);
      expect((period().year, period().month), (2026, 11));

      await runByTap(tester, '>이전', CommandIds.previousMonth);
      expect((period().year, period().month), (2026, 10));
      await runByTap(tester, '>다음', CommandIds.nextMonth);
      await runByTap(tester, '>다음', CommandIds.nextMonth);
      await runByTap(tester, '>next', CommandIds.nextMonth);
      expect((period().year, period().month), (2027, 1));
      await runByTap(tester, '>이번', CommandIds.currentMonth);
      expect((period().year, period().month), (2026, 11));
    });

    testWidgets('내역 검색: 내역으로 가고 검색 칸 초점을 청한다', (tester) async {
      final container = await pumpCommands(tester);
      await runByTap(tester, '>검색', CommandIds.search);
      expect(locationOf(tester), '/transactions');
      final request = container.read(
        transactionSearchFocusRequestProvider.notifier,
      );
      // 내역 화면이 가져가면 비워진다.
      expect(request.take(), isTrue);
      expect(request.take(), isFalse);
    });

    testWidgets('테마 바꾸기: 톤 넷', (tester) async {
      final container = await pumpCommands(tester);
      final controller = container.read(themeControllerProvider);
      for (final tone in [
        ThemeTone.ledger,
        ThemeTone.tool,
        ThemeTone.quiet,
        ThemeTone.system,
      ]) {
        await runByTap(tester, '>테마', CommandIds.theme(tone));
        expect(controller.value.tone, tone);
      }
      // 화면에도 바로 반영된다.
      await runByTap(tester, '>theme', CommandIds.theme(ThemeTone.ledger));
      final context = tester.element(find.byType(CommandHarness));
      expect(Theme.of(context).colorScheme, controller.light.colorScheme);
    });

    testWidgets('단축키 도움말: 표로 된 대화상자', (tester) async {
      await pumpCommands(tester);
      await runByTap(tester, '>도움말', CommandIds.shortcutsHelp);
      final dialog = find.byKey(const ValueKey('shortcuts-help'));
      expect(dialog, findsOneWidget);
      expect(
        find.descendant(of: dialog, matching: find.byType(Table)),
        findsWidgets,
      );
      for (final text in [
        'Ctrl+K',
        'Ctrl+Z',
        'Ctrl+Enter',
        '/',
        '?',
        '[',
        ']',
        '내역 검색',
        '이전 달',
        '다음 달',
        '모두 승인하고 저장',
      ]) {
        expect(
          find.descendant(of: dialog, matching: find.text(text)),
          findsOneWidget,
          reason: text,
        );
      }
      await tester.tap(find.byKey(const ValueKey('shortcuts-help-close')));
      await tester.pumpAndSettle();
      expect(dialog, findsNothing);
    });

    for (final (name, size) in [
      ('360×640', phone),
      ('412×915', largePhone),
      ('700×800', foldable),
      ('1280×800', desktop),
    ]) {
      testWidgets('도움말은 글자 크기 200%에서도 넘치지 않는다 ($name)', (tester) async {
        await pumpCommands(tester, size: size, textScale: 2);
        showShortcutsHelp(tester.element(find.byType(CommandHarness)));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('shortcuts-help')), findsOneWidget);
        expect(tester.takeException(), isNull);
        // 끝까지 굴려 닫기 단추를 누를 수 있다.
        final close = find.byKey(const ValueKey('shortcuts-help-close'));
        await tester.ensureVisible(close);
        await tester.pumpAndSettle();
        await tester.tap(close);
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('shortcuts-help')), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('지금 동기화: 결과를 알린다', (tester) async {
      final sync = FakeSync();
      await pumpCommands(tester, sync: sync);
      await runByTap(tester, '>동기화', CommandIds.syncNow);
      expect(sync.synced, 1);
      expect(find.text('동기화했습니다.'), findsOneWidget);

      sync.fail = true;
      await runByTap(tester, '>sync', CommandIds.syncNow);
      expect(sync.synced, 2);
      expect(find.text('동기화하지 못했습니다. 연결을 확인하고 다시 해 주세요.'), findsOneWidget);
    });

    testWidgets('로그아웃: 묻고 나서 한다', (tester) async {
      final sync = FakeSync();
      await pumpCommands(tester, sync: sync);

      await runByTap(tester, '>로그아웃', CommandIds.signOut);
      expect(find.byKey(const ValueKey('sign-out-dialog')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('sign-out-cancel')));
      await tester.pumpAndSettle();
      expect(sync.signedOut, 0);

      await runByTap(tester, '>logout', CommandIds.signOut);
      await tester.tap(find.byKey(const ValueKey('sign-out-confirm')));
      await tester.pumpAndSettle();
      expect(sync.signedOut, 1);

      // 로그아웃한 뒤에는 동기화와 로그아웃 명령이 사라진다.
      await tester.enterText(find.byKey(const ValueKey('field')), '>로그아웃');
      await tester.pump();
      expect(find.byKey(const ValueKey('command-list')), findsNothing);
    });

    testWidgets('마지막 입력 되돌리기: 알릴 말을 보여 준다', (tester) async {
      var undone = 0;
      await pumpCommands(
        tester,
        undo: () async {
          undone++;
          return '3건을 되돌리고, 고친 1건은 남겼습니다';
        },
      );
      await runByTap(tester, '>되돌리기', CommandIds.undoLast);
      expect(undone, 1);
      expect(find.text('3건을 되돌리고, 고친 1건은 남겼습니다'), findsOneWidget);
    });

    testWidgets('되돌리지 못하면 예외 문구 대신 안내를 보여 준다', (tester) async {
      await pumpCommands(
        tester,
        undo: () async => throw StateError('db is locked'),
      );
      await runByTap(tester, '>undo', CommandIds.undoLast);
      expect(find.text('되돌리지 못했습니다. 잠시 뒤에 다시 해 주세요.'), findsOneWidget);
      expect(find.textContaining('db is locked'), findsNothing);
    });

    testWidgets('되돌리기가 이어지지 않았으면 명령이 없다', (tester) async {
      await pumpCommands(tester);
      await tester.enterText(find.byKey(const ValueKey('field')), '>되돌리기');
      await tester.pump();
      expect(find.byKey(const ValueKey('command-list')), findsNothing);
    });

    testWidgets('붙여넣고 해석: 클립보드의 글을 입력창에 건네고 초점을 청한다', (tester) async {
      final container = await pumpCommands(tester);
      mockClipboard(tester, '신한카드 승인 12,000원 김밥천국');
      await runByTap(tester, '>붙여넣', CommandIds.paste);
      expect(container.read(incomingTextProvider), '신한카드 승인 12,000원 김밥천국');
      expect(container.read(composerFocusRequestProvider), 1);
    });

    testWidgets('붙여넣고 해석: 클립보드가 비었거나 읽지 못하면 알린다', (tester) async {
      final container = await pumpCommands(tester);
      mockClipboard(tester, '  ');
      await runByTap(tester, '>paste', CommandIds.paste);
      expect(find.text('클립보드에 글자가 없습니다.'), findsOneWidget);

      mockClipboard(tester, null, denied: true);
      await runByTap(tester, '>paste', CommandIds.paste);
      expect(find.text('클립보드를 읽지 못했습니다. 입력창에 직접 붙여넣어 주세요.'), findsOneWidget);
      expect(container.read(incomingTextProvider), isNull);
      expect(container.read(composerFocusRequestProvider), 0);
    });
  });
}

/// 화면 안의 `WidgetRef`. 입력창 쪽이 부르는 함수를 그대로 불러 보는 데 쓴다.
WidgetRef _refOf(WidgetTester tester) => tester
    .state<ConsumerState<CommandHarness>>(find.byType(CommandHarness))
    .ref;
