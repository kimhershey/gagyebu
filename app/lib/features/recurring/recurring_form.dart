import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/providers.dart';
import '../../core/formatters.dart';
import '../../core/local_date.dart';
import '../../data/db/database.dart';
import '../../data/repositories/recurring_repository.dart';
import '../../domain/enums.dart';
import '../accounts/manage_common.dart';

/// 주기를 글로 옮긴다: '매달 25일', '2주마다 화요일', '매년 3월 1일'.
String describeSchedule(
  RecurringFrequency frequency,
  int intervalCount,
  LocalDate nextRunOn, {
  int? anchorDay,
}) {
  final every = intervalCount <= 1;
  switch (frequency) {
    case RecurringFrequency.weekly:
      final day = '${weekdayName(nextRunOn)}요일';
      return every ? '매주 $day' : '$intervalCount주마다 $day';
    case RecurringFrequency.monthly:
      final day = anchorDay ?? nextRunOn.day;
      // 31일은 달마다 마지막 날로 당겨진다.
      final label = day >= 31 ? '말일' : '$day일';
      return every ? '매달 $label' : '$intervalCount달마다 $label';
    case RecurringFrequency.yearly:
      final label = '${nextRunOn.month}월 ${anchorDay ?? nextRunOn.day}일';
      return every ? '매년 $label' : '$intervalCount년마다 $label';
  }
}

/// 거래 [tx]를 틀로 삼는 규칙의 처음 값: 그 거래 다음 달의 같은 날부터 매달.
///
/// 틀이 된 거래의 날짜는 이미 적혀 있으므로 그다음부터 만든다. 오래된 거래를 골랐을 때
/// 밀린 거래가 한꺼번에 생기지 않게, [today] 이후의 가장 가까운 날로 잡는다.
RecurringRuleInput ruleInputFromTransaction(TxRow tx, LocalDate today) {
  final anchor = tx.occurredOn.day;
  var next = tx.occurredOn;
  do {
    next = nextRecurrence(
      next,
      RecurringFrequency.monthly,
      1,
      anchorDay: anchor,
    );
  } while (next < today);
  return RecurringRuleInput(
    template: RecurringTemplate(
      type: tx.type,
      amount: tx.amount.abs(),
      accountId: tx.accountId,
      toAccountId: tx.toAccountId,
      counterparty: switch (tx.type) {
        TxType.expense => tx.receiver,
        TxType.income => tx.sender,
        TxType.transfer => null,
      },
      categoryId: tx.categoryId,
      memo: tx.memo,
      anchorDay: anchor,
    ),
    frequency: RecurringFrequency.monthly,
    nextRunOn: next,
  );
}

/// 반복 규칙을 더하거나 고치는 칸.
///
/// [existing]이 있으면 그 규칙을 고친다. 없으면 새로 만들고, [initial]이 있으면(거래에서
/// '반복으로 등록'을 눌렀을 때) 그 값으로 칸을 채워 둔다.
class RecurringForm extends ConsumerStatefulWidget {
  const RecurringForm({super.key, this.existing, this.initial});

  final RecurringRuleRow? existing;
  final RecurringRuleInput? initial;

  @override
  ConsumerState<RecurringForm> createState() => _RecurringFormState();
}

