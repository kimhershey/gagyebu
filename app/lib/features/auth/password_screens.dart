import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/sync_controller.dart';
import '../../data/server/server_connection.dart';
import 'auth_frame.dart';

/// 비밀번호를 잊었을 때: 이메일을 적으면 다시 정하는 링크를 메일로 보낸다.
class PasswordResetScreen extends ConsumerStatefulWidget {
  const PasswordResetScreen({super.key});

  @override
  ConsumerState<PasswordResetScreen> createState() =>
      _PasswordResetScreenState();
}

class _PasswordResetScreenState extends ConsumerState<PasswordResetScreen> {
  final _email = TextEditingController();
  bool _busy = false;
  String? _error;
  String? _sentTo;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final email = _email.text.trim();
    if (!looksLikeEmail(email)) {
      setState(() => _error = '이메일 주소를 확인해 주세요');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(syncControllerProvider.notifier).sendPasswordReset(email);
      if (mounted) setState(() => _sentTo = email);
    } on AuthFailure catch (failure) {
      if (mounted) {
        setState(() => _error = authFailureMessage(failure, action: '메일을 보내지'));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final header = Row(
      children: [
        IconButton(
          key: const ValueKey('reset-back'),
          tooltip: '뒤로',
          onPressed: () => context.go('/welcome/login'),
          icon: const Icon(Icons.arrow_back),
        ),
        const SizedBox(width: 4),
        // 좁은 화면이나 큰 글자에서는 줄을 바꾼다.
        Expanded(
          child: Text('비밀번호 다시 정하기', style: theme.textTheme.headlineSmall),
        ),
      ],
    );

    final sentTo = _sentTo;
    if (sentTo != null) {
      return AuthFrame(
        children: [
          header,
          const SizedBox(height: 24),
          Icon(
            Icons.mark_email_read_outlined,
            size: 40,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: 12),
          Text(
            '메일을 보냈습니다',
            key: const ValueKey('reset-sent'),
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            '$sentTo(으)로 가입한 계정이 있으면 메일이 갑니다. 메일의 링크를 누르면 '
            '새 비밀번호를 정하는 화면이 열립니다.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () => context.go('/welcome/login'),
            child: const Text('로그인 화면으로'),
          ),
        ],
      );
    }

    return AuthFrame(
      children: [
        header,
        const SizedBox(height: 16),
        Text(
          '가입한 이메일을 적어 주세요. 비밀번호를 다시 정하는 링크를 메일로 보냅니다.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 20),
        TextField(
          key: const ValueKey('reset-email'),
          controller: _email,
          enabled: !_busy,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.done,
          autocorrect: false,
          autofillHints: const [AutofillHints.email],
          onSubmitted: (_) => _send(),
          decoration: const InputDecoration(
            labelText: '이메일',
            border: OutlineInputBorder(),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(
            _error!,
            key: const ValueKey('reset-error'),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        ],
        const SizedBox(height: 16),
        FilledButton(
          key: const ValueKey('reset-send'),
          onPressed: _busy ? null : _send,
          child: _busy
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('메일 보내기'),
        ),
      ],
    );
  }
}

/// 비밀번호를 다시 정하는 메일의 링크로 들어왔을 때: 새 비밀번호를 정한다.
///
/// 정하고 나면 라우터가 가계부로 보낸다(`app/router.dart`).
class NewPasswordScreen extends ConsumerStatefulWidget {
  const NewPasswordScreen({super.key});

  @override
  ConsumerState<NewPasswordScreen> createState() => _NewPasswordScreenState();
}

class _NewPasswordScreenState extends ConsumerState<NewPasswordScreen> {
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    String? invalid;
    if (_password.text.length < minPasswordLength) {
      invalid = '비밀번호는 $minPasswordLength자 이상이어야 합니다';
    } else if (_password.text != _confirm.text) {
      invalid = '비밀번호가 서로 다릅니다';
    }
    if (invalid != null) {
      setState(() => _error = invalid);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(syncControllerProvider.notifier)
          .updatePassword(_password.text);
    } on AuthFailure catch (failure) {
      if (mounted) {
        setState(
          () => _error = authFailureMessage(failure, action: '비밀번호를 바꾸지'),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final email = ref.watch(syncControllerProvider).user?.email;
    return AuthFrame(
      children: [
        Text('새 비밀번호 정하기', style: theme.textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text(
          email == null ? '새 비밀번호를 적어 주세요.' : '$email 계정의 새 비밀번호를 적어 주세요.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 20),
        TextField(
          key: const ValueKey('new-password'),
          controller: _password,
          enabled: !_busy,
          obscureText: _obscure,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.newPassword],
          decoration: InputDecoration(
            labelText: '새 비밀번호',
            helperText: '$minPasswordLength자 이상',
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              tooltip: _obscure ? '비밀번호 보기' : '비밀번호 가리기',
              onPressed: () => setState(() => _obscure = !_obscure),
              icon: Icon(
                _obscure
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const ValueKey('new-password-confirm'),
          controller: _confirm,
          enabled: !_busy,
          obscureText: _obscure,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.newPassword],
          onSubmitted: (_) => _save(),
          decoration: const InputDecoration(
            labelText: '새 비밀번호 확인',
            border: OutlineInputBorder(),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(
            _error!,
            key: const ValueKey('new-password-error'),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        ],
        const SizedBox(height: 16),
        FilledButton(
          key: const ValueKey('new-password-save'),
          onPressed: _busy ? null : _save,
          child: _busy
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('비밀번호 바꾸기'),
        ),
      ],
    );
  }
}
