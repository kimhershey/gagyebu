import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthUser;

import '../sync/sync_gateway.dart';
import 'server_config.dart';
import 'server_connection.dart';

/// Supabase에 연결한다. 저장해 둔 로그인 세션이 있으면 되살린다.
Future<ServerConnection> connectSupabase(ServerConfig config) async {
  final supabase = await Supabase.initialize(
    url: config.url,
    publishableKey: config.publishableKey,
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,
    ),
  );
  return supabaseConnection(supabase.client);
}

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
  SupabaseAuthService(this._client);

  final SupabaseClient _client;

  static AuthUser? _user(User? user) =>
      user == null ? null : AuthUser(id: user.id, email: user.email);

  @override
  AuthUser? get currentUser => _user(_client.auth.currentUser);

  @override
  Stream<AuthUser?> get userChanges => _client.auth.onAuthStateChange
      .map((state) => _user(state.session?.user))
      .distinct();

  // Windows · Android 앱은 브라우저에서 로그인하고 앱으로 돌아오는 주소를 등록해야 한다.
  // 그 작업 전까지는 웹에서만 로그인한다.
  @override
  bool get canSignInHere => kIsWeb;

  @override
  Future<void> signInWithGoogle() async {
    await _client.auth.signInWithOAuth(
      OAuthProvider.google,
      // 웹: 로그인한 뒤 지금 이 앱의 주소로 돌아온다(주소 뒤의 #/화면은 뺀다).
      redirectTo: kIsWeb ? '${Uri.base.origin}${Uri.base.path}' : null,
    );
  }

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
