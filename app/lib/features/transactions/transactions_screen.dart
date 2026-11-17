import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/providers.dart';
import '../../core/breakpoints.dart';
import '../../core/formatters.dart';
import '../../core/local_date.dart';
import '../../data/db/database.dart';
import '../../data/repositories/ledger_repository.dart';
import '../../domain/enums.dart';
import '../common/widgets.dart';
import 'transaction_editor.dart';
import 'transaction_tile.dart';

/// 내역: 한 달의 거래 목록과 거래 편집.
///
/// - 좁음: 날짜별 목록. 거래를 누르면 편집 화면이 목록을 덮는다.
/// - 중간: 목록과 편집 두 칸.
/// - 넓음: 표와 편집 패널.
class TransactionsScreen extends ConsumerWidget {
  const TransactionsScreen({super.key, this.selectedId, this.newType});

  /// 고치려고 고른 거래(`?id=`).
  final String? selectedId;

  /// 새 거래의 종류(`?new=expense|income|transfer`).
  final String? newType;

  bool get _editing => selectedId != null || newType != null;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final size = WindowSize.of(context);
    void close() => context.go('/transactions');

    final editor = _editing
        ? _EditorHost(
            key: ValueKey('editor-${selectedId ?? 'new-$newType'}'),
            selectedId: selectedId,
            newType: newType,
            onDone: close,
          )
        : null;

    if (size.isCompact) {
      return SafeArea(child: editor ?? _ListPane(selectedId: selectedId));
    }
    final detail =
        editor ??
        EmptyState(
          icon: Icons.edit_note,
          message: '거래를 고르면 여기서 고칠 수 있다',
          action: FilledButton.tonal(
            onPressed: () => context.go('/transactions?new=expense'),
            child: const Text('새 거래'),
          ),
        );
    return SafeArea(
      child: Row(
        children: [
          Expanded(
            child: _ListPane(selectedId: selectedId, table: size.isExpanded),
          ),
          const VerticalDivider(width: 1),
          // 넓은 창은 편집 칸의 폭을 고정하고, 중간 창은 두 칸을 똑같이 나눈다.
          if (size.isExpanded)
            SizedBox(width: 380, child: detail)
          else
            Expanded(child: detail),
        ],
      ),
    );
  }
}

/// 고른 거래를 읽어 편집 폼에 넘긴다.
class _EditorHost extends ConsumerWidget {
  const _EditorHost({
    super.key,
    required this.selectedId,
    required this.newType,
    required this.onDone,
  });

  final String? selectedId;
  final String? newType;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = selectedId;
    if (id == null) {
      final type = TxType.values.firstWhere(
        (t) => t.code == newType,
        orElse: () => TxType.expense,
      );
      return TransactionEditor(initialType: type, onDone: onDone);
    }
    return FutureBuilder<TxRow?>(
      future: ref.watch(repositoryProvider).transactionById(id),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final row = snapshot.data;
        if (row == null || row.deletedAt != null) {
          return EmptyState(
            icon: Icons.search_off,
            message: '거래를 찾지 못했다',
            action: TextButton(onPressed: onDone, child: const Text('목록으로')),
          );
        }
        return TransactionEditor(existing: row, onDone: onDone);
      },
    );
  }
}

class _ListPane extends ConsumerStatefulWidget {
  const _ListPane({required this.selectedId, this.table = false});

  final String? selectedId;

  /// 넓은 창에서는 표로 그린다.
  final bool table;

  @override
  ConsumerState<_ListPane> createState() => _ListPaneState();
}

