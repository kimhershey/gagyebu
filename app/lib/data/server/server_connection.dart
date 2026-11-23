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

/// 로그인.
abstract interface class AuthService {
  /// 지금 로그인한 사용자. 없으면 null.
  AuthUser? get currentUser;

  /// 로그인 · 로그아웃할 때마다 알린다.
  Stream<AuthUser?> get userChanges;

  /// 이 플랫폼에서 로그인 흐름이 준비됐는지.
  bool get canSignInHere;

  /// Google 로그인을 시작한다. 웹에서는 로그인 페이지로 갔다가 돌아온다.
  Future<void> signInWithGoogle();

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
