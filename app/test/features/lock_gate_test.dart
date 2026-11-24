import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:gagyebu/app/providers.dart';
import 'package:gagyebu/data/prefs/device_prefs.dart';
import 'package:gagyebu/features/lock/app_lock.dart';

import 'settings_harness.dart';

void main() {
  late MemoryDevicePrefs prefs;
  late TestClock clock;
  late AppLock lock;

  /// 잠금 번호 2580을 정해 둔 기기 설정을 만든다.
  Future<void> enableLock() async {
    await AppLock(prefs, iterations: 20).setPin('2580');
  }

  setUp(() {
    prefs = MemoryDevicePrefs();
    clock = TestClock();
    lock = AppLock(prefs, iterations: 20, clock: clock.call);
  });

  Future<void> start(
    WidgetTester tester,
    AppServices services, {
    Size size = phone,
    double textScale = 1,
    FakeSyncController? sync,
    List<Override> overrides = const [],
  }) => pumpAppWith(
    tester,
    services,
    size: size,
    textScale: textScale,
    prefs: prefs,
    clock: clock.call,
    sync: sync,
    overrides: [appLockProvider.overrideWithValue(lock), ...overrides],
  );

  Future<void> enter(WidgetTester tester, String pin) async {
    for (final digit in pin.split('')) {
      await tester.tap(find.byKey(ValueKey('pin-$digit')));
      await tester.pump();
    }
    await tester.tap(find.byKey(const ValueKey('pin-ok')));
    await tester.pumpAndSettle();
  }

  /// 앱을 뒤로 보냈다가 [away] 뒤에 돌아온다.
  Future<void> leaveAndReturn(WidgetTester tester, Duration away) async {
    for (final state in [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
    clock.advance(away);
    for (final state in [
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
    await tester.pumpAndSettle();
  }

  final lockScreen = find.byKey(const ValueKey('lock-screen'));
  final home = find.byKey(const ValueKey('total-expense'));

  testWidgets('잠금이 꺼져 있으면 앱이 바로 보인다', (tester) async {
    final services = await createTestServices();
    await start(tester, services);
    expect(lockScreen, findsNothing);
    expect(home, findsOneWidget);
    await disposeApp(tester, services);
  });

  testWidgets('켤 때 잠겨 있고, 맞는 번호를 넣으면 풀린다', (tester) async {
    await enableLock();
    final services = await createTestServices();
    await start(tester, services);

    expect(lockScreen, findsOneWidget);
    expect(find.text('잠금 번호를 넣어 주십시오'), findsOneWidget);
    // 가려진 앱은 보이지 않고 누를 수도 없다.
    expect(home, findsNothing);
    expect(find.text('설정'), findsNothing);

    await enter(tester, '2580');
    expect(lockScreen, findsNothing);
    expect(home, findsOneWidget);
    await disposeApp(tester, services);
  });

  testWidgets('틀린 번호는 받지 않고 남은 횟수를 알린다', (tester) async {
    await enableLock();
    final services = await createTestServices();
    await start(tester, services);

    await enter(tester, '1111');
    expect(lockScreen, findsOneWidget);
    expect(find.textContaining('번호가 맞지 않습니다. 4번 더 틀리면'), findsOneWidget);

    // 네 자리가 안 되면 확인하지 않는다(틀린 횟수도 세지 않는다).
    await enter(tester, '12');
    expect(find.text('숫자 4–6자리를 넣어 주십시오'), findsOneWidget);
    expect(lock.attemptsLeft, 4);

    // 지우기로 고쳐 넣는다.
    await tester.tap(find.byKey(const ValueKey('pin-back')));
    await tester.tap(find.byKey(const ValueKey('pin-back')));
    await tester.pump();
    await enter(tester, '2580');
    expect(lockScreen, findsNothing);
    await disposeApp(tester, services);
  });

  testWidgets('다섯 번 틀리면 30초 동안 번호판이 꺼지고, 지나면 다시 받는다', (tester) async {
    await enableLock();
    final services = await createTestServices();
    await start(tester, services);

    for (var i = 0; i < 5; i++) {
      await enter(tester, '0000');
    }
    expect(find.byKey(const ValueKey('lock-wait')), findsOneWidget);
    expect(find.textContaining('30초 뒤에 다시 넣을 수 있습니다'), findsOneWidget);

    // 기다리는 동안에는 맞는 번호를 눌러도 들어가지 않는다.
    await tester.tap(find.byKey(const ValueKey('pin-2')), warnIfMissed: false);
    await tester.pump();
    clock.advance(const Duration(seconds: 10));
    await tester.pump(const Duration(seconds: 1));
    expect(find.textContaining('20초 뒤에'), findsOneWidget);

    clock.advance(const Duration(seconds: 20));
    await tester.pump(const Duration(seconds: 1));
    expect(find.byKey(const ValueKey('lock-wait')), findsNothing);
    await enter(tester, '2580');
    expect(lockScreen, findsNothing);
    await disposeApp(tester, services);
  });

  testWidgets('뒤로 보냈다가 1분 넘어 돌아오면 다시 잠근다', (tester) async {
    await enableLock();
    final services = await createTestServices();
    await start(tester, services);
    await enter(tester, '2580');
    expect(lockScreen, findsNothing);

    // 1분이 안 됐으면 그대로다.
    await leaveAndReturn(tester, const Duration(seconds: 59));
    expect(lockScreen, findsNothing);
    await leaveAndReturn(tester, const Duration(minutes: 1));
    expect(lockScreen, findsNothing);

    await leaveAndReturn(tester, const Duration(minutes: 1, seconds: 1));
    expect(lockScreen, findsOneWidget);
    expect(home, findsNothing);

    await enter(tester, '2580');
    expect(lockScreen, findsNothing);
    expect(home, findsOneWidget);
    await disposeApp(tester, services);
  });

  testWidgets('창이 초점만 잃은 것은 뒤로 보낸 것으로 치지 않는다', (tester) async {
    await enableLock();
    final services = await createTestServices();
    await start(tester, services);
    await enter(tester, '2580');

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    clock.advance(const Duration(minutes: 10));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(lockScreen, findsNothing);
    await disposeApp(tester, services);
  });

  testWidgets('잠금이 꺼져 있으면 오래 뒤에 돌아와도 잠그지 않는다', (tester) async {
    final services = await createTestServices();
    await start(tester, services);
    await leaveAndReturn(tester, const Duration(hours: 1));
    expect(lockScreen, findsNothing);
    await disposeApp(tester, services);
  });

  testWidgets('잠겼다 풀려도 보던 화면이 그대로다', (tester) async {
    await enableLock();
    final services = await createTestServices();
    await start(tester, services, size: desktop);
    await enter(tester, '2580');
    await tester.tap(find.text('설정').last);
    await tester.pumpAndSettle();
    expect(find.text('월 시작일'), findsOneWidget);

    await leaveAndReturn(tester, const Duration(minutes: 5));
    expect(lockScreen, findsOneWidget);
    expect(find.text('월 시작일'), findsNothing);
    await enter(tester, '2580');
    expect(find.text('월 시작일'), findsOneWidget);
    await disposeApp(tester, services);
  });

  testWidgets('키보드로도 번호를 넣는다', (tester) async {
    await enableLock();
    final services = await createTestServices();
    await start(tester, services, size: desktop);

    await tester.sendKeyEvent(LogicalKeyboardKey.digit9, character: '9');
    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    for (final (key, character) in [
      (LogicalKeyboardKey.digit2, '2'),
      (LogicalKeyboardKey.digit5, '5'),
      (LogicalKeyboardKey.numpad8, '8'),
      (LogicalKeyboardKey.digit0, '0'),
    ]) {
      await tester.sendKeyEvent(key, character: character);
    }
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(lockScreen, findsNothing);
    await disposeApp(tester, services);
  });

  testWidgets('번호를 잊었으면 로그아웃하고 잠금을 끈다', (tester) async {
    await enableLock();
    final services = await createTestServices();
    final sync = FakeSyncController.signedIn();
    await start(tester, services, sync: sync);

    await tester.tap(find.byKey(const ValueKey('lock-forgot')));
    await tester.pumpAndSettle();
    expect(find.textContaining('기기의 가계부는 그대로 있고'), findsOneWidget);

    // 돌아가면 아무 일도 없다.
    await tester.tap(find.byKey(const ValueKey('lock-forgot-cancel')));
    await tester.pumpAndSettle();
    expect(lock.isEnabled, isTrue);
    expect(sync.signOuts, 0);

    await tester.tap(find.byKey(const ValueKey('lock-forgot')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('lock-forgot-confirm')));
    await tester.pumpAndSettle();
    expect(sync.signOuts, 1);
    expect(lock.isEnabled, isFalse);
    expect(prefs.getString(AppLock.pinKey), isNull);
    expect(lockScreen, findsNothing);
    await disposeApp(tester, services);
  });

  testWidgets('로그인이 없는 빌드에는 로그아웃으로 푸는 길이 없다', (tester) async {
    await enableLock();
    final services = await createTestServices();
    await start(tester, services);
    expect(find.byKey(const ValueKey('lock-forgot')), findsNothing);
    await disposeApp(tester, services);
  });

  testWidgets('생체 인증은 이어 준 기기에서 켰을 때만 쓴다', (tester) async {
    await enableLock();
    await lock.setBiometric(true);
    final services = await createTestServices();

    // 이어 주지 않은 기기: 켜 두었어도 단추가 없다.
    await start(tester, services);
    expect(find.byKey(const ValueKey('lock-biometric-unlock')), findsNothing);
    await tester.pumpWidget(const SizedBox());

    // 이어 준 기기: 잠금 화면이 뜨면 바로 묻고, 통과하면 풀린다.
    var asked = 0;
    await start(
      tester,
      services,
      overrides: [
        biometricAuthProvider.overrideWithValue(() async {
          asked++;
          return asked > 1;
        }),
      ],
    );
    expect(asked, 1);
    expect(lockScreen, findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('lock-biometric-unlock')));
    await tester.pumpAndSettle();
    expect(asked, 2);
    expect(lockScreen, findsNothing);
    await disposeApp(tester, services);
  });

  group('잠금 화면은 넘치지 않는다', () {
    for (final (name, size) in fourSizes) {
      testWidgets(name, (tester) async {
        await enableLock();
        final services = await createTestServices();
        await start(
          tester,
          services,
          size: size,
          sync: FakeSyncController.signedIn(),
        );
        expect(lockScreen, findsOneWidget);
        expect(tester.takeException(), isNull);
        // 로그아웃을 묻는 칸도 본다.
        await tester.ensureVisible(find.byKey(const ValueKey('lock-forgot')));
        await tester.tap(find.byKey(const ValueKey('lock-forgot')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await disposeApp(tester, services);
      });
    }

    testWidgets('소형 폰에서 글자를 200%로 키워도', (tester) async {
      await enableLock();
      final services = await createTestServices();
      await start(
        tester,
        services,
        textScale: 2,
        sync: FakeSyncController.signedIn(),
      );
      expect(tester.takeException(), isNull);
      for (var i = 0; i < 5; i++) {
        for (final digit in '0000'.split('')) {
          await tester.ensureVisible(find.byKey(ValueKey('pin-$digit')));
          await tester.tap(find.byKey(ValueKey('pin-$digit')));
        }
        await tester.ensureVisible(find.byKey(const ValueKey('pin-ok')));
        await tester.tap(find.byKey(const ValueKey('pin-ok')));
        await tester.pumpAndSettle();
      }
      expect(find.byKey(const ValueKey('lock-wait')), findsOneWidget);
      expect(tester.takeException(), isNull);
      // 남은 시간을 그리는 시계를 끝낸다.
      clock.advance(const Duration(seconds: 31));
      await tester.pump(const Duration(seconds: 1));
      await disposeApp(tester, services);
    });
  });
}
