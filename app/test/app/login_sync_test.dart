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
import 'package:gagyebu/domain/enums.dart';

import '../data/fake_sync_server.dart';
import '../features/test_app.dart';

/// 단추를 누르면 바로 로그인되는 가짜 로그인.
class FakeAuth implements AuthService {
  final _changes = StreamController<AuthUser?>.broadcast();

  /// 다음에 로그인할 사용자.
  AuthUser next = const AuthUser(id: 'user-1', email: 'me@example.com');

  @override
  AuthUser? currentUser;

  @override
  bool canSignInHere = true;

  @override
  Stream<AuthUser?> get userChanges => _changes.stream;

  @override
  Future<void> signInWithGoogle() async {
    currentUser = next;
    _changes.add(currentUser);
  }

  @override
  Future<void> signOut() async {
    currentUser = null;
    _changes.add(null);
  }
}

void main() {
  late Directory dir;
  late FakeSyncServer server;
  late FakeAuth auth;
  late Map<String, String> ledgers;
  final opened = <AppServices>[];

  setUp(() {
    dir = Directory.systemTemp.createTempSync('gagyebu-login-test');
    server = FakeSyncServer(clock: DateTime.now);
    auth = FakeAuth();
    ledgers = {'user-1': server.seedLedger(ownerId: 'user-1')};
    opened.clear();
  });

  tearDown(() => dir.deleteSync(recursive: true));

  /// 같은 파일의 DB를 여는 앱 서비스. 다시 열어도 내용이 남는다.
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
    );
    opened.add(services);
    return services;
  }

  Future<void> start(WidgetTester tester) async {
    tester.view.physicalSize = desktop;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(Bootstrap(open: open));
    await tester.pumpAndSettle();
    await tester.tap(find.text('설정').first);
    await tester.pumpAndSettle();
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pumpAndSettle();
  }

  Future<void> addLunch(AppServices services) async {
    final repo = services.repository;
    final cash = (await repo.accounts(services.ledgerId)).first.id;
    await repo.addTransaction(
      services.ledgerId,
      TransactionInput(
        type: TxType.expense,
        occurredOn: LocalDate(2026, 11, 16),
        amount: 8000,
        accountId: cash,
        counterparty: '김밥천국',
      ),
    );
  }

  testWidgets('로그인하면 기기의 가계부를 계정으로 옮기고, 그 뒤의 변경도 올린다', (tester) async {
    await start(tester);
    expect(find.text('로그인하지 않았습니다'), findsOneWidget);

    // 로그인 전에 거래를 하나 적어 둔다.
    await addLunch(opened.single);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('sign-in')));
    await settle(tester);

    // 가계부가 바뀌어 앱이 다시 열렸다. 보던 화면(설정)으로 돌아와 있다.
    expect(opened, hasLength(2));
    expect(opened.last.ledgerId, ledgers['user-1']);
    expect(find.text('me@example.com'), findsOneWidget);
    expect(find.textContaining('동기화했습니다'), findsOneWidget);
    expect(server.rows('transactions').single['receiver'], '김밥천국');
    expect(server.rows('categories'), hasLength(16));

    // 로그인한 뒤에 적은 거래는 잠깐 모았다가 올라간다.
    await addLunch(opened.last);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    expect(find.textContaining('올릴 변경 1건'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    await settle(tester);
    expect(server.rows('transactions'), hasLength(2));
    expect(find.textContaining('올릴 변경'), findsNothing);

    // 로그아웃해도 기기의 가계부는 그대로다.
    await tester.tap(find.byKey(const ValueKey('sign-out')));
    await settle(tester);
    expect(find.text('로그인하지 않았습니다'), findsOneWidget);
    expect(
      await opened.last.db.select(opened.last.db.ledgerTransactions).get(),
      hasLength(2),
    );

    await disposeApp(tester, opened.last);
  });

  testWidgets('다른 기기에서 올린 거래를 받아 온다', (tester) async {
    await start(tester);
    await tester.tap(find.byKey(const ValueKey('sign-in')));
    await settle(tester);
    expect(find.text('me@example.com'), findsOneWidget);

    // 같은 계정의 다른 기기가 거래를 올린다.
    final otherDb = AppDatabase(NativeDatabase.memory());
    final otherRepo = LedgerRepository(otherDb);
    final otherEngine = SyncEngine(
      db: otherDb,
      gateway: server,
      deviceId: 'other-device',
    );
    final ledgerId = ledgers['user-1']!;
    await LedgerAdoption(
      db: otherDb,
      engine: otherEngine,
      repository: otherRepo,
    ).adopt(
      userId: 'user-1',
      serverLedgerId: ledgerId,
      localLedgerId: await otherRepo.ensureLocalLedger(),
    );
    final cash = (await otherRepo.accounts(ledgerId)).single.id;
    await otherRepo.addTransaction(
      ledgerId,
      TransactionInput(
        type: TxType.expense,
        occurredOn: LocalDate(2026, 11, 16),
        amount: 4500,
        accountId: cash,
        counterparty: '카페',
      ),
    );
    await otherEngine.syncOnce(ledgerId);
    await otherDb.close();
    expect(server.rows('transactions'), hasLength(1));

    // '지금 동기화'는 바로 서버를 확인한다.
    final db = opened.last.db;
    expect(await db.select(db.ledgerTransactions).get(), isEmpty);
    await tester.tap(find.byKey(const ValueKey('sync-now')));
    await settle(tester);
    expect(
      (await db.select(db.ledgerTransactions).get()).single.receiver,
      '카페',
    );
    expect(find.textContaining('동기화했습니다'), findsOneWidget);

    await disposeApp(tester, opened.last);
  });

  testWidgets('다른 계정이 쓰던 기기에서는 지우고 받을지 묻는다', (tester) async {
    await start(tester);
    await tester.tap(find.byKey(const ValueKey('sign-in')));
    await settle(tester);
    await addLunch(opened.last);
    await tester.pump(const Duration(seconds: 3));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('sign-out')));
    await settle(tester);

    // 다른 사람이 이 기기에서 로그인한다.
    ledgers['user-2'] = server.seedLedger(ownerId: 'user-2');
    auth.next = const AuthUser(id: 'user-2', email: 'other@example.com');
    await tester.tap(find.byKey(const ValueKey('sign-in')));
    await settle(tester);
    expect(find.text('이 기기에는 다른 계정의 가계부가 있습니다'), findsOneWidget);
    // 아직 아무것도 지우지 않았다.
    expect(
      await opened.last.db.select(opened.last.db.ledgerTransactions).get(),
      hasLength(1),
    );

    await tester.tap(find.byKey(const ValueKey('replace-local')));
    await settle(tester);
    expect(opened.last.ledgerId, ledgers['user-2']);
    expect(find.text('other@example.com'), findsOneWidget);
    expect(
      await opened.last.db.select(opened.last.db.ledgerTransactions).get(),
      isEmpty,
    );
    // 앞선 계정의 거래는 서버에 남아 있다.
    expect(server.rows('transactions'), hasLength(1));

    await disposeApp(tester, opened.last);
  });

  testWidgets('로그인 흐름이 준비되지 않은 플랫폼에서는 단추를 보이지 않는다', (tester) async {
    auth.canSignInHere = false;
    await start(tester);
    expect(find.text('로그인하지 않았습니다'), findsOneWidget);
    expect(find.textContaining('웹 앱에서 로그인할 수 있습니다'), findsOneWidget);
    expect(find.byKey(const ValueKey('sign-in')), findsNothing);
    await disposeApp(tester, opened.last);
  });
}
