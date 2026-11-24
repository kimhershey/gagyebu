import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/providers.dart';
import '../../app/sync_controller.dart';
import '../../app/theme/theme_setting.dart';
import '../composer/composer_state.dart';
import 'command_requests.dart';
import 'shortcuts.dart';
import 'shortcuts_help.dart';

export 'command_list.dart';
export 'command_requests.dart';
export 'shortcuts.dart';
export 'shortcuts_help.dart';

/// 명령창에서 고를 수 있는 명령 하나(`docs/SPEC.md` 7.8).
class AppCommand {
  const AppCommand({
    required this.id,
    required this.title,
    required this.run,
    this.keywords = const [],
    this.shortcut,
    this.icon,
  });

  final String id;

  /// 목록에 보이는 이름.
  final String title;

  /// 이름 말고도 찾을 수 있는 낱말(영문 포함).
  final List<String> keywords;

  /// 단축키 표기('Ctrl+K'). 없으면 null.
  final String? shortcut;
  final IconData? icon;

  final void Function(BuildContext context, WidgetRef ref) run;
}

/// 단축키와 다른 화면이 찾아 쓰는 명령의 ID.
abstract final class CommandIds {
  static const search = 'search';
  static const previousMonth = 'month-previous';
  static const nextMonth = 'month-next';
  static const currentMonth = 'month-current';
  static const undoLast = 'undo-last';
  static const shortcutsHelp = 'shortcuts-help';
  static const syncNow = 'sync-now';
  static const signOut = 'sign-out';
  static const paste = 'paste-parse';

  /// 톤마다 하나씩 있는 테마 명령.
  static String theme(ThemeTone tone) => 'theme-${tone.name}';
}

