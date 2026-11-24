import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'commands.dart';

/// 보조키로 ⌘을 쓰는 플랫폼인지. 웹도 Mac의 브라우저면 그렇다.
bool get usesCommandKey =>
    defaultTargetPlatform == TargetPlatform.macOS ||
    defaultTargetPlatform == TargetPlatform.iOS;

/// 보조키와 함께 누르는 단축키의 표기: Mac이면 '⌘K', 아니면 'Ctrl+K'.
String modifierShortcut(String key) => usesCommandKey ? '⌘$key' : 'Ctrl+$key';

/// 앱 전체에서 듣는 단축키(`docs/SPEC.md` 7.8).
enum AppShortcut {
  /// Ctrl/⌘+K: 입력창(명령창)으로.
  focusComposer,

  /// `/`: 내역 검색.
  search,

  /// `?`: 단축키 도움말.
  help,

  /// `[`: 이전 달.
  previousMonth,

  /// `]`: 다음 달.
  nextMonth,

  /// Ctrl/⌘+Z: 마지막 입력 묶음 되돌리기.
  undo,
}

/// 영문 자판의 글자로 알려 준 키인지. 아니면(한글 · 입력기가 삼킨 키) 자리로 본다.
bool _isAsciiKey(LogicalKeyboardKey key) =>
    key.keyId >= 0x20 && key.keyId <= 0x7e;

/// 입력기가 가져가 무슨 키인지 알려 주지 않은 키인지.
bool _isSwallowed(LogicalKeyboardKey key) =>
    key == LogicalKeyboardKey.process || key == LogicalKeyboardKey.unidentified;

/// 보조키와 함께 누른 글자 키가 [logical]인지.
///
/// 한글 자판이 켜져 있으면 브라우저가 'k' 대신 'ㅏ'를 알려 주기도 한다. 그럴 때는
/// 자판의 자리([physical])로 본다. 영문 글자로 알려 준 키는 그대로 믿는다(자리로 보면
/// 드보락 같은 배열에서 엉뚱한 키가 걸린다).
bool _isLetter(
  KeyEvent event,
  LogicalKeyboardKey logical,
  PhysicalKeyboardKey physical,
) =>
    event.logicalKey == logical ||
    (!_isAsciiKey(event.logicalKey) && event.physicalKey == physical);

/// 보조키 없이 누른 키가 낸 글자. 단축키로 쓰는 `/ ? [ ]`가 아니면 null.
String? _plainCharacter(KeyEvent event, {required bool shift}) {
  final character = event.character;
  if (character != null && character.isNotEmpty) {
    return '/?[]'.contains(character) && character.length == 1
        ? character
        : null;
  }
  final key = event.logicalKey;
  if (key == LogicalKeyboardKey.question) return '?';
  if (key == LogicalKeyboardKey.slash) return shift ? '?' : '/';
  if (key == LogicalKeyboardKey.bracketLeft) return shift ? null : '[';
  if (key == LogicalKeyboardKey.bracketRight) return shift ? null : ']';
  if (_isSwallowed(key)) {
    // 입력기가 키를 삼켰다. 자판의 자리로 본다.
    final physical = event.physicalKey;
    if (physical == PhysicalKeyboardKey.slash) return shift ? '?' : '/';
    if (physical == PhysicalKeyboardKey.bracketLeft) return shift ? null : '[';
    if (physical == PhysicalKeyboardKey.bracketRight) return shift ? null : ']';
  }
  return null;
}

