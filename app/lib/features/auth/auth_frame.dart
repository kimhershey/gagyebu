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
