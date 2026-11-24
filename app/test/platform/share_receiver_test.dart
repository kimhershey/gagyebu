import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gagyebu/app/bootstrap.dart';
import 'package:gagyebu/app/providers.dart';
import 'package:gagyebu/data/db/database.dart';
import 'package:gagyebu/data/repositories/ledger_repository.dart';
import 'package:gagyebu/data/server/server_connection.dart';
import 'package:gagyebu/platform/share_receiver.dart';

import '../app/login_sync_test.dart' show FakeAuth;
import '../data/fake_sync_server.dart';
import '../features/test_app.dart';

/// 기기 쪽(`MainActivity`)을 흉내 낸다: 받은 글을 들고 있다가 `take`에 내주고, 새로 받으면
/// `changed`로 알린다.
class FakeShareHost {
  FakeShareHost() {
    _messenger.setMockMethodCallHandler(_channel, (call) async {
      calls.add(call.method);
      if (call.method != 'take') return null;
      final text = pending;
      pending = null;
      return text;
    });
  }

  static const _channel = MethodChannel(ShareReceiver.channelName);

  static TestDefaultBinaryMessenger get _messenger =>
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  /// 앱이 아직 가져가지 않은 글.
  String? pending;

  /// 앱이 부른 것들.
  final calls = <String>[];

  /// 앱이 떠 있는 동안 다른 앱이 글을 공유한다.
  Future<void> share(String text) async {
    pending = text;
    await _messenger.handlePlatformMessage(
      ShareReceiver.channelName,
      const StandardMethodCodec().encodeMethodCall(const MethodCall('changed')),
      (_) {},
    );
  }

  void dispose() => _messenger.setMockMethodCallHandler(_channel, null);
}

