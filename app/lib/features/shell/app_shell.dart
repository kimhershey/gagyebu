import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/providers.dart';
import '../../core/breakpoints.dart';
import '../input/input_panel.dart';

class _Destination {
  const _Destination(this.label, this.icon, this.selectedIcon);

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

const _destinations = [
  _Destination('홈', Icons.home_outlined, Icons.home),
  _Destination('내역', Icons.receipt_long_outlined, Icons.receipt_long),
  _Destination('통계', Icons.pie_chart_outline, Icons.pie_chart),
  _Destination('설정', Icons.settings_outlined, Icons.settings),
];

/// 창 너비에 따라 메뉴의 자리를 바꾸는 바깥 틀.
///
/// - 좁음: 하단 탭(가운데에 입력 단추)
/// - 중간: 옆 메뉴(레일)
/// - 넓음: 이름이 보이는 왼쪽 메뉴
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  void _select(int index) => navigationShell.goBranch(
    index,
    // 지금 탭을 다시 누르면 그 탭의 첫 화면으로 돌아간다.
    initialLocation: index == navigationShell.currentIndex,
  );

  @override
  Widget build(BuildContext context) {
    final size = WindowSize.of(context);
    final index = navigationShell.currentIndex;

    switch (size) {
      case WindowSize.compact:
        // 입력 단추를 하단 막대 가운데에 둔다. 떠 있는 단추는 목록의 금액을 가린다.
        const inputSlot = 2;
        return Scaffold(
          body: navigationShell,
          bottomNavigationBar: NavigationBar(
            key: const ValueKey('nav-bottom'),
            selectedIndex: index >= inputSlot ? index + 1 : index,
            onDestinationSelected: (i) {
              if (i == inputSlot) {
                openInput(context);
              } else {
                _select(i > inputSlot ? i - 1 : i);
              }
            },
            destinations: [
              for (var i = 0; i < _destinations.length; i++) ...[
                if (i == inputSlot)
                  NavigationDestination(
                    icon: Icon(
                      Icons.add_circle,
                      key: const ValueKey('input-fab'),
                      size: 30,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    label: '입력',
                  ),
                NavigationDestination(
                  icon: Icon(_destinations[i].icon),
                  selectedIcon: Icon(_destinations[i].selectedIcon),
                  label: _destinations[i].label,
                ),
              ],
            ],
          ),
        );
      case WindowSize.medium:
        return Scaffold(
          body: SafeArea(
            child: Row(
              children: [
                NavigationRail(
                  key: const ValueKey('nav-rail'),
                  selectedIndex: index,
                  onDestinationSelected: _select,
                  labelType: NavigationRailLabelType.all,
                  leading: Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 12),
                    child: FloatingActionButton(
                      key: const ValueKey('input-fab'),
                      tooltip: '입력',
                      elevation: 0,
                      onPressed: () => openInput(context),
                      child: const Icon(Icons.add),
                    ),
                  ),
                  destinations: [
                    for (final d in _destinations)
                      NavigationRailDestination(
                        icon: Icon(d.icon),
                        selectedIcon: Icon(d.selectedIcon),
                        label: Text(d.label),
                      ),
                  ],
                ),
                const VerticalDivider(width: 1),
                Expanded(child: navigationShell),
              ],
            ),
          ),
        );
      case WindowSize.expanded:
        return Scaffold(
          body: SafeArea(
            child: Row(
              children: [
                SizedBox(
                  width: 232,
                  child: _SideMenu(index: index, onSelect: _select),
                ),
                const VerticalDivider(width: 1),
                Expanded(child: navigationShell),
              ],
            ),
          ),
        );
    }
  }
}

class _SideMenu extends ConsumerWidget {
  const _SideMenu({required this.index, required this.onSelect});

  final int index;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final pending = ref.watch(pendingChangesProvider).value ?? 0;
    return Column(
      key: const ValueKey('nav-side'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Text('가계부', style: theme.textTheme.titleLarge),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: FilledButton.icon(
            key: const ValueKey('input-fab'),
            onPressed: () => openInput(context),
            icon: const Icon(Icons.add),
            label: const Text('입력'),
          ),
        ),
        const SizedBox(height: 12),
        for (var i = 0; i < _destinations.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            child: ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              selected: i == index,
              selectedTileColor: theme.colorScheme.secondaryContainer,
              selectedColor: theme.colorScheme.onSecondaryContainer,
              leading: Icon(
                i == index
                    ? _destinations[i].selectedIcon
                    : _destinations[i].icon,
              ),
              title: Text(_destinations[i].label),
              onTap: () => onSelect(i),
            ),
          ),
        const Spacer(),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            pending == 0 ? '이 기기에 저장됨' : '이 기기에 저장됨 · 보낼 변경 $pending건',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

/// 입력 화면을 연다. 넓은 창에서는 대화상자로, 그 밖에서는 전체 화면으로 연다.
Future<void> openInput(BuildContext context) async {
  if (WindowSize.of(context).isExpanded) {
    await showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760, maxHeight: 720),
          child: InputPanel(onClose: () => Navigator.of(context).pop()),
        ),
      ),
    );
  } else {
    await context.push('/input');
  }
}
