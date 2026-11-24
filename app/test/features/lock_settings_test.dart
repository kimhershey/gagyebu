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

  setUp(() {
    prefs = MemoryDevicePrefs();
    clock = TestClock();
    // 시험에서는 해시를 적게 돌린다.
    lock = AppLock(prefs, iterations: 20, clock: clock.call);
  });

  Future<void> open(
    WidgetTester tester,
    AppServices services, {
    Size size = desktop,
    double textScale = 1,
    List<Override> overrides = const [],
  }) => pumpAppWith(
    tester,
    services,
    size: size,
    textScale: textScale,
    location: '/settings/lock',
    prefs: prefs,
    clock: clock.call,
    overrides: [appLockProvider.overrideWithValue(lock), ...overrides],
  );

  Future<void> type(WidgetTester tester, String key, String text) async {
    final field = find.byKey(ValueKey(key));
    await tester.ensureVisible(field);
    await tester.enterText(field, text);
  }

  Future<void> tap(WidgetTester tester, String key) async {
    final button = find.byKey(ValueKey(key));
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  testWidgets('화면만 가린다는 것을 알린다', (tester) async {
    final services = await createTestServices();
    await open(tester, services);
    expect(find.text('화면만 가립니다. 기기의 파일은 암호화하지 않습니다.'), findsOneWidget);
    expect(find.text('앱 잠금이 꺼져 있습니다'), findsOneWidget);
    await disposeApp(tester, services);
  });

  testWidgets('번호를 두 번 같게 넣어야 켜진다', (tester) async {
    final services = await createTestServices();
    await open(tester, services);

    await tap(tester, 'lock-enable');
    // 켤 때는 지금 번호를 묻지 않는다.
    expect(find.byKey(const ValueKey('lock-current-pin')), findsNothing);

    await type(tester, 'lock-new-pin', '123');
    await type(tester, 'lock-confirm-pin', '123');
    await tap(tester, 'lock-save');
    expect(find.text('새 번호는 숫자 4–6자리로 정해 주십시오'), findsOneWidget);
    expect(lock.isEnabled, isFalse);

    await type(tester, 'lock-new-pin', '2580');
    await type(tester, 'lock-confirm-pin', '2581');
    await tap(tester, 'lock-save');
    expect(find.text('두 번 넣은 번호가 서로 다릅니다'), findsOneWidget);
    expect(lock.isEnabled, isFalse);

    await type(tester, 'lock-confirm-pin', '2580');
    await tap(tester, 'lock-save');
    expect(lock.isEnabled, isTrue);
    expect(await lock.verify('2580'), isTrue);
    expect(find.text('앱 잠금이 켜져 있습니다'), findsOneWidget);
    expect(find.text('앱 잠금을 켰습니다'), findsOneWidget);
    // 켠 것만으로는 바로 잠그지 않는다.
    expect(find.byKey(const ValueKey('lock-screen')), findsNothing);
    await disposeApp(tester, services);
  });

  testWidgets('숫자만, 여섯 자리까지만 들어간다', (tester) async {
    final services = await createTestServices();
    await open(tester, services);
    await tap(tester, 'lock-enable');
    await type(tester, 'lock-new-pin', '12ab34567');
    expect(
      tester
          .widget<EditableText>(
            find.descendant(
              of: find.byKey(const ValueKey('lock-new-pin')),
              matching: find.byType(EditableText),
            ),
          )
          .controller
          .text,
      '123456',
    );
    await disposeApp(tester, services);
  });

  testWidgets('지금 번호를 알아야 바꿀 수 있다', (tester) async {
    await lock.setPin('2580');
    final services = await createTestServices();
    await open(tester, services);
    // 화면을 여는 데는 잠금을 풀어야 한다.
    for (final digit in '2580'.split('')) {
      await tester.tap(find.byKey(ValueKey('pin-$digit')));
    }
    await tester.tap(find.byKey(const ValueKey('pin-ok')));
    await tester.pumpAndSettle();

    await tap(tester, 'lock-change');
    await type(tester, 'lock-current-pin', '0000');
    await type(tester, 'lock-new-pin', '135790');
    await type(tester, 'lock-confirm-pin', '135790');
    await tap(tester, 'lock-save');
    expect(find.text('지금 번호가 맞지 않습니다'), findsOneWidget);
    expect(await lock.verify('2580'), isTrue);

    await type(tester, 'lock-current-pin', '2580');
    await tap(tester, 'lock-save');
    expect(find.text('잠금 번호를 바꿨습니다'), findsOneWidget);
    expect(await lock.verify('135790'), isTrue);
    expect(await lock.verify('2580'), isFalse);
    await disposeApp(tester, services);
  });

  testWidgets('지금 번호를 넣어야 끌 수 있고, 다섯 번 틀리면 기다려야 한다', (tester) async {
    await lock.setPin('2580');
    final services = await createTestServices();
    await open(tester, services);
    for (final digit in '2580'.split('')) {
      await tester.tap(find.byKey(ValueKey('pin-$digit')));
    }
    await tester.tap(find.byKey(const ValueKey('pin-ok')));
    await tester.pumpAndSettle();

    await tap(tester, 'lock-disable');
    expect(find.byKey(const ValueKey('lock-new-pin')), findsNothing);
    for (var i = 0; i < 5; i++) {
      await type(tester, 'lock-current-pin', '0000');
      await tap(tester, 'lock-save');
    }
    expect(find.textContaining('다섯 번 틀렸습니다'), findsOneWidget);
    // 기다리는 동안에는 맞는 번호도 받지 않는다.
    await type(tester, 'lock-current-pin', '2580');
    await tap(tester, 'lock-save');
    expect(lock.isEnabled, isTrue);

    clock.advance(const Duration(seconds: 31));
    await tap(tester, 'lock-save');
    expect(lock.isEnabled, isFalse);
    expect(find.text('앱 잠금이 꺼져 있습니다'), findsOneWidget);
    expect(find.text('앱 잠금을 껐습니다'), findsOneWidget);
    await disposeApp(tester, services);
  });

  testWidgets('취소하면 아무것도 바뀌지 않는다', (tester) async {
    final services = await createTestServices();
    await open(tester, services);
    await tap(tester, 'lock-enable');
    await type(tester, 'lock-new-pin', '2580');
    await tap(tester, 'lock-cancel');
    expect(lock.isEnabled, isFalse);
    expect(find.byKey(const ValueKey('lock-enable')), findsOneWidget);
    await disposeApp(tester, services);
  });

  testWidgets('생체 인증 줄은 이어 준 기기에서 잠금을 켰을 때만 보인다', (tester) async {
    final services = await createTestServices();
    // 이어 주지 않은 기기
    await lock.setPin('2580');
    await lock.setBiometric(false);
    await open(tester, services);
    for (final digit in '2580'.split('')) {
      await tester.tap(find.byKey(ValueKey('pin-$digit')));
    }
    await tester.tap(find.byKey(const ValueKey('pin-ok')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('lock-biometric')), findsNothing);
    await tester.pumpWidget(const SizedBox());

    // 이어 준 기기
    await lock.clear();
    Future<bool> pass() async => true;
    await open(
      tester,
      services,
      overrides: [biometricAuthProvider.overrideWithValue(pass)],
    );
    // 잠금이 꺼져 있으면 보이지 않는다.
    expect(find.byKey(const ValueKey('lock-biometric')), findsNothing);
    await tap(tester, 'lock-enable');
    await type(tester, 'lock-new-pin', '2580');
    await type(tester, 'lock-confirm-pin', '2580');
    await tap(tester, 'lock-save');
    expect(find.byKey(const ValueKey('lock-biometric')), findsOneWidget);
    expect(lock.biometricEnabled, isFalse);
    await tap(tester, 'lock-biometric');
    expect(lock.biometricEnabled, isTrue);
    expect(prefs.getString(AppLock.biometricKey), 'true');
    await disposeApp(tester, services);
  });

  group('넘치지 않는다', () {
    for (final (name, size) in fourSizes) {
      testWidgets(name, (tester) async {
        final services = await createTestServices();
        await open(tester, services, size: size);
        expect(tester.takeException(), isNull);
        await tap(tester, 'lock-enable');
        await type(tester, 'lock-new-pin', '1');
        await tap(tester, 'lock-save');
        expect(find.byKey(const ValueKey('lock-error')), findsOneWidget);
        expect(tester.takeException(), isNull);
        await disposeApp(tester, services);
      });
    }

    testWidgets('소형 폰에서 글자를 200%로 키워도', (tester) async {
      final services = await createTestServices();
      await open(tester, services, size: phone, textScale: 2);
      expect(tester.takeException(), isNull);
      await tap(tester, 'lock-enable');
      expect(tester.takeException(), isNull);
      await disposeApp(tester, services);
    });
  });
}
