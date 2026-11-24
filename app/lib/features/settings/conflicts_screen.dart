import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/providers.dart';
import '../../core/formatters.dart';
import '../../core/local_date.dart';
import '../../data/repositories/conflict_repository.dart';
import '../../domain/enums.dart';
import '../common/widgets.dart';
import 'sub_screen.dart';

/// 동기화 충돌 화면(`docs/SPEC.md` 4.6): 밀려난 쪽의 값을 보여 주고, 거래는 되살린다.
class ConflictsScreen extends ConsumerStatefulWidget {
  const ConflictsScreen({super.key});

  @override
  ConsumerState<ConflictsScreen> createState() => _ConflictsScreenState();
}

class _ConflictsScreenState extends ConsumerState<ConflictsScreen> {
  /// 되살리거나 지우는 중인 기록.
  final _busy = <int>{};

  @override
  void initState() {
    super.initState();
    // 화면을 열 때 오래된 기록을 정리한다. 정리하지 못해도 화면은 그대로 보여 준다.
    ref.read(conflictRepositoryProvider).pruneConflicts().catchError((
      Object _,
    ) {
      return 0;
    });
  }

  Future<void> _run(
    ConflictView view,
    Future<void> Function() action, {
    required String done,
    required String failed,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy.add(view.row.seq));
    try {
      await action();
      messenger.showSnackBar(SnackBar(content: Text(done)));
    } on Object {
      messenger.showSnackBar(SnackBar(content: Text(failed)));
    } finally {
      if (mounted) setState(() => _busy.remove(view.row.seq));
    }
  }

  @override
  Widget build(BuildContext context) {
    final conflicts = ref.watch(conflictsProvider);
    final repository = ref.watch(conflictRepositoryProvider);
    final names = _Names(
      accounts: {
        for (final a in ref.watch(accountsProvider).value ?? const [])
          a.id: a.name,
      },
      categories: {
        for (final c in ref.watch(categoriesProvider).value ?? const [])
          c.id: c.name,
      },
    );

    final list = conflicts.value;
    final List<Widget> body;
    if (list == null) {
      body = [
        conflicts.hasError
            ? const EmptyState(
                icon: Icons.error_outline,
                message: '충돌 기록을 불러오지 못했습니다.\n화면을 닫았다가 다시 열어 주십시오.',
              )
            : const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              ),
      ];
    } else if (list.isEmpty) {
      body = const [
        EmptyState(icon: Icons.call_split, message: '충돌 기록이 없습니다.'),
      ];
    } else {
      body = [
        for (final view in list) ...[
          _ConflictCard(
            key: ValueKey('conflict-${view.row.seq}'),
            view: view,
            names: names,
            busy: _busy.contains(view.row.seq),
            onRestore: !view.canRestore
                ? null
                : () => _run(
                    view,
                    () => repository.restore(view.row),
                    done: view.loserIsDeletion
                        ? '거래를 다시 지웠습니다'
                        : '밀려난 값으로 되살렸습니다',
                    failed:
                        '되살리지 못했습니다. 이 거래가 쓰던 자산이 지워졌으면 '
                        '되살릴 수 없습니다.',
                  ),
            onDelete: () => _run(
              view,
              () => repository.deleteConflict(view.row.seq),
              done: '기록을 지웠습니다',
              failed: '기록을 지우지 못했습니다. 다시 시도해 주십시오.',
            ),
          ),
          const SizedBox(height: 12),
        ],
      ];
    }

    return SubScreen(
      title: '동기화 충돌',
      children: [
        const HintText(
          '두 기기가 같은 항목을 고치면 나중에 고친 쪽이 남습니다. 밀려난 쪽의 값은 여기에 '
          '30일 동안(최근 200건까지) 남습니다. 거래는 밀려난 값으로 되살릴 수 있습니다.',
        ),
        const SizedBox(height: 12),
        ...body,
      ],
    );
  }
}

/// 자산 · 분류의 ID를 이름으로 바꾸는 표.
class _Names {
  const _Names({required this.accounts, required this.categories});

  final Map<String, String> accounts;
  final Map<String, String> categories;
}

class _ConflictCard extends StatelessWidget {
  const _ConflictCard({
    super.key,
    required this.view,
    required this.names,
    required this.busy,
    required this.onRestore,
    required this.onDelete,
  });