class _ListPaneState extends ConsumerState<_ListPane> {
  late final TextEditingController _search = TextEditingController(
    text: ref.read(searchQueryProvider),
  );

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final transactions = ref.watch(transactionsProvider);
    final query = ref.watch(searchQueryProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
          child: LayoutBuilder(
            builder: (context, constraints) {
              void create() => context.go('/transactions?new=expense');
              // 칸이 좁으면 글자를 빼고 아이콘만 둔다.
              final narrow = constraints.maxWidth < 380;
              return Row(
                children: [
                  const Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: MonthSwitcher(),
                    ),
                  ),
                  if (narrow)
                    IconButton.filledTonal(
                      key: const ValueKey('new-transaction'),
                      tooltip: '직접 입력',
                      onPressed: create,
                      icon: const Icon(Icons.edit_outlined),
                    )
                  else
                    FilledButton.tonalIcon(
                      key: const ValueKey('new-transaction'),
                      onPressed: create,
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: const Text('직접 입력'),
                    ),
                ],
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: TextField(
            controller: _search,
            decoration: InputDecoration(
              hintText: '상대방 · 메모 · 분류 검색',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: query.isEmpty
                  ? null
                  : IconButton(
                      tooltip: '검색어 지우기',
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _search.clear();
                        ref.read(searchQueryProvider.notifier).set('');
                      },
                    ),
            ),
            onChanged: (value) =>
                ref.read(searchQueryProvider.notifier).set(value),
          ),
        ),
        Expanded(
          child: AsyncBody<List<TransactionView>>(
            value: transactions,
            builder: (list) {
              if (list.isEmpty) {
                return EmptyState(
                  icon: Icons.receipt_long_outlined,
                  message: query.isEmpty ? '이 달의 내역이 없다' : '검색 결과가 없다',
                );
              }
              return widget.table
                  ? _TransactionTable(list: list, selectedId: widget.selectedId)
                  : _GroupedList(list: list, selectedId: widget.selectedId);
            },
          ),
        ),
      ],
    );
  }
}

/// 날짜별로 묶은 목록.
class _GroupedList extends StatelessWidget {
  const _GroupedList({required this.list, required this.selectedId});

  final List<TransactionView> list;
  final String? selectedId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // 날짜 머리줄과 거래를 한 줄씩 펼친다.
    final rows = <Object>[];
    LocalDate? current;
    for (final view in list) {
      if (view.row.occurredOn != current) {
        current = view.row.occurredOn;
        rows.add(current);
      }
      rows.add(view);
    }
    int dayTotal(LocalDate date) => list
        .where((v) => v.row.occurredOn == date)
        .fold(0, (sum, v) => sum + v.signedAmount);

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: rows.length,
      itemBuilder: (context, index) {
        final row = rows[index];
        if (row is LocalDate) {
          return Container(
            color: theme.colorScheme.surfaceContainerLow,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(dayLabel(row), style: theme.textTheme.labelLarge),
                ),
                Text(
                  signedWon(dayTotal(row)),
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          );
        }
        final view = row as TransactionView;
        return TransactionTile(
          view: view,
          selected: view.row.id == selectedId,
          onTap: () => context.go('/transactions?id=${view.row.id}'),
        );
      },
    );
  }
}

/// 넓은 창의 표.
class _TransactionTable extends StatelessWidget {
  const _TransactionTable({required this.list, required this.selectedId});

  final List<TransactionView> list;
  final String? selectedId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final header = theme.textTheme.labelMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    Widget cells(List<Widget> children) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          SizedBox(width: 92, child: children[0]),
          Expanded(flex: 5, child: children[1]),
          Expanded(flex: 3, child: children[2]),
          Expanded(flex: 3, child: children[3]),
          SizedBox(
            width: 120,
            child: Align(alignment: Alignment.centerRight, child: children[4]),
          ),
        ],
      ),
    );

    Text cell(String text) =>
        Text(text, maxLines: 1, overflow: TextOverflow.ellipsis);

    return Column(
      children: [
        cells([
          Text('날짜', style: header),
          Text('내용', style: header),
          Text('분류', style: header),
          Text('자산', style: header),
          Text('금액', style: header),
        ]),
        const Divider(height: 1),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.only(bottom: 24),
            itemCount: list.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final view = list[index];
              final row = view.row;
              final selected = row.id == selectedId;
              return Material(
                color: selected
                    ? theme.colorScheme.secondaryContainer.withValues(
                        alpha: 0.5,
                      )
                    : Colors.transparent,
                child: InkWell(
                  key: ValueKey('row-${row.id}'),
                  onTap: () => context.go('/transactions?id=${row.id}'),
                  child: cells([
                    cell(
                      '${monthDay(row.occurredOn)} ${weekdayName(row.occurredOn)}',
                    ),
                    cell(view.isCanceled ? '${view.title} (취소)' : view.title),
                    cell(
                      row.type == TxType.transfer
                          ? '이체'
                          : view.categoryName ?? '분류 없음',
                    ),
                    cell(
                      row.type == TxType.transfer
                          ? '${view.accountName} → ${view.toAccountName ?? ''}'
                          : view.accountName,
                    ),
                    AmountText(view, style: theme.textTheme.bodyMedium),
                  ]),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
