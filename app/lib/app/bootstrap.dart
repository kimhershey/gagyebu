import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../data/db/connection/connection.dart';
import '../data/db/database.dart';
import '../data/prefs/device_prefs.dart';
import '../data/repositories/ledger_repository.dart';
import '../data/server/server_config.dart';
import '../data/server/server_connection.dart';
import '../data/server/supabase_connection.dart';
import 'app.dart';
import 'providers.dart';
import 'router.dart';
import 'sync_controller.dart';
import 'theme/theme_setting.dart';

/// 로컬 DB를 열고 가계부를 준비한다.
Future<AppServices> openAppServices() async {
  final opened = await openAppDatabase();
  final db = AppDatabase(opened.executor);
  final repository = LedgerRepository(db);
  final ledgerId = await repository.ensureLocalLedger();
  final ledger = await (db.select(
    db.ledgers,
  )..where((l) => l.id.equals(ledgerId))).getSingleOrNull();
  final server = await _connectServer();
  return AppServices(
    db: db,
    repository: repository,
    ledgerId: ledgerId,
    storage: opened.storage,
    persistent: opened.persistent,
    startedAt: ledger?.createdAt,
    takenOver: opened.takenOver,
    server: server,
    // 로그인할 수 있는데 하지 않았으면 로그인 안내부터 보여 준다.
    showWelcome: server != null && server.auth.currentUser == null,
  );
}

/// 서버 주소를 넣은 빌드면 서버에 연결한다. 연결하지 못해도 앱은 기기 안에서 동작한다.
Future<ServerConnection?> _connectServer() async {
  final config = ServerConfig.fromEnvironment();
  if (config == null) return null;
  try {
    return await connectSupabase(config);
  } catch (e) {
    debugPrint('서버에 연결하지 못했다: $e');
    return null;
  }
}

/// 앱에 넣은 글꼴의 라이선스를 라이선스 화면에 올린다.
void registerBundledLicenses() {
  LicenseRegistry.addLicense(() async* {
    final text = await rootBundle.loadString('assets/fonts/Pretendard-OFL.txt');
    yield LicenseEntryWithLineBreaks(['Pretendard'], text);
  });
}

/// 준비가 끝날 때까지 기다렸다가 앱을 띄운다.
class Bootstrap extends StatefulWidget {
  const Bootstrap({super.key, this.open = openAppServices, this.prefs});

  /// 로컬 DB를 여는 함수. 시험에서 바꿔 끼운다.
  final Future<AppServices> Function() open;

  /// 앱이 뜨기 전에 읽어 둔 기기 설정. 없으면 메모리에만 둔다.
  final DevicePrefs? prefs;

  @override
  State<Bootstrap> createState() => _BootstrapState();
}

class _BootstrapState extends State<Bootstrap> {
  late Future<AppServices> _services;

  /// 다른 탭이 저장소를 가져가 이 탭이 멈췄는지.
  bool _takenOver = false;

  /// 몇 번째로 연 것인지. 예전에 연 것의 신호를 가려낸다.
  int _opened = 0;

  /// 지금 화면이 쓰고 있는 연결.
  AppServices? _current;

  /// 화면 이동 상태. 연결을 다시 열어도 보던 화면이 그대로이게 여기서 들고 있다.
  /// (웹 엔진은 앱이 주소를 넘겨받은 뒤에는 시작 주소를 '/'로 돌려 버린다.)
  GoRouter? _router;

  /// 기기 설정과 테마. 연결을 다시 열어도 그대로 쓴다.
  late final DevicePrefs _prefs = widget.prefs ?? MemoryDevicePrefs();
  late final ThemeController _theme = ThemeController(_prefs);

  /// 로그인하지 않아 안내 화면에 머물러야 하는 동안 true. 라우터가 본다.
  final _welcomeGate = ValueNotifier(false);

  /// 비밀번호를 다시 정하는 메일의 링크로 들어와 새 비밀번호를 정해야 하는 동안 true.
  final _recoveryGate = ValueNotifier(false);
  StreamSubscription<bool>? _recoveries;

  @override
  void initState() {
    super.initState();
    _open();
  }

  @override
  void dispose() {
    _router?.dispose();
    _recoveries?.cancel();
    _welcomeGate.dispose();
    _recoveryGate.dispose();
    _theme.dispose();
    super.dispose();
  }

