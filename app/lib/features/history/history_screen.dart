import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/providers.dart';
import '../../app/theme/tokens.dart';
import '../../core/breakpoints.dart';
import '../../core/formatters.dart';
import '../../core/local_date.dart';
import '../../data/db/database.dart';
import '../../data/repositories/input_batch_repository.dart';
import '../../domain/enums.dart';
import '../common/widgets.dart';
import 'history_actions.dart';

/// 이 가계부의 묶음 목록(최근 순).
final inputBatchesProvider = StreamProvider<List<InputBatchRow>>(
  (ref) => ref
      .watch(inputBatchRepositoryProvider)
      .watchBatches(ref.watch(ledgerIdProvider)),
);

/// 묶음 하나가 건드린 거래.
final batchItemsProvider = StreamProvider.family<List<BatchItemView>, String>(
  (ref, batchId) =>
      ref.watch(inputBatchRepositoryProvider).watchBatchItems(batchId),
);

/// 묶음이 들어온 경로의 이름.
String batchSourceLabel(TxSource source) => switch (source) {
  TxSource.nl => '한 줄 입력',
  TxSource.paste => '붙여넣기',
  TxSource.image => '이미지 입력',
  TxSource.share => '공유로 받음',
  TxSource.import => '파일 가져오기',
  TxSource.recurring => '반복 거래',
  TxSource.manual => '직접 입력',
};