/// 쓸 수 있는 명령 전부.
///
/// 지금 할 수 없는 명령은 목록에 넣지 않는다: 되돌리기는 구현이 이어졌을 때만,
/// 동기화와 로그아웃은 로그인했을 때만 보인다.
///
/// 낱말에는 거래를 적을 때 첫머리에 오기 쉬운 말('오늘', '카드', '구독')을 넣지 않는다.
/// '>' 없이도 두 글자부터 찾기 때문에, 그런 말이 있으면 거래를 적는 동안 목록이 뜬다.
final commandsProvider = Provider<List<AppCommand>>((ref) {
  final canUndo = ref.watch(undoLastBatchProvider) != null;
  final signedIn = ref.watch(
    syncControllerProvider.select((status) => status.signedIn),
  );

  AppCommand go(
    String id,
    String title,
    String path,
    IconData icon,
    List<String> keywords,
  ) => AppCommand(
    id: id,
    title: title,
    keywords: keywords,
    icon: icon,
    run: (context, ref) => context.go(path),
  );

  return [
    go(
      'new-expense',
      '새 지출',
      '/transactions?new=expense',
      Icons.remove_circle_outline,
      const ['new', 'expense', 'add', '지출 추가', '쓴 돈', '추가'],
    ),
    go(
      'new-income',
      '새 수입',
      '/transactions?new=income',
      Icons.add_circle_outline,
      const ['new', 'income', 'add', '수입 추가', '번 돈', '추가'],
    ),
    go(
      'new-transfer',
      '새 이체',
      '/transactions?new=transfer',
      Icons.swap_horiz,
      const ['new', 'transfer', 'add', '이체 추가', '옮기기', '추가'],
    ),
    const AppCommand(
      id: CommandIds.paste,
      title: '붙여넣고 해석',
      keywords: ['paste', 'clipboard', '붙여넣기', '클립보드', '결제 문자'],
      icon: Icons.content_paste_go_outlined,
      run: _paste,
    ),
    AppCommand(
      id: CommandIds.search,
      title: '내역 검색',
      keywords: const ['search', 'find', '검색', '찾기'],
      shortcut: '/',
      icon: Icons.search,
      run: (context, ref) {
        ref.read(transactionSearchFocusRequestProvider.notifier).request();
        context.go('/transactions');
      },
    ),
    AppCommand(
      id: CommandIds.previousMonth,
      title: '이전 달',
      keywords: const ['previous', 'prev', 'month', '지난달', '전달', '저번 달'],
      shortcut: '[',
      icon: Icons.chevron_left,
      run: (context, ref) =>
          ref.read(selectedPeriodProvider.notifier).previous(),
    ),
    AppCommand(
      id: CommandIds.nextMonth,
      title: '다음 달',
      keywords: const ['next', 'month', '다음달'],
      shortcut: ']',
      icon: Icons.chevron_right,
      run: (context, ref) => ref.read(selectedPeriodProvider.notifier).next(),
    ),
    AppCommand(
      id: CommandIds.currentMonth,
      title: '이번 달',
      keywords: const ['today', 'current', 'this month', '이번달'],
      icon: Icons.today_outlined,
      run: (context, ref) =>
          ref.read(selectedPeriodProvider.notifier).showToday(),
    ),
    if (canUndo)
      AppCommand(
        id: CommandIds.undoLast,
        title: '마지막 입력 되돌리기',
        keywords: const ['undo', 'revert', '되돌리기', '취소', '실행 취소'],
        shortcut: modifierShortcut('Z'),
        icon: Icons.undo,
        run: _undoLast,
      ),
    go('go-home', '홈으로 이동', '/', Icons.home_outlined, const [
      'home',
      'go',
      '처음',
      '요약',
    ]),
    go(
      'go-transactions',
      '내역으로 이동',
      '/transactions',
      Icons.receipt_long_outlined,
      const ['transactions', 'list', 'go', '목록'],
    ),
    go('go-stats', '통계로 이동', '/stats', Icons.pie_chart_outline, const [
      'stats',
      'statistics',
      'chart',
      'go',
      '분석',
      '그래프',
    ]),
    go(
      'go-accounts',
      '자산으로 이동',
      '/accounts',
      Icons.account_balance_wallet_outlined,
      const ['accounts', 'assets', 'go', '계좌'],
    ),
    go(
      'go-categories',
      '분류로 이동',
      '/categories',
      Icons.category_outlined,
      const ['categories', 'category', 'go', '카테고리'],
    ),
    go('go-budget', '예산으로 이동', '/budget', Icons.donut_large_outlined, const [
      'budget',
      'go',
      '한도',
    ]),
    go('go-recurring', '반복 거래로 이동', '/recurring', Icons.event_repeat, const [
      'recurring',
      'repeat',
      'go',
      '정기',
    ]),
    go('go-history', '작업 기록으로 이동', '/history', Icons.history, const [
      'history',
      'log',
      'go',
      '입력 기록',
      '묶음',
    ]),
    go('go-settings', '설정으로 이동', '/settings', Icons.settings_outlined, const [
      'settings',
      'preferences',
      'go',
      '환경설정',
    ]),
    for (final tone in ThemeTone.values)
      AppCommand(
        id: CommandIds.theme(tone),
        title: '테마 바꾸기: ${tone.label}',
        keywords: ['theme', 'tone', 'color', tone.name, '테마', '톤', '색', '화면'],
        icon: Icons.palette_outlined,
        run: (context, ref) => ref.read(themeControllerProvider).setTone(tone),
      ),
    if (signedIn)
      const AppCommand(
        id: CommandIds.syncNow,
        title: '지금 동기화',
        keywords: ['sync', 'refresh', '동기화', '올리기', '받기'],
        icon: Icons.sync,
        run: _syncNow,
      ),
    AppCommand(
      id: CommandIds.shortcutsHelp,
      title: '단축키 도움말',
      keywords: const ['help', 'shortcuts', 'keyboard', 'keys', '도움말', '단축키'],
      shortcut: '?',
      icon: Icons.keyboard_outlined,
      run: (context, ref) => showShortcutsHelp(context),
    ),
    if (signedIn)
      const AppCommand(
        id: CommandIds.signOut,
        title: '로그아웃',
        keywords: ['logout', 'log out', 'signout', 'sign out', '나가기'],
        icon: Icons.logout,
        run: _signOut,
      ),
  ];
});

void _say(ScaffoldMessengerState? messenger, String text) {
  messenger
    ?..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));
}

/// 클립보드의 글을 입력창에 넣고 바로 해석한다. 초안은 검토함에 올라온다.
Future<void> _paste(BuildContext context, WidgetRef ref) async {
  final composer = ref.read(composerControllerProvider.notifier);
  await composer.pasteFromClipboard();
  if (composer.text.text.trim().isNotEmpty) await composer.submit();
}

