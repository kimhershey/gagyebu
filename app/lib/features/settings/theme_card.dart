import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/theme/theme_setting.dart';
import '../common/widgets.dart';

/// 설정의 '화면' 칸: 테마의 톤과 밝기를 고른다(`docs/SPEC.md` 6.1).
class ThemeCard extends ConsumerWidget {
  const ThemeCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(themeControllerProvider);
    final theme = Theme.of(context);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final setting = controller.value;
        return SectionCard(
          title: '화면',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('테마'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final tone in ThemeTone.values)
                    ChoiceChip(
                      key: ValueKey('theme-tone-${tone.name}'),
                      label: Text(tone.label),
                      tooltip: tone.description,
                      selected: setting.tone == tone,
                      onSelected: (_) => controller.setTone(tone),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                setting.tone.description,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              // 톤을 직접 골랐을 때만 밝기를 고른다. '시스템에 맞춤'은 밝기도 시스템을 따른다.
              if (setting.tone != ThemeTone.system) ...[
                const SizedBox(height: 12),
                const Text('밝기'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final brightness in ThemeBrightness.values)
                      ChoiceChip(
                        key: ValueKey('theme-brightness-${brightness.name}'),
                        label: Text(brightness.label),
                        selected: setting.brightness == brightness,
                        onSelected: (_) => controller.setBrightness(brightness),
                      ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
