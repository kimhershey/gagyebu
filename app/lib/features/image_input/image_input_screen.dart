import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../ai/vision/vision_rows.dart';
import '../../app/providers.dart';
import '../../app/theme/tokens.dart';
import '../../core/breakpoints.dart';
import '../../core/formatters.dart';
import '../../core/local_date.dart';
import '../command/shortcuts.dart' show focusIsInTextField;
import '../common/widgets.dart';
import 'image_input_state.dart';
import 'image_intake.dart';
import 'image_row_tile.dart';

/// 이미지 입력 화면. `docs/SPEC.md` 5.5.
///
/// 영수증 · 거래내역 화면 캡처를 끌어놓거나 붙여넣거나 골라 넣으면 한 장씩 읽어, 왼쪽에
/// 원본을 오른쪽에 뽑은 줄을 보여 준다. 줄을 원본과 견주어 고치거나 뺀 뒤 검토함으로 보낸다.
/// 이미지는 메모리에서만 다루고 화면을 떠나면 버린다.
class ImageInputScreen extends ConsumerStatefulWidget {
  const ImageInputScreen({super.key});

  @override
  ConsumerState<ImageInputScreen> createState() => _ImageInputScreenState();
}

class _ImageInputScreenState extends ConsumerState<ImageInputScreen> {
  bool _dragging = false;
  bool _leaving = false;

  ImageInputController get _controller =>
      ref.read(imageInputControllerProvider.notifier);

  @override
  void initState() {
    super.initState();
    // 붙여넣기는 초점이 어디에 있든(없어도) 들어야 해서 키보드에서 바로 듣는다.
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    super.dispose();
  }

  /// Ctrl+V(⌘V): 클립보드의 이미지를 넣는다. 글 칸에서 누른 것은 글 붙여넣기라 건드리지 않는다.
  bool _onKey(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    if (event.logicalKey != LogicalKeyboardKey.keyV &&
        event.physicalKey != PhysicalKeyboardKey.keyV) {
      return false;
    }
    final keyboard = HardwareKeyboard.instance;
    if (!keyboard.isControlPressed && !keyboard.isMetaPressed) return false;
    if (keyboard.isAltPressed || keyboard.isShiftPressed) return false;
    if (!mounted || focusIsInTextField()) return false;
    // 대화상자(날짜 고르기, 닫기 확인)가 위에 떠 있으면 듣지 않는다.
    if (ModalRoute.isCurrentOf(context) != true) return false;
    if (ref.read(visionEngineProvider) == null) return false;
    if (!ref.read(imageIntakeProvider).canReadClipboard) return false;
    _paste();
    return true;
  }

  Future<void> _pick() async {
    try {
      final images = await ref.read(imageIntakeProvider).pickFiles();
      if (mounted && images.isNotEmpty) _controller.add(images);
    } catch (_) {
      if (mounted) _controller.notify('파일을 열지 못했습니다.');
    }
  }

  Future<void> _paste() async {
    try {
      final image = await ref.read(imageIntakeProvider).readClipboard();
      if (!mounted) return;
      if (image == null) {
        _controller.notify('클립보드에 이미지가 없습니다.');
      } else {
        _controller.add([image]);
      }
    } catch (_) {
      if (mounted) _controller.notify('클립보드의 이미지를 읽지 못했습니다.');
    }
  }

  Future<void> _drop(DropDoneDetails details) async {
    setState(() => _dragging = false);
    final images = <PickedImage>[];
    for (final file in details.files) {
      Uint8List bytes;
      try {
        bytes = await file.readAsBytes();
      } catch (_) {
        // 폴더나 읽을 수 없는 파일. 빈 바이트로 넘겨 "이미지가 아닌 파일"로 세게 한다.
        bytes = Uint8List(0);
      }
      images.add(PickedImage(name: file.name, bytes: bytes));
    }
    if (mounted && images.isNotEmpty) _controller.add(images);
  }

