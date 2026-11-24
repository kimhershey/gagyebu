import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gagyebu/app/bootstrap.dart';
import 'package:gagyebu/app/providers.dart';
import 'package:gagyebu/core/local_date.dart';
import 'package:gagyebu/data/db/database.dart';
import 'package:gagyebu/data/repositories/ledger_repository.dart';
import 'package:gagyebu/data/server/server_connection.dart';
import 'package:gagyebu/data/sync/ledger_adoption.dart';
import 'package:gagyebu/data/sync/sync_engine.dart';
import 'package:gagyebu/data/sync/sync_gateway.dart';
import 'package:gagyebu/domain/enums.dart';

import '../data/fake_sync_server.dart';
import '../features/test_app.dart';
import 'login_sync_test.dart' show FakeAuth;

/// 받기를 한 번 실패하게 할 수 있는 서버.
class _FlakyGateway implements SyncGateway {
  _FlakyGateway(this._inner);

  final SyncGateway _inner;
  bool failNextPull = false;

  @override
  Future<PushResponse> push({
    required String ledgerId,
    required String deviceId,
    required String batchId,
    required List<PushChange> changes,
  }) => _inner.push(
    ledgerId: ledgerId,
    deviceId: deviceId,
    batchId: batchId,
    changes: changes,
  );

  @override
  Future<PullResponse> pull({
    required String ledgerId,
    required int since,
    int limit = 500,
  }) async {
    if (failNextPull) {
      failNextPull = false;
      throw Exception('offline');
    }
    return _inner.pull(ledgerId: ledgerId, since: since, limit: limit);
  }
}

/// 실시간 신호(`docs/SPEC.md` 4.4): 서버가 신호를 내면 기다리지 않고 받는다.
void main() {
  late Directory dir;
  late FakeSyncServer server;
  late _FlakyGateway gateway;
  late FakeAuth auth;
  late String ledgerId;
  final opened = <AppServices>[];

  /// 구독 중인 채널: 가계부 ID → 신호를 내는 자리.
  final channels = <String, StreamController<void>>{};

  /// 지금까지 구독한 가계부 ID(끊은 것도 남긴다).
  final subscribed = <String>[];

  setUp(() {
    dir = Directory.systemTemp.createTempSync('gagyebu-realtime-test');
    server = FakeSyncServer(clock: DateTime.now);
    gateway = _FlakyGateway(server);
    auth = FakeAuth();
    ledgerId = server.seedLedger(ownerId: 'user-1');
    opened.clear();
    channels.clear();
    subscribed.clear();
  });

  tearDown(() => dir.deleteSync(recursive: true));

  Stream<void> changes(String id) {
    late final StreamController<void> controller;
    controller = StreamController<void>(
      onListen: () {
        subscribed.add(id);
        channels[id] = controller;
      },
      onCancel: () => channels.remove(id),
    );
    return controller.stream;
  }

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
        gateway: gateway,
        ledgerIdOf: (userId) async => userId == 'user-1' ? ledgerId : null,
        changes: changes,
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

  Future<void> signIn(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('welcome-login')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('auth-google')));
    await settle(tester);
  }

  /// 앱을 띄우고 로그인한다. 가계부가 맞춰지고 첫 동기화가 끝난 상태가 된다.
  Future<void> startSignedIn(WidgetTester tester) async {
    tester.view.physicalSize = desktop;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(Bootstrap(open: open));
    await tester.pumpAndSettle();
    // 로그인하기 전에는 듣지 않는다.
    expect(subscribed, isEmpty);
    await signIn(tester);
    expect(opened.last.ledgerId, ledgerId);
  }

  /// 같은 계정의 다른 기기가 거래를 하나 올린다.
  Future<void> pushFromOtherDevice(String counterparty) async {
    final db = AppDatabase(NativeDatabase.memory());
    final repo = LedgerRepository(db);
    final engine = SyncEngine(db: db, gateway: server, deviceId: 'other');
    await LedgerAdoption(db: db, engine: engine, repository: repo).adopt(
      userId: 'user-1',
      serverLedgerId: ledgerId,
      localLedgerId: await repo.ensureLocalLedger(),
    );
    final cash = (await repo.accounts(ledgerId)).single.id;
    await repo.addTransaction(
      ledgerId,
      TransactionInput(
        type: TxType.expense,
        occurredOn: LocalDate(2026, 11, 16),
        amount: 4500,
        accountId: cash,
        counterparty: counterparty,
      ),
    );
    await engine.syncOnce(ledgerId);
    await db.close();
  }

  Future<List<String?>> localReceivers() async {
    final db = opened.last.db;
    final rows = await db.select(db.ledgerTransactions).get();
    return [for (final row in rows) row.receiver];
  }

  testWidgets('가계부가 맞춰지면 그 가계부의 채널을 듣고, 신호를 받으면 1초 안에 받는다', (tester) async {
    await startSignedIn(tester);
    // 기기에만 있던 가계부(서버에 없는 ID)의 채널은 듣지 않는다.
    expect(subscribed, [ledgerId]);
    expect(channels.keys, [ledgerId]);

    await pushFromOtherDevice('카페');
    expect(await localReceivers(), isEmpty);

    channels[ledgerId]!.add(null);
    // 0.5초 모으는 동안에는 아직 받지 않는다.
    await tester.pump(const Duration(milliseconds: 400));
    expect(await localReceivers(), isEmpty);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 300));
    expect(await localReceivers(), ['카페']);

    await disposeApp(tester, opened.last);
    expect(channels, isEmpty);
  });

  testWidgets('신호가 여러 개 와도 받기는 한 번만 돈다', (tester) async {
    await startSignedIn(tester);
    await pushFromOtherDevice('카페');

    final before = server.pullCalls;
    for (var i = 0; i < 5; i++) {
      channels[ledgerId]!.add(null);
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(await localReceivers(), ['카페']);
    expect(server.pullCalls - before, 1);

    // 모은 것을 다 쓴 뒤의 신호는 새로 한 번 돈다.
    channels[ledgerId]!.add(null);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(server.pullCalls - before, 2);

    await disposeApp(tester, opened.last);
  });

  testWidgets('로그아웃하면 구독을 끊고, 기다리던 받기도 돌지 않는다', (tester) async {
    await startSignedIn(tester);
    final channel = channels[ledgerId]!;
    channel.add(null);
    await tester.pump(const Duration(milliseconds: 100));
    final before = server.pullCalls;

    await auth.signOut();
    await settle(tester);
    expect(find.byKey(const ValueKey('welcome-login')), findsOneWidget);
    expect(channel.hasListener, isFalse);
    expect(channels, isEmpty);
    await tester.pump(const Duration(seconds: 1));
    expect(server.pullCalls, before);

    // 다시 로그인하면 다시 듣는다.
    await signIn(tester);
    expect(subscribed, [ledgerId, ledgerId]);
    expect(channels.keys, [ledgerId]);

    await disposeApp(tester, opened.last);
  });

  testWidgets('동기화가 잠깐 실패해도 구독은 그대로 둔다', (tester) async {
    await startSignedIn(tester);
    final channel = channels[ledgerId]!;

    gateway.failNextPull = true;
    channel.add(null);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(gateway.failNextPull, isFalse);
    expect(channel.hasListener, isTrue);
    expect(subscribed, [ledgerId]);

    // 다음 신호에는 다시 받는다.
    await pushFromOtherDevice('카페');
    channel.add(null);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(await localReceivers(), ['카페']);

    await disposeApp(tester, opened.last);
  });
}
