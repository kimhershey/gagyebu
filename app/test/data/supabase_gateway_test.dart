import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:gagyebu/data/server/server_connection.dart';
import 'package:gagyebu/data/server/supabase_connection.dart';
import 'package:gagyebu/data/sync/sync_gateway.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthUser;

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
}
