import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../features/accounts/accounts_screen.dart';
import '../features/auth/auth_screen.dart';
import '../features/auth/password_screens.dart';
import '../features/auth/welcome_screen.dart';
import '../features/budget/budget_screen.dart';
import '../features/categories/categories_screen.dart';
import '../features/history/history_screen.dart';
import '../features/home/home_screen.dart';
import '../features/image_input/image_input_screen.dart';
import '../features/input/input_panel.dart';
import '../features/lock/lock_screen.dart';
import '../features/models/models_screen.dart';
import '../features/query/query_screen.dart';
import '../features/recurring/recurring_screen.dart';
import '../features/review/review_panel.dart';
import '../features/settings/account_screen.dart';
import '../features/settings/conflicts_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/shell/app_shell.dart';
import '../features/stats/stats_screen.dart';
import '../features/transactions/transactions_screen.dart';
import '../features/transfer/data_screen.dart';

/// 화면과 주소의 대응.
///
/// 웹에서는 주소와 브라우저의 뒤로 가기가 화면과 맞게 움직인다.
/// 내역 화면의 선택과 새 거래는 쿼리로 나타낸다(`/transactions?id=…`, `?new=expense`).
/// 같은 화면이 창 너비에 따라 목록 + 상세 두 칸으로도, 한 칸씩으로도 그려지기 때문이다.
///
/// [welcomeGate]가 true인 동안(로그인하지 않은 동안)에는 로그인 안내 화면(`/welcome` 아래)
/// 으로만 갈 수 있고, false면 안내 화면에 머물 수 없다. [recoveryGate]가 true인 동안
/// (비밀번호를 다시 정하는 메일의 링크로 들어왔을 때)에는 새 비밀번호 화면에만 머문다.
GoRouter createRouter({
  String initialLocation = '/',
  ValueListenable<bool>? welcomeGate,
  ValueListenable<bool>? recoveryGate,
}) => GoRouter(
  initialLocation: initialLocation,
  refreshListenable: Listenable.merge([?welcomeGate, ?recoveryGate]),
  redirect: (context, state) {
    final location = state.matchedLocation;
    final recovering = recoveryGate?.value ?? false;
    if (recovering != (location == '/new-password')) {
      return recovering ? '/new-password' : '/';
    }
    if (recovering) return null;
    final gated = welcomeGate?.value ?? false;
    final atWelcome = location.startsWith('/welcome');
    if (gated != atWelcome) return gated ? '/welcome' : '/';
    return null;
  },
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
              routes: [
                GoRoute(
                  path: 'account',
                  builder: (context, state) => const AccountSettingsScreen(),
                ),
                GoRoute(
                  path: 'data',
                  builder: (context, state) => const DataScreen(),
                ),
                GoRoute(
                  path: 'lock',
                  builder: (context, state) => const LockSettingsScreen(),
                ),
                GoRoute(
                  path: 'models',
                  builder: (context, state) => const ModelsScreen(),
                ),
                GoRoute(
                  path: 'conflicts',
                  builder: (context, state) => const ConflictsScreen(),
                ),
              ],
            ),
            // 탭이 아닌 화면은 설정 탭에 속한다.
            GoRoute(
              path: '/accounts',
              builder: (context, state) => const AccountsScreen(),
            ),
            GoRoute(
              path: '/categories',
              builder: (context, state) => const CategoriesScreen(),
            ),
            GoRoute(
              path: '/budget',
              builder: (context, state) => const BudgetScreen(),
            ),
            GoRoute(
              path: '/recurring',
              builder: (context, state) => const RecurringScreen(),
            ),
            GoRoute(
              path: '/history',
              builder: (context, state) => const HistoryScreen(),
            ),
          ],
        ),
      ],
    ),
    GoRoute(path: '/review', builder: (context, state) => const ReviewScreen()),
    GoRoute(
      path: '/query',
      builder: (context, state) => Scaffold(
        body: QueryScreen(question: state.uri.queryParameters['q'] ?? ''),
      ),
    ),
    GoRoute(
      path: '/image-input',
      builder: (context, state) => const Scaffold(body: ImageInputScreen()),
    ),
    GoRoute(
      path: '/welcome',
      builder: (context, state) => const WelcomeScreen(),
      routes: [
        GoRoute(
          path: 'login',
          builder: (context, state) => const AuthScreen(mode: AuthMode.login),
        ),
        GoRoute(
          path: 'signup',
          builder: (context, state) => const AuthScreen(mode: AuthMode.signUp),
        ),
        GoRoute(
          path: 'reset',
          builder: (context, state) => const PasswordResetScreen(),
        ),
      ],
    ),
    GoRoute(
      path: '/new-password',
      builder: (context, state) => const NewPasswordScreen(),
    ),
    GoRoute(
      path: '/input',
      builder: (context, state) => Scaffold(
        body: SafeArea(
          child: InputPanel(
            onClose: () => context.pop(),
            initialText: state.extra as String?,
          ),
        ),
      ),
    ),
  ],
);
