import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/providers.dart';
import '../../app/theme/tokens.dart';
import '../../core/breakpoints.dart';
import '../../core/formatters.dart';
import '../../core/local_date.dart';
import '../../data/db/database.dart';
import '../../data/repositories/ledger_repository.dart';
import '../../data/repositories/transaction_query.dart';
import '../../domain/enums.dart';
import '../common/widgets.dart';
import 'transaction_calendar.dart';
import 'transaction_editor.dart';
import 'transaction_filter_sheet.dart';
import 'transaction_table.dart';
import 'transaction_tile.dart';

/// 내역: 한 달의 거래를 목록이나 달력으로 보고 고친다(`docs/SPEC.md` 7.3).
///
/// - 좁음: 날짜별 목록(또는 달력과 그 아래 고른 날의 거래). 거래를 누르면 편집 화면이 덮는다.
/// - 중간: 목록과 편집 두 칸.
/// - 넓음: 표와 편집 칸. 표에서는 여러 행을 골라 한꺼번에 고친다.
///
/// 주소의 쿼리로 필터를 걸 수 있다: `?review=1`(확인 필요만), `?category=<분류 ID>`.
class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key, this.selectedId, this.newType});

  /// 고치려고 고른 거래(`?id=`).
  final String? selectedId;

  /// 새 거래의 종류(`?new=expense|income|transfer`).
  final String? newType;

  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

/// 주소에 필터 쿼리가 없을 때의 표시.
const _noQueryFilter = '|';

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  /// 마지막으로 필터에 옮긴 주소의 쿼리. 같은 주소로 다시 그려질 때 또 걸지 않게 한다.
  String _appliedQuery = _noQueryFilter;

  /// 창 너비가 바뀌어 편집 칸의 자리가 옮겨져도 적던 내용이 남게 한다.
  GlobalKey _editorKey = GlobalKey();
  String? _editorTarget;

  /// 주소의 `review` · `category`를 필터로 옮긴다. 다른 화면(홈의 "확인 필요", 통계의 분류)
  /// 에서 넘어올 때 쓰는 길이라, 걸려 있던 필터와 검색어는 버리고 새로 건다.
  void _applyQueryFilter(Map<String, String> params) {
    final review = params['review'] == '1';
    final category = params['category'] ?? '';
    final key = '${review ? 1 : ''}|$category';
    if (key == _appliedQuery) return;
    _appliedQuery = key;
    if (key == _noQueryFilter) return;
    final filter = TransactionFilter(
      needsReviewOnly: review,
      categoryIds: {if (category.isNotEmpty) category},
    );
    // 화면을 그리는 중에는 상태를 바꿀 수 없어 그린 뒤로 미룬다.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(transactionFilterProvider.notifier).set(filter);
      ref.read(searchQueryProvider.notifier).set('');
    });
  }

  @override
  Widget build(BuildContext context) {
    _applyQueryFilter(GoRouterState.of(context).uri.queryParameters);

    final selectedId = widget.selectedId;
    final newType = widget.newType;
    final target = selectedId ?? (newType == null ? null : 'new-$newType');
    if (target != _editorTarget) {
      _editorTarget = target;
      _editorKey = GlobalKey();
    }
    final mode = ref.watch(transactionViewModeProvider);
    void close() => context.go('/transactions');

    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = WindowSize.of(context);
          final width = constraints.maxWidth;
          final editor = target == null
              ? null
              : _EditorHost(
                  key: _editorKey,
                  selectedId: selectedId,
                  newType: newType,
                  // 달력에서 날을 골라 둔 채 새 거래를 열면 그날로 채운다.
                  initialDate: mode == TransactionViewMode.calendar
                      ? ref.read(shownCalendarDayProvider)
                      : null,
                  onDone: close,
                );

          // 검토함이 옆에 붙어 자리가 줄면 넓은 창이어도 한 칸으로 그린다.
          if (size.isCompact || width < 520) {
            return editor ?? _ListPane(selectedId: selectedId, dayBelow: true);
          }

          // 넓은 창은 편집 칸의 폭을 정해 두고, 중간 창은 두 칸을 똑같이 나눈다.
          final detailWidth = size.isExpanded
              ? (width * 0.42).clamp(300.0, 380.0)
              : (width - 1) / 2;
          final listWidth = width - 1 - detailWidth;
          final detail =
              editor ??
              (mode == TransactionViewMode.calendar
                  ? _DaySidePane(selectedId: selectedId)
                  : EmptyState(
                      icon: Icons.edit_note,
                      message: '거래를 고르면 여기서 고칠 수 있습니다',
                      action: FilledButton.tonal(
                        onPressed: () =>
                            context.go('/transactions?new=expense'),
                        child: const Text('새 거래'),
                      ),
                    ));
          return Row(
            children: [
              Expanded(
                child: _ListPane(
                  selectedId: selectedId,
                  table: size.isExpanded && listWidth >= 560,
                ),
              ),
              const VerticalDivider(width: 1),
              SizedBox(width: detailWidth, child: detail),
            ],
          );
        },
      ),
    );
  }
}

