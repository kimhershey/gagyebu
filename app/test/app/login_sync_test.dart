import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:material_ui/material_ui.dart';
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

  /// 다음에 Google로 로그인할 사용자.
  AuthUser next = const AuthUser(id: 'user-1', email: 'me@example.com');

  /// 이메일로 가입한 계정: 이메일 → (비밀번호, 사용자 ID).
  final accounts = <String, (String, String)>{
    'me@example.com': ('secret1', 'user-1'),
  };

  /// 가입하면 확인 메일부터 보내는 서버인지.
  bool confirmEmail = true;

  @override
  AuthUser? currentUser;

  @override
  bool googleAvailable = true;

  @override
  Stream<AuthUser?> get userChanges => _changes.stream;

  void _enter(AuthUser user) {
    currentUser = user;
    _changes.add(user);
  }

  @override
  Future<void> signInWithGoogle() async => _enter(next);

  @override
  Future<void> signInWithPassword({
    required String email,
    required String password,
  }) async {
    final account = accounts[email];
    if (account == null || account.$1 != password) {
      throw const AuthFailure(AuthFailureReason.invalidCredentials);
    }
    _enter(AuthUser(id: account.$2, email: email));
  }

  @override
  Future<SignUpResult> signUpWithPassword({
    required String email,
    required String password,
  }) async {
    if (accounts.containsKey(email)) {
      throw const AuthFailure(AuthFailureReason.alreadyRegistered);
    }
    accounts[email] = (password, 'user-${accounts.length + 1}');
    if (confirmEmail) return SignUpResult.confirmationSent;
    _enter(AuthUser(id: accounts[email]!.$2, email: email));
    return SignUpResult.signedIn;
  }

  final _recoveries = StreamController<bool>.broadcast();

  /// 비밀번호를 다시 정하는 메일을 보낸 주소들.
  final resetMails = <String>[];

  @override
  bool passwordRecoveryPending = false;

  @override
  Stream<bool> get passwordRecoveryChanges => _recoveries.stream;

  @override
  Future<void> sendPasswordReset({required String email}) async {
    resetMails.add(email);
  }

  /// 메일의 링크를 누른 것처럼 한다: 로그인되고 새 비밀번호를 정해야 한다.
  void openResetLink(String email) {
    passwordRecoveryPending = true;
    _recoveries.add(true);
    _enter(AuthUser(id: accounts[email]!.$2, email: email));
  }

  @override
  Future<void> updatePassword({required String password}) async {
    final email = currentUser!.email!;
    if (accounts[email]!.$1 == password) {
      throw const AuthFailure(AuthFailureReason.samePassword);
    }
    accounts[email] = (password, accounts[email]!.$2);
    passwordRecoveryPending = false;
    _recoveries.add(false);
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
      showWelcome: auth.currentUser == null,
    );
    opened.add(services);
    return services;
  }

  /// 앱을 띄운다. 로그인하지 않았으므로 안내 화면이 뜬다.
  Future<void> start(WidgetTester tester, {Size size = desktop}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(Bootstrap(open: open));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('welcome-login')), findsOneWidget);
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pumpAndSettle();
  }

  /// 안내 화면에서 로그인 화면으로 가 Google로 로그인한다.
  Future<void> signInWithGoogle(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('welcome-login')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('auth-google')));
    await settle(tester);
  }

  /// 설정 화면의 단추를 누른다. 화면 아래에 있으면 올려서 누른다.
  Future<void> tapInSettings(WidgetTester tester, String key) async {
    final button = find.byKey(ValueKey(key));
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
  }

  Future<void> openSettings(WidgetTester tester) async {
    await tester.tap(find.text('설정').first);
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

    // 로그인 전에 기기에 거래가 하나 있었다.
    await addLunch(opened.single);
    await tester.pumpAndSettle();

    await signInWithGoogle(tester);

    // 가계부가 바뀌어 앱이 다시 열렸고, 안내 화면에서 가계부로 넘어왔다.
    expect(opened, hasLength(2));
    expect(opened.last.ledgerId, ledgers['user-1']);
    expect(find.byKey(const ValueKey('welcome-login')), findsNothing);
    await openSettings(tester);
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

    // 로그아웃하면 안내 화면으로 돌아간다. 기기의 가계부는 그대로다.
    await tapInSettings(tester, 'sign-out');
    await settle(tester);
    expect(find.byKey(const ValueKey('welcome-login')), findsOneWidget);
    expect(find.byKey(const ValueKey('sign-out')), findsNothing);
    expect(
      await opened.last.db.select(opened.last.db.ledgerTransactions).get(),
      hasLength(2),
    );

    await disposeApp(tester, opened.last);
  });

  testWidgets('다른 기기에서 올린 거래를 받아 온다', (tester) async {
    await start(tester);
    await signInWithGoogle(tester);
    await openSettings(tester);
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
    await tapInSettings(tester, 'sync-now');
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
    await signInWithGoogle(tester);
    await addLunch(opened.last);
    await tester.pump(const Duration(seconds: 3));
    await settle(tester);
    await openSettings(tester);
    await tapInSettings(tester, 'sign-out');
    await settle(tester);

    // 다른 사람이 이 기기에서 로그인한다. 지우고 받을지 묻는 설정 화면으로 간다.
    ledgers['user-2'] = server.seedLedger(ownerId: 'user-2');
    auth.next = const AuthUser(id: 'user-2', email: 'other@example.com');
    await signInWithGoogle(tester);
    expect(find.text('이 기기에는 다른 계정의 가계부가 있습니다'), findsOneWidget);
    // 아직 아무것도 지우지 않았다.
    expect(
      await opened.last.db.select(opened.last.db.ledgerTransactions).get(),
      hasLength(1),
    );

    await tapInSettings(tester, 'replace-local');
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

  testWidgets('Google 로그인이 준비되지 않은 플랫폼에서는 이메일 입력만 보인다', (tester) async {
    auth.googleAvailable = false;
    await start(tester);
    await tester.tap(find.byKey(const ValueKey('welcome-login')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('auth-google')), findsNothing);
    expect(find.textContaining('Google 로그인을 준비하고 있습니다'), findsOneWidget);
    expect(find.byKey(const ValueKey('auth-email')), findsOneWidget);
    await disposeApp(tester, opened.last);
  });

  group('처음 시작할 때', () {
    testWidgets('계정 만들기와 로그인을 고르는 화면부터 보인다', (tester) async {
      await start(tester, size: phone);
      // 고를 것은 계정 만들기와 로그인 둘뿐이다.
      expect(find.byKey(const ValueKey('welcome-signup')), findsOneWidget);
      expect(find.byKey(const ValueKey('welcome-login')), findsOneWidget);
      expect(find.byType(FilledButton), findsOneWidget);
      expect(find.byType(OutlinedButton), findsOneWidget);
      expect(find.byType(TextButton), findsNothing);
      expect(find.byKey(const ValueKey('nav-bottom')), findsNothing);

      // 두 화면 모두 Google 로그인과 이메일 · 비밀번호 입력을 함께 보여 준다.
      await tester.tap(find.byKey(const ValueKey('welcome-signup')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('auth-google')), findsOneWidget);
      expect(find.byKey(const ValueKey('auth-email')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('auth-password-confirm')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey('auth-switch')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('auth-google')), findsOneWidget);
      expect(find.byKey(const ValueKey('auth-email')), findsOneWidget);
      expect(find.byKey(const ValueKey('auth-password-confirm')), findsNothing);

      // 뒤로 가면 고르는 화면이다. 가계부로는 넘어가지 못한다.
      await tester.tap(find.byKey(const ValueKey('auth-back')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('welcome-login')), findsOneWidget);
      await disposeApp(tester, opened.last);
    });

    testWidgets('로그인한 채로 다시 켜면 바로 가계부가 열린다', (tester) async {
      auth.currentUser = const AuthUser(id: 'user-1', email: 'me@example.com');
      tester.view.physicalSize = phone;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(Bootstrap(open: open));
      await settle(tester);
      expect(find.byKey(const ValueKey('welcome-login')), findsNothing);
      expect(find.byKey(const ValueKey('nav-bottom')), findsOneWidget);
      await disposeApp(tester, opened.last);
    });

    testWidgets('이메일과 비밀번호로 로그인하면 가계부가 열린다', (tester) async {
      await start(tester, size: phone);
      await addLunch(opened.single);
      await tester.tap(find.byKey(const ValueKey('welcome-login')));
      await tester.pumpAndSettle();

      // 비밀번호가 틀리면 그 자리에서 알려 준다.
      await tester.enterText(
        find.byKey(const ValueKey('auth-email')),
        'me@example.com',
      );
      await tester.enterText(
        find.byKey(const ValueKey('auth-password')),
        'wrong-password',
      );
      await tester.tap(find.byKey(const ValueKey('auth-submit')));
      await tester.pumpAndSettle();
      expect(find.text('이메일이나 비밀번호가 맞지 않습니다'), findsOneWidget);
      expect(auth.currentUser, isNull);

      await tester.enterText(
        find.byKey(const ValueKey('auth-password')),
        'secret1',
      );
      await tester.tap(find.byKey(const ValueKey('auth-submit')));
      await settle(tester);

      // 기기에 적어 둔 거래가 계정으로 올라가고 가계부 화면이 열린다.
      expect(opened.last.ledgerId, ledgers['user-1']);
      expect(server.rows('transactions').single['receiver'], '김밥천국');
      expect(find.byKey(const ValueKey('nav-bottom')), findsOneWidget);
      expect(find.byKey(const ValueKey('welcome-login')), findsNothing);
      expect(find.byKey(const ValueKey('auth-submit')), findsNothing);
      await disposeApp(tester, opened.last);
    });

    testWidgets('Google로 로그인해도 가계부가 열린다', (tester) async {
      await start(tester, size: phone);
      await tester.tap(find.byKey(const ValueKey('welcome-signup')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('auth-google')));
      await settle(tester);
      expect(opened.last.ledgerId, ledgers['user-1']);
      expect(find.byKey(const ValueKey('nav-bottom')), findsOneWidget);
      await disposeApp(tester, opened.last);
    });

    testWidgets('계정을 만들면 확인 메일 안내를 보여 준다', (tester) async {
      await start(tester, size: phone);
      await tester.tap(find.byKey(const ValueKey('welcome-signup')));
      await tester.pumpAndSettle();

      Future<void> fill(String email, String password, String confirm) async {
        await tester.enterText(find.byKey(const ValueKey('auth-email')), email);
        await tester.enterText(
          find.byKey(const ValueKey('auth-password')),
          password,
        );
        await tester.enterText(
          find.byKey(const ValueKey('auth-password-confirm')),
          confirm,
        );
        await tester.tap(find.byKey(const ValueKey('auth-submit')));
        await tester.pumpAndSettle();
      }

      // 입력이 틀리면 서버에 묻지 않는다.
      await fill('new@example', 'secret2', 'secret2');
      expect(find.text('이메일 주소를 확인해 주세요'), findsOneWidget);
      await fill('new@example.com', '12345', '12345');
      expect(find.text('비밀번호는 6자 이상이어야 합니다'), findsOneWidget);
      await fill('new@example.com', 'secret2', 'secret3');
      expect(find.text('비밀번호가 서로 다릅니다'), findsOneWidget);
      expect(auth.accounts, hasLength(1));

      await fill('me@example.com', 'secret2', 'secret2');
      expect(find.text('이미 가입한 이메일입니다. 로그인해 주세요'), findsOneWidget);

      await fill('new@example.com', 'secret2', 'secret2');
      expect(find.byKey(const ValueKey('auth-sent')), findsOneWidget);
      expect(find.textContaining('new@example.com'), findsOneWidget);
      expect(auth.currentUser, isNull);

      // 안내에서 로그인 화면으로 넘어간다.
      await tester.tap(find.text('로그인 화면으로'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('auth-password-confirm')), findsNothing);
      expect(find.byKey(const ValueKey('auth-submit')), findsOneWidget);
      await disposeApp(tester, opened.last);
    });

    testWidgets('메일 확인이 없는 서버에서는 계정을 만들자마자 가계부가 열린다', (tester) async {
      auth.confirmEmail = false;
      ledgers['user-2'] = server.seedLedger(ownerId: 'user-2');
      await start(tester, size: phone);
      await tester.tap(find.byKey(const ValueKey('welcome-signup')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('auth-email')),
        'new@example.com',
      );
      await tester.enterText(
        find.byKey(const ValueKey('auth-password')),
        'secret2',
      );
      await tester.enterText(
        find.byKey(const ValueKey('auth-password-confirm')),
        'secret2',
      );
      await tester.tap(find.byKey(const ValueKey('auth-submit')));
      await settle(tester);
      expect(opened.last.ledgerId, ledgers['user-2']);
      expect(find.byKey(const ValueKey('nav-bottom')), findsOneWidget);
      await disposeApp(tester, opened.last);
    });
  });

  group('비밀번호를 잊었을 때', () {
    testWidgets('로그인 화면에서 다시 정하는 메일을 보낸다', (tester) async {
      await start(tester, size: phone);
      await tester.tap(find.byKey(const ValueKey('welcome-login')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('auth-forgot')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const ValueKey('reset-email')), 'me@');
      await tester.tap(find.byKey(const ValueKey('reset-send')));
      await tester.pumpAndSettle();
      expect(find.text('이메일 주소를 확인해 주세요'), findsOneWidget);
      expect(auth.resetMails, isEmpty);

      await tester.enterText(
        find.byKey(const ValueKey('reset-email')),
        'me@example.com',
      );
      await tester.tap(find.byKey(const ValueKey('reset-send')));
      await tester.pumpAndSettle();
      expect(auth.resetMails, ['me@example.com']);
      expect(find.byKey(const ValueKey('reset-sent')), findsOneWidget);

      await tester.tap(find.text('로그인 화면으로'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('auth-submit')), findsOneWidget);
      await disposeApp(tester, opened.last);
    });

    testWidgets('메일의 링크로 들어오면 새 비밀번호를 정한 뒤에 가계부가 열린다', (tester) async {
      await start(tester, size: phone);
      auth.openResetLink('me@example.com');
      await settle(tester);

      // 새 비밀번호를 정하기 전에는 가계부로 넘어가지 않는다.
      expect(find.byKey(const ValueKey('new-password')), findsOneWidget);
      expect(find.textContaining('me@example.com'), findsOneWidget);
      expect(find.byKey(const ValueKey('nav-bottom')), findsNothing);

      Future<void> fill(String password, String confirm) async {
        await tester.enterText(
          find.byKey(const ValueKey('new-password')),
          password,
        );
        await tester.enterText(
          find.byKey(const ValueKey('new-password-confirm')),
          confirm,
        );
        await tester.tap(find.byKey(const ValueKey('new-password-save')));
        await settle(tester);
      }

      await fill('fresh-pw', 'fresh-px');
      expect(find.text('비밀번호가 서로 다릅니다'), findsOneWidget);
      await fill('secret1', 'secret1');
      expect(find.text('지금 쓰는 비밀번호와 같습니다'), findsOneWidget);

      await fill('fresh-pw', 'fresh-pw');
      expect(auth.accounts['me@example.com']!.$1, 'fresh-pw');
      expect(find.byKey(const ValueKey('new-password')), findsNothing);
      expect(find.byKey(const ValueKey('nav-bottom')), findsOneWidget);
      expect(opened.last.ledgerId, ledgers['user-1']);
      await disposeApp(tester, opened.last);
    });
  });
}
