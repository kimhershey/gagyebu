import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/providers.dart';
import '../../app/sync_controller.dart';
import '../../data/server/server_connection.dart';
import 'auth_frame.dart';

/// 계정을 새로 만드는지, 있는 계정으로 들어가는지.
enum AuthMode { login, signUp }

/// 계정 만들기 화면과 로그인 화면.
///
/// 두 화면 모두 Google 로그인과 이메일 · 비밀번호 입력을 함께 보여 준다. Google 계정은
/// 처음 로그인할 때 계정이 만들어지므로 어느 화면에서 눌러도 결과가 같다.
class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key, required this.mode});

  final AuthMode mode;

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen>
    with LeaveWhenSignedIn {
  /// 서버의 기본 최소 길이.
  static const _minPasswordLength = 6;

  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  bool _busy = false;
  bool _obscure = true;
  String? _error;

  /// 확인 메일을 보낸 주소. 있으면 입력 칸 대신 안내를 보여 준다.
  String? _sentTo;

  bool get _signUp => widget.mode == AuthMode.signUp;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  /// 입력이 틀렸으면 그 까닭.
  String? _validate() {
    final email = _email.text.trim();
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      return '이메일 주소를 확인해 주세요';
    }
    if (_password.text.length < _minPasswordLength) {
      return '비밀번호는 $_minPasswordLength자 이상이어야 합니다';
    }
    if (_signUp && _password.text != _confirm.text) {
      return '비밀번호가 서로 다릅니다';
    }
    return null;
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } on AuthFailure catch (failure) {
      if (mounted) setState(() => _error = _message(failure));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submit() async {
    final invalid = _validate();
    if (invalid != null) {
      setState(() => _error = invalid);
      return;
    }
    final controller = ref.read(syncControllerProvider.notifier);
    final email = _email.text.trim();
    await _run(() async {
      if (!_signUp) {
        await controller.signInWithPassword(email, _password.text);
        return;
      }
      final result = await controller.signUpWithPassword(email, _password.text);
      if (result == SignUpResult.confirmationSent && mounted) {
        setState(() => _sentTo = email);
      }
    });
    // 로그인됐으면 로그인 상태가 바뀌면서 이 화면에서 나간다.
    TextInput.finishAutofillContext();
  }

  Future<void> _google() =>
      _run(ref.read(syncControllerProvider.notifier).signInWithGoogle);

  String _message(AuthFailure failure) => switch (failure.reason) {
    AuthFailureReason.invalidCredentials => '이메일이나 비밀번호가 맞지 않습니다',
    AuthFailureReason.emailNotConfirmed =>
      '메일 확인이 끝나지 않았습니다. 가입할 때 받은 메일의 링크를 눌러 주세요',
    AuthFailureReason.alreadyRegistered => '이미 가입한 이메일입니다. 로그인해 주세요',
    AuthFailureReason.weakPassword => '비밀번호가 너무 쉽습니다. 더 길게 정해 주세요',
    AuthFailureReason.invalidEmail => '이메일 주소를 확인해 주세요',
    AuthFailureReason.rateLimited => '요청이 너무 많습니다. 잠시 뒤에 다시 해 주세요',
    AuthFailureReason.signupDisabled => '지금은 새 계정을 만들 수 없습니다',
    AuthFailureReason.network => '서버에 연결하지 못했습니다. 인터넷 연결을 확인해 주세요',
    AuthFailureReason.unknown =>
      '${_signUp ? '계정을 만들지' : '로그인하지'} 못했습니다'
          '${failure.detail == null ? '' : ': ${failure.detail}'}',
  };

  void _back() => context.canPop() ? context.pop() : context.go('/welcome');

  void _switchMode() =>
      context.pushReplacement(_signUp ? '/welcome/login' : '/welcome/signup');

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(syncControllerProvider);
    if (leaveIfSignedIn(status)) {
      return const AuthFrame(
        children: [Center(child: CircularProgressIndicator())],
      );
    }
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final googleAvailable =
        ref.watch(appServicesProvider).server?.auth.googleAvailable ?? false;

    final header = Row(
      children: [
        IconButton(
          key: const ValueKey('auth-back'),
          tooltip: '뒤로',
          onPressed: _back,
          icon: const Icon(Icons.arrow_back),
        ),
        const SizedBox(width: 4),
        Text(_signUp ? '계정 만들기' : '로그인', style: theme.textTheme.headlineSmall),
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
            '확인 메일을 보냈습니다',
            key: const ValueKey('auth-sent'),
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            '$sentTo(으)로 보낸 메일의 링크를 누르면 가입이 끝납니다. 그다음 로그인해 주세요.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          FilledButton(onPressed: _switchMode, child: const Text('로그인 화면으로')),
        ],
      );
    }

    return AuthFrame(
      children: [
        header,
        const SizedBox(height: 24),
        if (googleAvailable) ...[
          OutlinedButton.icon(
            key: const ValueKey('auth-google'),
            onPressed: _busy ? null : _google,
            icon: const Icon(Icons.login, size: 18),
            label: Text(_signUp ? 'Google 계정으로 만들기' : 'Google로 로그인'),
          ),
          if (_signUp) ...[
            const SizedBox(height: 6),
            Text(
              'Google 계정을 고르면 바로 만들어집니다.',
              textAlign: TextAlign.center,
              style: muted,
            ),
          ],
        ] else
          Text(
            '이 앱에서는 Google 로그인을 준비하고 있습니다. 이메일로 '
            '${_signUp ? '계정을 만들어' : '로그인해'} 주세요.',
            style: muted,
          ),
        const SizedBox(height: 20),
        Row(
          children: [
            const Expanded(child: Divider()),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text('또는 이메일로', style: muted),
            ),
            const Expanded(child: Divider()),
          ],
        ),
        const SizedBox(height: 20),
        AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                key: const ValueKey('auth-email'),
                controller: _email,
                enabled: !_busy,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autocorrect: false,
                autofillHints: const [AutofillHints.email],
                decoration: const InputDecoration(
                  labelText: '이메일',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const ValueKey('auth-password'),
                controller: _password,
                enabled: !_busy,
                obscureText: _obscure,
                textInputAction: _signUp
                    ? TextInputAction.next
                    : TextInputAction.done,
                autofillHints: [
                  _signUp ? AutofillHints.newPassword : AutofillHints.password,
                ],
                onSubmitted: _signUp ? null : (_) => _submit(),
                decoration: InputDecoration(
                  labelText: '비밀번호',
                  helperText: _signUp ? '$_minPasswordLength자 이상' : null,
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
              if (_signUp) ...[
                const SizedBox(height: 12),
                TextField(
                  key: const ValueKey('auth-password-confirm'),
                  controller: _confirm,
                  enabled: !_busy,
                  obscureText: _obscure,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.newPassword],
                  onSubmitted: (_) => _submit(),
                  decoration: const InputDecoration(
                    labelText: '비밀번호 확인',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ],
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(
            _error!,
            key: const ValueKey('auth-error'),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        ],
        const SizedBox(height: 16),
        FilledButton(
          key: const ValueKey('auth-submit'),
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(_signUp ? '계정 만들기' : '로그인'),
        ),
        const SizedBox(height: 8),
        TextButton(
          key: const ValueKey('auth-switch'),
          onPressed: _busy ? null : _switchMode,
          child: Text(_signUp ? '이미 계정이 있으면 로그인' : '계정이 없으면 계정 만들기'),
        ),
      ],
    );
  }
}
