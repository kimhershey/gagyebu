import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/providers.dart';
import '../../app/theme/tokens.dart';
import '../../core/formatters.dart';
import '../../core/local_date.dart';
import '../../data/db/database.dart';
import '../../data/repositories/ledger_repository.dart';
import '../../domain/enums.dart';
import 'amount_input.dart';
import 'transaction_tile.dart';

/// 거래를 직접 넣거나 고치는 폼.
///
/// [existing]이 있으면 고치고, 없으면 새로 만든다. 저장하면 거래는 확인한 것이 된다
/// (`docs/SPEC.md` 7.3: 확인이 필요하던 거래도 고쳐서 저장하면 `confirmed`).
class TransactionEditor extends ConsumerStatefulWidget {
  const TransactionEditor({
    super.key,
    this.existing,
    this.initialType = TxType.expense,
    this.initialDate,
    required this.onDone,
  });

  final TxRow? existing;
  final TxType initialType;

  /// 새 거래의 날짜. 없으면 오늘이다.
  final LocalDate? initialDate;

  /// 저장 · 삭제 · 닫기가 끝났을 때.
  final VoidCallback onDone;

  @override
  ConsumerState<TransactionEditor> createState() => _TransactionEditorState();
}

class _TransactionEditorState extends ConsumerState<TransactionEditor> {
  final _formKey = GlobalKey<FormState>();
  late TxType _type;
  late LocalDate _date;
  late final TextEditingController _amount;
  late final TextEditingController _party;
  late final TextEditingController _memo;
  late final TextEditingController _time;
  String? _accountId;
  String? _toAccountId;
  String? _categoryId;
  bool _canceled = false;
  bool _saving = false;

  /// 적은 상대방에 예전에 고른 분류. 없으면 null이다.
  String? _suggestedCategoryId;

  /// 상대방을 빨리 고쳐 적을 때 늦게 온 답이 새 답을 덮지 않게 차례를 센다.
  int _lookup = 0;

  @override
  void initState() {
    super.initState();
    final row = widget.existing;
    _type = row?.type ?? widget.initialType;
    _date = row?.occurredOn ?? widget.initialDate ?? ref.read(todayProvider);
    _amount = TextEditingController(
      text: row == null ? '' : formatNumber(row.amount),
    );
    final party = switch (row?.type) {
      TxType.income => row?.sender,
      TxType.expense => row?.receiver,
      _ => null,
    };
    _party = TextEditingController(text: party ?? '');
    _memo = TextEditingController(text: row?.memo ?? '');
    _time = TextEditingController(text: row?.occurredTime ?? '');
    _accountId = row?.accountId;
    _toAccountId = row?.toAccountId;
    _categoryId = row?.categoryId;
    _canceled = row?.canceledAt != null;
  }

  @override
  void dispose() {
    _amount.dispose();
    _party.dispose();
    _memo.dispose();
    _time.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final today = ref.read(todayProvider);
    final picked = await showDatePicker(
      context: context,
      initialDate: _date.toDateTime(),
      firstDate: DateTime(2000),
      lastDate: today.addDays(366).toDateTime(),
    );
    if (picked != null) setState(() => _date = LocalDate.fromDateTime(picked));
  }

  /// 적은 상대방에 예전에 고른 분류가 있는지 찾는다.
  Future<void> _lookUpCategory(String party) async {
    final seq = ++_lookup;
    final String? found;
    try {
      found = await ref
          .read(repositoryProvider)
          .categoryForCounterparty(ref.read(ledgerIdProvider), party);
    } catch (_) {
      // 제안은 없어도 되는 것이라 못 찾으면 조용히 넘어간다.
      return;
    }
    if (!mounted || seq != _lookup) return;
    setState(() => _suggestedCategoryId = found);
  }

