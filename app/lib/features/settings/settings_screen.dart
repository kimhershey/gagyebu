import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/providers.dart';
import '../../app/sync_controller.dart';
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
        SnackBar(content: Text('${account.name}을(를) 지웠습니다')),
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
                      ? '이름을 넣어야 합니다'
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
                    helperText: '결제 문자의 카드 · 계좌 표기와 맞춰 자산을 고릅니다',
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
                      '급여일에 맞추면 그날부터 한 달로 집계합니다',
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
    final theme = Theme.of(context);
    final started = services.startedAt?.toLocal();
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
              [
                if (!services.persistent)
                  '이 브라우저는 저장소를 허용하지 않아 창을 닫으면 내용이 사라집니다'
                else if (kIsWeb)
                  '이 브라우저에만 저장됩니다. 다른 기기나 다른 브라우저에서는 보이지 않습니다'
                else
                  '이 기기에만 저장됩니다',
                // 들어올 때마다 날짜가 오늘로 바뀌어 있으면 브라우저가 저장소를 비운 것이다.
                if (services.persistent && started != null)
                  '${started.year}년 ${started.month}월 ${started.day}일부터 '
                      '여기에 저장하고 있습니다',
              ].join('\n'),
            ),
          ),
          const _AccountTile(),
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

/// 로그인 상태와 동기화 상태. 로그인 · 로그아웃 · 지금 동기화.
class _AccountTile extends ConsumerWidget {
  const _AccountTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(syncControllerProvider);
    final pending = ref.watch(pendingChangesProvider).value ?? 0;
    final controller = ref.read(syncControllerProvider.notifier);
    final theme = Theme.of(context);

    Widget tile(IconData icon, String title, String subtitle, {Color? color}) =>
        ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: Icon(icon, color: color),
          title: Text(title),
          subtitle: Text(subtitle),
        );
    Widget actions(List<Widget> buttons) => Padding(
      padding: const EdgeInsets.only(left: 40, bottom: 4),
      child: Wrap(spacing: 8, runSpacing: 4, children: buttons),
    );

    switch (status.phase) {
      case SyncPhase.unavailable:
        return tile(
          Icons.cloud_off_outlined,
          '이 앱에는 로그인이 들어 있지 않습니다',
          pending == 0
              ? '가계부는 이 기기 안에만 저장됩니다'
              : '가계부는 이 기기 안에만 저장됩니다(올리지 않은 변경 $pending건)',
        );
      case SyncPhase.signedOut:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            tile(
              Icons.cloud_off_outlined,
              '로그인하지 않았습니다',
              '로그인하면 이 가계부를 계정에 올리고 다른 기기와 맞춥니다',
            ),
            actions([
              FilledButton.tonalIcon(
                key: const ValueKey('sign-in'),
                onPressed: () => context.push('/welcome/login'),
                icon: const Icon(Icons.login, size: 18),
                label: const Text('로그인'),
              ),
              TextButton(
                key: const ValueKey('sign-up'),
                onPressed: () => context.push('/welcome/signup'),
                child: const Text('계정 만들기'),
              ),
            ]),
          ],
        );
      case SyncPhase.differentAccount:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            tile(
              Icons.warning_amber,
              '이 기기에는 다른 계정의 가계부가 있습니다',
              '${status.user?.email ?? '이 계정'}(으)로 계속하려면 이 기기의 가계부를 지우고 '
                  '계정의 가계부를 받아야 합니다.'
                  '${pending > 0 ? ' 아직 올리지 않은 변경 $pending건은 사라집니다.' : ''}',
              color: theme.colorScheme.error,
            ),
            actions([
              TextButton(
                onPressed: controller.signOut,
                child: const Text('로그아웃'),
              ),
              FilledButton.tonal(
                key: const ValueKey('replace-local'),
                onPressed: controller.replaceLocalLedger,
                child: const Text('지우고 받기'),
              ),
            ]),
          ],
        );
      case SyncPhase.syncing:
      case SyncPhase.idle:
      case SyncPhase.failed:
        final last = status.lastSyncedAt?.toLocal();
        final waiting = pending > 0 ? ' · 올릴 변경 $pending건' : '';
        final (icon, line) = switch (status.phase) {
          SyncPhase.syncing => (Icons.cloud_sync_outlined, '동기화하는 중입니다'),
          SyncPhase.failed => (
            Icons.cloud_off_outlined,
            '동기화하지 못했습니다. 잠시 뒤 다시 시도합니다$waiting\n${status.error ?? ''}',
          ),
          _ => (
            Icons.cloud_done_outlined,
            last == null
                ? '동기화했습니다$waiting'
                : '${formatTimeOfDay(last)}에 동기화했습니다$waiting',
          ),
        };
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            tile(
              icon,
              status.user?.email ?? '로그인했습니다',
              line,
              color: status.phase == SyncPhase.failed
                  ? theme.colorScheme.error
                  : null,
            ),
            actions([
              TextButton(
                key: const ValueKey('sync-now'),
                onPressed: status.phase == SyncPhase.syncing
                    ? null
                    : controller.syncNow,
                child: const Text('지금 동기화'),
              ),
              TextButton(
                key: const ValueKey('sign-out'),
                onPressed: controller.signOut,
                child: const Text('로그아웃'),
              ),
            ]),
          ],
        );
    }
  }
}
