import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/providers.dart';
import '../../app/theme/tokens.dart';
import '../../core/formatters.dart';
import '../../core/local_date.dart';
import '../../data/db/database.dart';
import '../../data/repositories/recurring_repository.dart';
import '../../domain/enums.dart';
import '../accounts/manage_common.dart';
import '../common/widgets.dart';
import 'recurring_form.dart';

/// 반복 규칙 목록(다음 날짜가 가까운 순서).
final recurringRulesProvider = StreamProvider<List<RecurringRuleRow>>(
  (ref) => ref
      .watch(recurringRepositoryProvider)
      .watchRules(ref.watch(ledgerIdProvider)),
);

/// 반복 거래 화면. `docs/SPEC.md` 7.13.
///
/// 주소에 `?from=<거래 ID>`가 있으면(거래 편집에서 '반복으로 등록'을 눌렀을 때) 그 거래를
/// 틀로 새 규칙을 만드는 칸을 연다.
class RecurringScreen extends ConsumerStatefulWidget {
  const RecurringScreen({super.key});

  @override
  ConsumerState<RecurringScreen> createState() => _RecurringScreenState();
}

class _RecurringScreenState extends ConsumerState<RecurringScreen> {
  /// 이미 칸을 열어 준 `from` 값. 화면을 다시 그릴 때 또 열지 않게 한다.
  String? _handledFrom;

  void _openForm({RecurringRuleRow? existing}) => showEditor<void>(
    context,
    builder: (context) => RecurringForm(existing: existing),
  );

  void _checkFrom(String? from) {
    if (from == null) {
      _handledFrom = null;
      return;
    }
    if (from == _handledFrom) return;
    _handledFrom = from;
    // 화면을 그리는 중에는 칸을 열 수 없다.
    WidgetsBinding.instance.addPostFrameCallback((_) => _openFrom(from));
  }

  Future<void> _openFrom(String transactionId) async {
    final tx = await ref
        .read(repositoryProvider)
        .transactionById(transactionId);
    if (!mounted) return;
    if (tx == null || tx.deletedAt != null) {
      showNotice(context, '틀로 삼을 거래를 찾지 못했습니다.');
    } else {
      await showEditor<void>(
        context,
        builder: (context) => RecurringForm(
          initial: ruleInputFromTransaction(tx, ref.read(todayProvider)),
        ),
      );
    }
    // 주소에서 from을 떼어, 새로 고치거나 뒤로 왔을 때 칸이 또 열리지 않게 한다.
    if (mounted) context.go('/recurring');
  }

  Future<void> _setActive(RecurringRuleRow rule, bool active) async {
    final repository = ref.read(recurringRepositoryProvider);
    try {
      await repository.setActive(rule.id, active: active);
      // 다시 켰으면 그사이 밀린 것을 바로 만든다.
      final created = active
          ? await repository.runDue(rule.ledgerId, ref.read(todayProvider))
          : 0;
      if (!mounted) return;
      if (created > 0) showNotice(context, '밀린 거래 $created건을 만들었습니다.');
    } catch (_) {
      if (mounted) showNotice(context, '바꾸지 못했습니다. 잠시 뒤에 다시 시도해 주세요.');
    }
  }

  @override
  Widget build(BuildContext context) {
    _checkFrom(GoRouterState.of(context).uri.queryParameters['from']);
    final rules = ref.watch(recurringRulesProvider);
    return SafeArea(
      child: ListView(
        padding: manageListPadding,
        children: [
          ManageHeader(
            title: '반복 거래',
            actions: [
              FilledButton.tonalIcon(
                key: const ValueKey('recurring-add'),
                onPressed: _openForm,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('추가'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ManageAsync<List<RecurringRuleRow>>(
            value: rules,
            what: '반복 거래를',
            onRetry: () => ref.invalidate(recurringRulesProvider),
            builder: _buildList,
          ),
        ],
      ),
    );
  }

  Widget _buildList(List<RecurringRuleRow> rules) {
    if (rules.isEmpty) {
      return EmptyState(
        icon: Icons.event_repeat,
        message: '등록한 반복 거래가 없습니다.\n월세나 구독료처럼 정해진 날에 나가는 돈을 넣어 두면 그날 알아서 적습니다.',
        action: FilledButton(
          key: const ValueKey('recurring-add-first'),
          onPressed: _openForm,
          child: const Text('반복 거래 추가'),
        ),
      );
    }
    final accounts = {
      for (final a in ref.watch(accountsProvider).value ?? const <AccountRow>[])
        a.id: a.name,
    };
    final categories = {
      for (final c
          in ref.watch(categoriesProvider).value ?? const <CategoryRow>[])
        c.id: c.name,
    };
    final accountsLoaded = ref.watch(accountsProvider).hasValue;
    final today = ref.watch(todayProvider);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (index, rule) in rules.indexed) ...[
            if (index > 0) const Divider(height: 1),
            _RuleTile(
              key: ValueKey('recurring-rule-${rule.id}'),
              rule: rule,
              accounts: accounts,
              categories: categories,
              accountsLoaded: accountsLoaded,
              today: today,
              onTap: () => _openForm(existing: rule),
              onActiveChanged: (active) => _setActive(rule, active),
            ),
          ],
        ],
      ),
    );
  }
}