  /// 이 화면을 닫는다. 돌아갈 화면이 없으면(주소로 바로 들어왔으면) 홈으로 간다.
  void _leave() {
    if (_leaving) return;
    _leaving = true;
    final router = GoRouter.of(context);
    if (router.canPop()) {
      router.pop();
    } else {
      router.go('/');
    }
  }

  /// 닫기 전에, 넣어 둔 이미지가 있으면 버릴지 묻는다.
  Future<void> _close() async {
    if (ref.read(imageInputControllerProvider).pages.isEmpty) {
      _leave();
      return;
    }
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('이미지 입력을 닫을까요?'),
        content: const Text('넣어 둔 이미지와 읽은 내용을 버립니다.'),
        actions: [
          TextButton(
            key: const ValueKey('image-close-cancel'),
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('계속 보기'),
          ),
          FilledButton(
            key: const ValueKey('image-close-confirm'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('버리고 닫기'),
          ),
        ],
      ),
    );
    if (discard == true && mounted) _leave();
  }

  Future<void> _send() async {
    // 좁은 창에는 검토함을 둘 옆 칸이 없어 전체 화면으로 연다.
    final compact = WindowSize.of(context).isCompact;
    final router = GoRouter.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final int count;
    try {
      count = await _controller.send();
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('검토함으로 보내지 못했습니다. 다시 시도해 주세요.')),
      );
      return;
    }
    if (count == 0 || !mounted) return;
    _leave();
    if (compact) router.push('/review');
  }

  @override
  Widget build(BuildContext context) {
    final engine = ref.watch(visionEngineProvider);
    final state = ref.watch(imageInputControllerProvider);
    return PopScope(
      canPop: state.pages.isEmpty || _leaving,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: SafeArea(
        child: Column(
          children: [
            _Header(onClose: _close),
            Expanded(
              child: engine == null ? const _NoModel() : _workspace(state),
            ),
          ],
        ),
      ),
    );
  }

  Widget _workspace(ImageInputState state) {
    final scheme = Theme.of(context).colorScheme;
    final intake = ref.watch(imageIntakeProvider);
    return DropTarget(
      onDragEntered: (_) => setState(() => _dragging = true),
      onDragExited: (_) => setState(() => _dragging = false),
      onDragDone: _drop,
      child: DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          border: _dragging
              ? Border.all(color: scheme.primary, width: 2)
              : null,
        ),
        child: Column(
          children: [
            _Toolbar(
              state: state,
              canPaste: intake.canReadClipboard,
              onPick: _pick,
              onPaste: _paste,
              onStop: _controller.stop,
              onResume: _controller.resume,
            ),
            if (state.notice != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    state.notice!,
                    key: const ValueKey('image-notice'),
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: context.tokens.warn),
                  ),
                ),
              ),
            Expanded(
              child: state.pages.isEmpty
                  ? _DropHint(canPaste: intake.canReadClipboard)
                  : _Pages(state: state, controller: _controller),
            ),
            if (state.pages.isNotEmpty) _SendBar(state: state, onSend: _send),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 4, 16, 4),
    child: Row(
      children: [
        IconButton(
          key: const ValueKey('image-close'),
          tooltip: '닫기',
          onPressed: onClose,
          icon: const Icon(Icons.close),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            '이미지 입력',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
      ],
    ),
  );
}