/// 필터를 바꾼다. 주소에 필터 쿼리가 남아 있으면 지워, 같은 주소로 다시 들어올 때
/// (홈의 "확인 필요"를 또 누를 때) 필터가 다시 걸리게 한다.
void _setFilter(BuildContext context, WidgetRef ref, TransactionFilter filter) {
  ref.read(transactionFilterProvider.notifier).set(filter);
  final params = GoRouterState.of(context).uri.queryParameters;
  if (params.containsKey('review') || params.containsKey('category')) {
    final rest = {...params}
      ..remove('review')
      ..remove('category');
    context.go(
      Uri(
        path: '/transactions',
        queryParameters: rest.isEmpty ? null : rest,
      ).toString(),
    );
  }
}

/// 고른 거래를 읽어 편집 폼에 넘긴다.
class _EditorHost extends ConsumerStatefulWidget {
  const _EditorHost({
    super.key,
    required this.selectedId,
    required this.newType,
    required this.initialDate,
    required this.onDone,
  });

  final String? selectedId;
  final String? newType;
  final LocalDate? initialDate;
  final VoidCallback onDone;

  @override
  ConsumerState<_EditorHost> createState() => _EditorHostState();
}

class _EditorHostState extends ConsumerState<_EditorHost> {
  // 한 번만 읽는다. 그릴 때마다 다시 읽으면 적던 내용이 사라진다.
  late final Future<TxRow?>? _row = widget.selectedId == null
      ? null
      : ref.read(repositoryProvider).transactionById(widget.selectedId!);

  // 새 거래의 날짜도 처음 열 때의 것을 쓴다.
  late final LocalDate? _initialDate = widget.initialDate;

  @override
  Widget build(BuildContext context) {
    final future = _row;
    if (future == null) {
      final type = TxType.values.firstWhere(
        (t) => t.code == widget.newType,
        orElse: () => TxType.expense,
      );
      return TransactionEditor(
        initialType: type,
        initialDate: _initialDate,
        onDone: widget.onDone,
      );
    }
    return FutureBuilder<TxRow?>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final row = snapshot.data;
        if (row == null || row.deletedAt != null) {
          return EmptyState(
            icon: Icons.search_off,
            message: snapshot.hasError ? '거래를 불러오지 못했습니다' : '거래를 찾지 못했습니다',
            action: TextButton(
              onPressed: widget.onDone,
              child: const Text('목록으로'),
            ),
          );
        }
        return TransactionEditor(existing: row, onDone: widget.onDone);
      },
    );
  }
}

class _ListPane extends ConsumerStatefulWidget {
  const _ListPane({
    required this.selectedId,
    this.table = false,
    this.dayBelow = false,
  });

  final String? selectedId;

  /// 넓은 창에서는 표로 그린다.
  final bool table;

  /// 달력에서 고른 날의 거래를 달력 아래에 둘지. 아니면 옆 칸이 보여 준다.
  final bool dayBelow;

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

  Future<void> _openFilter() async {
    final picked = await showTransactionFilter(
      context,
      initial: ref.read(transactionFilterProvider),
      categories: ref.read(categoriesProvider).value ?? const [],
      accounts: ref.read(accountsProvider).value ?? const [],
    );
    if (picked != null && mounted) _setFilter(context, ref, picked);
  }