const _sms = '[Web발신] 신한카드(1234) 승인 홍*동 12,500원 일시불 11/24 12:30 김밥천국';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeShareHost host;

  setUp(() => host = FakeShareHost());
  tearDown(() {
    host.dispose();
    debugDefaultTargetPlatformOverride = null;
  });

  group('공유로 받은 글', () {
    setUp(() => debugDefaultTargetPlatformOverride = TargetPlatform.android);

    test('듣기 시작하면 앱을 띄운 공유부터 가져온다', () async {
      host.pending = _sms;
      final receiver = ShareReceiver();
      final texts = <String>[];
      final subscription = receiver.texts.listen(texts.add);
      await pumpEventQueue();
      expect(texts, [_sms]);
      expect(host.pending, isNull);

      await subscription.cancel();
      receiver.dispose();
    });

    test('앱이 떠 있는 동안 받은 글도 알림을 받고 가져온다', () async {
      final receiver = ShareReceiver();
      final texts = <String>[];
      final subscription = receiver.texts.listen(texts.add);
      await pumpEventQueue();
      expect(texts, isEmpty);

      await host.share(_sms);
      await host.share('두 번째 글');
      await pumpEventQueue();
      expect(texts, [_sms, '두 번째 글']);

      // 그만 들으면 알림이 와도 가져가지 않는다.
      await subscription.cancel();
      await host.share('세 번째 글');
      await pumpEventQueue();
      expect(host.pending, '세 번째 글');
      receiver.dispose();
    });

    test('빈 글은 넘기지 않는다', () async {
      host.pending = '  \n';
      final receiver = ShareReceiver();
      final texts = <String>[];
      final subscription = receiver.texts.listen(texts.add);
      await pumpEventQueue();
      expect(texts, isEmpty);
      await subscription.cancel();
      receiver.dispose();
    });

    test('기기 쪽 코드가 없어도 조용히 넘어간다', () async {
      host.dispose();
      final receiver = ShareReceiver();
      final texts = <String>[];
      final errors = <Object>[];
      final subscription = receiver.texts.listen(
        texts.add,
        onError: errors.add,
      );
      await pumpEventQueue();
      expect(texts, isEmpty);
      expect(errors, isEmpty);
      await subscription.cancel();
      receiver.dispose();
    });

    test('Android가 아니면 아무 일도 하지 않는다', () async {
      for (final platform in [TargetPlatform.windows, TargetPlatform.linux]) {
        debugDefaultTargetPlatformOverride = platform;
        host.pending = _sms;
        final receiver = ShareReceiver();
        final texts = <String>[];
        final subscription = receiver.texts.listen(texts.add);
        await pumpEventQueue();
        expect(texts, isEmpty, reason: '$platform');
        expect(host.calls, isEmpty, reason: '$platform');
        await subscription.cancel();
        receiver.dispose();
      }
    });
  });

  group('받은 글을 입력창에 채운다', () {
    late Directory dir;
    late FakeSyncServer server;
    late FakeAuth auth;
    late Map<String, String> ledgers;
    final opened = <AppServices>[];

    setUp(() {
      dir = Directory.systemTemp.createTempSync('gagyebu-share-test');
      server = FakeSyncServer(clock: DateTime.now);
      auth = FakeAuth();
      ledgers = {'user-1': server.seedLedger(ownerId: 'user-1')};
      opened.clear();
    });

    tearDown(() => dir.deleteSync(recursive: true));

    Future<AppServices> open() async {
      final db = AppDatabase(NativeDatabase(File('${dir.path}/app.sqlite')));
      final repository = LedgerRepository(db);
      final services = AppServices(
        db: db,
        repository: repository,
        ledgerId: await repository.ensureLocalLedger(),
        storage: '시험용 파일',
        persistent: true,
        server: ServerConnection(
          auth: auth,
          gateway: server,
          ledgerIdOf: (userId) async => ledgers[userId],
        ),
        showWelcome: auth.currentUser == null,
      );
      opened.add(services);
      return services;
    }

    Future<void> settle(WidgetTester tester) async {
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.pumpAndSettle();
    }

    Future<void> start(
      WidgetTester tester, {
      Future<AppServices> Function()? openWith,
    }) async {
      tester.view.physicalSize = phone;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(Bootstrap(open: openWith ?? open));
      await settle(tester);
    }

    Future<int> savedTransactions() async {
      final db = opened.last.db;
      return (await db.select(db.ledgerTransactions).get()).length;
    }

    testWidgets('앱이 꺼져 있을 때 받은 글은 켜진 뒤에 채운다', (tester) async {
      auth.currentUser = const AuthUser(id: 'user-1', email: 'me@example.com');
      host.pending = _sms;
      await start(tester);

      expect(find.byKey(const ValueKey('nav-bottom')), findsOneWidget);
      expect(find.text(_sms), findsOneWidget);
      // 채우기만 한다. 바로 저장하지 않는다.
      expect(await savedTransactions(), 0);
      expect(host.pending, isNull);
      await disposeApp(tester, opened.last);
    });

    testWidgets('앱이 떠 있는 동안 받은 글도 채운다', (tester) async {
      auth.currentUser = const AuthUser(id: 'user-1', email: 'me@example.com');
      await start(tester);
      expect(find.text(_sms), findsNothing);

      await host.share(_sms);
      await settle(tester);
      expect(find.text(_sms), findsOneWidget);
      expect(await savedTransactions(), 0);
      expect(host.pending, isNull);
      await disposeApp(tester, opened.last);
    });

    testWidgets('로그인 전에 받은 글은 로그인한 뒤에 채운다', (tester) async {
      host.pending = _sms;
      await start(tester);

      // 로그인 안내에 머문다. 입력창이 없으니 들고 있는다.
      expect(find.byKey(const ValueKey('welcome-login')), findsOneWidget);
      expect(find.text(_sms), findsNothing);
      expect(host.pending, isNull);

      await tester.tap(find.byKey(const ValueKey('welcome-login')));
      await tester.pumpAndSettle();
      expect(find.text(_sms), findsNothing);
      await tester.tap(find.byKey(const ValueKey('auth-google')));
      await settle(tester);

      // 가계부가 계정의 것으로 바뀌어 앱이 다시 열린 뒤에 채워진다.
      expect(opened, hasLength(2));
      expect(opened.last.ledgerId, ledgers['user-1']);
      expect(find.byKey(const ValueKey('nav-bottom')), findsOneWidget);
      expect(find.text(_sms), findsOneWidget);
      expect(await savedTransactions(), 0);
      await disposeApp(tester, opened.last);
    });

    testWidgets('로그인 전에 여러 번 받으면 마지막 글을 채운다', (tester) async {
      await start(tester);
      await host.share(_sms);
      await host.share('어제 점심 9천원');
      await settle(tester);
      expect(find.text('어제 점심 9천원'), findsNothing);

      await tester.tap(find.byKey(const ValueKey('welcome-login')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('auth-google')));
      await settle(tester);
      expect(find.text('어제 점심 9천원'), findsOneWidget);
      expect(find.text(_sms), findsNothing);
      await disposeApp(tester, opened.last);
    });

    testWidgets('서버에 닿지 못한 채로 켜져도 채운다', (tester) async {
      auth.currentUser = const AuthUser(id: 'user-1', email: 'me@example.com');
      ledgers.clear();
      host.pending = _sms;
      await start(tester);
      expect(find.byKey(const ValueKey('nav-bottom')), findsOneWidget);
      expect(find.text(_sms), findsOneWidget);
      await disposeApp(tester, opened.last);
    });

    testWidgets('로그인이 없는 빌드에서는 켜지자마자 채운다', (tester) async {
      host.pending = _sms;
      await start(
        tester,
        openWith: () async {
          final services = await createTestServices();
          opened.add(services);
          return services;
        },
      );
      expect(find.text(_sms), findsOneWidget);
      await disposeApp(tester, opened.last);
    });
  });
}