/// 이미지 모델이 없을 때의 안내.
class _NoModel extends StatelessWidget {
  const _NoModel();

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    child: EmptyState(
      icon: Icons.image_not_supported_outlined,
      // 웹에는 기기 안의 모델이 없다. 내려받으라고 하지 않는다.
      message: kIsWeb
          ? '웹 앱에서는 이미지를 읽을 수 없습니다.\nWindows 앱에서 쓸 수 있습니다.'
          : '이미지 모델이 없습니다.\n설정 → AI 모델에서 내려받을 수 있습니다.',
      action: FilledButton(
        key: const ValueKey('image-go-models'),
        onPressed: () => context.go('/settings/models'),
        child: const Text('AI 모델 설정 열기'),
      ),
    ),
  );
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.state,
    required this.canPaste,
    required this.onPick,
    required this.onPaste,
    required this.onStop,
    required this.onResume,
  });

  final ImageInputState state;
  final bool canPaste;
  final VoidCallback onPick;
  final VoidCallback onPaste;
  final VoidCallback onStop;
  final VoidCallback onResume;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = state.pages.length;
    final unread = state.unreadCount;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            FilledButton.tonalIcon(
              key: const ValueKey('image-pick'),
              onPressed: onPick,
              icon: const Icon(Icons.folder_open, size: 18),
              label: const Text('파일 고르기'),
            ),
            if (canPaste)
              OutlinedButton.icon(
                key: const ValueKey('image-paste'),
                onPressed: onPaste,
                icon: const Icon(Icons.content_paste, size: 18),
                label: const Text('붙여넣기'),
              ),
            if (unread > 0 && !state.paused) ...[
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              Text(
                '읽는 중 · ${total - unread + 1}/$total',
                key: const ValueKey('image-progress'),
                style: theme.textTheme.bodySmall,
              ),
              TextButton(
                key: const ValueKey('image-stop'),
                onPressed: onStop,
                child: const Text('그만'),
              ),
            ],
            if (unread > 0 && state.paused) ...[
              Text(
                '멈춤 · $unread장 남음',
                key: const ValueKey('image-progress'),
                style: theme.textTheme.bodySmall,
              ),
              TextButton(
                key: const ValueKey('image-resume'),
                onPressed: onResume,
                child: const Text('이어서 읽기'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 대기열이 비었을 때: 이미지를 넣는 법과, 이미지를 어떻게 다루는지.
class _DropHint extends StatelessWidget {
  const _DropHint({required this.canPaste});

  final bool canPaste;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    key: const ValueKey('image-empty'),
    child: EmptyState(
      icon: Icons.add_photo_alternate_outlined,
      message:
          '영수증이나 거래내역 화면 캡처를 이 창에 끌어다 놓거나'
          '${canPaste ? ', 붙여넣거나(Ctrl+V),' : ''} 파일을 골라 주세요.\n'
          '여러 장을 넣으면 한 장씩 차례로 읽습니다.\n\n'
          '이미지는 이 기기 안에서만 읽고 저장하지 않습니다.',
    ),
  );
}

String _statusLabel(ImagePage page) => switch (page.status) {
  PageStatus.waiting => '기다림',
  PageStatus.reading => '읽는 중',
  PageStatus.failed => '읽지 못함',
  PageStatus.done when page.rows.isEmpty => '끝남 · 거래 없음',
  PageStatus.done when page.pendingCount > 0 =>
    '끝남 · 확인 필요 ${page.pendingCount}건',
  PageStatus.done => '끝남 · ${page.rows.length}건',
};

/// 대기열과, 고른 장의 원본 · 읽은 줄.
class _Pages extends ConsumerWidget {
  const _Pages({required this.state, required this.controller});

  final ImageInputState state;
  final ImageInputController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final page = state.selected ?? state.pages.first;
    final today = ref.watch(todayProvider);
    final result = _resultChildren(context, page, today);
    final original = _Original(bytes: page.bytes, pageId: page.id);
    final wide = WindowSize.of(context).isExpanded;

    return Column(
      children: [
        _QueueStrip(
          pages: state.pages,
          selectedId: page.id,
          onSelect: controller.select,
          onRemove: controller.remove,
        ),
        const Divider(height: 1),
        Expanded(
          child: wide
              // 넓은 창: 왼쪽에 원본, 오른쪽에 뽑은 줄.
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      flex: 4,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: original,
                      ),
                    ),
                    const VerticalDivider(width: 1),
                    Expanded(
                      flex: 5,
                      child: ListView(
                        key: const ValueKey('image-result'),
                        padding: const EdgeInsets.all(16),
                        children: result,
                      ),
                    ),
                  ],
                )
              // 좁은 창: 위에 원본, 아래에 뽑은 줄. 함께 굴린다.
              : LayoutBuilder(
                  builder: (context, constraints) => ListView(
                    key: const ValueKey('image-result'),
                    padding: const EdgeInsets.all(16),
                    children: [
                      SizedBox(
                        height: (constraints.maxHeight * 0.45).clamp(
                          120.0,
                          360.0,
                        ),
                        child: original,
                      ),
                      const SizedBox(height: 12),
                      ...result,
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  List<Widget> _resultChildren(
    BuildContext context,
    ImagePage page,
    LocalDate today,
  ) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    Widget retry(String label) => Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        key: const ValueKey('image-retry'),
        onPressed: () => controller.retry(page.id),
        icon: const Icon(Icons.refresh, size: 18),
        label: Text(label),
      ),
    );

    switch (page.status) {
      case PageStatus.waiting:
        return [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(
              state.paused ? '읽기를 멈췄습니다.' : '차례를 기다리고 있습니다.',
              key: const ValueKey('image-page-waiting'),
              textAlign: TextAlign.center,
              style: muted,
            ),
          ),
        ];
      case PageStatus.reading:
        return [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Column(
              key: const ValueKey('image-page-reading'),
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 12),
                Text(
                  '이미지를 읽고 있습니다. 한 장에 1분쯤 걸릴 수 있습니다.',
                  textAlign: TextAlign.center,
                  style: muted,
                ),
              ],
            ),
          ),
        ];
      case PageStatus.failed:
        return [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              '읽지 못했습니다. 글자가 또렷하게 보이는 이미지로 다시 해 보거나 직접 입력해 주세요.',
              key: const ValueKey('image-page-failed'),
              style: theme.textTheme.bodyMedium,
            ),
          ),
          retry('다시 읽기'),
        ];
      case PageStatus.done:
    }

    final extraction = page.extraction!;
    if (page.rows.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Text(
            '거래를 찾지 못했습니다. 거래내역이나 영수증이 보이는 이미지인지 확인해 주세요.',
            key: const ValueKey('image-page-empty'),
            style: theme.textTheme.bodyMedium,
          ),
        ),
        retry('다시 읽기'),
      ];
    }

    final verified = page.checks.where((c) => c.verified).length;
    final pending = page.pendingCount;
    return [
      Text(
        [
          extraction.kind == VisionKind.receipt ? '영수증' : '거래내역 화면',
          '${page.rows.length}건',
          if (verified > 0) '검산 맞음 $verified건',
          if (pending > 0) '확인 필요 $pending건',
        ].join(' · '),
        key: const ValueKey('image-page-summary'),
        style: theme.textTheme.titleSmall,
      ),
      // 견줄 숫자가 이미지에 없으면 검산하지 못한다. 틀렸다는 뜻은 아니므로 경고색을 쓰지 않는다.
      if (verified == 0 && page.checks.every((c) => !c.needsCheck))
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            extraction.kind == VisionKind.receipt
                ? '품목이 보이지 않아 검산하지 못했습니다. 금액을 원본과 견주어 주세요.'
                : '잔액이 보이지 않아 검산하지 못했습니다. 금액을 원본과 견주어 주세요.',
            key: const ValueKey('image-page-unchecked'),
            style: muted,
          ),
        ),
      const SizedBox(height: 8),
      for (var i = 0; i < page.rows.length; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: ImageRowTile(
            key: ValueKey('image-row-tile-${page.id}-$i'),
            index: i,
            row: page.rows[i],
            check: page.checks[i],
            issues: page.issuesOf(i),
            included: page.isIncluded(i),
            today: today,
            onInclude: (include) => controller.setIncluded(page.id, i, include),
            onEdit: (change) => controller.editRow(page.id, i, change),
            onConfirm: () => controller.confirmRow(page.id, i),
          ),
        ),
      if (extraction.items.isNotEmpty) _ReceiptItems(extraction: extraction),
      retry('이 이미지 다시 읽기'),
    ];
  }
}