  void _say(String message) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final repo = ref.read(repositoryProvider);
    final ledgerId = ref.read(ledgerIdProvider);
    final party = _party.text.trim();
    final input = TransactionInput(
      type: _type,
      occurredOn: _date,
      occurredTime: _time.text.trim().isEmpty ? null : _time.text.trim(),
      amount: parseAmountInput(_amount.text)!,
      accountId: _accountId!,
      toAccountId: _type == TxType.transfer ? _toAccountId : null,
      counterparty: party,
      categoryId: _categoryId,
      memo: _memo.text,
      installmentMonths: widget.existing?.installmentMonths,
      balanceAfter: widget.existing?.balanceAfter,
      currency: widget.existing?.currency,
      originalAmount: widget.existing?.originalAmount,
      source: widget.existing?.source ?? TxSource.manual,
      aiModel: widget.existing?.aiModel,
      canceled: _canceled,
      // 사용자가 보고 저장한 것이므로 확인한 거래다.
      status: TxStatus.confirmed,
    );
    setState(() => _saving = true);
    try {
      final existing = widget.existing;
      if (existing == null) {
        await repo.addTransaction(ledgerId, input);
      } else {
        await repo.updateTransaction(existing.id, input);
      }
      // 사용자가 고른 분류를 상대방의 규칙으로 기억한다.
      final categoryId = _categoryId;
      if (_type != TxType.transfer && party.isNotEmpty && categoryId != null) {
        await repo.rememberCategory(ledgerId, party, categoryId);
      }
      if (!mounted) return;
      ref.read(selectedPeriodProvider.notifier).show(_date);
      widget.onDone();
    } catch (_) {
      if (mounted) _say('저장하지 못했습니다. 적은 내용을 확인하고 다시 시도해 주세요.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final existing = widget.existing;
    if (existing == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('이 거래를 지울까요?'),
        content: const Text('지운 거래는 다른 기기에서도 사라집니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('지우기'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(repositoryProvider).deleteTransaction(existing.id);
      if (mounted) widget.onDone();
    } catch (_) {
      if (mounted) _say('지우지 못했습니다. 잠시 뒤에 다시 시도해 주세요.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final accounts = ref.watch(accountsProvider).value ?? const <AccountRow>[];
    final categories =
        ref.watch(categoriesProvider).value ?? const <CategoryRow>[];
    final profile = ref.watch(profileProvider).value;

    // 고른 자산이 없으면 기본 자산을 쓴다.
    if (_accountId == null && accounts.isNotEmpty) {
      final preferred = profile?.defaultAccountId;
      _accountId = accounts.any((a) => a.id == preferred)
          ? preferred
          : accounts.first.id;
    }
    final kind = _type == TxType.income
        ? CategoryKind.income
        : CategoryKind.expense;
    final options = [
      for (final c in categories)
        if (c.kind == kind) c,
    ];
    final categoryValue = options.any((c) => c.id == _categoryId)
        ? _categoryId
        : null;
    final existing = widget.existing;
    final isNew = existing == null;
    final tokens = context.tokens;
    final visuals = ref.watch(categoryVisualsProvider);
    // 지금 고른 분류와 다를 때만 제안한다. 종류가 다른 분류는 options에 없어 걸러진다.
    final suggestion = _suggestedCategoryId == _categoryId
        ? null
        : options.where((c) => c.id == _suggestedCategoryId).firstOrNull;

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  isNew ? '새 거래' : '거래 고치기',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              if (!isNew)
                IconButton(
                  tooltip: '지우기',
                  onPressed: _saving ? null : _delete,
                  icon: const Icon(Icons.delete_outline),
                ),
              IconButton(
                tooltip: '닫기',
                onPressed: widget.onDone,
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          if (existing?.status == TxStatus.needsReview) ...[
            const SizedBox(height: 4),
            _ReviewBanner(onConfirm: _saving ? null : _save),
          ],
          const SizedBox(height: 8),
          SegmentedButton<TxType>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: TxType.expense, label: Text('지출')),
              ButtonSegment(value: TxType.income, label: Text('수입')),
              ButtonSegment(value: TxType.transfer, label: Text('이체')),
            ],
            selected: {_type},
            onSelectionChanged: (selection) => setState(() {
              _type = selection.first;
              _categoryId = null;
            }),
          ),
          const SizedBox(height: 16),
          TextFormField(
            key: const ValueKey('editor-amount'),
            controller: _amount,
            autofocus: isNew,
            keyboardType: TextInputType.number,
            inputFormatters: [ThousandsFormatter()],
            decoration: const InputDecoration(labelText: '금액', suffixText: '원'),
            validator: (value) {
              final amount = parseAmountInput(value ?? '');
              if (amount == null || amount <= 0) return '금액을 넣어야 합니다';
              return null;
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: InkWell(
                  onTap: _pickDate,
                  borderRadius: BorderRadius.circular(4),
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: '날짜'),
                    child: Text(fullDateLabel(_date)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: _time,
                  keyboardType: TextInputType.datetime,
                  decoration: const InputDecoration(
                    labelText: '시각',
                    hintText: '12:30',
                  ),
                  validator: (value) {
                    final text = value?.trim() ?? '';
                    if (text.isEmpty) return null;
                    final m = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(text);
                    if (m == null ||
                        int.parse(m.group(1)!) > 23 ||
                        int.parse(m.group(2)!) > 59) {
                      return '12:30처럼';
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            key: ValueKey('account-$_accountId'),
            initialValue: accounts.any((a) => a.id == _accountId)
                ? _accountId
                : null,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: _type == TxType.transfer ? '보내는 자산' : '자산',
            ),
            items: [
              for (final a in accounts)
                DropdownMenuItem(value: a.id, child: Text(a.name)),
            ],
            onChanged: (value) => setState(() => _accountId = value),
            validator: (value) => value == null ? '자산을 골라야 합니다' : null,
          ),
          const SizedBox(height: 12),
          if (_type == TxType.transfer)
            DropdownButtonFormField<String>(
              key: ValueKey('to-account-$_toAccountId'),
              initialValue: accounts.any((a) => a.id == _toAccountId)
                  ? _toAccountId
                  : null,
              isExpanded: true,
              decoration: const InputDecoration(labelText: '받는 자산'),
              items: [
                for (final a in accounts)
                  DropdownMenuItem(value: a.id, child: Text(a.name)),
              ],
              onChanged: (value) => setState(() => _toAccountId = value),
              validator: (value) {
                if (value == null) return '받는 자산을 골라야 합니다';
                if (value == _accountId) return '같은 자산으로는 이체할 수 없습니다';
                return null;
              },
            )
          else ...[
            TextFormField(
              key: const ValueKey('editor-party'),
              controller: _party,
              decoration: InputDecoration(
                labelText: _type == TxType.income
                    ? '보낸 사람 · 기관'
                    : '받는 사람 · 가맹점',
              ),
              onChanged: _lookUpCategory,
            ),
            if (suggestion != null) ...[
              const SizedBox(height: 8),
              Material(
                color: tokens.accentSoft,
                borderRadius: BorderRadius.circular(tokens.radius),
                clipBehavior: Clip.antiAlias,
                child: ListTile(
                  key: const ValueKey('editor-suggest-category'),
                  dense: true,
                  leading: Icon(
                    visuals[suggestion.id]?.icon ?? Icons.label_outline,
                    color: visuals[suggestion.id]?.color(tokens),
                  ),
                  title: Text('예전에 고른 분류: ${suggestion.name}'),
                  trailing: const Text('적용'),
                  onTap: () => setState(() => _categoryId = suggestion.id),
                ),
              ),
            ],
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              key: ValueKey('category-$_type-$categoryValue'),
              initialValue: categoryValue,
              isExpanded: true,
              decoration: const InputDecoration(labelText: '분류'),
              items: [
                const DropdownMenuItem<String?>(child: Text('분류 없음')),
                for (final c in options)
                  DropdownMenuItem<String?>(
                    value: c.id,
                    child: Row(
                      children: [
                        CategoryDot(categoryId: c.id),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            c.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
              onChanged: (value) => setState(() => _categoryId = value),
            ),
          ],
          const SizedBox(height: 12),
          TextFormField(
            controller: _memo,
            decoration: const InputDecoration(labelText: '메모'),
            maxLines: 2,
            minLines: 1,
          ),
          if (_type != TxType.transfer)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('취소된 거래'),
              subtitle: const Text('집계에서 뺍니다'),
              value: _canceled,
              onChanged: (value) => setState(() => _canceled = value),
            ),
          const SizedBox(height: 16),
          FilledButton(
            key: const ValueKey('editor-save'),
            onPressed: _saving ? null : _save,
            child: Text(isNew ? '저장' : '고친 내용 저장'),
          ),
          if (existing != null) ...[
            const SizedBox(height: 8),
            // 반복 거래 화면이 이 거래를 틀로 규칙을 만든다(7.13).
            OutlinedButton.icon(
              key: const ValueKey('editor-recurring'),
              onPressed: _saving
                  ? null
                  : () => context.go('/recurring?from=${existing.id}'),
              icon: const Icon(Icons.repeat, size: 18),
              label: const Text('반복으로 등록'),
            ),
          ],
        ],
      ),
    );
  }
}

/// 확인이 필요한 거래라는 알림과 "확인함" 단추.
class _ReviewBanner extends StatelessWidget {
  const _ReviewBanner({required this.onConfirm});

  final VoidCallback? onConfirm;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    return Container(
      key: const ValueKey('editor-review-banner'),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      decoration: BoxDecoration(
        color: tokens.warnSoft,
        borderRadius: BorderRadius.circular(tokens.radius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.error_outline, size: 20, color: tokens.warn),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '확인이 필요한 거래입니다. 내용이 맞으면 "확인함"을 누르고, 다르면 고쳐서 저장해 주세요.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: tokens.warn,
                  ),
                ),
              ),
            ],
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              key: const ValueKey('editor-confirm'),
              onPressed: onConfirm,
              style: TextButton.styleFrom(foregroundColor: tokens.warn),
              icon: const Icon(Icons.check, size: 18),
              label: const Text('확인함'),
            ),
          ),
        ],
      ),
    );
  }
}
