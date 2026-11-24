import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/providers.dart';
import '../../app/sync_controller.dart';
import 'auth_frame.dart';

/// 처음 시작할 때 보는 화면: 계정 만들기와 로그인 가운데 하나를 고른다.
///
/// 로그인하지 않고 쓸 수도 있다. 그때는 기기 안에만 저장하고, 다음부터는 이 화면을 건너뛴다.
class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key});

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen>
    with LeaveWhenSignedIn {
  Future<void> _skip() async {
    await ref.read(skipLoginProvider)();
    if (mounted) context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(syncControllerProvider);
    final theme = Theme.of(context);
    if (leaveIfSignedIn(status)) {
      return const AuthFrame(
        children: [Center(child: CircularProgressIndicator())],
      );
    }
    final available = status.phase != SyncPhase.unavailable;

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
          available
              ? '결제 문자를 붙여넣거나 한 줄로 적으면 됩니다.\n'
                    '계정으로 로그인하면 여러 기기에서 같은 가계부를 봅니다.'
              : '이 앱에는 로그인이 들어 있지 않습니다. 가계부는 기기 안에 저장됩니다.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 32),
        if (available) ...[
          FilledButton(
            key: const ValueKey('welcome-signup'),
            onPressed: () => context.push('/welcome/signup'),
            child: const Text('계정 만들기'),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            key: const ValueKey('welcome-login'),
            onPressed: () => context.push('/welcome/login'),
            child: const Text('로그인'),
          ),
          const SizedBox(height: 24),
        ],
        TextButton(
          key: const ValueKey('welcome-skip'),
          onPressed: _skip,
          child: Text(available ? '로그인하지 않고 사용' : '가계부 열기'),
        ),
        if (available)
          Text(
            '기기 안에만 저장됩니다. 나중에 설정에서 로그인할 수 있습니다.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
      ],
    );
  }
}
