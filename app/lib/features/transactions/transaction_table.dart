import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/providers.dart';
import '../../app/theme/tokens.dart';
import '../../core/formatters.dart';
import '../../data/db/database.dart';
import '../../data/repositories/ledger_repository.dart';
import '../../domain/enums.dart';
import 'bulk_edit.dart';
import 'transaction_tile.dart';

/// 넓은 창의 표. 행을 여러 개 골라 한꺼번에 고칠 수 있다(`docs/SPEC.md` 7.3).
class TransactionTable extends ConsumerStatefulWidget {
  const TransactionTable({
    super.key,
    required this.list,
    required this.selectedId,
  });

  final List<TransactionView> list;

  /// 편집 칸에 열려 있는 거래.
  final String? selectedId;

  @override
  ConsumerState<TransactionTable> createState() => _TransactionTableState();
}

class _TransactionTableState extends ConsumerState<TransactionTable> {
  /// 일괄 수정하려고 고른 행.
  final _picked = <String>{};
  bool _busy = false;

  void _toggle(String id, bool on) => setState(() {
    on ? _picked.add(id) : _picked.remove(id);
  });

  void _say(String message) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));

  /// 일괄 수정을 돌리고 결과를 알린다. 중간에 실패하면 거기서 멈춘다(앞의 것은 저장돼 있다).
  Future<void> _run(Future<String> Function() action) async {
    setState(() => _busy = true);
    try {
      final message = await action();
      if (!mounted) return;
      setState(_picked.clear);
      _say(message);
    } catch (_) {
      if (mounted) _say('일부를 바꾸지 못했습니다. 목록을 확인하고 다시 시도해 주세요.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _withSkipped(String message, int skipped, String reason) =>
      skipped == 0 ? message : '$message $reason $skipped건은 그대로 두었습니다.';

  Future<void> _changeCategory(List<TxRow> rows) async {
    final categories =
        ref.read(categoriesProvider).value ?? const <CategoryRow>[];
    final kinds = {
      for (final row in rows)
        if (row.type == TxType.expense)
          CategoryKind.expense
        else if (row.type == TxType.income)
          CategoryKind.income,
    };
    if (kinds.isEmpty) {
      _say('이체에는 분류가 없습니다.');
      return;
    }
    final choice = await showDialog<_CategoryChoice>(
      context: context,
      builder: (context) => _CategoryPicker(
        categories: [
          for (final c in categories)
            if (kinds.contains(c.kind)) c,
        ],
        showKind: kinds.length > 1,
      ),
    );
    if (choice == null) return;
    final repo = ref.read(repositoryProvider);
    await _run(() async {
      final result = await bulkSetCategory(repo, rows, choice.category);
      final name = choice.category?.name ?? '분류 없음';
      return _withSkipped(
        "${result.done}건을 '$name' 분류로 바꿨습니다.",
        result.skipped,
        '종류가 맞지 않는',
      );
    });
  }

  Future<void> _changeAccount(List<TxRow> rows) async {
    final accounts = ref.read(accountsProvider).value ?? const <AccountRow>[];
    final account = await showDialog<AccountRow>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('자산 바꾸기'),
        children: [
          for (final a in accounts)
            SimpleDialogOption(
              key: ValueKey('bulk-pick-account-${a.id}'),
              onPressed: () => Navigator.of(context).pop(a),
              child: Text(a.name),
            ),
        ],
      ),
    );
    if (account == null) return;
    final repo = ref.read(repositoryProvider);
    await _run(() async {
      final result = await bulkSetAccount(repo, rows, account.id);
      return _withSkipped(
        "${result.done}건을 '${account.name}' 자산으로 바꿨습니다.",
        result.skipped,
        '받는 자산이 같은 이체',
      );
    });
  }

  Future<void> _confirm(List<TxRow> rows) async {
    final repo = ref.read(repositoryProvider);
    await _run(() async => '${await bulkConfirm(repo, rows)}건을 확인했습니다.');
  }

  Future<void> _delete(List<TxRow> rows) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('거래 ${rows.length}건을 지울까요?'),
        content: const Text('지운 거래는 다른 기기에서도 사라집니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          FilledButton(
            key: const ValueKey('bulk-delete-confirm'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('지우기'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final repo = ref.read(repositoryProvider);
    // 편집 칸에 열려 있던 거래를 지웠으면 편집 칸을 닫는다.
    final closeEditor = rows.any((row) => row.id == widget.selectedId);
    await _run(() async {
      final count = await bulkDelete(repo, rows);
      if (closeEditor && mounted) context.go('/transactions');
      return '$count건을 지웠습니다.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final list = widget.list;
    // 필터를 바꾸거나 지워서 목록에서 빠진 행은 고른 것에서도 뺀다.
    final ids = {for (final view in list) view.row.id};
    _picked.retainAll(ids);
    final pickedRows = [
      for (final view in list)
        if (_picked.contains(view.row.id)) view.row,
    ];
    final header = theme.textTheme.labelMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    Widget cells(Widget check, List<Widget> children) => ConstrainedBox(
      constraints: BoxConstraints(minHeight: tokens.rowHeight),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 2, 16, 2),
        child: Row(
          children: [
            SizedBox(width: 44, child: check),
            SizedBox(width: 92, child: children[0]),
            Expanded(flex: 5, child: children[1]),
            Expanded(flex: 3, child: children[2]),
            Expanded(flex: 3, child: children[3]),
            SizedBox(
              width: 120,
              child: Align(
                alignment: Alignment.centerRight,
                child: FittedBox(fit: BoxFit.scaleDown, child: children[4]),
              ),
            ),
          ],
        ),
      ),
    );

    Text cell(String text, {TextStyle? style}) =>
        Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: style);

    final allPicked = list.isNotEmpty && pickedRows.length == list.length;

    return Column(
      children: [
        if (pickedRows.isNotEmpty)
          _BulkBar(
            count: pickedRows.length,
            busy: _busy,
            canConfirm: pickedRows.any(
              (row) => row.status == TxStatus.needsReview,
            ),
            onCategory: () => _changeCategory(pickedRows),
            onAccount: () => _changeAccount(pickedRows),
            onConfirm: () => _confirm(pickedRows),
            onDelete: () => _delete(pickedRows),
            onClear: () => setState(_picked.clear),
          ),
        cells(
          Checkbox(
            key: const ValueKey('select-all'),
            semanticLabel: '모두 고르기',
            tristate: true,
            value: allPicked ? true : (pickedRows.isEmpty ? false : null),
            onChanged: (_) => setState(() {
              allPicked ? _picked.clear() : _picked.addAll(ids);
            }),
          ),
          [
            Text('날짜', style: header),
            Text('내용', style: header),
            Text('분류', style: header),
            Text('자산', style: header),
            Text('금액', style: header),
          ],
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.only(bottom: 24),
            itemCount: list.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final view = list[index];
              final row = view.row;
              final selected = row.id == widget.selectedId;
              final picked = _picked.contains(row.id);
              return Material(
                color: selected || picked
                    ? theme.colorScheme.secondaryContainer.withValues(
                        alpha: 0.5,
                      )
                    : Colors.transparent,
                child: InkWell(
                  key: ValueKey('row-${row.id}'),
                  onTap: () => context.go('/transactions?id=${row.id}'),
                  child: cells(
                    Checkbox(
                      key: ValueKey('select-${row.id}'),
                      semanticLabel: '${view.title} 고르기',
                      value: picked,
                      onChanged: (on) => _toggle(row.id, on ?? false),
                    ),
                    [
                      cell(
                        '${monthDay(row.occurredOn)} ${weekdayName(row.occurredOn)}',
                      ),
                      Row(
                        children: [
                          if (needsReview(view)) ...[
                            const NeedsReviewBadge(iconOnly: true),
                            const SizedBox(width: 6),
                          ],
                          Expanded(
                            child: cell(
                              view.isCanceled
                                  ? '${view.title} (취소)'
                                  : view.title,
                            ),
                          ),
                        ],
                      ),
                      if (row.type == TxType.transfer)
                        cell('이체')
                      else
                        Row(
                          children: [
                            CategoryDot(categoryId: row.categoryId),
                            const SizedBox(width: 6),
                            Expanded(child: cell(view.categoryName ?? '분류 없음')),
                          ],
                        ),
                      cell(
                        row.type == TxType.transfer
                            ? '${view.accountName} → ${view.toAccountName ?? ''}'
                            : view.accountName,
                      ),
                      AmountText(view, style: theme.textTheme.bodyMedium),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// 고른 행에 할 수 있는 일. 좁으면 단추가 다음 줄로 내려간다.
class _BulkBar extends StatelessWidget {
  const _BulkBar({
    required this.count,
    required this.busy,
    required this.canConfirm,
    required this.onCategory,
    required this.onAccount,
    required this.onConfirm,
    required this.onDelete,
    required this.onClear,
  });

  final int count;
  final bool busy;
  final bool canConfirm;
  final VoidCallback onCategory;
  final VoidCallback onAccount;
  final VoidCallback onConfirm;
  final VoidCallback onDelete;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      key: const ValueKey('bulk-bar'),
      width: double.infinity,
      color: context.tokens.accentSoft,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Wrap(
        spacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Text(
              '$count건 고름',
              key: const ValueKey('bulk-count'),
              style: theme.textTheme.labelLarge,
            ),
          ),
          TextButton.icon(
            key: const ValueKey('bulk-category'),
            onPressed: busy ? null : onCategory,
            icon: const Icon(Icons.label_outline, size: 18),
            label: const Text('분류 바꾸기'),
          ),
          TextButton.icon(
            key: const ValueKey('bulk-account'),
            onPressed: busy ? null : onAccount,
            icon: const Icon(Icons.account_balance_wallet_outlined, size: 18),
            label: const Text('자산 바꾸기'),
          ),
          if (canConfirm)
            TextButton.icon(
              key: const ValueKey('bulk-confirm'),
              onPressed: busy ? null : onConfirm,
              icon: const Icon(Icons.check, size: 18),
              label: const Text('확인함'),
            ),
          TextButton.icon(
            key: const ValueKey('bulk-delete'),
            onPressed: busy ? null : onDelete,
            icon: const Icon(Icons.delete_outline, size: 18),
            label: const Text('삭제'),
          ),
          IconButton(
            key: const ValueKey('bulk-clear'),
            tooltip: '고른 것 풀기',
            onPressed: busy ? null : onClear,
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }
}

/// 분류 고르기의 답. "분류 없음"을 고른 것과 닫은 것을 가르려고 감싼다.
class _CategoryChoice {
  const _CategoryChoice(this.category);

  final CategoryRow? category;
}

class _CategoryPicker extends ConsumerWidget {
  const _CategoryPicker({required this.categories, required this.showKind});

  final List<CategoryRow> categories;

  /// 지출과 수입이 섞여 있으면 어느 쪽 분류인지 함께 적는다.
  final bool showKind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final visuals = ref.watch(categoryVisualsProvider);
    return SimpleDialog(
      title: const Text('분류 바꾸기'),
      children: [
        if (showKind)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Text(
              '지출 분류는 지출에만, 수입 분류는 수입에만 붙습니다.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        for (final c in categories)
          SimpleDialogOption(
            key: ValueKey('bulk-pick-category-${c.id}'),
            onPressed: () => Navigator.of(context).pop(_CategoryChoice(c)),
            child: Row(
              children: [
                Icon(
                  visuals[c.id]?.icon ?? Icons.label_outline,
                  size: 20,
                  color: visuals[c.id]?.color(tokens),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    showKind
                        ? '${c.name} (${c.kind == CategoryKind.expense ? '지출' : '수입'})'
                        : c.name,
                  ),
                ),
              ],
            ),
          ),
        SimpleDialogOption(
          key: const ValueKey('bulk-pick-category-none'),
          onPressed: () =>
              Navigator.of(context).pop(const _CategoryChoice(null)),
          child: Row(
            children: [
              Icon(
                Icons.label_off_outlined,
                size: 20,
                color: Theme.of(context).colorScheme.outline,
              ),
              const SizedBox(width: 12),
              const Expanded(child: Text('분류 없음')),
            ],
          ),
        ),
      ],
    );
  }
}
