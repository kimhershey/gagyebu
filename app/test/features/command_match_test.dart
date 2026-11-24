import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gagyebu/app/sync_controller.dart';
import 'package:gagyebu/app/theme/theme_setting.dart';
import 'package:gagyebu/data/server/server_connection.dart';
import 'package:gagyebu/features/command/commands.dart';

/// 서버 없이 로그인 상태만 흉내 낸다.
class _FakeSync extends SyncController {
  _FakeSync(this.signedIn);

  final bool signedIn;

  @override
  SyncStatus build() => signedIn
      ? const SyncStatus(SyncPhase.idle, user: AuthUser(id: 'user-1'))
      : const SyncStatus(SyncPhase.unavailable);
}

/// 실제 명령 목록.
List<AppCommand> _commands({bool signedIn = true, bool undo = true}) {
  final container = ProviderContainer(
    overrides: [
      syncControllerProvider.overrideWith(() => _FakeSync(signedIn)),
      // 이 시험에는 가계부가 없다. 되돌리기는 가짜로 두거나(있음) 비워 둔다(없음).
      undoLastBatchProvider.overrideWithValue(undo ? () async => null : null),
    ],
  );
  addTearDown(container.dispose);
  return container.read(commandsProvider);
}

List<String> _ids(List<AppCommand> commands, String query) => [
  for (final command in matchCommands(commands, query)) command.id,
];

