import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:gagyebu/app/app.dart';
import 'package:gagyebu/app/providers.dart';
import 'package:gagyebu/app/router.dart';
import 'package:gagyebu/app/sync_controller.dart';
import 'package:gagyebu/data/prefs/device_prefs.dart';
import 'package:gagyebu/data/server/server_connection.dart';
import 'package:gagyebu/features/settings/sub_screen.dart';

import 'test_app.dart';

export 'test_app.dart';

/// 네 화면 크기(`docs/SPEC.md` 6.4).
const fourSizes = [
  ('소형 폰', phone),
  ('큰 폰', largePhone),
  ('폴더블', foldable),
  ('PC', desktop),
];

/// 시험에서 손으로 돌리는 시계.
class TestClock {
  TestClock([DateTime? start]) : now = start ?? testNow;

  DateTime now;

  DateTime call() => now;

  void advance(Duration by) => now = now.add(by);
}

/// 로그인 상태를 정해 둔 가짜 동기화 제어기. 서버 없이 화면만 시험할 때 쓴다.
class FakeSyncController extends SyncController {
  FakeSyncController(this.initial);

  /// 로그인해 쉬고 있는 상태.
  FakeSyncController.signedIn({String email = 'me@example.com'})
    : initial = SyncStatus(
        SyncPhase.idle,
        user: AuthUser(id: 'user-1', email: email),
      );

  final SyncStatus initial;
  int signOuts = 0;

  @override
  SyncStatus build() => initial;

  @override
  Future<void> signOut() async {
    signOuts++;
    state = const SyncStatus(SyncPhase.signedOut);
  }

  @override
  Future<void> syncNow() async {}
}

/// [pumpApp]과 같지만 제공자를 더 덮어쓸 수 있다.
///
/// [prefs]를 주면 기기 설정으로, [clock]을 주면 시계로 쓴다. [sync]를 주면 로그인 상태를
/// 그것으로 고정한다.
Future<void> pumpAppWith(
  WidgetTester tester,
  AppServices services, {
  required Size size,
  String location = '/',
  double textScale = 1,
  DevicePrefs? prefs,
  DateTime Function()? clock,
  FakeSyncController? sync,
  List<Override> overrides = const [],
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appServicesProvider.overrideWithValue(services),
        clockProvider.overrideWithValue(clock ?? () => testNow),
        if (prefs != null) devicePrefsProvider.overrideWithValue(prefs),
        if (sync != null) syncControllerProvider.overrideWith(() => sync),
        ...overrides,
      ],
      child: GagyebuApp(router: createRouter(initialLocation: location)),
    ),
  );
  await tester.pumpAndSettle();
}

/// 설정 아래 화면에서 [target]이 보일 때까지 내린다. 목록은 보이는 근처만 그리므로, 아래쪽
/// 칸은 내려야 생긴다.
Future<void> scrollSubScreenTo(WidgetTester tester, Finder target) async {
  await tester.scrollUntilVisible(
    target,
    200,
    scrollable: find
        .descendant(
          of: find.byType(SubScreen),
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await tester.pumpAndSettle();
}
