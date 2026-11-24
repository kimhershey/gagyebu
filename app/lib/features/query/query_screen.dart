import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../ai/query/ledger_query.dart';
import '../../app/providers.dart';
import '../../app/theme/tokens.dart';
import '../../core/formatters.dart';
import '../../core/local_date.dart';
import '../../data/repositories/ledger_repository.dart';
import '../../data/repositories/query_repository.dart';
import '../../domain/enums.dart';
import '../common/widgets.dart';
import 'query_provider.dart';

/// 조회에서 권하는 물음. 조건을 읽지 못했을 때 보여 준다.
const queryExamples = <String>[
  '지난달 식비 얼마야?',
  '이번 달 카페 몇 번 갔어?',
  '어제 뭐 샀지?',
  '올해 수입 합계',
];

/// 조회 화면. `docs/SPEC.md` 7.15.
///
/// 문장, 읽은 조건, 답을 차례로 보여 준다. 조건을 함께 보여 주는 까닭은 문장을 잘못
/// 읽었을 때 사용자가 숫자를 믿기 전에 알아챌 수 있게 하려는 것이다.
class QueryScreen extends ConsumerWidget {
  const QueryScreen({super.key, required this.question});

  /// 사용자가 적은 물음.
  final String question;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final asked = question.trim();
    final outcome = ref.watch(queryOutcomeProvider(asked));
    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              Row(
                children: [
                  IconButton(
                    key: const ValueKey('query-back'),
                    tooltip: '뒤로',
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () =>
                        context.canPop() ? context.pop() : context.go('/'),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text('조회', style: theme.textTheme.headlineSmall),
                  ),
                ],
              ),
              if (asked.isNotEmpty) ...[
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    asked,
                    key: const ValueKey('query-question'),
                    style: theme.textTheme.titleMedium,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              switch (outcome) {
                AsyncData(value: QueryAnswered(:final result)) => _Answer(
                  result: result,
                ),
                AsyncData(value: QueryUnreadable()) => _Unreadable(
                  empty: asked.isEmpty,
                ),
                AsyncError() => EmptyState(
                  icon: Icons.error_outline,
                  message: '조회하지 못했습니다.\n잠시 뒤에 다시 해 주세요.',
                  action: OutlinedButton(
                    key: const ValueKey('query-retry'),
                    onPressed: () =>
                        ref.invalidate(queryOutcomeProvider(asked)),
                    child: const Text('다시 하기'),
                  ),
                ),
                _ => const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(
                    child: CircularProgressIndicator(
                      key: ValueKey('query-loading'),
                    ),
                  ),
                ),
              },
            ],
          ),
        ),
      ),
    );
  }
}

/// 조건을 읽지 못했을 때: 그렇게 말하고 예시를 보여 준다.
class _Unreadable extends StatelessWidget {
  const _Unreadable({required this.empty});