  @override
  Widget build(BuildContext context) {
    // 검색어를 밖에서 바꾸면(명령창, 주소의 필터) 글 칸도 따라간다.
    ref.listen(searchQueryProvider, (_, next) {
      if (_search.text != next) _search.text = next;
    });
    final transactions = ref.watch(filteredTransactionsProvider);
    final query = ref.watch(searchQueryProvider);
    final filter = ref.watch(transactionFilterProvider);
    final mode = ref.watch(transactionViewModeProvider);

    final searchField = TextField(
      key: const ValueKey('transaction-search'),
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
      onChanged: (value) => ref.read(searchQueryProvider.notifier).set(value),
    );
    final tools = [
      SegmentedButton<TransactionViewMode>(
        showSelectedIcon: false,
        style: const ButtonStyle(visualDensity: VisualDensity.compact),
        segments: const [
          ButtonSegment(
            value: TransactionViewMode.list,
            icon: Icon(Icons.view_list, key: ValueKey('view-list')),
            tooltip: '목록으로 보기',
          ),
          ButtonSegment(
            value: TransactionViewMode.calendar,
            icon: Icon(
              Icons.calendar_month_outlined,
              key: ValueKey('view-calendar'),
            ),
            tooltip: '달력으로 보기',
          ),
        ],
        selected: {mode},
        onSelectionChanged: (selection) =>
            ref.read(transactionViewModeProvider.notifier).set(selection.first),
      ),
      IconButton(
        key: const ValueKey('filter-button'),
        tooltip: filter.isEmpty ? '필터' : '필터 (${filter.activeCount}개 걸림)',
        onPressed: _openFilter,
        icon: Badge(
          isLabelVisible: !filter.isEmpty,
          // 글자를 크게 써도 숫자가 단추 밖으로 나가 잘리지 않게 한다. 걸린 필터는 아래의
          // 칩과 단추의 이름표로도 알 수 있다.
          label: MediaQuery.withClampedTextScaling(
            maxScaleFactor: 1.3,
            child: Text('${filter.activeCount}'),
          ),
          child: const Icon(Icons.filter_list),
        ),
      ),
    ];

    final list = transactions.value;
    final Widget body;
    if (list == null) {
      body = transactions.hasError
          ? _Notice(
              icon: Icons.error_outline,
              message: '내역을 불러오지 못했습니다',
              hint: '잠시 뒤에 다시 시도해 주세요.',
              action: FilledButton.tonal(
                onPressed: () => ref.invalidate(filteredTransactionsProvider),
                child: const Text('다시 시도'),
              ),
            )
          : const Center(child: CircularProgressIndicator());
    } else if (mode == TransactionViewMode.calendar) {
      body = _CalendarBody(
        list: list,
        selectedId: widget.selectedId,
        dayBelow: widget.dayBelow,
      );
    } else if (list.isEmpty) {
      body = const _EmptyNotice();
    } else if (widget.table) {
      body = TransactionTable(list: list, selectedId: widget.selectedId);
    } else {
      body = _GroupedList(list: list, selectedId: widget.selectedId);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        void create() => context.go('/transactions?new=expense');
        // 칸이 좁으면 글자를 빼고 아이콘만 둔다.
        final narrow = constraints.maxWidth < 380;
        // 더 좁으면 검색 칸이 설 자리가 없어 도구를 다음 줄로 내린다.
        final stacked = constraints.maxWidth < 340;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
              child: Row(
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
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
              child: stacked
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: searchField,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: tools,
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(child: searchField),
                        const SizedBox(width: 8),
                        ...tools,
                      ],
                    ),
            ),
            ActiveFilterChips(
              filter: filter,
              categories: ref.watch(categoriesProvider).value ?? const [],
              accounts: ref.watch(accountsProvider).value ?? const [],
              onChanged: (next) => _setFilter(context, ref, next),
            ),
            Expanded(child: body),
          ],
        );
      },
    );
  }
}

/// 보여 줄 거래가 없을 때의 안내. 왜 없는지에 따라 말과 할 일이 다르다.
class _EmptyNotice extends ConsumerWidget {
  const _EmptyNotice({this.embedded = false});

  /// 다른 스크롤 안에 넣을 때. 가운데로 모으지 않고 내용만 그린다.
  final bool embedded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(transactionFilterProvider);
    final query = ref.watch(searchQueryProvider).trim();

