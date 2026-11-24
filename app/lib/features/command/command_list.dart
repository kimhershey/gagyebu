import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/theme/tokens.dart';
import 'commands.dart';

/// 화살표로 고른 줄: 어떤 글([query])의 목록에서 몇 번째([index])를 골랐는지.
///
/// 글과 함께 적어 두므로 글이 바뀌면 고른 것이 저절로 풀린다.
@immutable
class CommandPick {
  const CommandPick(this.query, this.index);

  final String query;
  final int index;

  @override
  bool operator ==(Object other) =>
      other is CommandPick && other.query == query && other.index == index;

  @override
  int get hashCode => Object.hash(query, index);
}

/// 명령 목록에서 고른 줄. 입력창의 글 칸이 초점을 쥐고 있어서, 목록이 직접 키를 듣지
/// 않고 입력창이 ↑ ↓ 를 이 제공자로 옮겨 준다.
class CommandSelection extends Notifier<CommandPick?> {
  @override
  CommandPick? build() => null;

  /// [query]의 목록에서 고른 줄을 [delta]만큼 옮긴다. 끝에서는 반대쪽 끝으로 넘어간다.
  /// 목록이 비어 옮길 것이 없으면 false를 돌려준다(화살표가 글 칸의 커서를 옮기게 둔다).
  bool move(String query, int delta) {
    final matches = matchCommands(ref.read(commandsProvider), query);
    if (matches.isEmpty) return false;
    final current = selectedCommandIndex(matches, query, state);
    final next = current == null
        ? (delta > 0 ? 0 : matches.length - 1)
        : (current + delta) % matches.length;
    state = CommandPick(query, next);
    return true;
  }

  /// 고른 것을 푼다(Esc).
  void clear() => state = null;
}

final commandSelectionProvider =
    NotifierProvider<CommandSelection, CommandPick?>(CommandSelection.new);

/// [query]의 목록 [matches]에서 지금 고른 줄. 고른 것이 없으면 null.
///
/// '>'로 시작하는 글은 명령만 찾는 것이므로 첫 줄을 미리 골라 둔다. 그 밖의 글은
/// 화살표로 고르기 전까지 아무것도 고르지 않는다 — Enter가 거래 해석으로 가야 한다.
int? selectedCommandIndex(
  List<AppCommand> matches,
  String query,
  CommandPick? pick,
) {
  if (matches.isEmpty) return null;
  if (pick != null && pick.query == query) {
    return pick.index.clamp(0, matches.length - 1);
  }
  return isCommandQuery(query) ? 0 : null;
}

/// 명령을 실행한다. 고른 줄은 푼다.
void runCommand(BuildContext context, WidgetRef ref, AppCommand command) {
  ref.read(commandSelectionProvider.notifier).clear();
  command.run(context, ref);
}

/// 입력창의 ↑(-1) · ↓(+1)를 잇는다. 옮겼으면 true.
bool moveCommandSelection(WidgetRef ref, String query, int delta) =>
    ref.read(commandSelectionProvider.notifier).move(query, delta);

/// 입력창의 Enter를 잇는다: [query]의 목록에서 고른 명령이 있으면 실행하고 true를
/// 돌려준다. false면 고른 명령이 없는 것이니 글을 거래로 해석하면 된다.
bool runSelectedCommand(BuildContext context, WidgetRef ref, String query) {
  final matches = matchCommands(ref.read(commandsProvider), query);
  final index = selectedCommandIndex(
    matches,
    query,
    ref.read(commandSelectionProvider),
  );
  if (index == null) return false;
  runCommand(context, ref, matches[index]);
  return true;
}

/// 입력창 아래에 붙는 명령 목록. [query]에 맞는 명령이 없으면 아무것도 그리지 않는다.
class CommandSuggestionList extends ConsumerStatefulWidget {
  const CommandSuggestionList({super.key, required this.query, this.onRun});

  final String query;

  /// 명령을 실행한 뒤에 부른다(입력창을 비우는 데 쓴다).
  final VoidCallback? onRun;

  @override
  ConsumerState<CommandSuggestionList> createState() =>
      _CommandSuggestionListState();
}

class _CommandSuggestionListState extends ConsumerState<CommandSuggestionList> {
  /// 고른 줄에 단다. 목록이 길 때('>'만 적었을 때) 그 줄이 보이게 밀어 주는 데 쓴다.
  final _selectedKey = GlobalKey();

  void _revealSelected() {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      final context = _selectedKey.currentContext;
      if (context == null) return;
      // 이미 보이면 가만히 두고, 가려졌으면 가까운 쪽 끝에 맞춘다.
      for (final policy in const [
        ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
        ScrollPositionAlignmentPolicy.keepVisibleAtStart,
      ]) {
        Scrollable.ensureVisible(context, alignmentPolicy: policy);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final matches = matchCommands(ref.watch(commandsProvider), widget.query);
    if (matches.isEmpty) return const SizedBox.shrink();
    final selected = selectedCommandIndex(
      matches,
      widget.query,
      ref.watch(commandSelectionProvider),
    );
    ref.listen(commandSelectionProvider, (_, _) => _revealSelected());

    final theme = Theme.of(context);
    final tokens = context.tokens;
    return Material(
      key: const ValueKey('command-list'),
      color: theme.colorScheme.surfaceContainerLow,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(tokens.radius),
        side: tokens.surfaceBorder,
      ),
      child: ConstrainedBox(
        // 여섯 줄 남짓. 더 길면 안에서 굴린다.
        constraints: const BoxConstraints(maxHeight: 280),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (index, command) in matches.indexed)
                KeyedSubtree(
                  key: index == selected ? _selectedKey : null,
                  child: _CommandRow(
                    key: ValueKey('command-${command.id}'),
                    command: command,
                    selected: index == selected,
                    onTap: () {
                      runCommand(context, ref, command);
                      widget.onRun?.call();
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CommandRow extends StatelessWidget {
  const _CommandRow({
    super.key,
    required this.command,
    required this.selected,
    required this.onTap,
  });

  final AppCommand command;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = selected
        ? theme.colorScheme.onSecondaryContainer
        : theme.colorScheme.onSurface;
    final shortcut = command.shortcut;
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        // 누르는 동안에도 입력창의 글 칸이 초점을 쥐고 있게 한다.
        canRequestFocus: false,
        child: Ink(
          color: selected ? theme.colorScheme.secondaryContainer : null,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 40),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                children: [
                  Icon(
                    command.icon ?? Icons.bolt_outlined,
                    size: 20,
                    color: color,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      command.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(color: color),
                    ),
                  ),
                  if (shortcut != null) ...[
                    const SizedBox(width: 8),
                    ShortcutLabel(shortcut),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
