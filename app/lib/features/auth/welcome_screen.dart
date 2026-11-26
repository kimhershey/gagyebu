import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/providers.dart';
import '../../app/sync_controller.dart';
import 'auth_frame.dart';

/// 로그인하지 않았을 때 보는 첫 화면: 계정 만들기와 로그인 가운데 하나를 고른다.
///
/// 로그인하면 라우터가 가계부로 보낸다(`app/router.dart`).
class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(syncControllerProvider).signedIn) {
      return const AuthFrame.busy();
    }
    final theme = Theme.of(context);

    return AuthFrame(
      children: [
        Icon(
          Icons.account_balance_wallet_outlined,
          size: 48,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(height: 16),
        Text(
          '가계부',
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineMedium,
        ),
        const SizedBox(height: 8),
        Text(
          '결제 문자를 붙여넣거나 한 줄로 적으면 됩니다.\n'
          '계정으로 로그인하면 여러 기기에서 같은 가계부를 봅니다.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 32),
        SignInFailureNotice(auth: ref.watch(appServicesProvider).server?.auth),
        FilledButton(
          key: const ValueKey('welcome-signup'),
          onPressed: () => context.go('/welcome/signup'),
          child: const Text('계정 만들기'),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          key: const ValueKey('welcome-login'),
          onPressed: () => context.go('/welcome/login'),
          child: const Text('로그인'),
        ),
      ],
    );
  }
}