/// 영수증에서 읽은 품목. 고치지 않고, 금액을 원본과 견주는 데만 쓴다.
class _ReceiptItems extends StatelessWidget {
  const _ReceiptItems({required this.extraction});

  final VisionExtraction extraction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final total = extraction.receiptTotal;
    return Container(
      key: const ValueKey('image-receipt-items'),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(tokens.radius),
        border: Border.all(color: tokens.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '품목 ${extraction.items.length}줄 · 합 ${won(extraction.itemSum)}'
            '${total == null ? '' : ' · 영수증의 합계 ${won(total)}'}',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 4),
          for (final item in extraction.items)
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.name.isEmpty ? '(이름 없음)' : item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: muted,
                  ),
                ),
                const SizedBox(width: 8),
                Text(won(item.amount), style: tokens.amountStyle(muted)),
              ],
            ),
        ],
      ),
    );
  }
}

/// 원본 이미지. 글자를 견주어 볼 수 있게 확대 · 이동이 된다.
class _Original extends StatelessWidget {
  const _Original({required this.bytes, required this.pageId});

  final Uint8List bytes;
  final int pageId;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(context.tokens.radius),
      child: ColoredBox(
        color: scheme.surfaceContainerHighest,
        child: InteractiveViewer(
          maxScale: 6,
          child: Center(
            child: Image.memory(
              bytes,
              key: ValueKey('image-original-$pageId'),
              fit: BoxFit.contain,
              gaplessPlayback: true,
              semanticLabel: '원본 이미지',
              errorBuilder: (context, error, stack) => Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  '이미지를 그리지 못했습니다.',
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 대기열: 장마다 이름과 상태. 누르면 그 장을 펼친다.
class _QueueStrip extends StatelessWidget {
  const _QueueStrip({
    required this.pages,
    required this.selectedId,
    required this.onSelect,
    required this.onRemove,
  });

  final List<ImagePage> pages;
  final int selectedId;
  final ValueChanged<int> onSelect;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tokens = context.tokens;
    return SizedBox(
      height: 60,
      child: ListView.separated(
        key: const ValueKey('image-queue'),
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        itemCount: pages.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final page = pages[index];
          final selected = page.id == selectedId;
          final flagged =
              page.status == PageStatus.failed || page.pendingCount > 0;
          return Material(
            color: selected ? tokens.accentSoft : scheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(tokens.radius),
              side: BorderSide(
                color: selected ? scheme.primary : tokens.border,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              key: ValueKey('image-page-${page.id}'),
              onTap: () => onSelect(page.id),
              child: Padding(
                padding: const EdgeInsets.only(left: 12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 160),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${index + 1}. ${page.name}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelMedium,
                          ),
                          Text(
                            _statusLabel(page),
                            key: ValueKey('image-page-status-${page.id}'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: flagged
                                  ? tokens.warn
                                  : scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      key: ValueKey('image-page-remove-${page.id}'),
                      tooltip: '대기열에서 빼기',
                      visualDensity: VisualDensity.compact,
                      onPressed: () => onRemove(page.id),
                      icon: const Icon(Icons.close, size: 16),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// 아래 줄: 보낼 건수와 "검토함으로 보내기".
class _SendBar extends StatelessWidget {
  const _SendBar({required this.state, required this.onSend});

  final ImageInputState state;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final pending = state.pendingCount;
    final unread = state.unreadCount;
    final String text;
    if (pending > 0) {
      // 검산 표시는 검토함까지 이어지지 않는다. 원본이 옆에 있는 여기서 풀고 보낸다.
      text = '확인 필요 $pending건이 남았습니다. 고치거나 ‘맞음’을 누르거나 빼 주세요.';
    } else if (unread > 0 && !state.paused) {
      text = '읽는 중입니다 · 지금까지 ${state.includedCount}건';
    } else if (unread > 0) {
      text = '${state.includedCount}건 포함 · 읽지 않은 이미지 $unread장은 보내지 않습니다';
    } else {
      text = '${state.includedCount}건 포함';
    }
    final warn = pending > 0;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: tokens.border)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                text,
                key: const ValueKey('image-send-summary'),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: warn
                      ? tokens.warn
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(width: 12),
            FilledButton(
              key: const ValueKey('image-send'),
              onPressed: state.canSend ? onSend : null,
              child: const Text('검토함으로 보내기'),
            ),
          ],
        ),
      ),
    );
  }
}
