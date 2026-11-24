import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../features/auth/auth_screen.dart';
import '../features/auth/password_screens.dart';
import '../features/auth/welcome_screen.dart';
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
            ),
          ],
        ),
      ],
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
        body: SafeArea(child: InputPanel(onClose: () => context.pop())),
      ),
    ),
  ],
);