/// 작업 기록 화면. `docs/SPEC.md` 7.7.
///
/// 입력창 · 이미지 입력 · 가져오기로 저장한 묶음을 보여 주고, 묶음째 되돌리게 한다.
class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  @override
  void initState() {
    super.initState();
    // 화면을 열 때 보관 기간이 지난 기록을 치운다.
    final repository = ref.read(inputBatchRepositoryProvider);
    final ledgerId = ref.read(ledgerIdProvider);
    Future(() => repository.purgeExpired(ledgerId)).catchError((_) => 0);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final batches = ref.watch(inputBatchesProvider);
    final list = batches.value;

    final Widget body;
    if (list != null) {
      body = list.isEmpty
          ? const EmptyState(
              key: ValueKey('history-empty'),
              icon: Icons.history,
              message:
                  '아직 기록이 없습니다.\n'
                  '입력창에 적거나 붙여넣어 저장하면 묶음마다 여기에 남습니다.',
            )
          : Column(
              children: [for (final batch in list) _BatchCard(batch: batch)],
            );
    } else if (batches.hasError) {
      body = EmptyState(
        key: const ValueKey('history-error'),
        icon: Icons.error_outline,
        message: '작업 기록을 불러오지 못했습니다.\n잠시 뒤에 다시 열어 주세요.',
        action: OutlinedButton(
          onPressed: () => ref.invalidate(inputBatchesProvider),
          child: const Text('다시 불러오기'),
        ),
      );
    } else {
      body = const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return SafeArea(
      child: ListView(
        key: const ValueKey('history-list'),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          Row(
            children: [
              // 좁은 창에는 옆 메뉴가 없다. 들어온 곳(설정)으로 돌아갈 길을 둔다.
              if (!WindowSize.of(context).isExpanded)
                IconButton(
                  tooltip: '설정으로',
                  onPressed: () => context.go('/settings'),
                  icon: const Icon(Icons.arrow_back),
                ),
              Expanded(
                child: Text('작업 기록', style: theme.textTheme.headlineSmall),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '입력창 · 이미지 입력 · 가져오기로 저장한 묶음입니다. '
            '${InputBatchRepository.retentionDays}일 동안 이 기기에만 보관하고, '
            '원문은 남기지 않습니다.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          body,
        ],
      ),
    );
  }
}

/// 묶음 하나: 때 · 경로 · 건수 · 상태. 누르면 그 묶음의 거래와 되돌리기가 보인다.
class _BatchCard extends ConsumerStatefulWidget {
  const _BatchCard({required this.batch});

  final InputBatchRow batch;

  @override
  ConsumerState<_BatchCard> createState() => _BatchCardState();
}

class _BatchCardState extends ConsumerState<_BatchCard> {
  bool _open = false;
  bool _busy = false;

  Future<void> _undo() async {
    final batch = widget.batch;
    final messenger = ScaffoldMessenger.of(context);
    final container = ProviderScope.containerOf(context, listen: false);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('이 묶음을 되돌릴까요?'),
        content: const Text(
          '이 묶음이 만든 거래 가운데 그 뒤에 고치지 않은 것을 지우고, '
          '취소로 표시한 거래는 취소를 풉니다. 고친 거래는 남깁니다. '
          '되돌린 묶음은 다시 되돌릴 수 없습니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('그만두기'),
          ),
          FilledButton(
            key: const ValueKey('history-undo-confirm'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('되돌리기'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    await undoBatchAndNotify(messenger, container, batch.id);
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tokens = context.tokens;
    final batch = widget.batch;
    final undone = batch.undoneAt != null;
    final when = batch.createdAt.toLocal();
    final today = ref.watch(todayProvider);
    final day = LocalDate.fromDateTime(when);
    final dayText = day.year == today.year ? dayLabel(day) : fullDateLabel(day);

    return Card(
      key: ValueKey('history-batch-${batch.id}'),
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            key: ValueKey('history-open-${batch.id}'),
            onTap: () => setState(() => _open = !_open),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$dayText ${formatTimeOfDay(when)}',
                          style: theme.textTheme.titleSmall,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${batchSourceLabel(batch.source)} · ${batch.itemCount}건',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (undone)
                    Container(
                      key: ValueKey('history-undone-${batch.id}'),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(tokens.radius / 2),
                      ),
                      child: Text(
                        '되돌림',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  const SizedBox(width: 4),
                  Icon(
                    _open ? Icons.expand_less : Icons.expand_more,
                    semanticLabel: _open ? '접기' : '펼치기',
                  ),
                  const SizedBox(width: 8),
                ],
              ),
            ),
          ),
          if (_open) ...[
            const Divider(height: 1),
            _BatchItems(batchId: batch.id),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: undone
                  ? Text(
                      '${dayLabel(LocalDate.fromDateTime(batch.undoneAt!.toLocal()))}에 '
                      '되돌린 묶음입니다. 다시 되돌릴 수 없습니다.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    )
                  : Align(
                      alignment: Alignment.centerRight,
                      child: OutlinedButton.icon(
                        key: ValueKey('history-undo-${batch.id}'),
                        onPressed: _busy ? null : _undo,
                        icon: const Icon(Icons.undo, size: 18),
                        label: const Text('이 묶음 되돌리기'),
                      ),
                    ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 묶음이 건드린 거래의 지금 모습.
class _BatchItems extends ConsumerWidget {
  const _BatchItems({required this.batchId});

  final String batchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tokens = context.tokens;
    final items = ref.watch(batchItemsProvider(batchId));
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: scheme.onSurfaceVariant,
    );
    final list = items.value;
    if (list == null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: items.hasError
            ? Text('이 묶음의 거래를 불러오지 못했습니다. 접었다가 다시 펼쳐 주세요.', style: muted)
            : const Center(child: CircularProgressIndicator()),
      );
    }
    if (list.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text('이 묶음이 건드린 거래가 없습니다.', style: muted),
      );
    }

    return Column(
      children: [
        for (final item in list)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: _itemRow(item, theme, tokens, muted),
          ),
      ],
    );
  }

  Widget _itemRow(
    BatchItemView item,
    ThemeData theme,
    AppTokens tokens,
    TextStyle? muted,
  ) {
    final view = item.transaction;
    final canceledByBatch = item.item.kind == BatchItemKind.canceled;
    if (view == null || item.isGone) {
      return Row(
        children: [
          Expanded(
            child: Text(
              canceledByBatch ? '취소로 표시했던 거래 · 지금은 지워짐' : '지워진 거래',
              style: muted,
            ),
          ),
        ],
      );
    }
    final row = view.row;
    // 음수 지출은 환불이다. 부호를 뒤집어 '+'로 보인다.
    final (amountText, amountColor) = switch (row.type) {
      TxType.income => ('+${won(row.amount)}', tokens.income),
      TxType.expense => (
        '${row.amount < 0 ? '+' : '-'}${won(row.amount.abs())}',
        tokens.expense,
      ),
      TxType.transfer => (won(row.amount), tokens.transfer),
    };
    final status = [
      monthDay(row.occurredOn),
      if (row.type == TxType.transfer) '이체' else view.categoryName ?? '분류 없음',
      if (canceledByBatch)
        row.canceledAt != null ? '이 묶음이 취소로 표시함' : '취소가 풀려 있음'
      else if (item.isEdited)
        '저장한 뒤에 고침 · 되돌려도 남습니다',
    ].join(' · ');
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                view.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium,
              ),
              Text(status, style: muted),
            ],
          ),
        ),
        const SizedBox(width: 8),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 150),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(
              amountText,
              maxLines: 1,
              style: tokens
                  .amountStyle(theme.textTheme.bodyLarge)
                  .copyWith(
                    color: view.isCanceled
                        ? theme.colorScheme.outline
                        : amountColor,
                    fontWeight: FontWeight.w600,
                    decoration: view.isCanceled
                        ? TextDecoration.lineThrough
                        : null,
                  ),
            ),
          ),
        ),
      ],
    );
  }
}
