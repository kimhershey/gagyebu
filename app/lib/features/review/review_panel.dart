import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/providers.dart';
import '../../core/breakpoints.dart';
import '../../data/db/database.dart';
import '../common/widgets.dart';
import '../history/history_actions.dart';
import 'review_state.dart';
import 'review_tile.dart';

/// 검토함: 초안 묶음을 보고 건마다 포함 · 고치기 · 제외를 정한 뒤 한 번에 저장한다
/// (`docs/SPEC.md` 7.6). 넓은 창에서는 뼈대의 오른쪽 칸에 들어간다.
///
/// 내용은 [reviewSessionProvider]에 있고 이 위젯은 그것을 그리기만 한다. 그래서 창 크기에
/// 따라 옆 칸, 겹친 칸, 전체 화면으로 자리가 바뀌어도 검토하던 것이 남는다.
class ReviewPanel extends ConsumerStatefulWidget {
  const ReviewPanel({super.key});

  @override
  ConsumerState<ReviewPanel> createState() => _ReviewPanelState();
}

class _ReviewPanelState extends ConsumerState<ReviewPanel> {
  final _focus = FocusNode(debugLabel: 'review-panel');

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocusChanged);
    // 앞선 묶음의 "저장했습니다" 알림이 아직 떠 있으면 거둔다. 화면 아래쪽의 알림이
    // 검토함의 저장 단추를 가린다. 되돌리기는 작업 기록에서도 할 수 있다.
    if (ref.read(reviewSessionProvider) != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) ScaffoldMessenger.maybeOf(context)?.hideCurrentSnackBar();
      });
    }
  }

  @override
  void dispose() {
    _focus
      ..removeListener(_onFocusChanged)
      ..dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    if (mounted) setState(() {});
  }

  /// 검토함 자체에 초점이 있을 때의 키: ↑/↓ 이동, Space 포함/제외, Enter 고치기,
  /// Delete 제외, Ctrl/⌘+Enter 저장, Esc 닫기.
  ///
  /// 안쪽의 글 칸이나 단추에 초점이 있을 때는 듣지 않는다. 글 칸에서는 Space와 Delete가
  /// 글자를 넣고 지우는 키다.
  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (!node.hasPrimaryFocus) return KeyEventResult.ignored;
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    final state = ref.read(reviewSessionProvider);
    if (state == null) return KeyEventResult.ignored;
    final session = ref.read(reviewSessionProvider.notifier);
    final keyboard = HardwareKeyboard.instance;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowDown) {
      session.moveFocus(1);
    } else if (key == LogicalKeyboardKey.arrowUp) {
      session.moveFocus(-1);
    } else if (key == LogicalKeyboardKey.space) {
      session.toggleInclude(state.focused);
    } else if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      if (keyboard.isControlPressed || keyboard.isMetaPressed) {
        saveReviewAndNotify(context);
      } else {
        session.toggleExpanded(state.focused);
      }
    } else if (key == LogicalKeyboardKey.delete) {
      session.setInclude(state.focused, false);
    } else if (key == LogicalKeyboardKey.escape) {
      confirmDiscardReview(context);
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(reviewSessionProvider);
    final theme = Theme.of(context);
    if (state == null) {
      return const EmptyState(
        key: ValueKey('review-empty'),
        icon: Icons.fact_check_outlined,
        message:
            '검토할 내용이 없습니다.\n'
            '입력창에 결제 문자를 붙여넣거나 한 줄로 적어 보내면 여기에 초안이 올라옵니다.',
      );
    }

    final accounts = ref.watch(accountsProvider).value ?? const <AccountRow>[];
    final categories =
        ref.watch(categoriesProvider).value ?? const <CategoryRow>[];
    final today = ref.watch(todayProvider);
    final session = ref.read(reviewSessionProvider.notifier);
    final drafts = state.drafts;

    // 초안 뒤에 접어 둔 칸(안내문, 읽지 못한 글)이 온다.
    final folded = <Widget>[
      if (drafts.isEmpty)
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
          child: Text(
            '거래로 읽은 건이 없습니다.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      if (state.notices.isNotEmpty)
        FoldedSection(
          key: const ValueKey('review-notices'),
          icon: Icons.filter_alt_outlined,
          title: '거래가 아닌 안내문 ${state.notices.length}건은 뺐습니다',
          lines: [for (final n in state.notices) n.raw],
        ),
      if (state.unknown.isNotEmpty)
        FoldedSection(
          key: const ValueKey('review-unknown'),
          icon: Icons.help_outline,
          title: '읽지 못한 내용 ${state.unknown.length}건',
          lines: [for (final u in state.unknown) u.raw],
          footer: '아는 형식이 아닙니다. 직접 입력으로 넣을 수 있습니다.',
          actionLabel: '직접 입력',
          actionKey: 'review-manual',
          onAction: (index) {
            // 직접 넣으러 가는 글은 목록에서 뺀다. 검토하던 나머지는 그대로 남는다.
            session.dropUnknown(index);
            context.go('/transactions?new=expense');
          },
        ),
    ];

    final saveLabel = state.saving
        ? '저장하는 중입니다'
        : state.blockedCount > 0
        ? '채워야 하는 건이 ${state.blockedCount}건 있습니다'
        : state.savableCount == 0
        ? '저장할 건이 없습니다'
        : '모두 승인하고 저장 (${state.savableCount}건)';

    return Focus(
      focusNode: _focus,
      onKeyEvent: _onKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
            child: Row(
              children: [
                Expanded(child: Text('검토함', style: theme.textTheme.titleLarge)),
                IconButton(
                  key: const ValueKey('review-close'),
                  tooltip: '닫기',
                  onPressed: () => confirmDiscardReview(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              key: const ValueKey('review-list'),
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
              itemCount: 1 + drafts.length + folded.length,
              itemBuilder: (context, position) {
                // 요약도 목록과 함께 밀려 올라가게 둔다. 낮은 창에서 목록의 자리가 남는다.
                if (position == 0) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                    child: Text(
                      state.summary,
                      key: const ValueKey('review-summary'),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  );
                }
                final index = position - 1;
                if (index >= drafts.length) {
                  return folded[index - drafts.length];
                }
                return ReviewTile(
                  key: ValueKey('review-$index'),
                  index: index,
                  draft: drafts[index],
                  accounts: accounts,
                  categories: categories,
                  today: today,
                  expanded: state.expanded == index,
                  highlighted: _focus.hasPrimaryFocus && state.focused == index,
                  onFocus: () {
                    session.setFocused(index);
                    _focus.requestFocus();
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (state.needsReviewCount > 0)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      '확인 필요 ${state.needsReviewCount}건은 이대로 저장하면 내역에 '
                      '‘확인 필요’로 남습니다.',
                      key: const ValueKey('review-needs-review-note'),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                if (state.saveFailed)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      '저장하지 못했습니다. 한 건도 저장되지 않았습니다. '
                      '자산과 금액을 확인한 뒤 다시 눌러 주세요.',
                      key: const ValueKey('review-save-error'),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ),
                FilledButton(
                  key: const ValueKey('review-save'),
                  onPressed: state.canSave
                      ? () => saveReviewAndNotify(context)
                      : null,
                  child: Text(saveLabel, textAlign: TextAlign.center),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 좁은 창에서 검토함을 전체 화면으로 보여 준다(`/review`).
class ReviewScreen extends ConsumerStatefulWidget {
  const ReviewScreen({super.key});

  @override
  ConsumerState<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends ConsumerState<ReviewScreen> {
  bool _leaving = false;

  /// 이 화면을 닫는다. 돌아갈 화면이 없으면(주소로 바로 들어왔으면) 홈으로 간다.
  void _leave() {
    if (_leaving) return;
    _leaving = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // 저장하거나 버려서 검토가 끝나면 닫는다.
    ref.listen(reviewActiveProvider, (previous, next) {
      if (previous == true && !next) _leave();
    });
    final active = ref.watch(reviewActiveProvider);
    // 창을 넓히면 뼈대가 옆 칸에 검토함을 그린다. 같은 내용을 두 번 그리지 않게 물러난다.
    if (active && !WindowSize.of(context).isCompact) _leave();

    return Scaffold(
      body: SafeArea(
        child: active
            ? const ReviewPanel()
            : Column(
                children: [
                  const Expanded(child: ReviewPanel()),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: OutlinedButton(
                      key: const ValueKey('review-back'),
                      onPressed: _leave,
                      child: const Text('돌아가기'),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

/// 검토함을 닫는다. 검토하던 건이 있으면 버릴지 묻는다. 버렸으면 true.
///
/// 닫기 단추와 Esc가 함께 쓴다.
Future<bool> confirmDiscardReview(BuildContext context) async {
  final container = ProviderScope.containerOf(context, listen: false);
  final state = container.read(reviewSessionProvider);
  if (state == null) return true;
  if (state.drafts.isNotEmpty) {
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('검토하던 내용을 버릴까요?'),
        content: Text('저장하지 않은 초안 ${state.drafts.length}건이 사라집니다.'),
        actions: [
          TextButton(
            key: const ValueKey('review-keep'),
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('계속 검토'),
          ),
          FilledButton(
            key: const ValueKey('review-discard'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('버리기'),
          ),
        ],
      ),
    );
    if (discard != true) return false;
  }
  container.read(reviewSessionProvider.notifier).discard();
  return true;
}

/// "모두 승인하고 저장": 포함한 건을 한 번에 저장하고, 첫 건의 달로 옮긴 뒤 "되돌리기"가
/// 달린 알림을 띄운다. 저장 단추와 Ctrl/⌘+Enter가 함께 쓴다.
Future<void> saveReviewAndNotify(BuildContext context) async {
  // 저장이 끝나면 검토함이 화면에서 사라진다. 그 뒤에도 쓸 것은 미리 잡아 둔다.
  final container = ProviderScope.containerOf(context, listen: false);
  final messenger = ScaffoldMessenger.of(context);
  try {
    final saved = await container
        .read(reviewSessionProvider.notifier)
        .saveAll();
    if (saved == null) return;
    container.read(selectedPeriodProvider.notifier).show(saved.firstDate);
    showBatchSavedNotice(
      messenger,
      container,
      batchId: saved.batchId,
      count: saved.count,
    );
  } catch (_) {
    // 검토함이 저장 단추 위에 알린다(ReviewState.saveFailed). 알림을 띄우면 그 단추를 가린다.
  }
}
