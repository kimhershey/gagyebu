import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/server/server_connection.dart';
import '../data/sync/ledger_adoption.dart';
import '../data/sync/sync_engine.dart';
import 'providers.dart';

/// 로그인과 동기화가 어디까지 와 있는지.
enum SyncPhase {
  /// 서버를 넣지 않은 빌드다. 로그인이 없다.
  unavailable,

  /// 로그인하지 않았다.
  signedOut,

  /// 서버와 주고받는 중이다.
  syncing,

  /// 로그인했고 지금은 쉬고 있다.
  idle,

  /// 마지막 동기화가 실패했다. 다음 차례에 다시 해 본다.
  failed,

  /// 이 기기에 다른 계정의 가계부가 있다. 지우고 받을지 사용자가 정해야 한다.
  differentAccount,
}

class SyncStatus {
  const SyncStatus(this.phase, {this.user, this.lastSyncedAt, this.error});

  final SyncPhase phase;
  final AuthUser? user;

  /// 마지막으로 동기화에 성공한 때.
  final DateTime? lastSyncedAt;
  final String? error;

  bool get signedIn => user != null;
}

/// 로그인 상태를 따라가며 동기화를 돌린다.
///
/// - 로그인하면 기기의 가계부를 계정의 가계부에 맞추고(첫 로그인이면 옮긴다) 동기화한다.
/// - 기기에서 바꾼 것이 생기면 잠깐 모았다가 올린다. 그사이 다른 기기의 변경도 받는다.
/// - 일정한 간격으로도 받는다. 서버의 실시간 신호를 받으면 바로 받는다
///   (`data/server/realtime.dart`가 [syncNow]를 부른다).
/// - 가계부를 맞추는 단계에서 실패하면(서버에 닿지 못했을 때 등) 다음 차례에 다시 맞춘다.
class SyncController extends Notifier<SyncStatus> {
  /// 기기에서 바꾼 뒤 올리기까지 기다리는 시간.
  static const pushDelay = Duration(seconds: 2);

  /// 바꾼 것이 없어도 서버를 확인하는 간격.
  static const pollInterval = Duration(minutes: 1);

  ServerConnection? _server;
  SyncEngine? _engine;
  Timer? _pushTimer;
  bool _running = false;
  bool _again = false;

  /// 가계부를 맞춰 둔 사용자. 같은 사용자의 세션 갱신 알림을 걸러 낸다.
  String? _readyUserId;

  /// 지금 가계부를 맞추고 있는 사용자. 같은 일을 겹쳐 돌리지 않는다.
  String? _preparingUserId;

  /// 가계부 맞추기를 시작하거나 로그아웃할 때마다 오른다. 앞선 맞추기의 결과를 가려낸다.
  int _prepareRun = 0;

  /// 로그인한 계정의 가계부에 기기를 맞췄는지. 맞춘 뒤에야 서버와 주고받는다.
  bool get ledgerReady => _readyUserId != null;

  @override
  SyncStatus build() {
    final services = ref.watch(appServicesProvider);
    final server = _server = services.server;
    if (server == null) return const SyncStatus(SyncPhase.unavailable);

    final subscription = server.auth.userChanges.listen(_onUser);
    final poll = Timer.periodic(pollInterval, (_) => syncNow());
    ref.listen(pendingChangesProvider, (_, next) {
      if ((next.value ?? 0) > 0) _schedulePush();
    });
    ref.onDispose(() {
      subscription.cancel();
      poll.cancel();
      _pushTimer?.cancel();
    });

    final user = server.auth.currentUser;
    if (user == null) return const SyncStatus(SyncPhase.signedOut);
    // 저장해 둔 세션으로 시작했다. 화면이 뜬 다음에 맞춘다.
    Future.microtask(() => _onUser(user));
    return SyncStatus(SyncPhase.syncing, user: user);
  }

  AuthService get _auth {
    final server = _server;
    if (server == null) throw const AuthFailure(AuthFailureReason.unknown);
    return server.auth;
  }

  /// Google 로그인을 시작한다. 하지 못하면 [AuthFailure]를 던진다.
  Future<void> signInWithGoogle() => _auth.signInWithGoogle();

  /// 이메일과 비밀번호로 로그인한다. 하지 못하면 [AuthFailure]를 던진다.
  Future<void> signInWithPassword(String email, String password) =>
      _auth.signInWithPassword(email: email, password: password);

  /// 이메일과 비밀번호로 계정을 만든다. 하지 못하면 [AuthFailure]를 던진다.
  Future<SignUpResult> signUpWithPassword(String email, String password) =>
      _auth.signUpWithPassword(email: email, password: password);

  /// 비밀번호를 다시 정하는 메일을 보낸다. 하지 못하면 [AuthFailure]를 던진다.
  Future<void> sendPasswordReset(String email) =>
      _auth.sendPasswordReset(email: email);

  /// 로그인한 계정의 비밀번호를 바꾼다. 하지 못하면 [AuthFailure]를 던진다.
  Future<void> updatePassword(String password) =>
      _auth.updatePassword(password: password);

  /// 로그아웃한다. 기기의 가계부는 그대로 둔다.
  Future<void> signOut() async {
    await _server?.auth.signOut();
  }