    if (!filter.isEmpty) {
      return _Notice(
        embedded: embedded,
        icon: Icons.filter_list_off,
        message: '조건에 맞는 내역이 없습니다',
        hint: '필터를 줄이거나 지우면 더 많은 내역이 보입니다.',
        action: FilledButton.tonal(
          key: const ValueKey('filter-clear-all'),
          onPressed: () => _setFilter(context, ref, const TransactionFilter()),
          child: const Text('필터 지우기'),
        ),
      );
    }
    if (query.isNotEmpty) {
      return _Notice(
        embedded: embedded,
        icon: Icons.search_off,
        message: '검색 결과가 없습니다',
        hint: '상대방 · 메모 · 분류 이름에서 찾습니다. 다른 낱말로 찾아보세요.',
      );
    }
    // 취소한 거래는 평소에 숨기므로, 그것만 있는 달은 따로 알린다.
    final hidden = ref.watch(monthTransactionsProvider).value?.length ?? 0;
    if (hidden > 0) {
      return _Notice(
        embedded: embedded,
        icon: Icons.receipt_long_outlined,
        message: '취소한 거래 $hidden건만 있습니다',
        hint: '취소한 거래는 집계에서 빠져 평소에는 숨깁니다.',
        action: FilledButton.tonal(
          key: const ValueKey('show-canceled'),
          onPressed: () => _setFilter(
            context,
            ref,
            const TransactionFilter(includeCanceled: true),
          ),
          child: const Text('취소한 거래 보기'),
        ),
      );
    }
    return _Notice(
      embedded: embedded,
      icon: Icons.receipt_long_outlined,
      message: '이 달의 내역이 없습니다',
      hint: '입력창에 결제 문자를 붙여넣거나 "어제 점심 9천원"처럼 적으면 내역이 생깁니다.',
    );
  }
}

/// 아이콘 · 한 줄 말 · 덧붙이는 설명 · 할 일. 자리가 모자라면 굴려서 본다.
class _Notice extends StatelessWidget {
  const _Notice({
    required this.icon,
    required this.message,
    this.hint,
    this.action,
    this.embedded = false,
  });

  final IconData icon;
  final String message;
  final String? hint;
  final Widget? action;
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final content = Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 40, color: theme.colorScheme.outline),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(color: muted),
          ),
          if (hint != null) ...[
            const SizedBox(height: 6),
            Text(
              hint!,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(color: muted),
            ),
          ],
          if (action != null) ...[const SizedBox(height: 12), action!],
        ],
      ),
    );
    if (embedded) return Center(child: content);
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(child: content),
        ),
      ),
    );
  }
}

/// 달력과, 좁은 창에서는 그 아래에 고른 날의 거래.
class _CalendarBody extends ConsumerWidget {
  const _CalendarBody({
    required this.list,
    required this.selectedId,
    required this.dayBelow,
  });

  final List<TransactionView> list;
  final String? selectedId;
  final bool dayBelow;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final day = ref.watch(shownCalendarDayProvider);
    return ListView(
      key: const ValueKey('calendar-scroll'),
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: MonthCalendar(
            period: ref.watch(selectedPeriodProvider),
            totals: dailyTotals(list),
            today: ref.watch(todayProvider),
            selected: day,
            onSelect: (date) =>
                ref.read(calendarDayProvider.notifier).set(date),
          ),
        ),
        const SizedBox(height: 8),
        if (list.isEmpty)
          const _EmptyNotice(embedded: true)
        else if (dayBelow)
          ...dayTransactionWidgets(
            day: day,
            transactions: list,
            selectedId: selectedId,
            onOpen: (view) => context.go('/transactions?id=${view.row.id}'),
          ),
      ],
    );
  }
}

/// 넓은 창에서 달력 옆에 고른 날의 거래를 보여 주는 칸.
class _DaySidePane extends ConsumerWidget {
  const _DaySidePane({required this.selectedId});

  final String? selectedId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(filteredTransactionsProvider).value;
    if (list == null) return const SizedBox.shrink();
    return ListView(
      key: const ValueKey('calendar-day-pane'),
      padding: const EdgeInsets.only(bottom: 24),
      children: dayTransactionWidgets(
        day: ref.watch(shownCalendarDayProvider),
        transactions: list,
        selectedId: selectedId,
        onOpen: (view) => context.go('/transactions?id=${view.row.id}'),
      ),
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
    final tokens = context.tokens;
    // 날짜 머리줄과 거래를 한 줄씩 펼친다.
    final rows = <Object>[];
    final dayTotals = <LocalDate, int>{};
    LocalDate? current;
    for (final view in list) {
      final date = view.row.occurredOn;
      if (date != current) {
        current = date;
        rows.add(date);
      }
      rows.add(view);
      dayTotals[date] = (dayTotals[date] ?? 0) + view.signedAmount;
    }

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
                  child: Text(
                    dayLabel(row),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelLarge,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  signedWon(dayTotals[row] ?? 0),
                  style: tokens
                      .amountStyle(theme.textTheme.labelLarge)
                      .copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          );
        }
        final view = row as TransactionView;
        return TransactionTile(
          key: ValueKey('row-${view.row.id}'),
          view: view,
          selected: view.row.id == selectedId,
          onTap: () => context.go('/transactions?id=${view.row.id}'),
        );
      },
    );
  }
}
