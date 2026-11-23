import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/providers.dart';
import '../../core/formatters.dart';
import '../../core/local_date.dart';
import '../../data/db/database.dart';
import '../../data/repositories/ledger_repository.dart';
import '../../domain/enums.dart';

/// 거래를 직접 넣거나 고치는 폼.
///
/// [existing]이 있으면 고치고, 없으면 새로 만든다.
class TransactionEditor extends ConsumerStatefulWidget {
  const TransactionEditor({
    super.key,
    this.existing,
    this.initialType = TxType.expense,
    required this.onDone,
  });

  final TxRow? existing;
  final TxType initialType;

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

  @override
  void initState() {
    super.initState();
    final row = widget.existing;
    _type = row?.type ?? widget.initialType;
    _date = row?.occurredOn ?? ref.read(todayProvider);
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
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('저장하지 못했습니다: $e')));
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
    await ref.read(repositoryProvider).deleteTransaction(existing.id);
    if (mounted) widget.onDone();
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
    final isNew = widget.existing == null;

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
          const SizedBox(height: 8),
          SegmentedButton<TxType>(
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
            inputFormatters: [_ThousandsFormatter()],
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
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              key: ValueKey('category-$_type-$categoryValue'),
              initialValue: categoryValue,
              isExpanded: true,
              decoration: const InputDecoration(labelText: '분류'),
              items: [
                const DropdownMenuItem<String?>(child: Text('분류 없음')),
                for (final c in options)
                  DropdownMenuItem<String?>(value: c.id, child: Text(c.name)),
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
        ],
      ),
    );
  }
}

/// 금액 입력란에 천 단위 쉼표를 넣는다.
class _ThousandsFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final amount = parseAmountInput(newValue.text);
    if (amount == null) return const TextEditingValue();
    final text = formatNumber(amount);
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
