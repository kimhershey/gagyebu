import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/providers.dart';
import '../../core/formatters.dart';

/// 달을 앞뒤로 넘기는 머리줄.
class MonthSwitcher extends ConsumerWidget {
  const MonthSwitcher({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(selectedPeriodProvider);
    final range = periodRangeLabel(period);
    final theme = Theme.of(context);
    return Row(
      children: [
        IconButton(
          tooltip: '이전 달',
          onPressed: () => ref.read(selectedPeriodProvider.notifier).previous(),
          icon: const Icon(Icons.chevron_left),
        ),
        Flexible(
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => ref.read(selectedPeriodProvider.notifier).showToday(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 좁은 칸에서는 줄을 바꾸지 않고 글자를 줄여 한 줄에 둔다.
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      periodLabel(period),
                      maxLines: 1,
                      softWrap: false,
                      style: theme.textTheme.titleLarge,
                      key: const ValueKey('period-label'),
                    ),
                  ),
                  if (range != null)
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        range,
                        maxLines: 1,
                        softWrap: false,
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        IconButton(
          tooltip: '다음 달',
          onPressed: () => ref.read(selectedPeriodProvider.notifier).next(),
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }
}

/// 제목이 붙은 카드.
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.title,
    required this.child,
    this.trailing,
  });

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(title, style: theme.textTheme.titleMedium),
                ),
                ?trailing,
              ],
            ),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }
}

/// 내용이 없을 때의 안내.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: theme.colorScheme.outline),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (action != null) ...[const SizedBox(height: 12), action!],
          ],
        ),
      ),
    );
  }
}

/// 비율을 보여 주는 가로 막대.
class RatioBar extends StatelessWidget {
  const RatioBar({super.key, required this.ratio, this.color});

  /// 0–1
  final double ratio;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: LinearProgressIndicator(
        value: ratio.clamp(0, 1).toDouble(),
        minHeight: 8,
        color: color ?? scheme.primary,
        backgroundColor: scheme.surfaceContainerHighest,
      ),
    );
  }
}

/// 비동기 값의 로딩 · 오류 · 내용을 한곳에서 그린다.
class AsyncBody<T> extends StatelessWidget {
  const AsyncBody({super.key, required this.value, required this.builder});

  final AsyncValue<T> value;
  final Widget Function(T data) builder;

  @override
  Widget build(BuildContext context) {
    final data = value.value;
    if (data != null) return builder(data);
    if (value.hasError) {
      return EmptyState(
        icon: Icons.error_outline,
        message: '불러오지 못했습니다\n${value.error}',
      );
    }
    return const Padding(
      padding: EdgeInsets.all(24),
      child: Center(child: CircularProgressIndicator()),
    );
  }
}
