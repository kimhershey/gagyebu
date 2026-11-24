import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gagyebu/data/server/server_connection.dart';
import 'package:gagyebu/data/server/supabase_connection.dart';
import 'package:gagyebu/data/sync/sync_gateway.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthUser;
import 'package:web_socket_channel/web_socket_channel.dart';

/// PKCE 확인값을 메모리에 두는 저장소.
class _MemoryStorage extends GotrueAsyncStorage {
  final values = <String, String>{};

  @override
  Future<String?> getItem({required String key}) async => values[key];

  @override
  Future<void> setItem({required String key, required String value}) async =>
      values[key] = value;

  @override
  Future<void> removeItem({required String key}) async => values.remove(key);
}

/// 실시간 서버 흉내: 기기가 보낸 메시지를 모으고, 채널에 들어오겠다는 요청에는 승낙한다.
class _FakeSocket extends StreamChannelMixin<dynamic>
    implements WebSocketChannel {
  _FakeSocket(this.url);

  final String url;
  final _incoming = StreamController<dynamic>();

  /// 기기가 보낸 메시지: [join_ref, ref, topic, event, payload].
  final sent = <List<Object?>>[];

  @override
  Future<void> get ready async {}

  @override
  Stream<dynamic> get stream => _incoming.stream;

  @override
  late final WebSocketSink sink = _FakeSink(this);

  @override
  int? get closeCode => null;

  @override
  String? get closeReason => null;

  @override
  String? get protocol => null;

  void _receive(Object? data) {
    final message = (jsonDecode(data as String) as List).cast<Object?>();
    sent.add(message);
    if (message[3] == 'phx_join' || message[3] == 'heartbeat') {
      serverSends(message[0], message[1], message[2] as String, 'phx_reply', {
        'status': 'ok',
        'response': <String, Object?>{},
      });
    }
  }

  void serverSends(
    Object? joinRef,
    Object? ref,
    String topic,
    String event,
    Map<String, Object?> payload,
  ) {
    if (_incoming.isClosed) return;
    _incoming.add(jsonEncode([joinRef, ref, topic, event, payload]));
  }
}

class _FakeSink implements WebSocketSink {
  _FakeSink(this._socket);

  final _FakeSocket _socket;
  final _done = Completer<void>();

  @override
  void add(Object? data) => _socket._receive(data);

  @override
  void addError(Object error, [StackTrace? stackTrace]) {}

  @override
  Future<void> addStream(Stream<dynamic> stream) => stream.forEach(add);

  @override
  Future<void> close([int? closeCode, String? closeReason]) async {
    if (!_done.isCompleted) _done.complete();
    await _socket._incoming.close();
  }

  @override
  Future<void> get done => _done.future;
}

