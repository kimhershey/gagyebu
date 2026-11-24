/// 홈과 통계가 함께 쓰는 조각: 분류의 자리(색 · 아이콘), 분류 한 줄, 불러오는 중 · 오류.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/providers.dart';
import '../../app/theme/tokens.dart';
import '../../core/formatters.dart';
import '../../data/db/database.dart';
import 'category_visual.dart';
import 'widgets.dart';

/// 분류 하나의 자리와 아이콘. 색은 테마에서 자리로 읽는다([color]).
@immutable
class CategoryVisual {
  const CategoryVisual({required this.index, required this.icon});

  /// 같은 종류(지출 · 수입)의 분류를 `sort_order`로 줄 세웠을 때의 자리(0부터).
  final int index;
  final IconData icon;

  Color color(AppTokens tokens) => categoryColor(tokens, index);
}

/// 분류 ID → 자리와 아이콘(`docs/SPEC.md` 6.1).
///
/// 색은 분류를 따라간다. 금액 순위가 바뀌어도 같은 분류는 같은 색이다.
Map<String, CategoryVisual> categoryVisualsOf(
  Iterable<CategoryRow> categories,
) {
  final result = <String, CategoryVisual>{};
  final kinds = {for (final c in categories) c.kind};
  for (final kind in kinds) {
    // 순서가 같은 분류는 ID로 가른다. ID는 만든 때의 순서라 기기마다 같다.
    final sorted = categories.where((c) => c.kind == kind).toList()
      ..sort((a, b) {
        final byOrder = a.sortOrder.compareTo(b.sortOrder);
        return byOrder != 0 ? byOrder : a.id.compareTo(b.id);
      });
    for (var i = 0; i < sorted.length; i++) {
      result[sorted[i].id] = CategoryVisual(
        index: i,
        icon: categoryIcon(sorted[i].name, sorted[i].icon),
      );
    }
  }
  return result;
}

/// 지금 가계부의 분류 ID → 자리와 아이콘. 분류를 아직 못 읽었으면 비어 있다.
final categoryVisualsProvider = Provider<Map<String, CategoryVisual>>(
  (ref) => categoryVisualsOf(ref.watch(categoriesProvider).value ?? const []),
);

/// 분류의 아이콘을 그 분류의 색으로 그린 동그란 표시. 분류가 없으면 회색 꼬리표다.
class CategoryBadge extends StatelessWidget {
  const CategoryBadge({
    super.key,
    this.visual,
    this.icon,
    this.color,
    this.size = 28,
  });

  /// 분류가 없는 거래면 null.
  final CategoryVisual? visual;

  /// 분류가 아닌 것(이체 따위)을 그릴 때 [visual] 대신 주는 아이콘과 색.
  final IconData? icon;
  final Color? color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final tint =
        color ??
        visual?.color(context.tokens) ??
        Theme.of(context).colorScheme.outline;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.16),
        shape: BoxShape.circle,
      ),
      child: Icon(
        icon ?? visual?.icon ?? Icons.label_outline,
        size: size * 0.58,
        color: tint,
      ),
    );
  }
}

/// 분류 이름, 비중, 금액과 비중 막대를 한 줄로.
///
/// 막대만으로는 값을 읽을 수 없는 사람을 위해 줄 전체를 "식비 20,000원, 27%"로 읽어 준다.
class CategoryBarRow extends StatelessWidget {
  const CategoryBarRow({
    super.key,
    required this.name,
    required this.amount,
    required this.ratio,
    this.visual,
    this.showBadge = true,
    this.onTap,
  });

  final String name;
  final int amount;

  /// 0–1
  final double ratio;

  /// 분류의 색과 아이콘. 분류가 없는 줄이면 null.
  final CategoryVisual? visual;

  /// 아이콘 표시를 그릴지.
  final bool showBadge;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final color = visual?.color(tokens) ?? theme.colorScheme.outline;

    final row = LayoutBuilder(
      builder: (context, constraints) => Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (showBadge) ...[
            CategoryBadge(visual: visual),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // 글자를 키워도 금액이 이름을 다 밀어내지 않게 너비의 절반 남짓까지만
                    // 주고, 넘치면 줄여 그린다.
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: constraints.maxWidth * 0.55,
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              percent(ratio),
                              style: tokens.amountStyle(
                                theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              won(amount),
                              style: tokens.amountStyle(
                                theme.textTheme.bodyMedium,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                RatioBar(ratio: ratio, color: color),
              ],
            ),
          ),
        ],
      ),
    );

    final labelled = Semantics(
      label: '$name ${won(amount)}, ${percent(ratio)}',
      button: onTap != null,
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: row,
      ),
    );
    if (onTap == null) return labelled;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(
        tokens.radius < 12 ? tokens.radius : 12,
      ),
      // 누름 영역은 48dp를 지킨다.
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Center(child: labelled),
      ),
    );
  }
}

/// 비동기 값의 불러오는 중 · 오류 · 내용을 그린다.
///
/// `AsyncBody`와 달리 예외의 문구를 화면에 보이지 않는다. [what]을 불러오지 못했다고만
/// 알리고 다시 해 볼 단추를 준다.
class LoadBody<T> extends StatelessWidget {
  const LoadBody({
    super.key,
    required this.value,
    required this.builder,
    required this.what,
    this.onRetry,
  });

  final AsyncValue<T> value;
  final Widget Function(T data) builder;

  /// 불러오는 것. '집계를'처럼 조사를 붙여 준다("집계를 불러오지 못했습니다").
  final String what;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    // 다시 읽는 동안에는 앞의 값이나 오류가 남아 있다. 다시 읽기가 끝나 오류로 굳었을 때만
    // 오류를 보이고, 그 밖에는 가진 값을 그린다.
    if (value.hasValue && (!value.hasError || value.isLoading)) {
      return builder(value.value as T);
    }
    if (value.hasError && !value.isLoading) {
      return EmptyState(
        icon: Icons.error_outline,
        message: '$what 불러오지 못했습니다.\n잠시 뒤에 다시 시도해 주세요.',
        action: onRetry == null
            ? null
            : OutlinedButton(onPressed: onRetry, child: const Text('다시 시도')),
      );
    }
    return const Padding(
      padding: EdgeInsets.all(24),
      child: Center(child: CircularProgressIndicator()),
    );
  }
}
