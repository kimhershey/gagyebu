import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/background_jobs.dart';
import '../../app/providers.dart';
import '../../app/theme/tokens.dart';
import '../../core/breakpoints.dart';
import '../command/commands.dart';
import '../composer/composer_bar.dart';
import '../review/review_panel.dart';
import '../review/review_state.dart';

class _Destination {
  const _Destination(this.label, this.icon, this.selectedIcon, {this.path});

  final String label;
  final IconData icon;
  final IconData selectedIcon;

  /// 탭이 아닌 화면의 주소. 탭이면 null이다.
  final String? path;
}

/// 탭 네 개. 순서가 라우터의 갈래 순서와 같다.
const _tabs = [
  _Destination('홈', Icons.home_outlined, Icons.home),
  _Destination('내역', Icons.receipt_long_outlined, Icons.receipt_long),
  _Destination('통계', Icons.pie_chart_outline, Icons.pie_chart),
  _Destination('설정', Icons.settings_outlined, Icons.settings),
];

/// 넓은 창의 옆 메뉴에만 더 보이는 화면. 설정 탭에 속한다.
const _extras = [
  _Destination(
    '자산',
    Icons.account_balance_wallet_outlined,
    Icons.account_balance_wallet,
    path: '/accounts',
  ),
  _Destination(
    '예산',
    Icons.donut_large_outlined,
    Icons.donut_large,
    path: '/budget',
  ),
];

/// 검토함 칸의 너비.
const _reviewWidth = 400.0;

/// 이 너비부터 검토함을 내용 옆에 고정한다. 그보다 좁으면 내용 위에 겹친다.
const _reviewDockedMinWidth = 1200.0;

/// 창 너비에 따라 메뉴 · 입력창 · 검토함의 자리를 바꾸는 바깥 틀(`docs/SPEC.md` 6.2).
///
/// - 좁음: 하단 탭 네 개, 그 위에 입력창
/// - 중간: 옆 메뉴(레일), 내용 위에 입력창, 검토함은 오른쪽에서 나온다
/// - 넓음: 이름이 보이는 왼쪽 메뉴, 맨 위에 명령창, 검토함은 오른쪽 칸
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  void _select(int index) => navigationShell.goBranch(
    index,
    // 지금 탭을 다시 누르면 그 탭의 첫 화면으로 돌아간다.
    initialLocation: index == navigationShell.currentIndex,
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 화면이 떠 있는 동안 뒤에서 도는 일을 켜 둔다.
    ref.watch(backgroundJobsProvider);
    final reviewing = ref.watch(reviewActiveProvider);
    final size = WindowSize.of(context);
    final index = navigationShell.currentIndex;

    final Widget shell;
    switch (size) {
      case WindowSize.compact:
        // 좁은 창에서는 검토함을 전체 화면(/review)으로 연다.
        shell = Scaffold(
          body: Column(
            children: [
              Expanded(child: navigationShell),
              const Divider(height: 1),
              const ComposerBar(placement: ComposerPlacement.bottom),
            ],
          ),
          bottomNavigationBar: NavigationBar(
            key: const ValueKey('nav-bottom'),
            selectedIndex: index,
            onDestinationSelected: _select,
            destinations: [
              for (final d in _tabs)
                NavigationDestination(
                  icon: Icon(d.icon),
                  selectedIcon: Icon(d.selectedIcon),
                  label: d.label,
                ),
            ],
          ),
        );
      case WindowSize.medium:
        shell = Scaffold(
          body: SafeArea(
            child: Row(
              children: [
                NavigationRail(
                  key: const ValueKey('nav-rail'),
                  selectedIndex: index,
                  onDestinationSelected: _select,
                  labelType: NavigationRailLabelType.all,
                  destinations: [
                    for (final d in _tabs)
                      NavigationRailDestination(
                        icon: Icon(d.icon),
                        selectedIcon: Icon(d.selectedIcon),
                        label: Text(d.label),
                      ),
                  ],
                ),
                const VerticalDivider(width: 1),
                Expanded(
                  child: Column(
                    children: [
                      const ComposerBar(placement: ComposerPlacement.top),
                      const Divider(height: 1),
                      Expanded(
                        child: _WithReview(
                          reviewing: reviewing,
                          docked: false,
                          child: navigationShell,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      case WindowSize.expanded:
        final docked =
            MediaQuery.sizeOf(context).width >= _reviewDockedMinWidth;
        shell = Scaffold(
          body: SafeArea(
            child: Row(
              children: [
                SizedBox(
                  width: 232,
                  child: _SideMenu(index: index, onSelect: _select),
                ),
                const VerticalDivider(width: 1),
                Expanded(
                  child: Column(
                    children: [
                      const ComposerBar(placement: ComposerPlacement.command),
                      const Divider(height: 1),
                      Expanded(
                        child: _WithReview(
                          reviewing: reviewing,
                          docked: docked,
                          child: navigationShell,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
    }
    return AppShortcuts(child: shell);
  }
}

/// 검토 중이면 내용 옆(또는 위)에 검토함을 둔다.
class _WithReview extends StatelessWidget {
  const _WithReview({
    required this.reviewing,
    required this.docked,
    required this.child,
  });

  final bool reviewing;

  /// 내용 옆에 고정할지. 아니면 내용 위에 겹친다.
  final bool docked;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!reviewing) return child;
    const panel = SizedBox(
      key: ValueKey('review-panel'),
      width: _reviewWidth,
      child: ReviewPanel(),
    );
    if (docked) {
      return Row(
        children: [
          Expanded(child: child),
          const VerticalDivider(width: 1),
          panel,
        ],
      );
    }
    return Stack(
      children: [
        child,
        Positioned(
          top: 0,
          right: 0,
          bottom: 0,
          child: Material(
            elevation: 8,
            color: Theme.of(context).colorScheme.surface,
            child: panel,
          ),
        ),
      ],
    );
  }
}

class _SideMenu extends ConsumerWidget {
  const _SideMenu({required this.index, required this.onSelect});

  final int index;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final pending = ref.watch(pendingChangesProvider).value ?? 0;
    final path = GoRouterState.of(context).uri.path;
    final extra = _extras.where((d) => d.path == path).firstOrNull;

    Widget item(
      _Destination d, {
      required bool selected,
      VoidCallback? onTap,
    }) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: ListTile(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(tokens.radius),
        ),
        selected: selected,
        selectedTileColor: theme.colorScheme.secondaryContainer,
        selectedColor: theme.colorScheme.onSecondaryContainer,
        leading: Icon(selected ? d.selectedIcon : d.icon),
        title: Text(d.label),
        onTap: onTap,
      ),
    );

    // 홈 · 내역 · 통계 · (자산 · 예산) · 설정 순서로 놓는다.
    const settingsTab = 3;
    return Column(
      key: const ValueKey('nav-side'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Text('가계부', style: theme.textTheme.titleLarge),
        ),
        for (var i = 0; i < settingsTab; i++)
          item(
            _tabs[i],
            selected: extra == null && i == index,
            onTap: () => onSelect(i),
          ),
        for (final d in _extras)
          item(d, selected: d == extra, onTap: () => context.go(d.path!)),
        item(
          _tabs[settingsTab],
          selected: extra == null && index == settingsTab,
          onTap: () => onSelect(settingsTab),
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
