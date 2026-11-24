import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/providers.dart';
import '../../app/theme/tokens.dart';
import '../../core/formatters.dart';
import '../../data/db/database.dart';
import '../../data/repositories/account_repository.dart';
import '../../domain/enums.dart';
import '../common/widgets.dart';
import 'account_form.dart';
import 'account_list.dart';
import 'manage_common.dart';

/// 자산 화면. `docs/SPEC.md` 7.2 · 7.12.
///
/// 종류별로 묶은 목록과 잔액을 보여 준다. 줄을 누르면 고치고, 길게 눌러 끌거나 손잡이를
/// 끌면 같은 종류 안에서 순서가 바뀐다.
class AccountsScreen extends ConsumerStatefulWidget {
  const AccountsScreen({super.key});

  @override
  ConsumerState<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends ConsumerState<AccountsScreen> {
  /// 방금 끌어 놓은 순서(종류별). 저장된 목록이 다시 올 때까지 이 순서로 그린다.
  final _pendingOrder = <AccountKind, List<String>>{};

  void _openForm([AccountRow? existing]) => showEditor<void>(
    context,
    builder: (context) => AccountForm(existing: existing),
  );

  Future<void> _reorder(AccountSection section, int from, int to) async {
    final ids = [for (final item in section.items) item.account.id];
    ids.insert(to, ids.removeAt(from));
    setState(() => _pendingOrder[section.kind] = ids);
    try {
      await ref
          .read(accountRepositoryProvider)
          .reorderAccounts(ref.read(ledgerIdProvider), ids);
    } catch (_) {
      if (!mounted) return;
      setState(() => _pendingOrder.remove(section.kind));
      showNotice(context, '순서를 바꾸지 못했습니다. 잠시 뒤에 다시 시도해 주세요.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final sections = ref.watch(accountSectionsProvider);
    return SafeArea(
      child: ListView(
        padding: manageListPadding,
        children: [
          ManageHeader(
            title: '자산',
            inSideMenu: true,
            actions: [
              FilledButton.tonalIcon(
                key: const ValueKey('accounts-add'),
                onPressed: _openForm,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('추가'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ManageAsync<List<AccountSection>>(
            value: sections,
            what: '자산을',
            onRetry: () => ref.invalidate(accountBalancesProvider),
            builder: _buildSections,
          ),
        ],
      ),
    );
  }

  Widget _buildSections(List<AccountSection> sections) {
    if (sections.isEmpty) {
      return EmptyState(
        icon: Icons.account_balance_wallet_outlined,
        message: '등록한 자산이 없습니다.\n카드와 계좌를 넣으면 결제 문자를 알아서 잇습니다.',
        action: FilledButton(
          key: const ValueKey('accounts-add-first'),
          onPressed: _openForm,
          child: const Text('자산 추가'),
        ),
      );
    }
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final total = sections
        .expand((s) => s.items)
        .fold<int>(0, (sum, item) => sum + (item.balance ?? 0));
    final hasDue = sections.any((s) => s.items.any((i) => i.due != null));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: LabelAmountRow(
              label: Text('자산 합계', style: theme.textTheme.titleMedium),
              amount: Text(
                won(total),
                key: const ValueKey('accounts-total'),
                maxLines: 1,
                style: tokens.amountStyle(theme.textTheme.titleLarge),
              ),
            ),
          ),
        ),
        for (final section in sections) ...[
          const SizedBox(height: 16),
          _buildSection(section),
        ],
        if (hasDue) ...[
          const SizedBox(height: 12),
          Text(
            '결제 예정액은 지난 결제일 다음 날부터 이번 결제일까지 그 카드로 쓴 돈을 더한 값입니다. '
            '카드사의 실제 청구액과 다를 수 있습니다.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSection(AccountSection section) {
    final theme = Theme.of(context);
    var pending = _pendingOrder[section.kind];
    // 저장된 목록이 끌어 놓은 순서로 왔으면 더 붙들 까닭이 없다. 계속 붙들면 다른
    // 기기에서 바꾼 순서를 가린다.
    if (pending != null &&
        listEquals(pending, [for (final i in section.items) i.account.id])) {
      _pendingOrder.remove(section.kind);
      pending = null;
    }
    final items = applyPendingOrder(
      section.items,
      pending,
      (item) => item.account.id,
    );
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(section.kind.label, style: theme.textTheme.titleMedium),
          ),
          ReorderableListView.builder(
            key: ValueKey('accounts-list-${section.kind.code}'),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            itemCount: items.length,
            onReorderItem: (from, to) => _reorder(
              AccountSection(kind: section.kind, items: items),
              from,
              to,
            ),
            itemBuilder: (context, index) => _AccountTile(
              key: ValueKey('account-${items[index].account.id}'),
              item: items[index],
              index: index,
              reorderable: items.length > 1,
              onTap: () => _openForm(items[index].account),
            ),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

IconData _kindIcon(AccountKind kind) => switch (kind) {
  AccountKind.cash => Icons.payments_outlined,
  AccountKind.bank => Icons.account_balance_outlined,
  AccountKind.creditCard => Icons.credit_card,
  AccountKind.checkCard => Icons.credit_score_outlined,
  AccountKind.pay => Icons.phone_iphone,
  AccountKind.other => Icons.account_balance_wallet_outlined,
};

class _AccountTile extends StatelessWidget {
  const _AccountTile({
    super.key,
    required this.item,
    required this.index,
    required this.reorderable,
    required this.onTap,
  });

  final AccountItem item;
  final int index;
  final bool reorderable;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final account = item.account;
    final balance = item.balance;
    final due = item.due;
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    final payment = item.paymentAccountName;
    final String? link = switch (account.kind) {
      // 잔액이 없으면 연결 계좌에 합쳐 센 것이다.
      AccountKind.checkCard =>
        balance == null ? '$payment에서 바로 나갑니다' : '연결 계좌를 정하지 않았습니다',
      AccountKind.creditCard => payment == null ? null : '결제 계좌 $payment',
      _ => null,
    };
    final details = [?account.institution, ?link];
    final name = Text(
      account.name,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.bodyLarge,
    );

    final row = InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          // 촘촘한 톤에서도 누름 영역은 48을 지킨다.
          minHeight: tokens.rowHeight < 48 ? 48 : tokens.rowHeight,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 4, 8),
          child: Row(
            children: [
              Icon(
                _kindIcon(account.kind),
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (balance == null)
                      name
                    else
                      LabelAmountRow(
                        label: name,
                        amount: Text(
                          won(balance),
                          key: ValueKey('account-balance-${account.id}'),
                          maxLines: 1,
                          style: tokens.amountStyle(theme.textTheme.bodyLarge),
                        ),
                      ),
                    if (details.isNotEmpty)
                      Text(details.join(' · '), style: muted),
                    if (due != null)
                      Text(
                        '다음 결제일 ${due.date.day}일 · 예정 ${won(due.amount)}',
                        key: ValueKey('account-due-${account.id}'),
                        style: muted,
                      )
                    else if (account.kind == AccountKind.creditCard)
                      Text('결제일을 정하면 결제 예정액을 보여 줍니다', style: muted),
                  ],
                ),
              ),
              if (reorderable)
                ReorderableDragStartListener(
                  index: index,
                  child: Tooltip(
                    message: '끌어서 순서 바꾸기',
                    child: SizedBox(
                      key: ValueKey('account-handle-${account.id}'),
                      width: 48,
                      height: 48,
                      child: Icon(
                        Icons.drag_handle,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                )
              else
                // 손잡이가 없는 줄도 같은 자리를 비워 금액의 끝을 맞춘다.
                const SizedBox(width: 48),
            ],
          ),
        ),
      ),
    );

    // 터치 기기에서는 줄을 길게 눌러 끌 수 있다.
    return Material(
      type: MaterialType.transparency,
      child: reorderable
          ? ReorderableDelayedDragStartListener(index: index, child: row)
          : row,
    );
  }
}
