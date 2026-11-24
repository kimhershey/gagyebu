import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthUser;
import 'package:url_launcher/url_launcher.dart';

import '../sync/sync_gateway.dart';
import 'server_config.dart';
import 'server_connection.dart';
import 'session_storage.dart';

/// Windows · Android 앱에서 Google 로그인을 마치고 돌아오는 주소(`docs/SPEC.md` 4.3).
///
/// Android는 매니페스트의 인텐트 필터가, Windows는 설치 파일이 등록한 URL 스킴이 이 주소를
/// 앱으로 넘긴다. Supabase의 Redirect URLs에도 같은 주소가 들어 있어야 한다.
const appLoginCallback = 'io.github.kimhershey.gagyebu://login-callback';

/// Supabase에 연결한다. 저장해 둔 로그인 세션이 있으면 되살린다.
///
/// 앱을 다시 열 때(로그인해서 가계부가 바뀌었을 때)도 불린다. 연결은 한 번만 만든다.
Future<ServerConnection> connectSupabase(ServerConfig config) async {
  final existing = _connection;
  if (existing != null) return existing;
  final supabase = await Supabase.initialize(
    url: config.url,
    publishableKey: config.publishableKey,
    authOptions: FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,
      // Android는 세션을 OS 보안 저장소에 둔다. 웹 · Windows는 패키지의 기본값을 쓴다.
      localStorage: sessionStorageFor(config.url),
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
  changes: (ledgerId) => ledgerChanges(client, ledgerId),
);

/// 서버가 가계부의 변경을 알리는 채널. 비공개 채널이라 로그인한 주인만 들을 수 있다.
RealtimeChannel ledgerChannel(SupabaseClient client, String ledgerId) =>
    client.channel(
      'ledger:$ledgerId',
      opts: const RealtimeChannelConfig(private: true),
    );

/// [ledgerId] 가계부에 변경이 적용될 때마다 알린다(`supabase/README.md`의 변경 신호).
///
/// 듣기 시작하면 채널을 구독하고, 그만 들으면 채널을 없앤다. 연결이 끊기면 라이브러리가
/// 다시 붙는다. 신호를 놓쳐도 1분 주기의 받기가 맞추므로 구독의 실패는 알리지 않는다.
Stream<void> ledgerChanges(SupabaseClient client, String ledgerId) {
  late final StreamController<void> controller;
  RealtimeChannel? channel;
  controller = StreamController<void>(
    onListen: () {
      channel = ledgerChannel(client, ledgerId)
          .onBroadcast(
            event: 'changed',
            callback: (_) {
              if (!controller.isClosed) controller.add(null);
            },
          )
          .subscribe();
    },
    onCancel: () async {
      final subscribed = channel;
      channel = null;
      if (subscribed != null) {
        try {
          await client.removeChannel(subscribed);
        } catch (e) {
          debugPrint('실시간 채널을 닫지 못했다: $e');
        }
      }
      await controller.close();
    },
  );
  return controller.stream;
}

class SupabaseAuthService implements AuthService {
  /// [launch]는 로그인 페이지를 여는 함수다. 시험에서 바꿔 끼운다.
  SupabaseAuthService(this._client, {Future<bool> Function(Uri url)? launch})
    : _launch = launch ?? _openLoginPage {
    // 비밀번호를 다시 정하는 메일의 링크로 들어오면 서버가 알려 준다. 앱이 뜨기 전에 온
    // 알림도 여기서 받는다(알림은 처음부터 다시 들려준다).
    _client.auth.onAuthStateChange.listen((state) {
      if (state.event == AuthChangeEvent.passwordRecovery) _setRecovery(true);
      if (state.event == AuthChangeEvent.signedOut) _setRecovery(false);
    }, onError: (Object _) {});
  }

  final SupabaseClient _client;
  final Future<bool> Function(Uri url) _launch;
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

  // 로그인을 취소하고 돌아왔거나 세션 갱신이 실패하면 이 흐름으로 오류가 온다. 로그인 상태가
  // 바뀐 것은 아니므로 알리지 않는다(듣는 쪽에서 처리하지 않은 오류로 남지 않게 한다).
  @override
  Stream<AuthUser?> get userChanges => _client.auth.onAuthStateChange
      .handleError((Object _) {})
      .map((state) => _user(state.session?.user))
      .distinct();

  // 웹은 페이지가 로그인 화면으로 갔다가 돌아온다. Android · Windows 앱은 기기의 브라우저에서
  // 로그인하고 [appLoginCallback]으로 돌아온다. 돌아오는 주소를 받는 길이 없는 플랫폼
  // (개발용 Linux 등)에서는 쓰지 않는다.
  @override
  bool get googleAvailable =>
      kIsWeb ||
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.windows;

  /// 웹: 로그인하거나 메일의 링크를 누른 뒤 돌아올 주소. 지금 이 앱의 주소에서 #/화면을 뺀다.
  static String? get _returnUrl =>
      kIsWeb ? '${Uri.base.origin}${Uri.base.path}' : null;

  /// Google 로그인을 마치고 돌아올 주소.
  static String? get googleReturnUrl => kIsWeb ? _returnUrl : appLoginCallback;

  /// 로그인 페이지를 연다. `supabase_flutter`의 `signInWithOAuth`가 하는 것과 같다: 웹은 이
  /// 탭에서, 앱은 기기의 브라우저에서 연다(Google은 앱 안의 웹뷰에서 로그인을 받지 않는다).
  static Future<bool> _openLoginPage(Uri url) => launchUrl(
    url,
    mode: kIsWeb ? LaunchMode.platformDefault : LaunchMode.externalApplication,
    webOnlyWindowName: '_self',
  );

  @override
  Future<void> signInWithGoogle() => _guard(() async {
    // 주소를 만들면서 PKCE 확인값을 기기에 적어 둔다. 돌아온 주소의 코드는 `supabase_flutter`가
    // 듣고 있다가(딥링크) 그 확인값과 함께 세션으로 바꾼다.
    final response = await _client.auth.getOAuthSignInUrl(
      provider: OAuthProvider.google,
      redirectTo: googleReturnUrl,
    );
    final opened = await _launch(Uri.parse(response.url));
    if (!opened) {
      throw const AuthFailure(
        AuthFailureReason.unknown,
        '로그인 페이지를 열 브라우저를 찾지 못했습니다',
      );
    }
  });

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

  @override
  Future<void> deleteAccount() async {
    try {
      await _client.rpc<dynamic>('delete_my_account');
    } on PostgrestException catch (e) {
      // 서버가 거절했다(로그인이 풀렸거나 함수가 실패했다). 아무것도 지워지지 않았다.
      throw AuthFailure(AuthFailureReason.unknown, e.message);
    } on AuthException catch (e) {
      throw AuthFailure(_reason(e), e.message);
    } catch (e) {
      throw AuthFailure(AuthFailureReason.network, '$e');
    }
    // 계정이 없어졌으니 이 기기의 세션도 지운다. 서버에 로그아웃을 알리는 요청은 계정이
    // 없어 실패할 수 있는데, 기기의 세션은 그 전에 지워지므로 넘어간다.
    try {
      await _client.auth.signOut(scope: SignOutScope.local);
    } catch (e) {
      debugPrint('계정을 지운 뒤 로그아웃 요청이 실패했다: $e');
    }
  }
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
