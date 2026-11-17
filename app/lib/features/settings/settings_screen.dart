import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/providers.dart';
import '../../core/breakpoints.dart';
import '../../core/formatters.dart';
import '../../data/db/database.dart';
import '../../data/repositories/ledger_repository.dart';
import '../../domain/enums.dart';
import '../common/widgets.dart';

/// 설정: 자산, 분류, 월 시작일, 저장 · 동기화 상태, 앱 정보.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wide = WindowSize.of(context).isExpanded;
    const accounts = _AccountsCard();
    const categories = _CategoriesCard();
    const general = _GeneralCard();
    const storage = _StorageCard();
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          Text('설정', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 12),
          if (wide)
            const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    children: [accounts, SizedBox(height: 16), general],
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    children: [categories, SizedBox(height: 16), storage],
                  ),
                ),
              ],
            )
          else ...const [
            accounts,
            SizedBox(height: 12),
            categories,
            SizedBox(height: 12),
            general,
            SizedBox(height: 12),
            storage,
          ],
        ],
      ),
    );
  }
}

class _AccountsCard extends ConsumerWidget {
  const _AccountsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balances = ref.watch(accountBalancesProvider);
    return SectionCard(
      title: '자산',
      trailing: TextButton.icon(
        key: const ValueKey('add-account'),
        onPressed: () => showDialog<void>(
          context: context,
          builder: (context) => const _AccountDialog(),
        ),
        icon: const Icon(Icons.add, size: 18),
        label: const Text('추가'),
      ),
      child: AsyncBody<List<AccountBalance>>(
        value: balances,
        builder: (list) => Column(
          children: [
            for (final item in list)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(item.account.name),
                subtitle: Text(
                  [
                    item.account.kind.label,
                    if (item.account.institution != null)
                      item.account.institution!,
                    if (item.account.matchHints.isNotEmpty)
                      '식별: ${item.account.matchHints.join(', ')}',
                  ].join(' · '),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(won(item.balance)),
                    IconButton(
                      tooltip: '지우기',
                      icon: const Icon(Icons.delete_outline, size: 20),
                      onPressed: () =>
                          _deleteAccount(context, ref, item.account),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteAccount(
    BuildContext context,
    WidgetRef ref,
    AccountRow account,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(repositoryProvider).deleteAccount(account.id);
      messenger.showSnackBar(
        SnackBar(content: Text('${account.name}을(를) 지웠다')),
      );
    } on StateError catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }
}

class _AccountDialog extends ConsumerStatefulWidget {
  const _AccountDialog();

  @override
  ConsumerState<_AccountDialog> createState() => _AccountDialogState();
}

class _AccountDialogState extends ConsumerState<_AccountDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _institution = TextEditingController();
  final _hints = TextEditingController();
  final _balance = TextEditingController();
  AccountKind _kind = AccountKind.bank;

  @override
  void dispose() {
    _name.dispose();
    _institution.dispose();
    _hints.dispose();
    _balance.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    await ref
        .read(repositoryProvider)
        .addAccount(
          ledgerId: ref.read(ledgerIdProvider),
          name: _name.text,
          kind: _kind,
          institution: _institution.text,
          matchHints: [
            for (final hint in _hints.text.split(RegExp(r'[,\s]+')))
              if (hint.trim().isNotEmpty) hint.trim(),
          ],
          openingBalance: parseAmountInput(_balance.text) ?? 0,
        );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('자산 추가'),
      content: SizedBox(
        width: 360,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  key: const ValueKey('account-name'),
                  controller: _name,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: '이름',
                    hintText: '예) 신한 체크카드',
                  ),
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? '이름을 넣어야 한다'
                      : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<AccountKind>(
                  initialValue: _kind,
                  decoration: const InputDecoration(labelText: '종류'),
                  items: [
                    for (final kind in AccountKind.values)
                      DropdownMenuItem(value: kind, child: Text(kind.label)),
                  ],
                  onChanged: (value) => setState(() => _kind = value ?? _kind),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _institution,
                  decoration: const InputDecoration(
                    labelText: '금융사',
                    hintText: '예) 신한카드',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const ValueKey('account-hints'),
                  controller: _hints,
                  decoration: const InputDecoration(
                    labelText: '식별 문구',
                    hintText: '예) 신한카드, 1234',
                    helperText: '결제 문자의 카드 · 계좌 표기와 맞춰 자산을 고른다',
                    helperMaxLines: 2,
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _balance,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: '시작 잔액',
                    suffixText: '원',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
        FilledButton(
          key: const ValueKey('account-save'),
          onPressed: _save,
          child: const Text('추가'),
        ),
      ],
    );
  }
}

class _CategoriesCard extends ConsumerWidget {
  const _CategoriesCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoriesProvider);
    return SectionCard(
      title: '분류',
      trailing: TextButton.icon(
        onPressed: () => showDialog<void>(
          context: context,
          builder: (context) => const _CategoryDialog(),
        ),
        icon: const Icon(Icons.add, size: 18),
        label: const Text('추가'),
      ),
      child: AsyncBody<List<CategoryRow>>(
        value: categories,
        builder: (list) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final kind in CategoryKind.values) ...[
              Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 6),
                child: Text(
                  kind == CategoryKind.expense ? '지출' : '수입',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final c in list.where((c) => c.kind == kind))
                    InputChip(
                      label: Text(c.name),
                      onDeleted: () =>
                          ref.read(repositoryProvider).deleteCategory(c.id),
                      deleteButtonTooltipMessage: '지우기',
                    ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }
}

class _CategoryDialog extends ConsumerStatefulWidget {
  const _CategoryDialog();

  @override
  ConsumerState<_CategoryDialog> createState() => _CategoryDialogState();
}

class _CategoryDialogState extends ConsumerState<_CategoryDialog> {
  final _name = TextEditingController();
  CategoryKind _kind = CategoryKind.expense;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) return;
    await ref
        .read(repositoryProvider)
        .addCategory(
          ledgerId: ref.read(ledgerIdProvider),
          kind: _kind,
          name: _name.text,
        );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('분류 추가'),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SegmentedButton<CategoryKind>(
              segments: const [
                ButtonSegment(value: CategoryKind.expense, label: Text('지출')),
                ButtonSegment(value: CategoryKind.income, label: Text('수입')),
              ],
              selected: {_kind},
              onSelectionChanged: (s) => setState(() => _kind = s.first),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _name,
              autofocus: true,
              decoration: const InputDecoration(labelText: '이름'),
              onSubmitted: (_) => _save(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
        FilledButton(onPressed: _save, child: const Text('추가')),
      ],
    );
  }
}

class _GeneralCard extends ConsumerWidget {
  const _GeneralCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final startDay = ref.watch(monthStartDayProvider);
    return SectionCard(
      title: '가계부',
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('월 시작일'),
                    Text(
                      '급여일에 맞추면 그날부터 한 달로 집계한다',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
              DropdownButton<int>(
                key: const ValueKey('month-start-day'),
                value: startDay,
                items: [
                  for (var day = 1; day <= 28; day++)
                    DropdownMenuItem(value: day, child: Text('$day일')),
                ],
                onChanged: (day) {
                  if (day == null) return;
                  ref
                      .read(repositoryProvider)
                      .setMonthStartDay(ref.read(ledgerIdProvider), day);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StorageCard extends ConsumerWidget {
  const _StorageCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final services = ref.watch(appServicesProvider);
    final pending = ref.watch(pendingChangesProvider).value ?? 0;
    final theme = Theme.of(context);
    return SectionCard(
      title: '저장과 동기화',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              services.persistent ? Icons.save_outlined : Icons.warning_amber,
              color: services.persistent ? null : theme.colorScheme.error,
            ),
            title: Text(services.storage),
            subtitle: Text(
              services.persistent
                  ? '거래는 이 기기에 먼저 저장된다'
                  : '이 브라우저는 저장소를 허용하지 않아 창을 닫으면 내용이 사라진다',
            ),
          ),
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.cloud_off_outlined),
            title: const Text('로그인하지 않음'),
            subtitle: Text(
              pending == 0
                  ? '로그인하면 다른 기기와 동기화한다(준비 중)'
                  : '서버로 보낼 변경 $pending건이 기다리고 있다(로그인 준비 중)',
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () =>
                  showLicensePage(context: context, applicationName: '가계부'),
              child: const Text('오픈소스 라이선스'),
            ),
          ),
        ],
      ),
    );
  }
}
