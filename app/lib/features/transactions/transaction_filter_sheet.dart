import 'package:material_ui/material_ui.dart';

import '../../core/breakpoints.dart';
import '../../core/formatters.dart';
import '../../data/db/database.dart';
import '../../data/repositories/transaction_query.dart';
import '../../domain/enums.dart';
import 'amount_input.dart';
import 'transaction_tile.dart';

/// 거래 종류의 이름.
String txTypeLabel(TxType type) => switch (type) {
  TxType.expense => '지출',
  TxType.income => '수입',
  TxType.transfer => '이체',
};

/// 금액 범위를 칩에 적을 글로 바꾼다.
String amountRangeLabel(int? min, int? max) {
  if (min != null && max != null) {
    return '${formatNumber(min)}–${won(max)}';
  }
  if (min != null) return '${won(min)} 이상';
  return '${won(max ?? 0)} 이하';
}

/// 필터를 고르는 칸을 연다. 좁은 창은 아래에서 올라오고, 그 밖에서는 대화상자로 뜬다.
///
/// "적용"을 누르면 고른 필터를, 닫으면 null을 돌려준다.
Future<TransactionFilter?> showTransactionFilter(
  BuildContext context, {
  required TransactionFilter initial,
  required List<CategoryRow> categories,
  required List<AccountRow> accounts,
}) {
  Widget form(BuildContext context) =>
      _FilterForm(initial: initial, categories: categories, accounts: accounts);
  if (WindowSize.of(context).isCompact) {
    return showModalBottomSheet<TransactionFilter>(
      context: context,
      // 탭과 입력창 위까지 덮어야 좁은 화면에서 고를 자리가 난다.
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.9,
          ),
          child: form(context),
        ),
      ),
    );
  }
  return showDialog<TransactionFilter>(
    context: context,
    builder: (context) => Dialog(
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 680),
        child: form(context),
      ),
    ),
  );
}

class _FilterForm extends StatefulWidget {
  const _FilterForm({
    required this.initial,
    required this.categories,
    required this.accounts,
  });

  final TransactionFilter initial;
  final List<CategoryRow> categories;
  final List<AccountRow> accounts;

  @override
  State<_FilterForm> createState() => _FilterFormState();
}

class _FilterFormState extends State<_FilterForm> {
  late Set<TxType> _types = {...widget.initial.types};
  late Set<String> _categoryIds = {...widget.initial.categoryIds};
  late Set<String> _accountIds = {...widget.initial.accountIds};
  late bool _needsReviewOnly = widget.initial.needsReviewOnly;
  late bool _includeCanceled = widget.initial.includeCanceled;
  late final _min = TextEditingController(
    text: _amountText(widget.initial.minAmount),
  );
  late final _max = TextEditingController(
    text: _amountText(widget.initial.maxAmount),
  );

  static String _amountText(int? value) =>
      value == null ? '' : formatNumber(value);

  @override
  void dispose() {
    _min.dispose();
    _max.dispose();
    super.dispose();
  }

  void _toggle<T>(Set<T> set, T value) => setState(() {
    if (!set.remove(value)) set.add(value);
  });

  void _reset() => setState(() {
    _types = {};
    _categoryIds = {};
    _accountIds = {};
    _needsReviewOnly = false;
    _includeCanceled = false;
    _min.clear();
    _max.clear();
  });

