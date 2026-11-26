import 'dart:async';

import 'package:flutter/foundation.dart';
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

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  bool _busy = false;
  bool _obscure = true;
  String? _error;

  /// 확인 메일을 보낸 주소. 있으면 입력 칸 대신 안내를 보여 준다.
  String? _sentTo;

  /// 브라우저로 로그인하러 나간 뒤 돌아오기를 기다리는 중인지(앱에서만).
  bool _waiting = false;

  /// 기다린 지 오래됐는지. 돌아오지 않을 때 볼 것을 알려 준다.
  bool _waitedLong = false;
  Timer? _longWait;

  bool get _signUp => widget.mode == AuthMode.signUp;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    _longWait?.cancel();
    super.dispose();
  }

  /// 입력이 틀렸으면 그 까닭.
  String? _validate() {
    final email = _email.text.trim();
    if (!looksLikeEmail(email)) return '이메일 주소를 확인해 주세요';
    if (_password.text.length < minPasswordLength) {
      return '비밀번호는 $minPasswordLength자 이상이어야 합니다';
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
      if (mounted) {
        setState(
          () => _error = authFailureMessage(
            failure,
            action: _signUp ? '계정을 만들지' : '로그인하지',
          ),
        );
      }
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
    // 로그인됐으면 라우터가 가계부로 보낸다.
    TextInput.finishAutofillContext();
  }

  Future<void> _google() async {
    await _run(ref.read(syncControllerProvider.notifier).signInWithGoogle);
    // 웹은 이 탭이 로그인 페이지로 간다. 앱은 브라우저가 따로 열리고 이 화면이 남는다.
    if (!mounted || kIsWeb || _error != null) return;
    _longWait?.cancel();
    setState(() {
      _waiting = true;
      _waitedLong = false;
    });
    _longWait = Timer(const Duration(seconds: 60), () {
      if (mounted) setState(() => _waitedLong = true);
    });
  }

  void _stopWaiting() {
    _longWait?.cancel();
    setState(() => _waiting = false);
  }

  void _back() => context.go('/welcome');

  void _switchMode() =>
      context.go(_signUp ? '/welcome/login' : '/welcome/signup');

  @override
  Widget build(BuildContext context) {
    if (ref.watch(syncControllerProvider).signedIn) {
      return const AuthFrame.busy();
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
        // 좁은 화면이나 큰 글자에서는 줄을 바꾼다.
        Expanded(
          child: Text(
            _signUp ? '계정 만들기' : '로그인',
            style: theme.textTheme.headlineSmall,
          ),
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
          if (_signUp && !_waiting) ...[
            const SizedBox(height: 6),
            Text(
              'Google 계정을 고르면 바로 만들어집니다.',
              textAlign: TextAlign.center,
              style: muted,
            ),
          ],
          if (_waiting) ...[
            const SizedBox(height: 8),
            Text(
              '브라우저에서 로그인을 마치면 이 창으로 돌아옵니다. 브라우저가 '
              '"가계부를 여시겠습니까"라고 물으면 열기를 눌러 주세요.',
              key: const ValueKey('auth-google-waiting'),
              style: muted,
            ),
            if (_waitedLong) ...[
              const SizedBox(height: 6),
              Text(
                '돌아오지 않으면 브라우저에 무엇이 보이는지 확인해 주세요. 웹 가계부가 '
                '열렸다면 서버에 앱 주소가 등록되지 않은 것입니다.',
                key: const ValueKey('auth-google-waited-long'),
                style: muted,
              ),
            ],
            Wrap(
              alignment: WrapAlignment.end,
              children: [
                TextButton(
                  key: const ValueKey('auth-google-reopen'),
                  onPressed: _busy ? null : _google,
                  child: const Text('브라우저 다시 열기'),
                ),
                TextButton(
                  key: const ValueKey('auth-google-cancel'),
                  onPressed: _stopWaiting,
                  child: const Text('취소'),
                ),
              ],
            ),
          ],
          SignInFailureNotice(
            auth: ref.watch(appServicesProvider).server?.auth,
          ),
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
                  helperText: _signUp ? '$minPasswordLength자 이상' : null,
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
        if (!_signUp)
          TextButton(
            key: const ValueKey('auth-forgot'),
            onPressed: _busy ? null : () => context.go('/welcome/reset'),
            child: const Text('비밀번호를 잊었습니다'),
          ),
      ],
    );
  }
}