void main() {
  group('명령 목록', () {
    test('설계서의 명령이 모두 있고 ID가 겹치지 않는다', () {
      final commands = _commands();
      final ids = [for (final command in commands) command.id];
      expect(ids.toSet().length, ids.length);
      expect(
        ids,
        containsAll([
          'go-home',
          'go-transactions',
          'go-stats',
          'go-accounts',
          'go-categories',
          'go-budget',
          'go-recurring',
          'go-history',
          'go-settings',
          'new-expense',
          'new-income',
          'new-transfer',
          CommandIds.paste,
          CommandIds.previousMonth,
          CommandIds.nextMonth,
          CommandIds.currentMonth,
          CommandIds.search,
          CommandIds.undoLast,
          for (final tone in ThemeTone.values) CommandIds.theme(tone),
          CommandIds.syncNow,
          CommandIds.shortcutsHelp,
          CommandIds.signOut,
        ]),
      );
    });

    test('되돌리기를 쓸 수 없으면 그 명령을 숨긴다', () {
      final ids = [for (final c in _commands(undo: false)) c.id];
      expect(ids, isNot(contains(CommandIds.undoLast)));
    });

    test('로그인하지 않았으면 동기화와 로그아웃을 숨긴다', () {
      final ids = [for (final c in _commands(signedIn: false)) c.id];
      expect(ids, isNot(contains(CommandIds.syncNow)));
      expect(ids, isNot(contains(CommandIds.signOut)));
      expect(ids, contains(CommandIds.shortcutsHelp));
    });

    test('단축키 표기는 Mac이면 ⌘, 아니면 Ctrl이다', () {
      String? undoShortcut() => _commands()
          .firstWhere((command) => command.id == CommandIds.undoLast)
          .shortcut;

      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      expect(undoShortcut(), 'Ctrl+Z');
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      expect(undoShortcut(), '⌘Z');
      debugDefaultTargetPlatformOverride = null;
    });
  });

  group('명령 찾기', () {
    test('한글 이름으로 찾는다', () {
      final commands = _commands();
      expect(_ids(commands, '예산'), ['go-budget']);
      expect(_ids(commands, '새 지출'), ['new-expense']);
      // 빈칸 없이 적어도 찾는다.
      expect(_ids(commands, '새지출'), ['new-expense']);
      expect(_ids(commands, '도움말'), [CommandIds.shortcutsHelp]);
    });

    test('영문 낱말로 찾는다(대소문자를 가리지 않는다)', () {
      final commands = _commands();
      expect(_ids(commands, 'home'), ['go-home']);
      expect(_ids(commands, 'Budget'), ['go-budget']);
      expect(_ids(commands, 'undo'), [CommandIds.undoLast]);
      expect(_ids(commands, 'THEME'), [
        for (final tone in ThemeTone.values) CommandIds.theme(tone),
      ]);
      expect(_ids(commands, 'logout'), [CommandIds.signOut]);
    });

    test('앞부분이 맞는 것이 먼저, 가운데가 맞는 것이 다음이다', () {
      final commands = _commands();
      // '내역으로 이동'은 이름의 앞이, '내역 검색'도 이름의 앞이 맞는다(목록의 순서대로).
      expect(_ids(commands, '내역'), [CommandIds.search, 'go-transactions']);
      // '지출': 낱말의 앞('지출 추가')이 맞는 것 하나.
      expect(_ids(commands, '지출'), ['new-expense']);

      AppCommand command(
        String id,
        String title, [
        List<String> keywords = const [],
      ]) =>
          AppCommand(id: id, title: title, keywords: keywords, run: (_, _) {});
      final sample = [
        command('keyword-contains', '가나', ['xx다라']),
        command('title-contains', '마 다라'),
        command('keyword-prefix', '바사', ['다라마']),
        command('title-prefix', '다라 아자'),
        command('none', '차카'),
      ];
      expect(_ids(sample, '다라'), [
        'title-prefix',
        'keyword-prefix',
        'title-contains',
        'keyword-contains',
      ]);
    });

    test("'>'로 시작하면 그 뒤의 말로 찾고, 한 글자로도 찾는다", () {
      final commands = _commands();
      expect(_ids(commands, '>예산'), ['go-budget']);
      expect(_ids(commands, '> budget'), ['go-budget']);
      expect(_ids(commands, '>홈'), ['go-home']);
      expect(_ids(commands, '>없는명령'), isEmpty);
    });

    test("'>'만 적으면 전부 돌려준다", () {
      final commands = _commands();
      expect(matchCommands(commands, '>'), commands);
      expect(matchCommands(commands, ' >  '), commands);
    });

    test("'>' 없이 적은 글은 두 글자부터 찾는다", () {
      final commands = _commands();
      expect(_ids(commands, ''), isEmpty);
      expect(_ids(commands, '홈'), isEmpty);
      expect(_ids(commands, '새'), isEmpty);
      expect(_ids(commands, ' 새 '), isEmpty);
      expect(_ids(commands, '새 '), isEmpty);
      expect(_ids(commands, '홈으'), ['go-home']);
    });

    test('거래를 적은 글에는 목록이 뜨지 않는다', () {
      final commands = _commands();
      expect(_ids(commands, '어제 점심 9천원'), isEmpty);
      expect(_ids(commands, '스타벅스 4,500원'), isEmpty);
      expect(
        _ids(commands, '[Web발신]\n신한카드 승인 12,000원\n11/17 12:30 김밥천국'),
        isEmpty,
      );
    });

    test('최대 여섯 개까지 돌려준다', () {
      final commands = _commands();
      // 화면 이동 명령은 아홉 개다.
      expect(_ids(commands, '이동'), hasLength(maxCommandMatches));
      expect(_ids(commands, '>이동'), hasLength(maxCommandMatches));
      expect(_ids(commands, '>go'), hasLength(maxCommandMatches));
      expect(maxCommandMatches, 6);
    });
  });

  group('고른 줄', () {
    test("'>'로 찾을 때는 첫 줄을 미리 고르고, 그 밖에는 고르지 않는다", () {
      final commands = _commands();
      expect(
        selectedCommandIndex(matchCommands(commands, '>예산'), '>예산', null),
        0,
      );
      expect(
        selectedCommandIndex(matchCommands(commands, '예산'), '예산', null),
        isNull,
      );
      expect(selectedCommandIndex(const [], '>없는명령', null), isNull);
    });

    test('글이 바뀌면 고른 것이 풀린다', () {
      final commands = _commands();
      final matches = matchCommands(commands, '테마');
      const pick = CommandPick('테마', 2);
      expect(selectedCommandIndex(matches, '테마', pick), 2);
      expect(selectedCommandIndex(matches, '테마 ', pick), isNull);
      // 목록이 줄었으면 마지막 줄에 맞춘다.
      expect(selectedCommandIndex(matches.take(2).toList(), '테마', pick), 1);
    });
  });
}
