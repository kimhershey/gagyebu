import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/providers.dart';
import '../../app/theme/tokens.dart';
import '../../core/formatters.dart';
import '../../data/db/database.dart';
import '../../data/repositories/ledger_repository.dart';
import '../../domain/enums.dart';
import '../common/category_visual.dart';

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
      maxLines: 1,
      softWrap: false,
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

/// 확인이 더 필요한 거래인지.
bool needsReview(TransactionView view) =>
    view.row.status == TxStatus.needsReview;

/// 분류의 색과 아이콘을 정하는 데 필요한 것.
class CategoryVisual {
  const CategoryVisual({required this.index, required this.category});

  /// 그 종류의 분류를 `sort_order`로 늘어놓았을 때의 자리(0부터). 색을 고른다.
  final int index;
  final CategoryRow category;

  Color color(AppTokens tokens) => categoryColor(tokens, index);

  IconData get icon => categoryIcon(category.name, category.icon);
}

/// 분류 ID → 색과 아이콘.
final categoryVisualsProvider = Provider<Map<String, CategoryVisual>>((ref) {
  final categories =
      ref.watch(categoriesProvider).value ?? const <CategoryRow>[];
  return categoryVisualsOf(categories);
});

/// [categories]의 분류마다 자리를 매긴다. 자리는 종류(지출 · 수입)별로 따로 센다.
Map<String, CategoryVisual> categoryVisualsOf(List<CategoryRow> categories) {
  final visuals = <String, CategoryVisual>{};
  for (final kind in CategoryKind.values) {
    final sorted = [
      for (final c in categories)
        if (c.kind == kind) c,
    ];
    // 순서가 같은 분류의 자리가 기기마다 달라지지 않게 ID로 한 번 더 가른다.
    sorted.sort((a, b) {
      final order = a.sortOrder.compareTo(b.sortOrder);
      return order != 0 ? order : a.id.compareTo(b.id);
    });
    for (var i = 0; i < sorted.length; i++) {
      visuals[sorted[i].id] = CategoryVisual(index: i, category: sorted[i]);
    }
  }
  return visuals;
}

/// 분류의 색 점. 분류가 없으면 흐린 점을 찍는다.
class CategoryDot extends ConsumerWidget {
  const CategoryDot({super.key, required this.categoryId, this.size = 10});

  final String? categoryId;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visual = ref.watch(categoryVisualsProvider)[categoryId];
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color:
            visual?.color(context.tokens) ??
            Theme.of(context).colorScheme.outlineVariant,
      ),
    );
  }
}

/// 거래의 분류를 색 동그라미와 아이콘으로 그린다. 확인이 필요한 거래면 경고색 점을 얹는다.
class CategoryAvatar extends ConsumerWidget {
  const CategoryAvatar({super.key, required this.view, this.size = 36});

  final TransactionView view;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = context.tokens;
    final row = view.row;
    final visual = ref.watch(categoryVisualsProvider)[row.categoryId];
    final (icon, color) = switch (row.type) {
      TxType.transfer => (Icons.swap_horiz, tokens.transfer),
      _ when visual != null => (visual.icon, visual.color(tokens)),
      _ => (Icons.label_outline, scheme.outline),
    };
    final circle = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.14),
      ),
      child: Icon(icon, size: size * 0.5, color: color),
    );
    if (!needsReview(view)) return circle;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        circle,
        Positioned(
          top: -2,
          right: -2,
          child: Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: tokens.warn,
              border: Border.all(color: scheme.surface, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}

/// '확인 필요' 표시. 색만으로 알리지 않게 아이콘과 글자를 함께 둔다.
class NeedsReviewBadge extends StatelessWidget {
  const NeedsReviewBadge({super.key, this.iconOnly = false});

  /// 자리가 좁은 표에서는 아이콘만 두고 이름표로 읽어 준다.
  final bool iconOnly;

  static const label = '확인 필요';

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final icon = Icon(Icons.error_outline, size: 16, color: tokens.warn);
    if (iconOnly) {
      return Tooltip(
        message: label,
        child: Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: tokens.warnSoft,
            shape: BoxShape.circle,
          ),
          child: icon,
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: tokens.warnSoft,
        borderRadius: BorderRadius.circular(tokens.radius),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          icon,
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium
                  ?.copyWith(color: tokens.warn, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
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
    final tokens = context.tokens;
    final subtitle = transactionSubtitle(view);
    final review = needsReview(view);
    return LayoutBuilder(
      builder: (context, constraints) {
        // 금액이 길거나 글자를 키워도 제목이 설 자리를 남긴다.
        final amountWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth * 0.4
            : 160.0;
        return ListTile(
          selected: selected,
          selectedTileColor: theme.colorScheme.secondaryContainer.withValues(
            alpha: 0.5,
          ),
          onTap: onTap,
          leading: CategoryAvatar(view: view),
          title: Text(view.title, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text.rich(
            TextSpan(
              children: [
                if (review)
                  TextSpan(
                    text: '${NeedsReviewBadge.label} · ',
                    style: TextStyle(
                      color: tokens.warn,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                TextSpan(
                  text: showDate
                      ? '${monthDay(view.row.occurredOn)} · $subtitle'
                      : subtitle,
                ),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: amountWidth),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: AmountText(view),
            ),
          ),
        );
      },
    );
  }
}