  void _apply() {
    var min = parseAmountInput(_min.text);
    var max = parseAmountInput(_max.text);
    // 거꾸로 적은 범위는 바로잡아 건다.
    if (min != null && max != null && min > max) (min, max) = (max, min);
    Navigator.of(context).pop(
      TransactionFilter(
        types: _types,
        categoryIds: _categoryIds,
        accountIds: _accountIds,
        minAmount: min,
        maxAmount: max,
        needsReviewOnly: _needsReviewOnly,
        includeCanceled: _includeCanceled,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget heading(String text) => Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Text(text, style: theme.textTheme.titleSmall),
    );

    // 이름이 길거나 글자를 키워도 칩이 칸을 넘지 않게 이름의 폭에 위를 둔다.
    Widget chipLabel(String text) => ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 180),
      child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis),
    );

    Widget categoryChip(String id, String name, {String? dotId}) => FilterChip(
      key: ValueKey('filter-category-$id'),
      avatar: dotId == null ? null : CategoryDot(categoryId: dotId),
      label: chipLabel(name),
      selected: _categoryIds.contains(id),
      onSelected: (_) => _toggle(_categoryIds, id),
    );

    Widget amountField(
      Key key,
      TextEditingController controller,
      String label,
    ) => TextField(
      key: key,
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [ThousandsFormatter()],
      decoration: InputDecoration(labelText: label, suffixText: '원'),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
          child: Row(
            children: [
              Expanded(child: Text('필터', style: theme.textTheme.titleLarge)),
              IconButton(
                tooltip: '닫기',
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
        ),
        Flexible(
          child: ListView(
            key: const ValueKey('filter-scroll'),
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            children: [
              heading('종류'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final type in TxType.values)
                    FilterChip(
                      key: ValueKey('filter-type-${type.code}'),
                      label: chipLabel(txTypeLabel(type)),
                      selected: _types.contains(type),
                      onSelected: (_) => _toggle(_types, type),
                    ),
                ],
              ),
              for (final kind in CategoryKind.values) ...[
                heading(kind == CategoryKind.expense ? '지출 분류' : '수입 분류'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final c in widget.categories)
                      if (c.kind == kind)
                        categoryChip(c.id, c.name, dotId: c.id),
                  ],
                ),
              ],
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: categoryChip(TransactionFilter.noCategory, '분류 없음'),
              ),
              heading('자산'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final a in widget.accounts)
                    FilterChip(
                      key: ValueKey('filter-account-${a.id}'),
                      label: chipLabel(a.name),
                      selected: _accountIds.contains(a.id),
                      onSelected: (_) => _toggle(_accountIds, a.id),
                    ),
                ],
              ),
              heading('금액'),
              Row(
                children: [
                  Expanded(
                    child: amountField(
                      const ValueKey('filter-min'),
                      _min,
                      '최소',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: amountField(
                      const ValueKey('filter-max'),
                      _max,
                      '최대',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                key: const ValueKey('filter-review'),
                contentPadding: EdgeInsets.zero,
                title: const Text('확인 필요만'),
                value: _needsReviewOnly,
                onChanged: (value) => setState(() => _needsReviewOnly = value),
              ),
              SwitchListTile(
                key: const ValueKey('filter-canceled'),
                contentPadding: EdgeInsets.zero,
                title: const Text('취소 포함'),
                subtitle: const Text('취소한 거래도 함께 보여 줍니다'),
                value: _includeCanceled,
                onChanged: (value) => setState(() => _includeCanceled = value),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: TextButton(
                  key: const ValueKey('filter-reset'),
                  onPressed: _reset,
                  child: const Text('초기화'),
                ),
              ),
              Flexible(
                child: FilledButton(
                  key: const ValueKey('filter-apply'),
                  onPressed: _apply,
                  child: const Text('적용'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 걸린 필터를 칩으로 보여 준다. 칩의 ×를 누르면 그 조건만 지운다.
class ActiveFilterChips extends StatelessWidget {
  const ActiveFilterChips({
    super.key,
    required this.filter,
    required this.categories,
    required this.accounts,
    required this.onChanged,
  });

  final TransactionFilter filter;
  final List<CategoryRow> categories;
  final List<AccountRow> accounts;
  final ValueChanged<TransactionFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    final categoryNames = {for (final c in categories) c.id: c.name};
    final accountNames = {for (final a in accounts) a.id: a.name};

    Widget chip(String key, String label, TransactionFilter without) => Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InputChip(
        key: ValueKey('filter-chip-$key'),
        label: Text(label),
        onDeleted: () => onChanged(without),
        deleteButtonTooltipMessage: '$label 필터 지우기',
      ),
    );

    final chips = [
      for (final type in TxType.values)
        if (filter.types.contains(type))
          chip(
            'type-${type.code}',
            txTypeLabel(type),
            filter.copyWith(types: {...filter.types}..remove(type)),
          ),
      for (final id in filter.categoryIds)
        chip(
          'category-$id',
          id == TransactionFilter.noCategory
              ? '분류 없음'
              : categoryNames[id] ?? '지워진 분류',
          filter.copyWith(categoryIds: {...filter.categoryIds}..remove(id)),
        ),
      for (final id in filter.accountIds)
        chip(
          'account-$id',
          accountNames[id] ?? '지워진 자산',
          filter.copyWith(accountIds: {...filter.accountIds}..remove(id)),
        ),
      if (filter.minAmount != null || filter.maxAmount != null)
        chip(
          'amount',
          amountRangeLabel(filter.minAmount, filter.maxAmount),
          filter.copyWith(minAmount: () => null, maxAmount: () => null),
        ),
      if (filter.needsReviewOnly)
        chip('review', '확인 필요만', filter.copyWith(needsReviewOnly: false)),
      if (filter.includeCanceled)
        chip('canceled', '취소 포함', filter.copyWith(includeCanceled: false)),
    ];
    if (chips.isEmpty) return const SizedBox.shrink();

    return SingleChildScrollView(
      key: const ValueKey('filter-chips'),
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 0, 8, 8),
      child: Row(
        children: [
          ...chips,
          if (chips.length > 1)
            TextButton(
              key: const ValueKey('filter-clear'),
              onPressed: () => onChanged(const TransactionFilter()),
              child: const Text('모두 지우기'),
            ),
        ],
      ),
    );
  }
}
