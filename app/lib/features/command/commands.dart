import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

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

/// 쓸 수 있는 명령 전부.
final commandsProvider = Provider<List<AppCommand>>((ref) => const []);

/// [query]에 맞는 명령을 잘 맞는 순서로 돌려준다. '>'로 시작하면 그 뒤의 말로 찾는다.
List<AppCommand> matchCommands(List<AppCommand> commands, String query) =>
    const [];

/// 입력창 아래에 붙는 명령 목록. [query]에 맞는 명령이 없으면 아무것도 그리지 않는다.
class CommandSuggestionList extends StatelessWidget {
  const CommandSuggestionList({super.key, required this.query, this.onRun});

  final String query;

  /// 명령을 실행한 뒤에 부른다(입력창을 비우는 데 쓴다).
  final VoidCallback? onRun;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

/// 앱 전체의 단축키를 듣는다. 뼈대를 감싼다.
class AppShortcuts extends StatelessWidget {
  const AppShortcuts({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}
