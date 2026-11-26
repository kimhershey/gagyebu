import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/server/server_connection.dart';

/// 로그인 안내 화면들이 함께 쓰는 틀: 가운데에 놓인 좁은 한 칸.
class AuthFrame extends StatelessWidget {
  const AuthFrame({super.key, required this.children});

  /// 로그인이 끝나 가계부로 넘어가는 동안 보여 주는 화면.
  const AuthFrame.busy({super.key})
    : children = const [Center(child: CircularProgressIndicator())];

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: children,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 서버의 기본 최소 비밀번호 길이.
const minPasswordLength = 6;

/// 이메일 주소처럼 생겼는지. 정확한 검사는 서버가 한다.
bool looksLikeEmail(String text) =>
    RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(text);

/// 로그인 관련 요청이 실패한 까닭을 사용자에게 보여 줄 말로 바꾼다.
///
/// [action]은 하려던 일이다('로그인하지', '계정을 만들지'). 까닭을 모를 때 쓴다.
String authFailureMessage(AuthFailure failure, {required String action}) =>
    switch (failure.reason) {
      AuthFailureReason.invalidCredentials => '이메일이나 비밀번호가 맞지 않습니다',
      AuthFailureReason.emailNotConfirmed =>
        '메일 확인이 끝나지 않았습니다. 가입할 때 받은 메일의 링크를 눌러 주세요',
      AuthFailureReason.alreadyRegistered => '이미 가입한 이메일입니다. 로그인해 주세요',
      AuthFailureReason.weakPassword => '비밀번호가 너무 쉽습니다. 더 길게 정해 주세요',
      AuthFailureReason.samePassword => '지금 쓰는 비밀번호와 같습니다',
      AuthFailureReason.invalidEmail => '이메일 주소를 확인해 주세요',
      AuthFailureReason.rateLimited => '요청이 너무 많습니다. 잠시 뒤에 다시 해 주세요',
      AuthFailureReason.signupDisabled => '지금은 새 계정을 만들 수 없습니다',
      AuthFailureReason.network => '서버에 연결하지 못했습니다. 인터넷 연결을 확인해 주세요',
      AuthFailureReason.unknown =>
        '$action 못했습니다${failure.detail == null ? '' : ': ${failure.detail}'}',
    };

/// 브라우저에서 돌아온 로그인을 끝내지 못했을 때의 알림. 실패가 없으면 아무것도 그리지 않는다.
///
/// 웹에서는 다른 앱(PC · 휴대폰 앱)에서 시작한 로그인이 이 페이지로 잘못 돌아왔을 때
/// 생긴다. 서버의 Redirect URLs에 앱 주소가 빠져 있으면 그렇게 된다.
class SignInFailureNotice extends StatefulWidget {
  const SignInFailureNotice({super.key, required this.auth});

  final AuthService? auth;

  @override
  State<SignInFailureNotice> createState() => _SignInFailureNoticeState();
}

class _SignInFailureNoticeState extends State<SignInFailureNotice> {
  StreamSubscription<AuthFailure>? _subscription;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    final auth = widget.auth;
    if (auth == null) return;
    _failed = auth.takeSignInFailure() != null;
    _subscription = auth.signInFailures.listen((_) {
      auth.takeSignInFailure();
      if (mounted) setState(() => _failed = true);
    });
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_failed) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        kIsWeb
            ? '이 로그인은 다른 앱에서 시작된 것이라 여기서 끝낼 수 없습니다. '
                  '시작한 앱으로 돌아가 다시 시도해 주세요.'
            : '로그인을 마치지 못했습니다. 다시 시도해 주세요.',
        key: const ValueKey('sign-in-failure'),
        textAlign: TextAlign.center,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.error,
        ),
      ),
    );
  }
}