  void _open() {
    final opened = ++_opened;
    _takenOver = false;
    final previous = _current;
    _current = null;
    final services = _services = () async {
      if (previous != null) {
        // 다시 여는 경우다. 화면이 내려간 다음에 앞선 연결을 닫고 새로 연다.
        await WidgetsBinding.instance.endOfFrame;
        await previous.db.close();
      }
      return widget.open();
    }();
    services.then((services) {
      if (opened != _opened) return;
      _current = services;
      _welcomeGate.value = services.showWelcome;
      final auth = services.server?.auth;
      _recoveries?.cancel();
      _recoveries = auth?.passwordRecoveryChanges.listen(
        (pending) => _recoveryGate.value = pending,
      );
      _recoveryGate.value = auth?.passwordRecoveryPending ?? false;
      services.takenOver?.then((_) {
        if (!mounted || opened != _opened) return;
        _current = null;
        setState(() => _takenOver = true);
        // 화면이 내려간 다음에 닫는다. 이 탭이 오래된 사본으로 다시 저장하지 못하게 한다.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          services.db.close();
        });
      });
    }, onError: (Object _) {});
  }

  /// 로그인 상태를 따라 안내 화면을 걸거나 푼다.
  void _onSyncStatus(SyncStatus? previous, SyncStatus next) {
    // 로그아웃하면 안내 화면으로 돌아가고, 로그인하면 가계부로 넘어간다.
    _welcomeGate.value = next.phase == SyncPhase.signedOut;
    if (next.phase == SyncPhase.differentAccount &&
        previous?.phase != SyncPhase.differentAccount) {
      // 이 기기에 다른 계정의 가계부가 있다. 지우고 받을지 묻는 곳으로 보낸다.
      _router?.go('/settings');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_takenOver) {
      return _BareScreen(
        theme: _theme,
        child: _Notice(
          icon: Icons.tab_unselected,
          title: '다른 탭에서 가계부를 열었습니다',
          body:
              '이 브라우저에서는 가계부를 탭 하나에서만 쓸 수 있습니다. 두 탭에서 함께 쓰면 '
              '저장한 내용이 서로 덮어써집니다. 그래서 이 탭은 멈췄습니다.',
          action: '이 탭에서 계속 쓰기',
          onAction: () => setState(_open),
        ),
      );
    }
    return FutureBuilder<AppServices>(
      future: _services,
      builder: (context, snapshot) {
        // 다시 여는 동안에는 앞선 결과(닫힌 연결이나 앞선 오류)를 쓰지 않는다.
        final done = snapshot.connectionState == ConnectionState.done;
        final services = snapshot.data;
        if (services != null && done) {
          return ProviderScope(
            // 다시 열면 앞선 연결을 쓰던 상태를 모두 버린다.
            key: ObjectKey(services),
            overrides: [
              appServicesProvider.overrideWithValue(services),
              devicePrefsProvider.overrideWithValue(_prefs),
              themeControllerProvider.overrideWithValue(_theme),
              appRestartProvider.overrideWithValue(() {
                if (mounted) setState(_open);
              }),
            ],
            // 화면이 떠 있는 동안 로그인 상태를 따라가며 동기화한다.
            child: Consumer(
              builder: (context, ref, child) {
                ref.watch(syncControllerProvider);
                ref.listen(syncControllerProvider, _onSyncStatus);
                return child!;
              },
              child: GagyebuApp(
                router: _router ??= createRouter(
                  welcomeGate: _welcomeGate,
                  recoveryGate: _recoveryGate,
                ),
              ),
            ),
          );
        }
        // 준비하는 동안에는 Navigator가 없는 맨 화면을 쓴다. 여기서 MaterialApp을 쓰면
        // 웹에서 주소가 '/'로 바뀌어, 주소로 바로 들어온 화면(#/transactions 등)을 잃는다.
        final failure = done && snapshot.hasError ? snapshot.error : null;
        return _BareScreen(
          theme: _theme,
          child: failure == null
              ? const CircularProgressIndicator()
              : _Notice(
                  icon: Icons.error_outline,
                  title: '데이터를 열지 못했습니다',
                  body: '$failure',
                  detail: kDebugMode ? '${snapshot.stackTrace}' : null,
                  action: '다시 시도',
                  onAction: () => setState(_open),
                ),
        );
      },
    );
  }
}

/// Navigator 없이 그리는 맨 화면.
class _BareScreen extends StatelessWidget {
  const _BareScreen({required this.theme, required this.child});

  final ThemeController theme;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final view = View.of(context);
    return MediaQuery.fromView(
      view: view,
      // 앱과 같은 테마(사용자가 고른 것)를 쓴다. 글꼴을 정해 두지 않으면 웹에서 한글 글꼴을
      // 밖에서 받아 온다.
      child: Theme(
        data: theme.resolve(view.platformDispatcher.platformBrightness),
        child: Directionality(
          textDirection: TextDirection.ltr,
          // 오류 내용이 길어도 넘치지 않게 스크롤한다.
          child: Material(
            child: Center(child: SingleChildScrollView(child: child)),
          ),
        ),
      ),
    );
  }
}

/// 아이콘, 제목, 설명, 단추 하나.
class _Notice extends StatelessWidget {
  const _Notice({
    required this.icon,
    required this.title,
    required this.body,
    required this.action,
    required this.onAction,
    this.detail,
  });

  final IconData icon;
  final String title;
  final String body;
  final String action;
  final VoidCallback onAction;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(body, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: onAction, child: Text(action)),
            if (detail != null) Text(detail!),
          ],
        ),
      ),
    );
  }
}