  /// 로그인한 계정을 서버에서 지운다(`docs/SPEC.md` 4.5). 하지 못하면 [AuthFailure]를 던지고
  /// 아무것도 바뀌지 않는다. 성공하면 로그아웃된 상태가 된다.
  ///
  /// 서버만 부른다. 기기의 가계부 · 대기열 · 작업 기록을 지우고 앱을 다시 여는 것은 부르는
  /// 쪽(설정의 계정 화면)이 한다.
  Future<void> deleteAccount() async {
    final auth = _auth;
    // 지우는 동안과 지운 뒤에는 올리지 않는다. 올릴 곳이 없다.
    _pushTimer?.cancel();
    await auth.deleteAccount();
  }

  /// 지금 동기화한다. 가계부를 맞추다 실패한 채로 있으면 맞추는 것부터 다시 한다.
  Future<void> syncNow() async {
    if (_readyUserId == null) {
      final user = state.user;
      if (user != null && state.phase == SyncPhase.failed) {
        await _prepare(user);
      }
      return;
    }
    await _sync();
  }

  /// 기기의 가계부를 지우고 로그인한 계정의 가계부를 받는다.
  Future<void> replaceLocalLedger() async {
    final user = state.user;
    if (user == null) return;
    await _prepare(user, replaceLocal: true);
  }

  void _onUser(AuthUser? user) {
    if (user == null) {
      _readyUserId = null;
      _preparingUserId = null;
      _prepareRun++;
      _pushTimer?.cancel();
      state = const SyncStatus(SyncPhase.signedOut);
      return;
    }
    if (user.id == _readyUserId) return;
    unawaited(_prepare(user));
  }

  /// 기기의 가계부를 [user]의 가계부에 맞춘다.
  Future<void> _prepare(AuthUser user, {bool replaceLocal = false}) async {
    // 시작할 때의 사용자와 로그인 알림이 겹쳐 와도 한 번만 맞춘다.
    if (_preparingUserId == user.id) return;
    _preparingUserId = user.id;
    final run = ++_prepareRun;
    try {
      await _adopt(user, run, replaceLocal: replaceLocal);
    } finally {
      if (run == _prepareRun) _preparingUserId = null;
    }
  }

  Future<void> _adopt(
    AuthUser user,
    int run, {
    required bool replaceLocal,
  }) async {
    final services = ref.read(appServicesProvider);
    final server = _server!;
    state = SyncStatus(SyncPhase.syncing, user: user);
    // 맞추는 사이에 로그아웃했거나 앱이 다시 열렸으면 결과를 쓰지 않는다.
    bool stale() => !ref.mounted || run != _prepareRun;
    try {
      final serverLedgerId = await server.ledgerIdOf(user.id);
      if (stale()) return;
      if (serverLedgerId == null) {
        state = SyncStatus(
          SyncPhase.failed,
          user: user,
          error: '계정의 가계부를 찾지 못했습니다',
        );
        return;
      }
      final engine = _engine ??= SyncEngine(
        db: services.db,
        gateway: server.gateway,
        deviceId: await SyncEngine.ensureDeviceId(services.db),
        clock: ref.read(clockProvider),
      );
      final changed =
          await LedgerAdoption(
            db: services.db,
            engine: engine,
            repository: services.repository,
          ).adopt(
            userId: user.id,
            serverLedgerId: serverLedgerId,
            localLedgerId: services.ledgerId,
            replaceLocal: replaceLocal,
          );
      if (!ref.mounted) return;
      if (changed) {
        // 쓰는 가계부가 바뀌었다. 앱을 새 가계부로 다시 연다(다시 열린 뒤에 동기화한다).
        // 그사이 로그아웃했더라도 다시 연다. 기기의 가계부는 이미 바뀌어 있다.
        ref.read(appRestartProvider)();
        return;
      }
      if (stale()) return;
      _readyUserId = user.id;
      await _sync();
    } on DifferentAccountException {
      if (stale()) return;
      state = SyncStatus(SyncPhase.differentAccount, user: user);
    } catch (e) {
      if (stale()) return;
      state = SyncStatus(SyncPhase.failed, user: user, error: '$e');
    }
  }

  void _schedulePush() {
    if (_readyUserId == null) return;
    _pushTimer?.cancel();
    _pushTimer = Timer(pushDelay, syncNow);
  }

  Future<void> _sync() async {
    final engine = _engine;
    final user = state.user;
    if (engine == null || user == null) return;
    if (_running) {
      // 도는 중에 또 바뀌었다. 끝나면 한 번 더 돈다.
      _again = true;
      return;
    }
    _running = true;
    final lastSyncedAt = state.lastSyncedAt;
    state = SyncStatus(
      SyncPhase.syncing,
      user: user,
      lastSyncedAt: lastSyncedAt,
    );
    try {
      do {
        _again = false;
        await engine.syncOnce(ref.read(appServicesProvider).ledgerId);
      } while (_again);
      if (!ref.mounted) return;
      if (_readyUserId != null) {
        state = SyncStatus(
          SyncPhase.idle,
          user: user,
          lastSyncedAt: ref.read(clockProvider)(),
        );
      }
    } catch (e) {
      if (!ref.mounted) return;
      state = SyncStatus(
        SyncPhase.failed,
        user: user,
        lastSyncedAt: lastSyncedAt,
        error: '$e',
      );
    } finally {
      _running = false;
    }
  }
}

final syncControllerProvider = NotifierProvider<SyncController, SyncStatus>(
  SyncController.new,
);
