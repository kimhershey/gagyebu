import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/providers.dart';
import '../../core/formatters.dart';
import '../../data/db/database.dart';
import '../../data/repositories/account_repository.dart';
import '../../domain/enums.dart';
import 'manage_common.dart';

/// 자산을 더하거나 고치는 칸. [existing]이 있으면 고친다.
class AccountForm extends ConsumerStatefulWidget {
  const AccountForm({super.key, this.existing});

  final AccountRow? existing;

  @override
  ConsumerState<AccountForm> createState() => _AccountFormState();
}

class _AccountFormState extends ConsumerState<AccountForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _institution;
  late final TextEditingController _opening;
  late final TextEditingController _hints;
  late final TextEditingController _billingDay;
  late AccountKind _kind;
  String? _paymentAccountId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final row = widget.existing;
    _name = TextEditingController(text: row?.name ?? '');
    _institution = TextEditingController(text: row?.institution ?? '');
    final opening = row?.openingBalance ?? 0;
    _opening = TextEditingController(
      text: opening == 0 ? '' : formatNumber(opening),
    );
    _hints = TextEditingController(text: row?.matchHints.join(', ') ?? '');
    _billingDay = TextEditingController(
      text: row?.billingDay?.toString() ?? '',
    );
    _kind = row?.kind ?? AccountKind.bank;
    _paymentAccountId = row?.paymentAccountId;
  }

  @override
  void dispose() {
    _name.dispose();
    _institution.dispose();
    _opening.dispose();
    _hints.dispose();
    _billingDay.dispose();
    super.dispose();
  }

  bool get _isCard =>
      _kind == AccountKind.creditCard || _kind == AccountKind.checkCard;

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final existing = widget.existing;
    final hints = [
      for (final hint in _hints.text.split(RegExp(r'[,\n]+')))
        if (hint.trim().isNotEmpty) hint.trim(),
    ];
    final opening = parseSignedAmount(_opening.text) ?? 0;
    final billingDay = _kind == AccountKind.creditCard
        ? int.tryParse(_billingDay.text.trim())
        : null;
    final payment = _isCard ? _paymentAccountId : null;
    setState(() => _saving = true);
    try {
      if (existing == null) {
        await ref
            .read(repositoryProvider)
            .addAccount(
              ledgerId: ref.read(ledgerIdProvider),
              name: _name.text,
              kind: _kind,
              institution: _institution.text,
              matchHints: hints,
              openingBalance: opening,
              billingDay: billingDay,
              paymentAccountId: payment,
            );
      } else {
        await ref
            .read(accountRepositoryProvider)
            .updateAccount(
              existing.id,
              name: _name.text,
              kind: _kind,
              institution: _institution.text,
              matchHints: hints,
              openingBalance: opening,
              billingDay: billingDay,
              paymentAccountId: payment,
            );
      }
      if (!mounted) return;
      Navigator.of(context).pop();
      showNotice(context, existing == null ? '자산을 추가했습니다.' : '자산을 고쳤습니다.');
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
      title: '${existing.name} 자산을 지울까요?',
      message: '지운 자산은 다른 기기에서도 사라집니다.',
    );
    if (!confirmed || !mounted) return;
    try {
      await ref.read(repositoryProvider).deleteAccount(existing.id);
      if (!mounted) return;
      Navigator.of(context).pop();
      showNotice(context, '${existing.name} 자산을 지웠습니다.');
    } on StateError {
      // 거래가 있는 자산은 지우지 못한다. 어떻게 하면 되는지 알려 준다.
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          key: const ValueKey('account-delete-blocked'),
          title: const Text('지울 수 없습니다'),
          content: Text(
            '${existing.name} 자산을 쓰는 거래가 있습니다.\n'
            '내역에서 그 거래의 자산을 다른 자산으로 옮긴 뒤에 다시 지워 주세요.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('확인'),
            ),
          ],
        ),
      );
    } catch (_) {
      if (mounted) showNotice(context, '지우지 못했습니다. 잠시 뒤에 다시 시도해 주세요.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final existing = widget.existing;
    final accounts = ref.watch(accountsProvider).value ?? const <AccountRow>[];
    // 결제 계좌로 고를 수 있는 자산: 카드가 아니고 자기 자신이 아닌 것.
    final paymentOptions = [
      for (final a in accounts)
        if (a.id != existing?.id &&
            a.kind != AccountKind.creditCard &&
            a.kind != AccountKind.checkCard)
          a,
    ];
    final paymentValue = paymentOptions.any((a) => a.id == _paymentAccountId)
        ? _paymentAccountId
        : null;
    const gap = SizedBox(height: 12);

    return Form(
      key: _formKey,
      child: EditorFrame(
        title: existing == null ? '자산 추가' : '자산 고치기',
        actions: [
          if (existing != null)
            TextButton(
              key: const ValueKey('account-form-delete'),
              onPressed: _saving ? null : _delete,
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
              ),
              child: const Text('삭제'),
            ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('취소'),
          ),
          FilledButton(
            key: const ValueKey('account-form-save'),
            onPressed: _saving ? null : _save,
            child: Text(existing == null ? '추가' : '저장'),
          ),
        ],
        children: [
          TextFormField(
            key: const ValueKey('account-form-name'),
            controller: _name,
            autofocus: existing == null,
            decoration: const InputDecoration(
              labelText: '이름',
              hintText: '예) 신한 체크카드',
            ),
            validator: (value) =>
                (value == null || value.trim().isEmpty) ? '이름을 넣어야 합니다' : null,
          ),
          gap,
          DropdownButtonFormField<AccountKind>(
            key: const ValueKey('account-form-kind'),
            initialValue: _kind,
            isExpanded: true,
            decoration: const InputDecoration(labelText: '종류'),
            items: [
              for (final kind in AccountKind.values)
                DropdownMenuItem(value: kind, child: Text(kind.label)),
            ],
            onChanged: (value) => setState(() => _kind = value ?? _kind),
          ),
          gap,
          TextFormField(
            key: const ValueKey('account-form-institution'),
            controller: _institution,
            decoration: const InputDecoration(
              labelText: '금융사',
              hintText: '예) 신한카드',
            ),
          ),
          gap,
          TextFormField(
            key: const ValueKey('account-form-opening'),
            controller: _opening,
            keyboardType: const TextInputType.numberWithOptions(signed: true),
            inputFormatters: const [AmountInputFormatter(allowNegative: true)],
            decoration: const InputDecoration(
              labelText: '시작 잔액',
              suffixText: '원',
              helperText: '가계부를 쓰기 시작할 때의 잔액입니다. 갚을 돈이면 -를 붙입니다',
              helperMaxLines: 3,
            ),
          ),
          gap,
          TextFormField(
            key: const ValueKey('account-form-hints'),
            controller: _hints,
            decoration: const InputDecoration(
              labelText: '문자와 잇는 말',
              hintText: '예) 신한카드, 1234',
              helperText: '결제 문자에 이 말이 있으면 이 자산으로 잇습니다. 쉼표로 나눠 적습니다',
              helperMaxLines: 3,
            ),
          ),
          if (_kind == AccountKind.creditCard) ...[
            gap,
            TextFormField(
              key: const ValueKey('account-form-billing-day'),
              controller: _billingDay,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(2),
              ],
              decoration: const InputDecoration(
                labelText: '결제일',
                suffixText: '일',
                helperText: '1–31. 그 달에 없는 날이면 마지막 날로 봅니다',
                helperMaxLines: 2,
              ),
              validator: (value) {
                final text = value?.trim() ?? '';
                if (text.isEmpty) return null;
                final day = int.tryParse(text);
                if (day == null || day < 1 || day > 31) {
                  return '1부터 31까지 넣어야 합니다';
                }
                return null;
              },
            ),
          ],
          if (_isCard) ...[
            gap,
            DropdownButtonFormField<String?>(
              key: const ValueKey('account-form-payment'),
              initialValue: paymentValue,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: _kind == AccountKind.creditCard ? '결제 계좌' : '연결 계좌',
                helperText: _kind == AccountKind.creditCard
                    ? '카드대금이 빠져나가는 계좌입니다'
                    : '체크카드로 쓴 돈은 이 계좌에서 바로 나간 것으로 봅니다',
                helperMaxLines: 3,
              ),
              items: [
                const DropdownMenuItem<String?>(child: Text('정하지 않음')),
                for (final a in paymentOptions)
                  DropdownMenuItem<String?>(
                    value: a.id,
                    child: Text(a.name, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: (value) => setState(() => _paymentAccountId = value),
            ),
          ],
        ],
      ),
    );
  }
}