/// 키 입력이 어떤 단축키인지 가린다. 단축키가 아니면 null.
///
/// - 글자 한 개짜리 단축키와 되돌리기는 글 칸 안([inTextField])에서는 듣지 않는다.
///   글 칸에서는 그 키가 글자이고, Ctrl+Z는 글 고치기를 되돌리는 키다.
/// - 보조키는 Mac이면 ⌘, 아니면 Ctrl이다. Mac의 Ctrl+K는 글 칸에서 줄 끝까지 지우는
///   키라서 건드리지 않는다.
AppShortcut? resolveAppShortcut(
  KeyEvent event, {
  required bool inTextField,
  required bool control,
  required bool meta,
  required bool alt,
  required bool shift,
}) {
  if (event is KeyUpEvent) return null;
  final repeat = event is KeyRepeatEvent;
  final modifier = usesCommandKey ? meta : control;
  final otherModifier = usesCommandKey ? control : meta;

  if (modifier) {
    if (otherModifier || alt || shift || repeat) return null;
    if (_isLetter(event, LogicalKeyboardKey.keyK, PhysicalKeyboardKey.keyK)) {
      return AppShortcut.focusComposer;
    }
    if (!inTextField &&
        _isLetter(event, LogicalKeyboardKey.keyZ, PhysicalKeyboardKey.keyZ)) {
      return AppShortcut.undo;
    }
    return null;
  }
  if (otherModifier || alt || inTextField) return null;

  return switch (_plainCharacter(event, shift: shift)) {
    // 누르고 있어도 한 번만 한다.
    '/' when !repeat => AppShortcut.search,
    '?' when !repeat => AppShortcut.help,
    // 달은 누르고 있으면 계속 넘어간다.
    '[' => AppShortcut.previousMonth,
    ']' => AppShortcut.nextMonth,
    _ => null,
  };
}

/// 지금 초점이 글 칸 안에 있는지.
bool focusIsInTextField() {
  final context = FocusManager.instance.primaryFocus?.context;
  if (context == null) return false;
  return context.widget is EditableText ||
      context.findAncestorWidgetOfExactType<EditableText>() != null;
}

/// 앱 전체의 단축키를 듣는다. 뼈대를 감싼다.
///
/// 초점이 어디에도 없을 때(브라우저에서 빈 곳을 눌렀을 때)도 들어야 해서, 초점 나무가
/// 아니라 키보드에서 바로 듣는다. 대신 뼈대가 맨 위에 있을 때만 움직인다: 대화상자나
/// 다른 화면이 위에 있거나, 초점이 뼈대 밖(잠금 화면 등)에 있으면 듣지 않는다.
class AppShortcuts extends ConsumerStatefulWidget {
  const AppShortcuts({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AppShortcuts> createState() => _AppShortcutsState();
}

class _AppShortcutsState extends ConsumerState<AppShortcuts> {
  /// 초점이 뼈대 안에 있는지 가리는 데만 쓴다. 스스로 초점을 받지는 않는다.
  final _scope = FocusNode(debugLabel: 'AppShortcuts');
  ModalRoute<Object?>? _route;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _route = ModalRoute.of(context);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    _scope.dispose();
    super.dispose();
  }

  /// 뼈대가 키를 받을 차례인지.
  bool get _active {
    if (!(_route?.isCurrent ?? true)) return false;
    final focus = FocusManager.instance.primaryFocus;
    if (focus == null || focus == _scope) return true;
    // 초점이 뼈대 안에 있거나, 아무것도 고르지 않아 바깥 범위에 머물러 있을 때.
    return focus.ancestors.contains(_scope) || _scope.ancestors.contains(focus);
  }

  bool _onKey(KeyEvent event) {
    if (!mounted || !_active) return false;
    final keyboard = HardwareKeyboard.instance;
    final shortcut = resolveAppShortcut(
      event,
      inTextField: focusIsInTextField(),
      control: keyboard.isControlPressed,
      meta: keyboard.isMetaPressed,
      alt: keyboard.isAltPressed,
      shift: keyboard.isShiftPressed,
    );
    if (shortcut == null) return false;

    if (shortcut == AppShortcut.focusComposer) {
      ref.read(composerFocusRequestProvider.notifier).request();
      return true;
    }
    final id = switch (shortcut) {
      AppShortcut.search => CommandIds.search,
      AppShortcut.help => CommandIds.shortcutsHelp,
      AppShortcut.previousMonth => CommandIds.previousMonth,
      AppShortcut.nextMonth => CommandIds.nextMonth,
      AppShortcut.undo => CommandIds.undoLast,
      AppShortcut.focusComposer => null,
    };
    final command = ref
        .read(commandsProvider)
        .where((command) => command.id == id)
        .firstOrNull;
    // 지금 쓸 수 없는 명령(되돌리기가 아직 없을 때)의 키는 남에게 넘긴다.
    if (command == null) return false;
    runCommand(context, ref, command);
    return true;
  }

  @override
  Widget build(BuildContext context) => Focus(
    focusNode: _scope,
    canRequestFocus: false,
    skipTraversal: true,
    child: widget.child,
  );
}