class _RuleTile extends StatelessWidget {
  const _RuleTile({
    super.key,
    required this.rule,
    required this.accounts,
    required this.categories,
    required this.accountsLoaded,
    required this.today,
    required this.onTap,
    required this.onActiveChanged,
  });

  final RecurringRuleRow rule;

  /// 자산 · 분류의 ID → 이름.
  final Map<String, String> accounts;
  final Map<String, String> categories;
  final bool accountsLoaded;
  final LocalDate today;
  final VoidCallback onTap;
  final ValueChanged<bool> onActiveChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final template = RecurringTemplate.tryParse(rule.template);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    final String name;
    final String amount;
    final Color amountColor;
    String? problem;
    if (template == null) {
      name = '읽을 수 없는 규칙';
      amount = '';
      amountColor = theme.colorScheme.onSurface;
      problem = '내용을 읽지 못했습니다. 눌러서 다시 적어 주세요.';
    } else {
      final from = accounts[template.accountId];
      final to = accounts[template.toAccountId];
      final transfer = template.type == TxType.transfer;
      name =
          [
                template.counterparty,
                template.memo,
                if (transfer) '${from ?? '?'} → ${to ?? '?'}',
                categories[template.categoryId],
              ]
              .whereType<String>()
              .where((text) => text.trim().isNotEmpty)
              .firstOrNull ??
          '반복 거래';
      // 이체에는 부호를 붙이지 않는다.
      (amount, amountColor) = switch (template.type) {
        TxType.expense => ('-${won(template.amount)}', tokens.expense),
        TxType.income => ('+${won(template.amount)}', tokens.income),
        TxType.transfer => (won(template.amount), tokens.transfer),
      };
      if (accountsLoaded && (from == null || (transfer && to == null))) {
        problem = '자산이 지워져 거래를 만들지 못합니다. 눌러서 자산을 다시 골라 주세요.';
      }
    }

    final end = rule.endOn;
    final ended = end != null && rule.nextRunOn > end;
    final schedule = describeSchedule(
      RecurringFrequency.fromCode(rule.frequency),
      rule.intervalCount,
      rule.nextRunOn,
      anchorDay: template?.anchorDay,
    );
    final nextLabel = rule.nextRunOn.year == today.year
        ? monthDay(rule.nextRunOn)
        : '${rule.nextRunOn.year}년 ${monthDay(rule.nextRunOn)}';
    final String state;
    if (ended) {
      state = '끝남';
    } else if (!rule.isActive) {
      state = '꺼짐';
    } else {
      state = '다음 $nextLabel';
    }

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
        child: Row(
          children: [
            Expanded(
              child: Opacity(
                // 꺼 둔 규칙과 끝난 규칙은 흐리게 보인다(글자로도 알린다).
                opacity: rule.isActive && !ended ? 1 : 0.6,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    LabelAmountRow(
                      label: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyLarge,
                      ),
                      amount: Text(
                        amount,
                        maxLines: 1,
                        style: tokens.amountStyle(
                          theme.textTheme.bodyLarge?.copyWith(
                            color: amountColor,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        schedule,
                        state,
                        if (end != null && !ended) '${monthDay(end)}까지',
                        rule.autoPost ? '자동 등록' : '확인 후 등록',
                      ].join(' · '),
                      style: muted,
                    ),
                    if (problem != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.warning_amber_rounded,
                              size: 16,
                              color: tokens.warn,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                problem,
                                style: muted?.copyWith(color: tokens.warn),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            Semantics(
              label: rule.isActive ? '반복 거래 끄기' : '반복 거래 켜기',
              child: Switch(
                key: ValueKey('recurring-active-${rule.id}'),
                value: rule.isActive,
                onChanged: onActiveChanged,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
