import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/providers.dart';
import '../../app/theme/tokens.dart';
import '../../core/formatters.dart';
import '../../data/db/database.dart';
import '../../data/repositories/budget_repository.dart';
import '../../domain/enums.dart';
import '../accounts/manage_common.dart';
import '../common/category_visual.dart';
import '../common/widgets.dart';
import 'budget_progress.dart';

/// 예산 화면. `docs/SPEC.md` 7.11.
///
/// 고른 달의 전체 예산과 분류별 예산을 쓴 돈과 함께 보여 준다. 줄을 누르면 금액을 고친다.
class BudgetScreen extends ConsumerStatefulWidget {
  const BudgetScreen({super.key});

  @override
  ConsumerState<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends ConsumerState<BudgetScreen> {
  /// 겹친 행을 정리해 둔 달. 달마다 한 번만 한다.
  String? _cleanedMonth;
  bool _copying = false;

  /// 두 기기가 같은 달 · 같은 분류의 예산을 따로 만들었으면 나중 것만 남긴다.
  void _cleanDuplicates(String month) {
    if (_cleanedMonth == month) return;
    _cleanedMonth = month;
    // 화면을 그리는 중에 저장소를 바꾸지 않게 뒤로 미룬다. 실패해도 화면은 나중에 고친
    // 행을 골라 보여 주므로 조용히 넘어가고, 다음에 이 달을 열 때 다시 한다.
    unawaited(
      Future.microtask(() async {
        try {
          await ref
              .read(budgetRepositoryProvider)
              .cleanDuplicates(ref.read(ledgerIdProvider), month: month);
        } catch (_) {
          _cleanedMonth = null;
        }
      }),
    );
  }

  void _edit(String month, BudgetLine line) => showEditor<void>(
    context,
    builder: (context) => BudgetForm(month: month, line: line),
  );

  Future<void> _copyPrevious(String month) async {
    setState(() => _copying = true);
    try {
      final copied = await ref
          .read(budgetRepositoryProvider)
          .copyFromPreviousMonth(ref.read(ledgerIdProvider), month);
      if (!mounted) return;
      showNotice(
        context,
        copied == 0 ? '지난달에 정한 예산이 없습니다.' : '지난달 예산 $copied건을 가져왔습니다.',
      );
    } catch (_) {
      if (mounted) showNotice(context, '가져오지 못했습니다. 잠시 뒤에 다시 시도해 주세요.');
    } finally {
      if (mounted) setState(() => _copying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final period = ref.watch(selectedPeriodProvider);
    final progress = ref.watch(budgetProgressProvider);
    _cleanDuplicates(period.key);
    return SafeArea(
      child: ListView(
        padding: manageListPadding,
        children: [
          const ManageHeader(title: '예산', inSideMenu: true),
          const MonthSwitcher(),
          const SizedBox(height: 8),
          ManageAsync<BudgetProgress>(
            value: progress,
            what: '예산을',
            onRetry: () {
              ref.invalidate(monthBudgetsProvider);
              ref.invalidate(monthSummaryProvider);
            },
            builder: _buildContent,
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BudgetProgress progress) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final total = progress.total;
    final month = progress.month;

    void addTotal() => showEditor<void>(
      context,
      builder: (context) => BudgetForm(month: month, total: true),
    );
    void addCategory() => showEditor<void>(
      context,
      builder: (context) => BudgetForm(month: month),
    );

    if (progress.isEmpty) {
      final hasPrevious =
          ref.watch(previousMonthBudgetsProvider).value?.isNotEmpty ?? false;
      return EmptyState(
        icon: Icons.donut_large_outlined,
        message: hasPrevious
            ? '이 달에는 정한 예산이 없습니다.\n지난달 예산을 그대로 가져올 수 있습니다.'
            : '이 달에는 정한 예산이 없습니다.\n전체 예산을 정하면 남은 돈을 보여 줍니다.',
        action: Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            if (hasPrevious)
              FilledButton(
                key: const ValueKey('budget-copy-previous'),
                onPressed: _copying ? null : () => _copyPrevious(month),
                child: const Text('지난달 예산 가져오기'),
              ),
            OutlinedButton(
              key: const ValueKey('budget-set-total'),
              onPressed: addTotal,
              child: const Text('전체 예산 정하기'),
            ),
            OutlinedButton(
              key: const ValueKey('budget-add-category'),
              onPressed: addCategory,
              child: const Text('분류 예산 추가'),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          clipBehavior: Clip.antiAlias,
          child: total == null
              ? Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('전체 예산', style: theme.textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Text(
                        '전체 예산을 정하지 않았습니다.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton(
                        key: const ValueKey('budget-set-total'),
                        onPressed: addTotal,
                        child: const Text('전체 예산 정하기'),
                      ),
                    ],
                  ),
                )
              : BudgetLineTile(
                  key: const ValueKey('budget-line-total'),
                  line: total,
                  emphasized: true,
                  onTap: () => _edit(month, total),
                ),
        ),
        if (progress.overAllocated > 0) ...[
          const SizedBox(height: 12),
          Container(
            key: const ValueKey('budget-over-allocated'),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: tokens.warnSoft,
              borderRadius: BorderRadius.circular(tokens.radius),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, size: 20, color: tokens.warn),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '분류 예산의 합(${won(progress.categorySum)})이 전체 예산보다 '
                    '${won(progress.overAllocated)} 많습니다.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
        Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Text('분류별 예산', style: theme.textTheme.titleMedium),
              ),
              if (progress.categories.isEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                  child: Text(
                    '분류마다 예산을 따로 정할 수 있습니다.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              for (final line in progress.categories)
                BudgetLineTile(
                  key: ValueKey('budget-line-${line.categoryId}'),
                  line: line,
                  onTap: () => _edit(month, line),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    key: const ValueKey('budget-add-category'),
                    onPressed: addCategory,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('분류 예산 추가'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 예산의 진행 막대. 넘기면 경고색이 된다. 값을 읽어 주는 설명을 단다.
class BudgetBar extends StatelessWidget {
  const BudgetBar({super.key, required this.line});

  final BudgetLine line;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final index = line.colorIndex;
    return Semantics(
      label: '${line.name} 진행',
      value: line.isOver
          ? '${won(line.overBy)} 넘음'
          : '${percent(line.ratio)} 씀',
      child: RatioBar(
        ratio: line.ratio,
        color: line.isOver
            ? tokens.warn
            : (index == null ? null : categoryColor(tokens, index)),
      ),
    );
  }
}

/// 예산 한 줄: 이름과 예산, 막대, 쓴 돈과 남은 돈.
class BudgetLineTile extends StatelessWidget {
  const BudgetLineTile({
    super.key,
    required this.line,
    this.onTap,
    this.emphasized = false,
  });

  final BudgetLine line;
  final VoidCallback? onTap;

  /// 전체 예산처럼 크게 보일지.
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final nameStyle = emphasized
        ? theme.textTheme.titleMedium
        : theme.textTheme.bodyLarge;
    final index = line.colorIndex;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          line.isChild ? 44 : 16,
          emphasized ? 16 : 10,
          16,
          emphasized ? 16 : 10,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LabelAmountRow(
              label: Row(
                children: [
                  if (index != null) ...[
                    Icon(
                      categoryIcon(line.name, line.icon),
                      size: 20,
                      color: categoryColor(tokens, index),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Text(
                      line.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: nameStyle,
                    ),
                  ),
                ],
              ),
              amount: Text(
                won(line.budget),
                maxLines: 1,
                style: tokens.amountStyle(nameStyle),
              ),
            ),
            const SizedBox(height: 8),
            BudgetBar(line: line),
            const SizedBox(height: 6),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              spacing: 12,
              runSpacing: 2,
              children: [
                Text(
                  '쓴 돈 ${won(line.spent)}',
                  style: tokens.amountStyle(muted),
                ),
                if (line.isOver)
                  // 색만으로 알리지 않게 글자와 아이콘을 함께 둔다.
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        size: 16,
                        color: tokens.warn,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          '${won(line.overBy)} 넘음',
                          style: tokens.amountStyle(
                            muted?.copyWith(color: tokens.warn),
                          ),
                        ),
                      ),
                    ],
                  )
                else
                  Text(
                    '남은 돈 ${won(line.remaining)}',
                    style: tokens.amountStyle(muted),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 예산을 정하거나 고치는 칸.
///
/// [line]이 있으면 그 예산을 고치고, 없으면 새로 정한다: [total]이면 전체 예산, 아니면
/// 분류를 골라 분류 예산을 정한다.
class BudgetForm extends ConsumerStatefulWidget {
  const BudgetForm({
    super.key,
    required this.month,
    this.line,
    this.total = false,
  });

  /// 'YYYY-MM'
  final String month;
  final BudgetLine? line;
  final bool total;

  @override
  ConsumerState<BudgetForm> createState() => _BudgetFormState();
}

class _BudgetFormState extends ConsumerState<BudgetForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amount;
  String? _categoryId;
  bool _saving = false;

  bool get _isTotal =>
      widget.line == null ? widget.total : widget.line!.categoryId == null;

  @override
  void initState() {
    super.initState();
    final line = widget.line;
    _amount = TextEditingController(
      text: line == null ? '' : formatNumber(line.budget),
    );
    _categoryId = line?.categoryId;
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(budgetRepositoryProvider)
          .setBudget(
            ref.read(ledgerIdProvider),
            month: widget.month,
            categoryId: _isTotal ? null : _categoryId,
            amount: parseAmountInput(_amount.text)!,
          );
      if (!mounted) return;
      Navigator.of(context).pop();
      showNotice(context, '예산을 저장했습니다.');
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      showNotice(context, '저장하지 못했습니다. 금액을 확인하고 다시 시도해 주세요.');
    }
  }

  Future<void> _delete() async {
    final line = widget.line;
    if (line == null) return;
    final confirmed = await confirmAction(
      context,
      title: '${line.name}${line.categoryId == null ? '' : ' 예산'}을 없앨까요?',
      message: '이 달의 예산만 없앱니다. 거래는 그대로 남습니다.',
      confirmLabel: '없애기',
    );
    if (!confirmed || !mounted) return;
    try {
      await ref
          .read(budgetRepositoryProvider)
          .deleteBudget(
            ref.read(ledgerIdProvider),
            month: widget.month,
            categoryId: line.categoryId,
          );
      if (!mounted) return;
      Navigator.of(context).pop();
      showNotice(context, '예산을 없앴습니다.');
    } catch (_) {
      if (mounted) showNotice(context, '없애지 못했습니다. 잠시 뒤에 다시 시도해 주세요.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final line = widget.line;
    final categories =
        ref.watch(categoriesProvider).value ?? const <CategoryRow>[];
    final taken = {
      for (final row
          in ref.watch(monthBudgetsProvider).value ?? const <BudgetRow>[])
        row.categoryId,
    };
    // 새로 정할 때는 아직 예산이 없는 지출 분류만 고른다.
    final options = [
      for (final c in categories)
        if (c.kind == CategoryKind.expense && !taken.contains(c.id)) c,
    ];
    final categoryValue = options.any((c) => c.id == _categoryId)
        ? _categoryId
        : null;
    final String title;
    if (line != null) {
      title = _isTotal ? '전체 예산 고치기' : '${line.name} 예산 고치기';
    } else {
      title = _isTotal ? '전체 예산 정하기' : '분류 예산 추가';
    }
    final pickCategory = line == null && !_isTotal;

    return Form(
      key: _formKey,
      child: EditorFrame(
        title: title,
        actions: [
          if (line != null)
            TextButton(
              key: const ValueKey('budget-form-delete'),
              onPressed: _saving ? null : _delete,
              style: TextButton.styleFrom(
                foregroundColor: theme.colorScheme.error,
              ),
              child: const Text('없애기'),
            ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('취소'),
          ),
          FilledButton(
            key: const ValueKey('budget-form-save'),
            onPressed: _saving || (pickCategory && options.isEmpty)
                ? null
                : _save,
            child: const Text('저장'),
          ),
        ],
        children: [
          if (pickCategory && options.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                '예산을 정하지 않은 지출 분류가 없습니다.',
                style: theme.textTheme.bodyMedium,
              ),
            )
          else if (pickCategory) ...[
            DropdownButtonFormField<String?>(
              key: const ValueKey('budget-form-category'),
              initialValue: categoryValue,
              isExpanded: true,
              decoration: const InputDecoration(labelText: '분류'),
              items: [
                for (final c in options)
                  DropdownMenuItem<String?>(
                    value: c.id,
                    child: Text(c.name, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: (value) => setState(() => _categoryId = value),
              validator: (value) => value == null ? '분류를 골라야 합니다' : null,
            ),
            const SizedBox(height: 12),
          ],
          TextFormField(
            key: const ValueKey('budget-form-amount'),
            controller: _amount,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: const [AmountInputFormatter()],
            decoration: InputDecoration(
              labelText: '${int.parse(widget.month.substring(5))}월 예산',
              suffixText: '원',
            ),
            validator: (value) =>
                parseAmountInput(value ?? '') == null ? '금액을 넣어야 합니다' : null,
            onFieldSubmitted: (_) => _save(),
          ),
        ],
      ),
    );
  }
}
