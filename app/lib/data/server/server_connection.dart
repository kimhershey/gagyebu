/// 서버와의 연결: 로그인과 동기화 호출.
///
/// 화면과 동기화 엔진은 이 인터페이스만 본다. 실제 구현은 Supabase다
/// (`supabase_connection.dart`). 서버 주소를 넣지 않고 만든 빌드에는 연결이 없고, 앱은
/// 기기 안에서만 동작한다.
library;

import '../sync/sync_gateway.dart';

/// 로그인한 사용자.
class AuthUser {
  const AuthUser({required this.id, this.email});

  final String id;
  final String? email;

  @override
  bool operator ==(Object other) =>
      other is AuthUser && other.id == id && other.email == email;

  @override
  int get hashCode => Object.hash(id, email);
}

/// 로그인하지 못한 까닭. 화면이 사용자에게 보여 줄 말을 고르는 데 쓴다.
enum AuthFailureReason {
  /// 이메일이나 비밀번호가 맞지 않는다.
  invalidCredentials,

  /// 가입은 했지만 메일의 확인 링크를 아직 누르지 않았다.
  emailNotConfirmed,

  /// 이미 가입한 이메일이다.
  alreadyRegistered,

  /// 비밀번호가 서버의 기준에 못 미친다.
  weakPassword,

  /// 새 비밀번호가 지금 비밀번호와 같다.
  samePassword,

  /// 이메일 주소의 꼴이 맞지 않는다.
  invalidEmail,

  /// 짧은 시간에 너무 많이 요청했다(확인 메일 보내기 포함).
  rateLimited,

  /// 서버가 새 가입을 받지 않는다.
  signupDisabled,

  /// 서버에 닿지 못했다.
  network,

  unknown,
}

class AuthFailure implements Exception {
  const AuthFailure(this.reason, [this.detail]);

  final AuthFailureReason reason;

  /// 서버가 준 말. 까닭을 알 수 없을 때 보여 준다.
  final String? detail;

  @override
  String toString() =>
      'AuthFailure(${reason.name}${detail == null ? '' : ': $detail'})';
}

/// 가입 요청의 결과.
enum SignUpResult {
  /// 바로 로그인됐다.
  signedIn,

  /// 확인 메일을 보냈다. 메일의 링크를 눌러야 로그인할 수 있다.
  confirmationSent,
}

/// 로그인.
///
/// 로그인에 실패하면 [AuthFailure]를 던진다.
abstract interface class AuthService {
  /// 지금 로그인한 사용자. 없으면 null.
  AuthUser? get currentUser;

  /// 로그인 · 로그아웃할 때마다 알린다.
  Stream<AuthUser?> get userChanges;

  /// 이 플랫폼에서 Google 로그인을 쓸 수 있는지. 이메일 로그인은 어디서나 된다.
  bool get googleAvailable;

  /// Google 로그인을 시작한다. 웹에서는 로그인 페이지로 갔다가 돌아온다. 처음이면 계정이
  /// 만들어진다.
  Future<void> signInWithGoogle();

  /// 이메일과 비밀번호로 로그인한다.
  Future<void> signInWithPassword({
    required String email,
    required String password,
  });

  /// 이메일과 비밀번호로 계정을 만든다.
  Future<SignUpResult> signUpWithPassword({
    required String email,
    required String password,
  });

  /// 비밀번호를 다시 정하는 링크를 메일로 보낸다.
  Future<void> sendPasswordReset({required String email});

  /// 그 메일의 링크로 들어와 새 비밀번호를 정해야 하는지.
  bool get passwordRecoveryPending;

  /// [passwordRecoveryPending]이 바뀔 때마다 알린다.
  Stream<bool> get passwordRecoveryChanges;

  /// 로그인한 계정의 비밀번호를 바꾼다.
  Future<void> updatePassword({required String password});

  /// 이 기기에서만 로그아웃한다. 기기의 가계부는 지우지 않는다.
  Future<void> signOut();
}

/// 서버 연결 한 벌.
class ServerConnection {
  const ServerConnection({
    required this.auth,
    required this.gateway,
    required this.ledgerIdOf,
  });

  final AuthService auth;
  final SyncGateway gateway;

  /// 사용자의 가계부 ID. 서버가 가입할 때 만들어 둔다. 찾지 못하면 null.
  final Future<String?> Function(String userId) ledgerIdOf;
}
