import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/theme/tokens.dart';
import '../../core/breakpoints.dart';
import '../../domain/enums.dart';
import '../command/commands.dart';
import '../image_input/image_input_available.dart';
import '../review/review_state.dart';
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
/// 결제 문자를 붙여넣거나 한 줄로 적어 보내면 해석해서 검토함에 넣는다. 글과 진행 상태는
/// [composerControllerProvider]에 있어, 창 너비가 바뀌어 자리가 달라져도 그대로다.
class ComposerBar extends ConsumerStatefulWidget {
  const ComposerBar({super.key, required this.placement});

  final ComposerPlacement placement;

  @override
  ConsumerState<ComposerBar> createState() => _ComposerBarState();
}

class _ComposerBarState extends ConsumerState<ComposerBar>
    with WidgetsBindingObserver {
  /// 입력창 안(글 칸이나 예시 칩)에 초점이 있는지.
  bool _active = false;

  ComposerController get _controller =>
      ref.read(composerControllerProvider.notifier);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // 이 입력창이 뜨기 전에 올라와 있던 글(앱을 켜면서 받은 공유)을 채운다.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _takeIncoming();
      // 명령창 자리의 입력창은 명령 목록의 키(↑ ↓ Enter Esc)를 글 칸보다 먼저 받는다.
      if (widget.placement == ComposerPlacement.command) {
        ref.read(composerKeyInterceptorProvider.notifier).set(_commandKeys);
      }
    });
  }

  /// 명령 목록에서 고르고 실행하는 키. 고른 명령이 없으면 글 칸에 맡긴다.
  KeyEventResult _commandKeys(KeyEvent event) {
    if (!mounted || widget.placement != ComposerPlacement.command) {
      return KeyEventResult.ignored;
    }
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    final query = _controller.text.text;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.arrowUp) {
      final delta = key == LogicalKeyboardKey.arrowDown ? 1 : -1;
      return moveCommandSelection(ref, query, delta)
          ? KeyEventResult.handled
          : KeyEventResult.ignored;
    }
    if (key == LogicalKeyboardKey.escape) {
      ref.read(commandSelectionProvider.notifier).clear();
      return KeyEventResult.ignored;
    }
    final enter =
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter;
    if (!enter || event is! KeyDownEvent) return KeyEventResult.ignored;
    final keyboard = HardwareKeyboard.instance;
    if (keyboard.isShiftPressed ||
        keyboard.isControlPressed ||
        keyboard.isMetaPressed ||
        keyboard.isAltPressed ||
        _controller.text.value.composing.isValid) {
      return KeyEventResult.ignored;
    }
    if (runSelectedCommand(context, ref, query)) {
      _controller.clear();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// 자판이 오르내리면 입력창이 쓸 수 있는 높이를 다시 잰다([_maxHeight]).
  @override
  void didChangeMetrics() {
    if (mounted) setState(() {});
  }

  /// 밖에서 채워 넣을 글(공유로 받은 글)이 있으면 입력창에 넣는다. 보내는 것은 사용자가 한다.
  void _takeIncoming() {
    final text = ref.read(incomingTextProvider.notifier).take();
    if (text != null && text.trim().isNotEmpty) {
      _controller.fill(text, source: TxSource.share);
    }
  }

  void _onEvent(ComposerEvent? event) {
    switch (event) {
      case ComposerQueryEvent(:final question):
        context.push('/query?q=${Uri.encodeQueryComponent(question)}');
      case ComposerReviewEvent():
        // 좁은 창에는 검토함을 둘 옆 칸이 없다. 전체 화면으로 연다. 자판은 내린다.
        if (WindowSize.of(context).isCompact) {
          _controller.focusNode.unfocus();
          context.push('/review');
        }
      case null:
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(incomingTextProvider, (_, next) {
      if (next != null) _takeIncoming();
    });
    // 단축키(Ctrl/⌘+K)와 명령이 입력창에 초점을 청한다.
    ref.listen(
      composerFocusRequestProvider,
      (_, _) => _controller.requestFocus(),
    );
    ref.listen(
      composerControllerProvider.select((s) => s.event),
      (previous, next) => _onEvent(next),
    );

    final state = ref.watch(composerControllerProvider);
    final controller = _controller;
    final reviewing = ref.watch(
      reviewSessionProvider.select((s) => s?.drafts.length),
    );
    final imageInput = ref.watch(imageInputAvailableProvider);

    final theme = Theme.of(context);
    final tokens = context.tokens;
    final placement = widget.placement;
    final bottom = placement == ComposerPlacement.bottom;
    final command = placement == ComposerPlacement.command;

    final field = TextField(
      key: const ValueKey('composer-input'),
      controller: controller.text,
      focusNode: controller.focusNode,
      readOnly: state.busy,
      minLines: 1,
      // 휴대폰에서는 평소 좁게 두고, 누르면 넓힌다. 한 줄로 고정하지는 않는다: 한 줄짜리
      // 글 칸은 붙여넣은 글의 줄바꿈을 지워서 문자 여러 건이 한 덩어리가 된다.
      maxLines: bottom && !_active ? 2 : 6,
      keyboardType: TextInputType.multiline,
      // 휴대폰 자판의 Enter는 줄바꿈이고, 보내기는 단추로 한다.
      textInputAction: TextInputAction.newline,
      inputFormatters: [_MaxLengthFormatter(controller.noteTruncated)],
      decoration: InputDecoration(
        hintText: command
            ? '결제 문자를 붙여넣거나 한 줄로 적어 보세요 (예: $composerExample)'
            : '문자 붙여넣기 · $composerExample',
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
    );

    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(child: field),
        if (imageInput && !state.busy)
          IconButton(
            key: const ValueKey('composer-image'),
            tooltip: '이미지로 입력',
            onPressed: () => context.push('/image-input'),
            icon: const Icon(Icons.image_outlined),
          ),
        const SizedBox(width: 4),
        if (state.busy)
          TextButton(
            key: const ValueKey('composer-stop'),
            onPressed: controller.stop,
            child: const Text('그만'),
          )
        else
          IconButton.filledTonal(
            key: const ValueKey('composer-send'),
            tooltip: '보내기',
            onPressed: controller.submit,
            icon: const Icon(Icons.arrow_upward),
          ),
      ],
    );

    // 글이 비어 있고 입력창을 쓰려는 참일 때만 예시를 보인다.
    final chips = ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller.text,
      builder: (context, value, _) {
        if (!_active || state.busy || value.text.isNotEmpty) {
          return const SizedBox.shrink();
        }
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              key: const ValueKey('composer-chips'),
              spacing: 8,
              runSpacing: 4,
              children: [
                ActionChip(
                  key: const ValueKey('composer-chip-paste'),
                  avatar: const Icon(Icons.content_paste, size: 18),
                  label: const Text('결제 문자 붙여넣기'),
                  onPressed: controller.pasteFromClipboard,
                ),
                ActionChip(
                  key: const ValueKey('composer-chip-example'),
                  label: const Text(composerExample),
                  onPressed: () => controller.fill(composerExample),
                ),
              ],
            ),
          ),
        );
      },
    );

    final extras = [
      if (state.busy) _Progress(done: state.done, total: state.total),
      if (state.notice != null)
        _NoticeBox(
          notice: state.notice!,
          onDismiss: controller.dismissNotice,
          onManual: () {
            controller.dismissNotice();
            context.go('/transactions?new=expense');
          },
        ),
      chips,
    ];

    return Material(
      color: theme.colorScheme.surface,
      child: Focus(
        // 글 칸과 칩 가운데 어디에 초점이 있어도 "쓰는 중"으로 본다. 칩을 누르는 사이에
        // 칩이 사라지지 않게 한다.
        canRequestFocus: false,
        skipTraversal: true,
        onFocusChange: (active) {
          if (active != _active) setState(() => _active = active);
        },
        child: Padding(
          padding: EdgeInsets.fromLTRB(12, command ? 10 : 6, 8, 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 글자를 크게 쓰거나 자판이 올라와 자리가 모자라면, 화면을 밀어내지 않고
              // 입력창 안에서 스크롤한다.
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: _maxHeight(context)),
                child: SingleChildScrollView(
                  // 탭 위에 놓일 때는 글 칸이 맨 아래에 있고 나머지가 위로 자란다.
                  // 넘칠 때도 글 칸이 보이게 아래쪽에 맞춘다.
                  reverse: bottom,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (bottom) ...[
                        if (reviewing != null) _ReviewStrip(count: reviewing),
                        ...extras,
                      ],
                      row,
                      if (!bottom) ...extras,
                    ],
                  ),
                ),
              ),
              if (command)
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: controller.text,
                  builder: (context, value, _) => CommandSuggestionList(
                    query: value.text,
                    onRun: controller.clear,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// 입력창이 차지할 수 있는 가장 큰 높이: 자판과 탭을 뺀 자리의 절반 남짓.
  double _maxHeight(BuildContext context) {
    // 뼈대의 Scaffold는 본문에 자판의 높이를 지운 값을 넘겨준다. 실제 값은 창에서 읽는다.
    final view = MediaQueryData.fromView(View.of(context));
    // 하단 탭의 높이. 뼈대가 알려 주지 않아 Material 3의 기본값을 쓴다. 자판이 올라오면
    // 탭은 자판 뒤에 가려진다.
    final tabs = widget.placement == ComposerPlacement.bottom
        ? 80.0 + view.padding.bottom
        : 0.0;
    final room =
        view.size.height -
        view.padding.top -
        math.max(view.viewInsets.bottom, tabs);
    return math.max(96.0, room * 0.6);
  }
}