  final ConflictView view;
  final _Names names;
  final bool busy;
  final VoidCallback? onRestore;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final row = view.row;
    final table = row.targetTable;
    final at = row.detectedAt.toLocal();
    final when =
        '${monthDay(LocalDate.fromDateTime(at))} ${formatTimeOfDay(at)}';
    final summary = _summary(view, names);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              summary == null
                  ? _tableLabel(table)
                  : '${_tableLabel(table)} · $summary',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 2),
            HintText(
              '${view.localLost ? '이 기기에서 고친 것이' : '다른 기기에서 고친 것이'} '
              '밀려났습니다 · $when',
            ),
            const SizedBox(height: 8),
            if (view.loserIsDeletion)
              Text(
                view.current == null
                    ? '밀려난 쪽은 이 항목을 지운 것이었습니다.'
                    : '밀려난 쪽은 이 항목을 지운 것이었습니다. 지금은 남아 있습니다.',
              )
            else if (view.loser.isEmpty)
              const Text('밀려난 값을 읽지 못했습니다.')
            else if (view.changed.isEmpty)
              const Text('밀려난 값이 지금 값과 같습니다.')
            else ...[
              if (view.current == null)
                const Padding(
                  padding: EdgeInsets.only(bottom: 4),
                  child: Text('지금 이 항목은 지워져 있습니다. 밀려난 값은 아래와 같습니다.'),
                ),
              for (final field in view.changed)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: '${_columnLabel(field.column)}  ',
                          style: TextStyle(color: scheme.onSurfaceVariant),
                        ),
                        TextSpan(
                          text: _valueLabel(field.column, field.loser, names),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        if (view.current != null)
                          TextSpan(
                            text:
                                '  (지금: '
                                '${_valueLabel(field.column, field.current, names)})',
                            style: TextStyle(color: scheme.onSurfaceVariant),
                          ),
                      ],
                    ),
                  ),
                ),
            ],
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: Wrap(
                spacing: 8,
                children: [
                  TextButton(
                    key: ValueKey('conflict-delete-${row.seq}'),
                    onPressed: busy ? null : onDelete,
                    child: const Text('지우기'),
                  ),
                  if (onRestore != null)
                    FilledButton.tonal(
                      key: ValueKey('conflict-restore-${row.seq}'),
                      onPressed: busy ? null : onRestore,
                      child: Text(view.loserIsDeletion ? '다시 지우기' : '되살리기'),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 거래면 '11월 16일 · 김밥천국 · 8,000원' 같은 한 줄. 다른 표는 이름이 있으면 이름.
String? _summary(ConflictView view, _Names names) {
  final source = view.loser.isNotEmpty ? view.loser : view.current;
  if (source == null) return null;
  if (view.row.targetTable != 'transactions') {
    final name = source['name'] ?? source['pattern'] ?? source['month'];
    return name is String && name.isNotEmpty ? name : null;
  }
  final date = LocalDate.tryParse('${source['occurred_on']}');
  final type = source['type'];
  final party = switch (type) {
    'income' => source['sender'],
    'expense' => source['receiver'],
    _ => null,
  };
  final amount = source['amount'];
  return [
    if (date != null) monthDay(date),
    if (party is String && party.isNotEmpty)
      party
    else if (source['memo'] case final String memo when memo.isNotEmpty)
      memo,
    if (amount is num) won(amount.toInt()),
  ].join(' · ');
}

String _tableLabel(String table) =>
    const {
      'transactions': '거래',
      'accounts': '자산',
      'categories': '분류',
      'budgets': '예산',
      'recurring_rules': '반복 거래',
      'category_rules': '분류 규칙',
      'monthly_summaries': '월별 요약',
      'profiles': '가계부 설정',
      'ledgers': '가계부',
    }[table] ??
    '항목';

String _columnLabel(String column) =>
    const {
      'type': '종류',
      'occurred_on': '날짜',
      'occurred_time': '시각',
      'amount': '금액',
      'currency': '통화',
      'original_amount': '원래 금액',
      'account_id': '자산',
      'to_account_id': '받는 자산',
      'sender': '보낸 쪽',
      'receiver': '받는 쪽',
      'category_id': '분류',
      'memo': '메모',
      'tags': '꼬리표',
      'installment_months': '할부',
      'balance_after': '거래 뒤 잔액',
      'canceled_at': '취소',
      'source': '입력 경로',
      'ai_model': 'AI 모델',
      'status': '확인 상태',
      'name': '이름',
      'kind': '종류',
      'institution': '금융사',
      'match_hints': '식별 문구',
      'opening_balance': '시작 잔액',
      'billing_day': '결제일',
      'payment_account_id': '결제 계좌',
      'sort_order': '순서',
      'parent_id': '대분류',
      'icon': '아이콘',
      'month': '달',
      'month_start_day': '월 시작일',
      'display_name': '이름',
      'default_account_id': '기본 자산',
      'template': '거래의 틀',
      'frequency': '주기',
      'interval_count': '간격',
      'next_run_on': '다음 날짜',
      'end_on': '끝나는 날',
      'auto_post': '자동 등록',
      'is_active': '켜짐',
      'pattern': '상대방',
      'hit_count': '쓴 횟수',
      'stats': '집계',
      'narrative': '총평',
      'data_hash': '집계 확인값',
      'owner_id': '주인',
    }[column] ??
    column;

String _valueLabel(String column, Object? value, _Names names) {
  if (value == null) return column == 'canceled_at' ? '취소 안 함' : '없음';
  switch (column) {
    case 'amount' || 'opening_balance' || 'balance_after':
      if (value is num) return won(value.toInt());
    case 'account_id' || 'to_account_id' || 'payment_account_id':
    case 'default_account_id':
      return names.accounts[value] ?? '(지워진 자산)';
    case 'category_id' || 'parent_id':
      return names.categories[value] ?? '(지워진 분류)';
    case 'canceled_at':
      return '취소함';
    case 'installment_months':
      return '$value개월';
    case 'billing_day' || 'month_start_day':
      return '$value일';
    case 'type':
      return const {'expense': '지출', 'income': '수입', 'transfer': '이체'}[value] ??
          '$value';
    case 'kind':
      for (final kind in AccountKind.values) {
        if (kind.code == value) return kind.label;
      }
      return const {'expense': '지출', 'income': '수입'}[value] ?? '$value';
    case 'status':
      return value == TxStatus.needsReview.code ? '확인 필요' : '확인함';
    case 'frequency':
      return const {'weekly': '매주', 'monthly': '매달', 'yearly': '매년'}[value] ??
          '$value';
  }
  return switch (value) {
    true => '예',
    false => '아니요',
    final List<Object?> list => list.isEmpty ? '없음' : list.join(', '),
    // 묶음 값(반복 거래의 틀, 집계)은 칸마다 풀어 보이지 않는다.
    Map<Object?, Object?>() => '(내용이 다릅니다)',
    _ => '$value',
  };
}
