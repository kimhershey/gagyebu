import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthUser;

import '../sync/sync_gateway.dart';
import 'server_config.dart';
import 'server_connection.dart';

/// Supabase에 연결한다. 저장해 둔 로그인 세션이 있으면 되살린다.
///
/// 앱을 다시 열 때(로그인해서 가계부가 바뀌었을 때)도 불린다. 연결은 한 번만 만든다.
Future<ServerConnection> connectSupabase(ServerConfig config) async {
  final existing = _connection;
  if (existing != null) return existing;
  final supabase = await Supabase.initialize(
    url: config.url,
    publishableKey: config.publishableKey,
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,
    ),
  );
  return _connection = supabaseConnection(supabase.client);
}

ServerConnection? _connection;

/// [client]로 연결 한 벌을 만든다.
ServerConnection supabaseConnection(SupabaseClient client) => ServerConnection(
  auth: SupabaseAuthService(client),
  gateway: SupabaseSyncGateway(client),
  ledgerIdOf: (userId) async {
    final row = await client
        .from('profiles')
        .select('ledger_id')
        .eq('id', userId)
        .maybeSingle();
    return row?['ledger_id'] as String?;
  },
);

class SupabaseAuthService implements AuthService {
  SupabaseAuthService(this._client) {
    // 비밀번호를 다시 정하는 메일의 링크로 들어오면 서버가 알려 준다. 앱이 뜨기 전에 온
    // 알림도 여기서 받는다(알림은 처음부터 다시 들려준다).
    _client.auth.onAuthStateChange.listen((state) {
      if (state.event == AuthChangeEvent.passwordRecovery) _setRecovery(true);
      if (state.event == AuthChangeEvent.signedOut) _setRecovery(false);
    }, onError: (Object _) {});
  }

  final SupabaseClient _client;
  final _recovery = StreamController<bool>.broadcast();
  bool _recoveryPending = false;

  void _setRecovery(bool pending) {
    if (_recoveryPending == pending) return;
    _recoveryPending = pending;
    _recovery.add(pending);
  }

  static AuthUser? _user(User? user) =>
      user == null ? null : AuthUser(id: user.id, email: user.email);

  @override
  AuthUser? get currentUser => _user(_client.auth.currentUser);

  @override
  Stream<AuthUser?> get userChanges => _client.auth.onAuthStateChange
      .map((state) => _user(state.session?.user))
      .distinct();

  // Windows · Android 앱은 브라우저에서 로그인하고 앱으로 돌아오는 주소를 등록해야 한다.
  // 그 작업 전까지 Google 로그인은 웹에서만 한다.
  @override
  bool get googleAvailable => kIsWeb;

  /// 웹: 로그인하거나 메일의 링크를 누른 뒤 돌아올 주소. 지금 이 앱의 주소에서 #/화면을 뺀다.
  static String? get _returnUrl =>
      kIsWeb ? '${Uri.base.origin}${Uri.base.path}' : null;

  @override
  Future<void> signInWithGoogle() => _guard(
    () => _client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: _returnUrl,
    ),
  );

  @override
  Future<void> signInWithPassword({
    required String email,
    required String password,
  }) => _guard(
    () => _client.auth.signInWithPassword(email: email, password: password),
  );

  @override
  Future<SignUpResult> signUpWithPassword({
    required String email,
    required String password,
  }) => _guard(() async {
    final response = await _client.auth.signUp(
      email: email,
      password: password,
      emailRedirectTo: _returnUrl,
    );
    if (response.session != null) return SignUpResult.signedIn;
    // 메일 확인을 켠 서버는 이미 가입한 주소에도 오류 없이 답한다. 그때는 로그인 수단
    // (identities)이 비어 있다.
    final identities = response.user?.identities;
    if (identities != null && identities.isEmpty) {
      throw const AuthFailure(AuthFailureReason.alreadyRegistered);
    }
    return SignUpResult.confirmationSent;
  });

  @override
  Future<void> sendPasswordReset({required String email}) => _guard(
    () => _client.auth.resetPasswordForEmail(email, redirectTo: _returnUrl),
  );

  @override
  bool get passwordRecoveryPending => _recoveryPending;

  @override
  Stream<bool> get passwordRecoveryChanges => _recovery.stream;

  @override
  Future<void> updatePassword({required String password}) => _guard(() async {
    await _client.auth.updateUser(UserAttributes(password: password));
    _setRecovery(false);
  });

  /// 서버의 오류를 [AuthFailure]로 바꾼다.
  static Future<T> _guard<T>(Future<T> Function() run) async {
    try {
      return await run();
    } on AuthFailure {
      rethrow;
    } on AuthRetryableFetchException catch (e) {
      throw AuthFailure(AuthFailureReason.network, e.message);
    } on AuthException catch (e) {
      throw AuthFailure(_reason(e), e.message);
    } catch (e) {
      // 연결이 끊겼을 때는 플랫폼마다 다른 예외가 온다.
      throw AuthFailure(AuthFailureReason.network, '$e');
    }
  }

  static AuthFailureReason _reason(AuthException e) =>
      e is AuthWeakPasswordException
      ? AuthFailureReason.weakPassword
      : switch (e.code) {
          'invalid_credentials' => AuthFailureReason.invalidCredentials,
          'email_not_confirmed' => AuthFailureReason.emailNotConfirmed,
          'user_already_exists' ||
          'email_exists' => AuthFailureReason.alreadyRegistered,
          'weak_password' => AuthFailureReason.weakPassword,
          'same_password' => AuthFailureReason.samePassword,
          'email_address_invalid' ||
          'validation_failed' => AuthFailureReason.invalidEmail,
          'over_email_send_rate_limit' ||
          'over_request_rate_limit' => AuthFailureReason.rateLimited,
          'signup_disabled' ||
          'email_provider_disabled' => AuthFailureReason.signupDisabled,
          _ => AuthFailureReason.unknown,
        };

  @override
  Future<void> signOut() => _client.auth.signOut();
}

/// 서버의 sync_push · sync_pull 함수를 부른다. 규약은 `supabase/README.md`에 있다.
class SupabaseSyncGateway implements SyncGateway {
  SupabaseSyncGateway(this._client);

  final SupabaseClient _client;

  @override
  Future<PushResponse> push({
    required String ledgerId,
    required String deviceId,
    required String batchId,
    required List<PushChange> changes,
  }) async {
    final result = await _client.rpc<dynamic>(
      'sync_push',
      params: {
        'p_ledger_id': ledgerId,
        'p_device_id': deviceId,
        'p_batch_id': batchId,
        'p_changes': [for (final c in changes) c.toJson()],
      },
    );
    return PushResponse.fromJson((result as Map).cast<String, Object?>());
  }

  @override
  Future<PullResponse> pull({
    required String ledgerId,
    required int since,
    int limit = 500,
  }) async {
    final result = await _client.rpc<dynamic>(
      'sync_pull',
      params: {'p_ledger_id': ledgerId, 'p_since': since, 'p_limit': limit},
    );
    return PullResponse.fromJson((result as Map).cast<String, Object?>());
  }
}