class _RecurringFormState extends ConsumerState<RecurringForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amount;
  late final TextEditingController _party;
  late final TextEditingController _memo;
  late final TextEditingController _interval;
  late TxType _type;
  late RecurringFrequency _frequency;
  late LocalDate _next;
  LocalDate? _end;
  String? _accountId;
  String? _toAccountId;
  String? _categoryId;
  bool _autoPost = false;
  bool _active = true;
  bool _saving = false;

  /// 처음 열었을 때의 다음 날짜와 고른 날. 날짜를 바꾸지 않았으면 고른 날을 지킨다
  /// (31일 규칙이 2월 28일에 와 있을 때 금액만 고쳐도 28일 규칙이 되지 않게).
  LocalDate? _originalNext;
  int? _originalAnchor;

  @override
  void initState() {
    super.initState();
    final row = widget.existing;
    final start = row == null
        ? widget.initial
        : RecurringRuleInput(
            // 읽을 수 없는 틀이면 빈 칸으로 열어 다시 적게 한다.
            template:
                RecurringTemplate.tryParse(row.template) ??
                const RecurringTemplate(
                  type: TxType.expense,
                  amount: 0,
                  accountId: '',
                ),
            frequency: RecurringFrequency.fromCode(row.frequency),
            intervalCount: row.intervalCount,
            nextRunOn: row.nextRunOn,
            endOn: row.endOn,
            autoPost: row.autoPost,
            isActive: row.isActive,
          );
    final template = start?.template;
    _type = template?.type ?? TxType.expense;
    final amount = template?.amount ?? 0;
    _amount = TextEditingController(
      text: amount > 0 ? formatNumber(amount) : '',
    );
    _party = TextEditingController(text: template?.counterparty ?? '');
    _memo = TextEditingController(text: template?.memo ?? '');
    _interval = TextEditingController(text: '${start?.intervalCount ?? 1}');
    _frequency = start?.frequency ?? RecurringFrequency.monthly;
    _next = start?.nextRunOn ?? ref.read(todayProvider);
    _end = start?.endOn;
    _accountId = template?.accountId;
    _toAccountId = template?.toAccountId;
    _categoryId = template?.categoryId;
    _autoPost = start?.autoPost ?? false;
    _active = start?.isActive ?? true;
    _originalNext = start?.nextRunOn;
    _originalAnchor = template?.anchorDay;
  }

  @override
  void dispose() {
    _amount.dispose();
    _party.dispose();
    _memo.dispose();
    _interval.dispose();
    super.dispose();
  }

  Future<LocalDate?> _pickDate(LocalDate initial) async {
    final today = ref.read(todayProvider);
    final first = DateTime(2000);
    final last = today.addDays(366 * 10).toDateTime();
    final start = initial.toDateTime();
    final picked = await showDatePicker(
      context: context,
      initialDate: start.isBefore(first)
          ? first
          : (start.isAfter(last) ? last : start),
      firstDate: first,
      lastDate: last,
    );
    return picked == null ? null : LocalDate.fromDateTime(picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final existing = widget.existing;
    final repository = ref.read(recurringRepositoryProvider);
    final ledgerId = ref.read(ledgerIdProvider);
    final input = RecurringRuleInput(
      template: RecurringTemplate(
        type: _type,
        amount: parseAmountInput(_amount.text)!,
        accountId: _accountId!,
        toAccountId: _type == TxType.transfer ? _toAccountId : null,
        counterparty: _party.text,
        categoryId: _categoryId,
        memo: _memo.text,
        anchorDay: _next == _originalNext ? _originalAnchor : null,
      ),
      frequency: _frequency,
      intervalCount: int.parse(_interval.text.trim()),
      nextRunOn: _next,
      endOn: _end,
      autoPost: _autoPost,
      isActive: _active,
    );
    setState(() => _saving = true);
    try {
      if (existing == null) {
        await repository.addRule(ledgerId, input);
      } else {
        await repository.updateRule(existing.id, input);
      }
      // 다음 날짜가 오늘이거나 지났으면 기다리지 않고 바로 만든다.
      final created = await repository.runDue(
        ledgerId,
        ref.read(todayProvider),
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      showNotice(
        context,
        created == 0 ? '반복 거래를 저장했습니다.' : '반복 거래를 저장하고 거래 $created건을 만들었습니다.',
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      showNotice(context, '저장하지 못했습니다. 입력한 내용을 확인하고 다시 시도해 주세요.');
    }
  }

  Future<void> _delete() async {
    final existing = widget.existing;
    if (existing == null) return;
    final confirmed = await confirmAction(
      context,
      title: '이 반복 거래를 지울까요?',
      message: '앞으로는 거래를 만들지 않습니다. 이미 만든 거래는 그대로 남습니다.',
    );
    if (!confirmed || !mounted) return;
    try {
      await ref.read(recurringRepositoryProvider).deleteRule(existing.id);
      if (!mounted) return;
      Navigator.of(context).pop();
      showNotice(context, '반복 거래를 지웠습니다.');
    } catch (_) {
      if (mounted) showNotice(context, '지우지 못했습니다. 잠시 뒤에 다시 시도해 주세요.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final existing = widget.existing;
    final accounts = ref.watch(accountsProvider).value ?? const <AccountRow>[];
    final categories =
        ref.watch(categoriesProvider).value ?? const <CategoryRow>[];
    final profile = ref.watch(profileProvider).value;

    // 고른 자산이 없으면(새 규칙) 기본 자산을 쓴다. 지워진 자산은 다시 고르게 비워 둔다.
    if (_accountId == null && accounts.isNotEmpty) {
      final preferred = profile?.defaultAccountId;
      _accountId = accounts.any((a) => a.id == preferred)
          ? preferred
          : accounts.first.id;
    }
    final accountValue = accounts.any((a) => a.id == _accountId)
        ? _accountId
        : null;
    final toAccountValue = accounts.any((a) => a.id == _toAccountId)
        ? _toAccountId
        : null;
    final kind = _type == TxType.income
        ? CategoryKind.income
        : CategoryKind.expense;
    final categoryOptions = [
      for (final c in categories)
        if (c.kind == kind) c,
    ];
    final categoryValue = categoryOptions.any((c) => c.id == _categoryId)
        ? _categoryId
        : null;
    final unit = switch (_frequency) {
      RecurringFrequency.weekly => '주마다',
      RecurringFrequency.monthly => '달마다',
      RecurringFrequency.yearly => '년마다',
    };
    const gap = SizedBox(height: 12);

    List<DropdownMenuItem<String>> accountItems() => [
      for (final a in accounts)
        DropdownMenuItem(
          value: a.id,
          child: Text(a.name, overflow: TextOverflow.ellipsis),
        ),
    ];

    return Form(
      key: _formKey,
      child: EditorFrame(
        title: existing != null
            ? '반복 거래 고치기'
            : (widget.initial != null ? '반복으로 등록' : '반복 거래 추가'),
        actions: [
          if (existing != null)
            TextButton(
              key: const ValueKey('recurring-form-delete'),
              onPressed: _saving ? null : _delete,
              style: TextButton.styleFrom(
                foregroundColor: theme.colorScheme.error,
              ),
              child: const Text('삭제'),
            ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('취소'),
          ),
          FilledButton(
            key: const ValueKey('recurring-form-save'),
            onPressed: _saving ? null : _save,
            child: Text(existing == null ? '추가' : '저장'),
          ),
        ],
        children: [
          SegmentedButton<TxType>(
            key: const ValueKey('recurring-form-type'),
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
            key: const ValueKey('recurring-form-amount'),
            controller: _amount,
            autofocus: existing == null && widget.initial == null,
            keyboardType: TextInputType.number,
            inputFormatters: const [AmountInputFormatter()],
            decoration: const InputDecoration(labelText: '금액', suffixText: '원'),
            validator: (value) {
              final amount = parseAmountInput(value ?? '');
              if (amount == null || amount <= 0) return '금액을 넣어야 합니다';
              return null;
            },
          ),
          gap,
          DropdownButtonFormField<String>(
            key: ValueKey('recurring-form-account-$accountValue'),
            initialValue: accountValue,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: _type == TxType.transfer ? '보내는 자산' : '자산',
            ),
            items: accountItems(),
            onChanged: (value) => setState(() => _accountId = value),
            validator: (value) => value == null ? '자산을 골라야 합니다' : null,
          ),
          gap,
          if (_type == TxType.transfer)
            DropdownButtonFormField<String>(
              key: ValueKey('recurring-form-to-account-$toAccountValue'),
              initialValue: toAccountValue,
              isExpanded: true,
              decoration: const InputDecoration(labelText: '받는 자산'),
              items: accountItems(),
              onChanged: (value) => setState(() => _toAccountId = value),
              validator: (value) {
                if (value == null) return '받는 자산을 골라야 합니다';
                if (value == _accountId) return '같은 자산으로는 이체할 수 없습니다';
                return null;
              },
            )
          else ...[
            TextFormField(
              key: const ValueKey('recurring-form-party'),
              controller: _party,
              decoration: InputDecoration(
                labelText: _type == TxType.income
                    ? '보낸 사람 · 기관'
                    : '받는 사람 · 가맹점',
                hintText: _type == TxType.income ? '예) 회사' : '예) 집주인',
              ),
            ),
            gap,
            DropdownButtonFormField<String?>(
              key: ValueKey('recurring-form-category-$_type-$categoryValue'),
              initialValue: categoryValue,
              isExpanded: true,
              decoration: const InputDecoration(labelText: '분류'),
              items: [
                const DropdownMenuItem<String?>(child: Text('분류 없음')),
                for (final c in categoryOptions)
                  DropdownMenuItem<String?>(
                    value: c.id,
                    child: Text(c.name, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: (value) => setState(() => _categoryId = value),
            ),
          ],
          gap,
          TextFormField(
            key: const ValueKey('recurring-form-memo'),
            controller: _memo,
            decoration: const InputDecoration(labelText: '메모'),
          ),
          const SizedBox(height: 20),
          Text('주기', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          DropdownButtonFormField<RecurringFrequency>(
            key: const ValueKey('recurring-form-frequency'),
            initialValue: _frequency,
            isExpanded: true,
            decoration: const InputDecoration(labelText: '반복'),
            items: const [
              DropdownMenuItem(
                value: RecurringFrequency.weekly,
                child: Text('매주'),
              ),
              DropdownMenuItem(
                value: RecurringFrequency.monthly,
                child: Text('매달'),
              ),
              DropdownMenuItem(
                value: RecurringFrequency.yearly,
                child: Text('매년'),
              ),
            ],
            onChanged: (value) =>
                setState(() => _frequency = value ?? _frequency),
          ),
          gap,
          TextFormField(
            key: const ValueKey('recurring-form-interval'),
            controller: _interval,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(2),
            ],
            decoration: InputDecoration(
              labelText: '간격',
              suffixText: unit,
              helperText: '1이면 빠짐없이, 2면 한 번씩 건너뜁니다',
              helperMaxLines: 2,
            ),
            validator: (value) {
              final count = int.tryParse(value?.trim() ?? '');
              if (count == null || count < 1) return '1 이상을 넣어야 합니다';
              return null;
            },
          ),
          gap,
          InkWell(
            key: const ValueKey('recurring-form-next'),
            onTap: () async {
              final picked = await _pickDate(_next);
              if (picked != null) setState(() => _next = picked);
            },
            borderRadius: BorderRadius.circular(4),
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: '다음 날짜',
                helperText: '이 날부터 거래를 만듭니다. 31일로 두면 짧은 달에는 마지막 날에 만듭니다',
                helperMaxLines: 3,
              ),
              child: Text(fullDateLabel(_next)),
            ),
          ),
          gap,
          Row(
            children: [
              Expanded(
                child: InkWell(
                  key: const ValueKey('recurring-form-end'),
                  onTap: () async {
                    final picked = await _pickDate(_end ?? _next);
                    if (picked != null) setState(() => _end = picked);
                  },
                  borderRadius: BorderRadius.circular(4),
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: '끝나는 날'),
                    child: Text(_end == null ? '정하지 않음' : fullDateLabel(_end!)),
                  ),
                ),
              ),
              if (_end != null)
                IconButton(
                  key: const ValueKey('recurring-form-end-clear'),
                  tooltip: '끝나는 날 지우기',
                  onPressed: () => setState(() => _end = null),
                  icon: const Icon(Icons.close),
                ),
            ],
          ),
          if (_end != null && _end! < _next)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '끝나는 날이 다음 날짜보다 앞이라 거래를 만들지 않습니다.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ),
          const SizedBox(height: 8),
          SwitchListTile(
            key: const ValueKey('recurring-form-auto'),
            contentPadding: EdgeInsets.zero,
            title: const Text('자동으로 등록'),
            subtitle: const Text("끄면 '확인 필요'로 만들어 두고 홈에서 알려 줍니다"),
            value: _autoPost,
            onChanged: (value) => setState(() => _autoPost = value),
          ),
          if (existing != null)
            SwitchListTile(
              key: const ValueKey('recurring-form-active'),
              contentPadding: EdgeInsets.zero,
              title: const Text('켜짐'),
              subtitle: const Text('꺼 두면 거래를 만들지 않습니다'),
              value: _active,
              onChanged: (value) => setState(() => _active = value),
            ),
        ],
      ),
    );
  }
}