Future<void> _undoLast(BuildContext context, WidgetRef ref) async {
  final undo = ref.read(undoLastBatchProvider);
  if (undo == null) return;
  final messenger = ScaffoldMessenger.maybeOf(context);
  try {
    final message = await undo();
    if (message != null) _say(messenger, message);
  } catch (_) {
    _say(messenger, '되돌리지 못했습니다. 잠시 뒤에 다시 해 주세요.');
  }
}

Future<void> _syncNow(BuildContext context, WidgetRef ref) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  final container = ProviderScope.containerOf(context, listen: false);
  var failed = false;
  try {
    await container.read(syncControllerProvider.notifier).syncNow();
    failed = container.read(syncControllerProvider).phase == SyncPhase.failed;
  } catch (_) {
    failed = true;
  }
  _say(messenger, failed ? '동기화하지 못했습니다. 연결을 확인하고 다시 해 주세요.' : '동기화했습니다.');
}

/// 잘못 골라 로그인 화면으로 밀려나지 않게 한 번 묻는다.
Future<void> _signOut(BuildContext context, WidgetRef ref) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  final controller = ref.read(syncControllerProvider.notifier);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      key: const ValueKey('sign-out-dialog'),
      title: const Text('로그아웃할까요?'),
      content: const Text('이 기기의 가계부는 그대로 남습니다. 다시 로그인하면 이어서 동기화합니다.'),
      actions: [
        TextButton(
          key: const ValueKey('sign-out-cancel'),
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('취소'),
        ),
        FilledButton(
          key: const ValueKey('sign-out-confirm'),
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('로그아웃'),
        ),
      ],
    ),
  );
  if (confirmed != true) return;
  try {
    await controller.signOut();
  } catch (_) {
    _say(messenger, '로그아웃하지 못했습니다. 잠시 뒤에 다시 해 주세요.');
  }
}

/// 한 번에 보여 주는 명령 수. '>'만 적었을 때는 전부 돌려준다.
const maxCommandMatches = 6;

/// 명령만 찾는 글인지('>'로 시작).
bool isCommandQuery(String query) => query.trimLeft().startsWith('>');

/// 견주기 좋게 소문자로 바꾸고 빈칸을 뺀다('새지출'로도 '새 지출'을 찾는다).
String _fold(String text) => text.toLowerCase().replaceAll(RegExp(r'\s+'), '');

/// 낮을수록 잘 맞는다. 맞지 않으면 null.
int? _score(AppCommand command, String term) {
  final title = _fold(command.title);
  if (title.startsWith(term)) return 0;
  final keywords = command.keywords.map(_fold).toList();
  if (keywords.any((keyword) => keyword.startsWith(term))) return 1;
  if (title.contains(term)) return 2;
  if (keywords.any((keyword) => keyword.contains(term))) return 3;
  return null;
}

/// [query]에 맞는 명령을 잘 맞는 순서로 돌려준다. '>'로 시작하면 그 뒤의 말로 찾는다.
///
/// - 앞부분이 맞는 것이 먼저, 그다음이 가운데가 맞는 것이다. 이름이 낱말보다 먼저다.
/// - '>'만 적으면 전부, 그 밖에는 [maxCommandMatches]개까지 돌려준다.
/// - '>' 없이 적은 글은 두 글자부터 찾는다. 거래를 적는 동안 목록이 자꾸 뜨지 않게
///   하려는 것이다.
List<AppCommand> matchCommands(List<AppCommand> commands, String query) {
  final trimmed = query.trim();
  final commandOnly = trimmed.startsWith('>');
  final term = _fold(commandOnly ? trimmed.substring(1) : trimmed);
  if (commandOnly && term.isEmpty) return List.of(commands);
  if (!commandOnly && term.length < 2) return const [];

  final scored = <(int, int, AppCommand)>[];
  for (final (index, command) in commands.indexed) {
    final score = _score(command, term);
    if (score != null) scored.add((score, index, command));
  }
  // 같은 점수면 목록의 순서를 지킨다.
  scored.sort((a, b) {
    final byScore = a.$1.compareTo(b.$1);
    return byScore != 0 ? byScore : a.$2.compareTo(b.$2);
  });
  return [for (final entry in scored.take(maxCommandMatches)) entry.$3];
}