  /// 물음이 비어 있었는지.
  final bool empty;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SectionCard(
      key: const ValueKey('query-unreadable'),
      title: empty ? '물음이 없습니다' : '조건을 읽지 못했습니다',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '기간, 분류, 가게 이름을 넣어 아래처럼 물어볼 수 있습니다.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final example in queryExamples)
                _Pill(
                  key: ValueKey('query-example-$example'),
                  label: example,
                  // 예시는 이 화면을 바꿔 끼운다. 뒤로 가면 조회 전의 화면으로 돌아간다.
                  onTap: () => context.pushReplacement(
                    Uri(
                      path: '/query',
                      queryParameters: {'q': example},
                    ).toString(),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 읽은 조건과 답.
class _Answer extends ConsumerWidget {
  const _Answer({required this.result});

  final QueryResult result;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final query = result.query;
    final range = query.range;
    final listed = query.aggregation == QueryAggregation.list;
    // 목록이 아니어도 무엇을 센 것인지 보이게 최근 몇 건을 함께 보여 준다.
    final rows = listed ? result.rows : result.rows.take(5).toList();
    final spansYears = range.from.year != range.last.year;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          key: const ValueKey('query-conditions'),
          spacing: 8,
          runSpacing: 8,
          children: [
            _Pill(
              key: const ValueKey('query-chip-period'),
              icon: Icons.event_outlined,
              label: '${query.period.label} · ${_rangeLabel(range)}',
            ),
            if (query.category != null)
              _Pill(
                key: const ValueKey('query-chip-category'),
                icon: Icons.label_outline,
                label: query.category!,
              ),
            if (query.party != null)
              _Pill(
                key: const ValueKey('query-chip-party'),
                icon: Icons.storefront_outlined,
                label: '‘${query.party}’ 포함',
              ),
            if (query.type != null)
              _Pill(
                key: const ValueKey('query-chip-type'),
                icon: Icons.swap_vert,
                label: queryTypeLabel(query.type!),
              ),
            _Pill(
              key: const ValueKey('query-chip-agg'),
              icon: Icons.functions,
              label: query.perDay ? '하루 평균' : query.aggregation.label,
            ),
          ],
        ),
        if (query.periodAssumed || query.aiModel != null) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              [
                if (query.periodAssumed) '기간을 적지 않아 이번 달로 봤습니다.',
                if (query.aiModel != null)
                  '기기 안의 모델이 조건을 읽었습니다. 조건이 맞는지 확인해 주세요.',
              ].join(' '),
              key: const ValueKey('query-note'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
        const SizedBox(height: 12),
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: result.isEmpty
                ? Text(
                    '조건에 맞는 내역이 없습니다.',
                    key: const ValueKey('query-empty'),
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  )
                : _Headline(result: result),
          ),
        ),
        if (rows.isNotEmpty) ...[
          const SizedBox(height: 12),
          SectionCard(
            title: listed ? '내역' : '최근 내역',
            child: Column(
              key: const ValueKey('query-rows'),
              children: [
                for (final view in rows) _Row(view: view, withYear: spansYears),
                if (listed && result.hiddenCount > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      '나머지 ${formatNumber(result.hiddenCount)}건은 내역에서 볼 수 있습니다.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.tonalIcon(
            key: const ValueKey('query-open-transactions'),
            icon: const Icon(Icons.receipt_long_outlined, size: 18),
            label: const Text('내역에서 보기'),
            onPressed: () {
              // 내역은 한 달씩 본다. 조회한 기간의 마지막 달(오늘을 넘지 않게)을 띄우고,
              // 상대방을 물었으면 그 말로 찾아 둔다.
              final today = ref.read(todayProvider);
              final target = range.last > today ? today : range.last;
              ref.read(selectedPeriodProvider.notifier).show(target);
              ref.read(searchQueryProvider.notifier).set(query.party ?? '');
              context.go('/transactions');
            },
          ),
        ),
      ],
    );
  }
}

/// 답의 큰 숫자와 그 밑의 한 줄.
class _Headline extends StatelessWidget {
  const _Headline({required this.result});

  final QueryResult result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final query = result.query;
    final type = query.type;
    final count = '${formatNumber(result.count)}건';
    // 종류를 가리지 않은 조회의 합은 수입과 지출이 섞여 뜻이 없다. 건수만 보인다.
    final total = type == null ? null : _signed(type, result.total);

    final String caption;
    final String big;
    final String? detail;
    var amount = true;
    switch (query.aggregation) {
      case QueryAggregation.sum when total != null:
        caption = '${queryTypeLabel(type!)} 합계';
        big = total;
        detail = count;
      case QueryAggregation.average when type != null:
        caption = query.perDay
            ? '하루 평균 ${queryTypeLabel(type)}'
            : '건당 평균 ${queryTypeLabel(type)}';
        big = _signed(type, result.average);
        detail = query.perDay
            ? '합계 $total · ${formatNumber(result.averageDays)}일 기준'
            : '합계 $total · $count';
      default:
        caption = '건수';
        big = count;
        detail = total == null ? null : '합계 $total';
        amount = false;
    }

    final color = !amount
        ? theme.colorScheme.onSurface
        : switch (type) {
            TxType.expense => tokens.expense,
            TxType.income => tokens.income,
            _ => tokens.transfer,
          };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          caption,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        // 글자를 키우거나 금액이 길어도 넘치지 않게 칸에 맞춰 줄인다.
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            big,
            key: const ValueKey('query-answer'),
            maxLines: 1,
            style: tokens.amountStyle(
              theme.textTheme.headlineMedium?.copyWith(
                fontSize: tokens.bigAmountSize,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ),
        if (detail != null) ...[
          const SizedBox(height: 4),
          Text(
            detail,
            key: const ValueKey('query-answer-detail'),
            style: tokens.amountStyle(
              theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// 거래 한 줄: 제목과 금액, 그 밑에 날짜와 분류.
class _Row extends ConsumerWidget {
  const _Row({required this.view, required this.withYear});

  final TransactionView view;

  /// 기간이 해를 넘으면 날짜에 연도를 붙인다.
  final bool withYear;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final row = view.row;
    final date = withYear
        ? row.occurredOn.toString()
        : monthDay(row.occurredOn);
    final color = switch (row.type) {
      TxType.expense => tokens.expense,
      TxType.income => tokens.income,
      TxType.transfer => tokens.transfer,
    };
    return InkWell(
      borderRadius: BorderRadius.circular(tokens.radius),
      onTap: () {
        // 내역 화면이 그 거래의 달을 보고 있어야 편집 칸이 열린다.
        ref.read(selectedPeriodProvider.notifier).show(row.occurredOn);
        context.go('/transactions?id=${row.id}');
      },
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: tokens.rowHeight),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          child: LayoutBuilder(
            builder: (context, constraints) => Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        view.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        [date, ?view.categoryName].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: constraints.maxWidth * 0.5,
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      _signed(row.type, row.amount),
                      style: tokens.amountStyle(
                        theme.textTheme.bodyMedium?.copyWith(color: color),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 조건이나 예시를 담는 둥근 칸. 글이 길면 줄을 바꾼다(Chip은 한 줄이라 좁은 화면과
/// 큰 글자에서 넘친다).
class _Pill extends StatelessWidget {
  const _Pill({super.key, required this.label, this.icon, this.onTap});

  final String label;
  final IconData? icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final radius = BorderRadius.circular(tokens.radius);
    final content = Padding(
      // 누를 수 있는 칸은 터치 영역 48dp를 채운다.
      padding: EdgeInsets.symmetric(
        horizontal: 12,
        vertical: onTap == null ? 6 : 12,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 6),
          ],
          Flexible(child: Text(label, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
    return Material(
      color: onTap == null
          ? theme.colorScheme.surfaceContainerHighest
          : tokens.accentSoft,
      borderRadius: radius,
      child: onTap == null
          ? content
          : InkWell(borderRadius: radius, onTap: onTap, child: content),
    );
  }
}

/// 수입은 +, 지출은 −를 붙인 금액. 이체에는 부호가 없다.
String _signed(TxType type, int amount) => switch (type) {
  TxType.expense => signedWon(-amount),
  TxType.income => signedWon(amount),
  TxType.transfer => won(amount),
};

String _rangeLabel(DateRange range) {
  String day(LocalDate d) => range.from.year == range.last.year
      ? monthDay(d)
      : '${d.year}년 ${monthDay(d)}';
  if (range.days == 1) return day(range.from);
  return '${day(range.from)} – ${day(range.last)}';
}
