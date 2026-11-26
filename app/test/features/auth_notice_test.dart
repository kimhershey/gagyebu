import 'package:flutter_test/flutter_test.dart';
import 'package:gagyebu/data/server/server_connection.dart';
import 'package:gagyebu/features/auth/auth_frame.dart';
import 'package:material_ui/material_ui.dart';

import '../app/login_sync_test.dart' show FakeAuth;

void main() {
  const key = ValueKey('sign-in-failure');
  const failure = AuthFailure(AuthFailureReason.unknown, 'bad_code_verifier');

  Future<void> pump(WidgetTester tester, FakeAuth? auth) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: SignInFailureNotice(auth: auth)),
    ),
  );

  testWidgets('실패가 없으면 아무것도 보이지 않는다', (tester) async {
    await pump(tester, FakeAuth());
    expect(find.byKey(key), findsNothing);
    await pump(tester, null);
    expect(find.byKey(key), findsNothing);
  });

  testWidgets('화면이 뜨기 전에 와 있던 실패를 알리고, 서버가 준 글은 보이지 않는다', (tester) async {
    final auth = FakeAuth()..pendingFailure = failure;
    await pump(tester, auth);
    expect(find.byKey(key), findsOneWidget);
    expect(find.textContaining('로그인을 마치지 못했습니다'), findsOneWidget);
    expect(find.textContaining('bad_code_verifier'), findsNothing);
    // 한 번 꺼낸 실패는 남지 않는다.
    expect(auth.pendingFailure, isNull);
  });

  testWidgets('떠 있는 동안 온 실패도 알린다', (tester) async {
    final auth = FakeAuth();
    await pump(tester, auth);
    expect(find.byKey(key), findsNothing);
    auth.failures.add(failure);
    await tester.pump();
    await tester.pump();
    expect(find.byKey(key), findsOneWidget);
  });
}