/// 글 칸에 들어오는 글을 [composerMaxLength]자에서 자르고, 잘랐으면 알린다.
class _MaxLengthFormatter extends TextInputFormatter {
  _MaxLengthFormatter(this.onTruncated);

  final void Function(String clipped) onTruncated;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final clipped = clipToMaxLength(newValue.text);
    if (clipped.length == newValue.text.length) return newValue;
    onTruncated(clipped);
    return TextEditingValue(
      text: clipped,
      selection: TextSelection.collapsed(offset: clipped.length),
    );
  }
}

/// 해석하는 동안의 진행 표시.
class _Progress extends StatelessWidget {
  const _Progress({required this.done, required this.total});

  final int done;
  final int total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final counted = total > 0 && done > 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, right: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            counted ? '읽는 중입니다 · $total건 가운데 $done건' : '읽는 중입니다',
            key: const ValueKey('composer-progress'),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            // 모델이 읽고 있는 건은 아직 끝나지 않았으므로 하나를 덜 채운다.
            value: counted ? (done - 1) / total : null,
          ),
        ],
      ),
    );
  }
}

/// 좁은 창에서 검토하던 것이 남아 있을 때 검토함으로 돌아가는 줄.
class _ReviewStrip extends StatelessWidget {
  const _ReviewStrip({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, right: 4),
      child: Material(
        color: tokens.accentSoft,
        borderRadius: BorderRadius.circular(tokens.radius),
        child: InkWell(
          key: const ValueKey('composer-review-open'),
          borderRadius: BorderRadius.circular(tokens.radius),
          onTap: () => context.push('/review'),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            // 글자를 키우면 한 줄에 다 들어가지 않는다. 그때는 줄을 바꾼다.
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 2,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.fact_check_outlined, size: 18),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        '검토하던 $count건이 남아 있습니다',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
                Text(
                  '이어서 보기',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 못 읽었을 때 등의 안내.
class _NoticeBox extends StatelessWidget {
  const _NoticeBox({
    required this.notice,
    required this.onDismiss,
    required this.onManual,
  });

  final ComposerNotice notice;
  final VoidCallback onDismiss;

  /// 직접 입력(새 거래)으로 간다.
  final VoidCallback onManual;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final (key, message, manual) = switch (notice) {
      ComposerNotice.unreadable => (
        'composer-unreadable',
        '읽지 못했습니다. 금액이 들어 있는지 확인해 다시 보내거나 직접 입력해 주세요.',
        true,
      ),
      ComposerNotice.notTransaction => (
        'composer-not-transaction',
        '거래가 아닌 안내문으로 보여 저장할 내용이 없습니다. 거래가 맞다면 직접 입력해 주세요.',
        true,
      ),
      ComposerNotice.failed => (
        'composer-failed',
        '해석하지 못했습니다. 잠시 뒤에 다시 보내거나 직접 입력해 주세요.',
        true,
      ),
      ComposerNotice.emptyClipboard => (
        'composer-empty-clipboard',
        '클립보드에 글이 없습니다. 결제 문자를 복사한 뒤에 다시 눌러 주세요.',
        false,
      ),
      ComposerNotice.truncated => (
        'composer-truncated',
        '한 번에 20,000자까지 받습니다. 넘는 부분은 잘랐습니다.',
        false,
      ),
    };
    return Padding(
      padding: const EdgeInsets.only(top: 2, bottom: 6, right: 4),
      child: Container(
        key: ValueKey(key),
        padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
        decoration: BoxDecoration(
          color: tokens.warnSoft,
          borderRadius: BorderRadius.circular(tokens.radius),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline, size: 18, color: tokens.warn),
            const SizedBox(width: 8),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  children: [
                    Text(
                      message,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    if (manual)
                      TextButton(
                        key: const ValueKey('composer-manual'),
                        onPressed: onManual,
                        child: const Text('직접 입력'),
                      ),
                  ],
                ),
              ),
            ),
            IconButton(
              tooltip: '안내 닫기',
              onPressed: onDismiss,
              icon: const Icon(Icons.close, size: 18),
            ),
          ],
        ),
      ),
    );
  }
}
