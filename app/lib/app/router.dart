import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../features/home/home_screen.dart';
import '../features/input/input_panel.dart';
import '../features/settings/settings_screen.dart';
import '../features/shell/app_shell.dart';
import '../features/stats/stats_screen.dart';
import '../features/transactions/transactions_screen.dart';

/// 화면과 주소의 대응.
///
/// 웹에서는 주소와 브라우저의 뒤로 가기가 화면과 맞게 움직인다.
/// 내역 화면의 선택과 새 거래는 쿼리로 나타낸다(`/transactions?id=…`, `?new=expense`).
/// 같은 화면이 창 너비에 따라 목록 + 상세 두 칸으로도, 한 칸씩으로도 그려지기 때문이다.
GoRouter createRouter({String initialLocation = '/'}) => GoRouter(
  initialLocation: initialLocation,
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) =>
          AppShell(navigationShell: navigationShell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/transactions',
              builder: (context, state) => TransactionsScreen(
                selectedId: state.uri.queryParameters['id'],
                newType: state.uri.queryParameters['new'],
              ),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/stats',
              builder: (context, state) => const StatsScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/settings',
              builder: (context, state) => const SettingsScreen(),
            ),
          ],
        ),
      ],
    ),
    GoRoute(
      path: '/input',
      builder: (context, state) => Scaffold(
        body: SafeArea(child: InputPanel(onClose: () => context.pop())),
      ),
    ),
  ],
);
