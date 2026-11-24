import 'package:material_ui/material_ui.dart';

import '../../core/formatters.dart';
import '../../data/repositories/ledger_repository.dart';
import '../../domain/enums.dart';
import '../../app/theme/tokens.dart';

/// 금액을 종류에 맞는 색과 부호로 그린다.
class AmountText extends StatelessWidget {
  const AmountText(this.view, {super.key, this.style});

  final TransactionView view;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = context.tokens;
    final row = view.row;
    final (text, color) = switch (row.type) {
      TxType.income => ('+${won(row.amount)}', tokens.income),
      TxType.expense => ('-${won(row.amount)}', tokens.expense),
      TxType.transfer => (won(row.amount), tokens.transfer),
    };
    final base = style ?? Theme.of(context).textTheme.bodyLarge;
    return Text(
      text,
      style: tokens
          .amountStyle(base)
          .copyWith(
            color: view.isCanceled ? scheme.outline : color,
            fontWeight: FontWeight.w600,
            decoration: view.isCanceled ? TextDecoration.lineThrough : null,
          ),
    );
  }
}

/// 분류 · 자산 · 시각을 이어 붙인 한 줄 설명.
String transactionSubtitle(TransactionView view) {
  final row = view.row;
  final parts = <String>[
    if (view.isCanceled) '취소됨',
    if (row.type == TxType.transfer) '이체' else view.categoryName ?? '분류 없음',
    if (row.type != TxType.transfer) view.accountName,
    if (row.occurredTime != null) row.occurredTime!,
    if (row.installmentMonths != null) '${row.installmentMonths}개월 할부',
  ];
  return parts.join(' · ');
}

/// 목록의 거래 한 줄.
class TransactionTile extends StatelessWidget {
  const TransactionTile({
    super.key,
    required this.view,
    this.onTap,
    this.selected = false,
    this.showDate = false,
  });

  final TransactionView view;
  final VoidCallback? onTap;
  final bool selected;

  /// 날짜별로 묶지 않은 목록에서는 날짜를 함께 보여 준다.
  final bool showDate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtitle = transactionSubtitle(view);
    return ListTile(
      selected: selected,
      selectedTileColor: theme.colorScheme.secondaryContainer.withValues(
        alpha: 0.5,
      ),
      onTap: onTap,
      title: Text(view.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        showDate ? '${monthDay(view.row.occurredOn)} · $subtitle' : subtitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: AmountText(view),
    );
  }
}
