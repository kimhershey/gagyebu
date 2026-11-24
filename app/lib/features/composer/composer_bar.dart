import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/theme/tokens.dart';
import '../shell/app_shell.dart';
import 'composer_state.dart';

/// 입력창이 놓이는 자리.
enum ComposerPlacement {
  /// 휴대폰: 하단 탭 바로 위.
  bottom,

  /// 태블릿: 내용 위쪽.
  top,

  /// PC: 맨 위의 명령창.
  command,
}

/// 어느 화면에서나 보이는 입력창(`docs/SPEC.md` 7.5).
///
/// 결제 문자를 붙여넣거나 한 줄로 적어 보내면 해석해서 검토하게 한다.
class ComposerBar extends ConsumerStatefulWidget {
  const ComposerBar({super.key, required this.placement});

  final ComposerPlacement placement;

  @override
  ConsumerState<ComposerBar> createState() => _ComposerBarState();
}

class _ComposerBarState extends ConsumerState<ComposerBar> {
  final _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    // 한글을 조합하는 중의 Enter는 보내지 않는다.
    if (_text.value.composing.isValid) return;
    final text = _text.text.trim();
    _text.clear();
    await openInput(context, initialText: text);
  }

  @override
  Widget build(BuildContext context) {
    // 밖에서 채워 넣을 글(공유로 받은 글)이 오면 입력창에 넣는다.
    ref.listen(incomingTextProvider, (_, next) {
      if (next == null) return;
      final text = ref.read(incomingTextProvider.notifier).take();
      if (text != null) _text.text = text;
    });

    final theme = Theme.of(context);
    final tokens = context.tokens;
    final command = widget.placement == ComposerPlacement.command;
    return Material(
      color: theme.colorScheme.surface,
      child: Padding(
        padding: EdgeInsets.fromLTRB(12, command ? 10 : 6, 8, 6),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                key: const ValueKey('composer-input'),
                controller: _text,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
                decoration: InputDecoration(
                  hintText: command
                      ? '결제 문자를 붙여넣거나 한 줄로 적어 보세요 (예: 어제 점심 9천원)'
                      : '문자 붙여넣기 · 어제 점심 9천원',
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainerLow,
                  prefixIcon: const Icon(Icons.auto_awesome_outlined, size: 20),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(tokens.radius),
                    borderSide: tokens.surfaceBorder,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(tokens.radius),
                    borderSide: tokens.surfaceBorder,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),
            IconButton.filledTonal(
              key: const ValueKey('composer-send'),
              tooltip: '해석하기',
              onPressed: _send,
              icon: const Icon(Icons.arrow_upward),
            ),
          ],
        ),
      ),
    );
  }
}