void main() {
  final requests = <http.Request>[];

  /// [answers]의 경로별 답을 돌려주는 가짜 서버에 붙은 클라이언트.
  SupabaseClient client(Map<String, Object?> answers) {
    requests.clear();
    return SupabaseClient(
      'https://example.supabase.co',
      'sb_publishable_test',
      httpClient: MockClient((request) async {
        requests.add(request);
        final answer = answers[request.url.path];
        return http.Response(
          jsonEncode(answer),
          answer == null ? 404 : 200,
          headers: {'content-type': 'application/json; charset=utf-8'},
          request: request,
        );
      }),
    );
  }

  test('push는 sync_push 함수를 규약의 인자 이름으로 부른다', () async {
    final supabase = client({
      '/rest/v1/rpc/sync_push': {
        'results': [
          {
            'table': 'transactions',
            'id': 'tx-1',
            'status': 'applied',
            'version': 1,
            'server_seq': 42,
            'server_row': null,
            'error': null,
          },
        ],
        'max_server_seq': 42,
      },
    });
    final response = await SupabaseSyncGateway(supabase).push(
      ledgerId: 'ledger-1',
      deviceId: 'device-1',
      batchId: 'batch-1',
      changes: [
        PushChange(
          table: 'transactions',
          op: 'upsert',
          id: 'tx-1',
          baseVersion: 0,
          clientUpdatedAt: DateTime.utc(2026, 11, 17, 3),
          data: const {'amount': 8000, 'receiver': '김밥천국'},
        ),
      ],
    );

    final request = requests.single;
    expect(request.method, 'POST');
    expect(request.url.path, '/rest/v1/rpc/sync_push');
    expect(request.headers['apikey'], 'sb_publishable_test');
    final body = jsonDecode(utf8.decode(request.bodyBytes)) as Map;
    expect(body.keys, {
      'p_ledger_id',
      'p_device_id',
      'p_batch_id',
      'p_changes',
    });
    expect(body['p_ledger_id'], 'ledger-1');
    final change = (body['p_changes'] as List).single as Map;
    expect(change['table'], 'transactions');
    expect(change['base_version'], 0);
    expect(change['client_updated_at'], '2026-11-17T03:00:00.000Z');
    expect((change['data'] as Map)['receiver'], '김밥천국');

    expect(response.results.single.status, PushResult.applied);
    expect(response.results.single.serverSeq, 42);
    expect(response.maxServerSeq, 42);
  });

  test('pull은 sync_pull 함수를 부르고 커서를 넘긴다', () async {
    final supabase = client({
      '/rest/v1/rpc/sync_pull': {
        'changes': [
          {
            'table': 'categories',
            'row': {'id': 'cat-1', 'name': '식비', 'server_seq': 7},
          },
        ],
        'next_seq': 7,
        'has_more': false,
      },
    });
    final response = await SupabaseSyncGateway(supabase)
        .pull(ledgerId: 'ledger-1', since: 3, limit: 100);

    final body = jsonDecode(utf8.decode(requests.single.bodyBytes)) as Map;
    expect(body, {'p_ledger_id': 'ledger-1', 'p_since': 3, 'p_limit': 100});
    expect(response.changes.single.table, 'categories');
    expect(response.changes.single.row['name'], '식비');
    expect(response.nextSeq, 7);
    expect(response.hasMore, isFalse);
  });

  test('계정의 가계부는 프로필에서 찾는다', () async {
    final supabase = client({
      '/rest/v1/profiles': {'ledger_id': 'ledger-1'},
    });
    final connection = supabaseConnection(supabase);
    expect(await connection.ledgerIdOf('user-1'), 'ledger-1');
    final request = requests.single;
    expect(request.method, 'GET');
    expect(request.url.queryParameters['id'], 'eq.user-1');
    expect(request.url.queryParameters['select'], 'ledger_id');
  });

  test('서버가 거절하면 예외로 알린다', () async {
    final supabase = client(const {});
    await expectLater(
      SupabaseSyncGateway(supabase).pull(ledgerId: 'ledger-1', since: 0),
      throwsA(isA<PostgrestException>()),
    );
  });

  group('이메일 로그인', () {
    /// 로그인 요청마다 [status]와 [body]로 답하는 서버에 붙은 로그인 서비스.
    SupabaseAuthService auth(int status, Map<String, Object?> body) {
      requests.clear();
      return SupabaseAuthService(
        SupabaseClient(
          'https://example.supabase.co',
          'sb_publishable_test',
          authOptions: const AuthClientOptions(
            authFlowType: AuthFlowType.implicit,
            autoRefreshToken: false,
          ),
          httpClient: MockClient((request) async {
            requests.add(request);
            return http.Response(
              jsonEncode(body),
              status,
              headers: {'content-type': 'application/json; charset=utf-8'},
              request: request,
            );
          }),
        ),
      );
    }

    Map<String, Object?> user({required List<Object?> identities}) => {
      'id': '00000000-0000-4000-8000-000000000001',
      'aud': 'authenticated',
      'email': 'new@example.com',
      'app_metadata': <String, Object?>{},
      'user_metadata': <String, Object?>{},
      'identities': identities,
      'created_at': '2026-11-24T00:00:00Z',
    };

    Matcher fails(AuthFailureReason reason) =>
        throwsA(isA<AuthFailure>().having((f) => f.reason, 'reason', reason));

    test('비밀번호가 틀리면 그 까닭을 알려 준다', () async {
      final service = auth(400, {
        'code': 400,
        'error_code': 'invalid_credentials',
        'msg': 'Invalid login credentials',
      });
      await expectLater(
        service.signInWithPassword(email: 'me@example.com', password: 'nope'),
        fails(AuthFailureReason.invalidCredentials),
      );
      expect(requests.single.url.path, '/auth/v1/token');
      expect(requests.single.url.queryParameters['grant_type'], 'password');
    });

    test('메일 확인이 끝나지 않은 계정은 따로 알려 준다', () async {
      final service = auth(400, {
        'code': 400,
        'error_code': 'email_not_confirmed',
        'msg': 'Email not confirmed',
      });
      await expectLater(
        service.signInWithPassword(email: 'me@example.com', password: 'pw'),
        fails(AuthFailureReason.emailNotConfirmed),
      );
    });

    test('가입하면 확인 메일을 보냈다고 답한다', () async {
      final service = auth(
        200,
        user(
          identities: [
            {
              'id': 'i-1',
              'identity_id': 'i-1',
              'user_id': '00000000-0000-4000-8000-000000000001',
              'identity_data': <String, Object?>{},
              'provider': 'email',
              'created_at': '2026-11-24T00:00:00Z',
              'last_sign_in_at': '2026-11-24T00:00:00Z',
            },
          ],
        ),
      );
      expect(
        await service.signUpWithPassword(
          email: 'new@example.com',
          password: 'secret2',
        ),
        SignUpResult.confirmationSent,
      );
      expect(requests.single.url.path, '/auth/v1/signup');
    });

    test('이미 가입한 주소면 서버가 오류 없이 답해도 알아본다', () async {
      final service = auth(200, user(identities: const []));
      await expectLater(
        service.signUpWithPassword(
          email: 'new@example.com',
          password: 'secret2',
        ),
        fails(AuthFailureReason.alreadyRegistered),
      );
    });

    test('확인 메일을 너무 자주 보내면 잠시 뒤에 하라고 알려 준다', () async {
      final service = auth(429, {
        'code': 429,
        'error_code': 'over_email_send_rate_limit',
        'msg': 'email rate limit exceeded',
      });
      await expectLater(
        service.signUpWithPassword(
          email: 'new@example.com',
          password: 'secret2',
        ),
        fails(AuthFailureReason.rateLimited),
      );
    });
  });

  /// 경로마다 [answer]가 고른 (상태, 본문)으로 답하는 서버에 붙은 클라이언트. PKCE로 로그인한다.
  SupabaseClient routed(
    (int, Object?) Function(http.Request request) answer, {
    RealtimeClientOptions realtime = const RealtimeClientOptions(),
  }) {
    requests.clear();
    return SupabaseClient(
      'https://example.supabase.co',
      'sb_publishable_test',
      authOptions: AuthClientOptions(
        authFlowType: AuthFlowType.pkce,
        autoRefreshToken: false,
        pkceAsyncStorage: _MemoryStorage(),
      ),
      realtimeClientOptions: realtime,
      httpClient: MockClient((request) async {
        requests.add(request);
        final (status, body) = answer(request);
        return http.Response(
          body == null ? '' : jsonEncode(body),
          status,
          headers: {'content-type': 'application/json; charset=utf-8'},
          request: request,
        );
      }),
    );
  }

  /// 로그인에 성공했을 때 서버가 주는 세션.
  const session = <String, Object?>{
    'access_token': 'user-token',
    'token_type': 'bearer',
    'expires_in': 3600,
    'refresh_token': 'refresh-token',
    'user': {
      'id': '00000000-0000-4000-8000-000000000001',
      'aud': 'authenticated',
      'email': 'me@example.com',
      'app_metadata': <String, Object?>{},
      'user_metadata': <String, Object?>{},
      'created_at': '2026-11-24T00:00:00Z',
    },
  };

  group('앱에서의 Google 로그인', () {
    tearDown(() => debugDefaultTargetPlatformOverride = null);

    test('Android와 Windows 앱에서 쓸 수 있다', () {
      final service = SupabaseAuthService(routed((_) => (404, null)));
      for (final platform in TargetPlatform.values) {
        debugDefaultTargetPlatformOverride = platform;
        expect(
          service.googleAvailable,
          platform == TargetPlatform.android ||
              platform == TargetPlatform.windows,
          reason: '$platform',
        );
      }
    });

    test('로그인 페이지를 열 때 앱으로 돌아올 주소를 넘긴다', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final opened = <Uri>[];
      final service = SupabaseAuthService(
        routed((_) => (404, null)),
        launch: (url) async {
          opened.add(url);
          return true;
        },
      );
      await service.signInWithGoogle();

      final url = opened.single;
      expect(url.host, 'example.supabase.co');
      expect(url.path, '/auth/v1/authorize');
      expect(url.queryParameters['provider'], 'google');
      expect(
        url.queryParameters['redirect_to'],
        'io.github.kimhershey.gagyebu://login-callback',
      );
      // 코드를 가로채도 세션으로 바꾸지 못하게 PKCE를 쓴다.
      expect(url.queryParameters['code_challenge'], isNotEmpty);
      expect(url.queryParameters['code_challenge_method'], 's256');
      // 주소를 만드는 데는 서버에 묻지 않는다.
      expect(requests, isEmpty);
    });

    test('돌아온 주소의 코드를 세션으로 바꾼다', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      final supabase = routed(
        (request) =>
            request.url.path == '/auth/v1/token' ? (200, session) : (404, null),
      );
      final service = SupabaseAuthService(supabase, launch: (_) async => true);
      final users = <AuthUser?>[];
      final subscription = service.userChanges.listen(users.add);
      await service.signInWithGoogle();
      expect(service.currentUser, isNull);

      // 브라우저가 앱으로 돌려보낸 주소. `supabase_flutter`가 딥링크로 받아 이렇게 넘긴다.
      await supabase.auth.getSessionFromUrl(
        Uri.parse('$appLoginCallback?code=auth-code-1'),
      );
      await Future<void>.delayed(Duration.zero);

      final request = requests.single;
      expect(request.method, 'POST');
      expect(request.url.path, '/auth/v1/token');
      expect(request.url.queryParameters['grant_type'], 'pkce');
      final body = jsonDecode(utf8.decode(request.bodyBytes)) as Map;
      expect(body['auth_code'], 'auth-code-1');
      expect(body['code_verifier'], isNotEmpty);
      expect(service.currentUser?.email, 'me@example.com');
      expect(users.last?.id, '00000000-0000-4000-8000-000000000001');
      await subscription.cancel();
    });

    test('로그인을 취소하고 돌아오면 세션을 만들지 않는다', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final supabase = routed((_) => (200, session));
      final service = SupabaseAuthService(supabase, launch: (_) async => true);
      await service.signInWithGoogle();
      await expectLater(
        supabase.auth.getSessionFromUrl(
          Uri.parse(
            '$appLoginCallback?error=access_denied&error_description=denied',
          ),
        ),
        throwsA(isA<AuthException>()),
      );
      expect(requests, isEmpty);
      expect(service.currentUser, isNull);
    });

    test('브라우저를 열지 못하면 실패로 알린다', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      final service = SupabaseAuthService(
        routed((_) => (404, null)),
        launch: (_) async => false,
      );
      await expectLater(
        service.signInWithGoogle(),
        throwsA(isA<AuthFailure>()),
      );
    });
  });

  group('계정 삭제', () {
    /// 이메일로 로그인해 둔 서비스. [deleteStatus]는 delete_my_account의 답이다.
    Future<(SupabaseClient, SupabaseAuthService)> signedIn(
      int deleteStatus,
    ) async {
      final supabase = routed(
        (request) => switch (request.url.path) {
          '/auth/v1/token' => (200, session),
          '/rest/v1/rpc/delete_my_account' =>
            deleteStatus == 204
                ? (204, null)
                : (deleteStatus, {'message': 'permission denied'}),
          // 계정이 없어진 뒤의 로그아웃 요청은 거절된다.
          '/auth/v1/logout' => (403, {'msg': 'User not found'}),
          _ => (404, null),
        },
      );
      final service = SupabaseAuthService(supabase);
      await service.signInWithPassword(
        email: 'me@example.com',
        password: 'secret1',
      );
      expect(service.currentUser, isNotNull);
      requests.clear();
      return (supabase, service);
    }

    test('delete_my_account를 로그인한 사용자로 부르고 기기의 세션을 지운다', () async {
      final (supabase, service) = await signedIn(204);
      final users = <AuthUser?>[];
      final subscription = service.userChanges.listen(users.add);
      await service.deleteAccount();
      await Future<void>.delayed(Duration.zero);

      final call = requests.first;
      expect(call.method, 'POST');
      expect(call.url.path, '/rest/v1/rpc/delete_my_account');
      expect(call.headers['Authorization'], 'Bearer user-token');
      expect(service.currentUser, isNull);
      expect(supabase.auth.currentSession, isNull);
      expect(users.last, isNull);
      await subscription.cancel();
    });

    test('서버가 거절하면 실패로 알리고 로그인한 채로 둔다', () async {
      final (_, service) = await signedIn(403);
      await expectLater(
        service.deleteAccount(),
        throwsA(
          isA<AuthFailure>().having(
            (f) => f.reason,
            'reason',
            AuthFailureReason.unknown,
          ),
        ),
      );
      expect(requests.single.url.path, '/rest/v1/rpc/delete_my_account');
      expect(service.currentUser, isNotNull);
    });
  });

  group('실시간 신호', () {
    test('비공개 채널 ledger:<가계부>를 구독하고 changed 신호를 알린다', () async {
      final sockets = <_FakeSocket>[];
      final supabase = routed(
        (_) => (404, null),
        realtime: RealtimeClientOptions(
          transport: (url, headers) {
            final socket = _FakeSocket(url);
            sockets.add(socket);
            return socket;
          },
          disconnectOnEmptyChannelsAfter: Duration.zero,
        ),
      );
      final connection = supabaseConnection(supabase);
      var signals = 0;
      final subscription = connection.changes!('ledger-1').listen((_) {
        signals++;
      });
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final socket = sockets.single;
      expect(socket.url, startsWith('wss://example.supabase.co/realtime/v1'));
      final join = socket.sent.firstWhere((m) => m[3] == 'phx_join');
      expect(join[2], 'realtime:ledger:ledger-1');
      final config = ((join[4] as Map)['config'] as Map);
      expect(config['private'], isTrue);

      // 서버가 변경을 알린다. 다른 이름의 신호는 지나친다.
      socket.serverSends(null, null, 'realtime:ledger:ledger-1', 'broadcast', {
        'type': 'broadcast',
        'event': 'changed',
        'payload': {'server_seq': 42},
      });
      socket.serverSends(null, null, 'realtime:ledger:ledger-1', 'broadcast', {
        'type': 'broadcast',
        'event': 'other',
        'payload': <String, Object?>{},
      });
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(signals, 1);

      // 그만 들으면 채널에서 나간다.
      await subscription.cancel();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(socket.sent.any((m) => m[3] == 'phx_leave'), isTrue);
      expect(supabase.getChannels(), isEmpty);
      await supabase.dispose();
    });
  });
}
