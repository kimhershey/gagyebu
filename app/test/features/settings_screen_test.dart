import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gagyebu/app/sync_controller.dart';
import 'package:gagyebu/data/server/server_connection.dart';
import 'package:gagyebu/features/settings/settings_screen.dart';

import 'settings_harness.dart';

void main() {
  Future<void> tapKey(WidgetTester tester, String key) async {
    final target = find.byKey(ValueKey(key));
    await tester.scrollUntilVisible(
      target,
      200,
      scrollable: find
          .descendant(
            of: find.byType(SettingsScreen),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  testWidgets('위에서부터 계정 · 화면 · 가계부 · 관리 · 정보 순서다', (tester) async {
    final services = await createTestServices();
    // 모든 칸이 한 번에 그려지게 아주 긴 창을 쓴다.
    await pumpAppWith(
      tester,
      services,
      size: const Size(412, 3000),
      location: '/settings',
    );
    double top(String text) => tester
        .getTopLeft(
          find.descendant(
            of: find.byType(SettingsScreen),
            matching: find.text(text),
          ),
        )
        .dy;
    // 칸의 제목 가운데 '계정'과 '가계부'는 다른 곳에도 나온다(관리 목록, 테마 이름).
    // 그 칸에만 있는 글로 자리를 본다.
    final order = [
      top('이 앱에는 로그인이 들어 있지 않습니다'),
      top('화면'),
      top('테마'),
      top('월 시작일'),
      top('관리'),
      top('정보'),
      top('시험용 메모리'),
    ];
    expect(order, [...order]..sort());
    await disposeApp(tester, services);
  });

  testWidgets('넓은 창에서는 두 칸으로 놓는다', (tester) async {
    final services = await createTestServices();
    await pumpAppWith(tester, services, size: desktop, location: '/settings');
    final left = tester.getTopLeft(find.text('화면')).dx;
    final right = tester.getTopLeft(find.text('관리')).dx;
    expect(right, greaterThan(left + 200));
    // 같은 줄에서 시작한다.
    expect(
      tester.getTopLeft(find.text('관리')).dy,
      tester.getTopLeft(find.text('계정').first).dy,
    );
    await disposeApp(tester, services);
  });

  testWidgets('자산과 분류를 더하고 지우는 칸은 없고, 관리 목록이 그 화면으로 간다', (tester) async {
    final services = await createTestServices();
    await pumpAppWith(tester, services, size: desktop, location: '/settings');
    expect(find.byKey(const ValueKey('add-account')), findsNothing);
    expect(find.text('추가'), findsNothing);
    // 기본 분류 이름이 설정에 늘어서지 않는다.
    expect(find.text('식비'), findsNothing);
    for (final name in [
      'accounts',
      'categories',
      'budget',
      'recurring',
      'history',
      'data',
      'conflicts',
      'lock',
      'models',
      'account',
    ]) {
      expect(find.byKey(ValueKey('link-$name')), findsOneWidget);
    }
    await disposeApp(tester, services);
  });

  testWidgets('관리 목록에서 하위 화면으로 갔다가 설정으로 돌아온다', (tester) async {
    final services = await createTestServices();
    await pumpAppWith(tester, services, size: phone, location: '/settings');
    for (final (link, text) in [
      ('link-data', '내보내기 · 가져오기'),
      ('link-conflicts', '충돌 기록이 없습니다.'),
      ('link-lock', '잠금 번호'),
      ('link-account', '이 앱에는 로그인이 들어 있지 않습니다.\n가계부는 이 기기 안에만 저장되고, 계정이 없습니다.'),
    ]) {
      await tapKey(tester, link);
      expect(find.text(text), findsOneWidget, reason: link);
      await tester.tap(find.byKey(const ValueKey('back-to-settings')));
      await tester.pumpAndSettle();
      expect(find.byType(SettingsScreen), findsOneWidget);
    }
    await disposeApp(tester, services);
  });

  testWidgets('개인정보 처리방침은 저장소의 문서를 브라우저로 연다', (tester) async {
    final services = await createTestServices();
    final opened = <Uri>[];
    await pumpAppWith(
      tester,
      services,
      size: desktop,
      location: '/settings',
      overrides: [
        linkOpenerProvider.overrideWithValue((uri) async {
          opened.add(uri);
          return true;
        }),
      ],
    );
    await tapKey(tester, 'open-privacy');
    expect(opened.single.toString(), privacyPolicyUrl);
    expect(opened.single.host, 'github.com');
    expect(opened.single.path, endsWith('/docs/PRIVACY.md'));
    await disposeApp(tester, services);
  });

  testWidgets('브라우저를 열지 못하면 주소를 보여 준다', (tester) async {
    final services = await createTestServices();
    await pumpAppWith(
      tester,
      services,
      size: desktop,
      location: '/settings',
      overrides: [
        linkOpenerProvider.overrideWithValue(
          (uri) async => throw StateError('열 수 없다'),
        ),
      ],
    );
    await tapKey(tester, 'open-privacy');
    expect(find.textContaining(privacyPolicyUrl), findsOneWidget);
    await disposeApp(tester, services);
  });

  testWidgets('오픈소스 라이선스 화면을 연다', (tester) async {
    final services = await createTestServices();
    await pumpAppWith(tester, services, size: desktop, location: '/settings');
    await tapKey(tester, 'open-licenses');
    expect(find.text('가계부'), findsWidgets);
    expect(find.byType(SettingsScreen), findsNothing);
    await disposeApp(tester, services);
  });

  group('계정 칸은 로그인 상태마다 다르다', () {
    const user = AuthUser(id: 'user-1', email: 'me@example.com');

    testWidgets('로그인해 쉬는 중: 이메일, 지금 동기화, 로그아웃', (tester) async {
      final services = await createTestServices();
      final sync = FakeSyncController(
        SyncStatus(
          SyncPhase.idle,
          user: user,
          lastSyncedAt: DateTime(2026, 11, 17, 15, 7),
        ),
      );
      await pumpAppWith(
        tester,
        services,
        size: desktop,
        location: '/settings',
        sync: sync,
      );
      expect(find.text('me@example.com'), findsOneWidget);
      expect(find.text('오후 3:07에 동기화했습니다'), findsOneWidget);
      expect(find.byKey(const ValueKey('sync-now')), findsOneWidget);
      await tapKey(tester, 'sign-out');
      expect(sync.signOuts, 1);
      expect(find.text('로그인하지 않았습니다'), findsOneWidget);
      await disposeApp(tester, services);
    });

    testWidgets('동기화하는 중에는 지금 동기화가 꺼져 있다', (tester) async {
      final services = await createTestServices();
      await pumpAppWith(
        tester,
        services,
        size: desktop,
        location: '/settings',
        sync: FakeSyncController(
          const SyncStatus(SyncPhase.syncing, user: user),
        ),
      );
      expect(find.text('동기화하는 중입니다'), findsOneWidget);
      expect(
        tester
            .widget<TextButton>(find.byKey(const ValueKey('sync-now')))
            .onPressed,
        isNull,
      );
      await disposeApp(tester, services);
    });

    testWidgets('실패했으면 다시 시도한다고 알린다', (tester) async {
      final services = await createTestServices();
      await pumpAppWith(
        tester,
        services,
        size: desktop,
        location: '/settings',
        sync: FakeSyncController(
          const SyncStatus(SyncPhase.failed, user: user, error: 'boom'),
        ),
      );
      expect(find.textContaining('동기화하지 못했습니다. 잠시 뒤 다시 시도합니다'), findsOneWidget);
      await disposeApp(tester, services);
    });

    testWidgets('다른 계정의 가계부가 있으면 지우고 받을지 묻는다', (tester) async {
      final services = await createTestServices();
      await pumpAppWith(
        tester,
        services,
        size: desktop,
        location: '/settings',
        sync: FakeSyncController(
          const SyncStatus(SyncPhase.differentAccount, user: user),
        ),
      );
      expect(find.text('이 기기에는 다른 계정의 가계부가 있습니다'), findsOneWidget);
      expect(find.byKey(const ValueKey('replace-local')), findsOneWidget);
      expect(find.byKey(const ValueKey('sync-now')), findsNothing);
      await disposeApp(tester, services);
    });
  });

  group('넘치지 않는다', () {
    for (final (name, size) in fourSizes) {
      testWidgets(name, (tester) async {
        final services = await createTestServices();
        await pumpAppWith(
          tester,
          services,
          size: size,
          location: '/settings',
          sync: FakeSyncController(
            const SyncStatus(
              SyncPhase.differentAccount,
              user: AuthUser(
                id: 'u',
                email: 'a-very-long-address-for-testing@example-company.co.kr',
              ),
            ),
          ),
        );
        expect(tester.takeException(), isNull);
        // 맨 아래까지 내려 본다.
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('open-privacy')),
          200,
          scrollable: find
              .descendant(
                of: find.byType(SettingsScreen),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        expect(tester.takeException(), isNull);
        await disposeApp(tester, services);
      });
    }
  });
}
