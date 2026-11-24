import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gagyebu/app/app.dart';
import 'package:gagyebu/app/providers.dart';
import 'package:gagyebu/app/router.dart';
import 'package:gagyebu/data/prefs/device_prefs.dart';
import 'package:gagyebu/platform/update_checker.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../features/test_app.dart';

void main() {
  AppVersion v(String text) => AppVersion.tryParse(text)!;

  group('버전 비교', () {
    test('숫자는 글이 아니라 수로 견준다', () {
      expect(v('1.10.0') > v('1.9.0'), isTrue);
      expect(v('1.9.0') < v('1.10.0'), isTrue);
      expect(v('2.0.0') > v('1.99.99'), isTrue);
      expect(v('0.1.1') > v('0.1.0'), isTrue);
      expect(v('1.2.0') > v('1.2.0'), isFalse);
    });

    test('자리가 모자라면 0으로 보고, 앞의 v와 빌드 번호는 보지 않는다', () {
      expect(v('1.2'), v('1.2.0'));
      expect(v('1.2').hashCode, v('1.2.0').hashCode);
      expect(v('v1.2.0'), v('1.2.0'));
      expect(v('1.2.0+7'), v('1.2.0+12'));
      expect('${v('v1.2.0+7')}', '1.2.0');
    });

    test('시험판 꼬리표가 붙은 버전은 같은 숫자의 정식 버전보다 낮다', () {
      expect(v('1.2.0-beta') < v('1.2.0'), isTrue);
      expect(v('1.2.0') > v('1.2.0-rc.1'), isTrue);
      expect(v('1.2.0-beta') > v('1.1.9'), isTrue);
      expect(v('1.2.0-beta').isPreRelease, isTrue);
      expect(v('1.2.0').isPreRelease, isFalse);
    });

    test('꼬리표끼리는 수는 수로, 글은 글로 견준다', () {
      expect(v('1.2.0-beta.2') < v('1.2.0-beta.10'), isTrue);
      expect(v('1.2.0-alpha') < v('1.2.0-beta'), isTrue);
      expect(v('1.2.0-beta') < v('1.2.0-beta.1'), isTrue);
      expect(v('1.2.0-1') < v('1.2.0-alpha'), isTrue);
      expect(v('1.2.0-rc.1'), v('1.2.0-rc.1'));
    });

    test('버전이 아닌 글은 읽지 않는다', () {
      for (final text in [
        '',
        'latest',
        '1..2',
        '1.x.0',
        '1.2.0-',
        '-1.0.0',
        '1.2.3.4.5',
        '99999999999999999999.0.0',
      ]) {
        expect(AppVersion.tryParse(text), isNull, reason: text);
      }
      expect(AppVersion.tryParse(null), isNull);
    });
  });

  group('업데이트 확인', () {
    late MemoryDevicePrefs prefs;
    late DateTime now;
    late int requests;

    /// 서버가 줄 답. null이면 연결이 끊긴 것처럼 예외를 던진다.
    late (int, String)? answer;

    const manifest = {
      'latest': '1.10.0',
      'min': '1.0.0',
      'notes': '예산 화면을 고쳤습니다.',
      'android': 'https://example.com/gagyebu.apk',
      'windows': 'https://example.com/gagyebu-setup.exe',
    };

    setUp(() {
      prefs = MemoryDevicePrefs();
      now = DateTime.utc(2026, 11, 24, 9);
      requests = 0;
      answer = (200, jsonEncode(manifest));
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
    });

    tearDown(() => debugDefaultTargetPlatformOverride = null);

    UpdateChecker checker(String? current) => UpdateChecker(
      prefs: prefs,
      currentVersion: () async => current,
      clock: () => now,
      client: MockClient((request) async {
        requests++;
        expect(request.url, UpdateChecker.source);
        final (status, body) = answer ?? (throw Exception('offline'));
        return http.Response.bytes(utf8.encode(body), status);
      }),
    );

    test('새 버전이 있으면 이 플랫폼의 주소와 함께 알린다', () async {
      final info = (await checker('1.9.0').check())!;
      expect(info.current, '1.9.0');
      expect(info.latest, '1.10.0');
      expect(info.required, isFalse);
      expect(info.notes, '예산 화면을 고쳤습니다.');
      expect('${info.download}', 'https://example.com/gagyebu.apk');

      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      final onWindows = (await checker('1.9.0').check())!;
      expect('${onWindows.download}', 'https://example.com/gagyebu-setup.exe');
    });

    test('같거나 더 높은 버전을 쓰고 있으면 알리지 않는다', () async {
      expect(await checker('1.10.0').check(), isNull);
      expect(await checker('1.11.0').check(), isNull);
      // 정식 버전을 쓰는데 같은 숫자의 시험판이 최신으로 적혀 있어도 알리지 않는다.
      answer = (200, jsonEncode({...manifest, 'latest': '1.9.0-beta.1'}));
      prefs = MemoryDevicePrefs();
      expect(await checker('1.9.0').check(), isNull);
    });

    test('시험판을 쓰고 있으면 같은 숫자의 정식 버전을 알린다', () async {
      final info = await checker('1.10.0-beta.2').check();
      expect(info?.latest, '1.10.0');
    });

    test('min보다 낮으면 꼭 올려야 한다고 알린다', () async {
      final info = (await checker('0.9.3').check())!;
      expect(info.required, isTrue);
      expect((await checker('1.0.0').check())!.required, isFalse);
    });

    test('하루에 한 번만 묻고, 그사이에는 받아 둔 내용으로 알린다', () async {
      expect((await checker('1.9.0').check())?.latest, '1.10.0');
      expect(requests, 1);
      expect(prefs.getString(UpdateChecker.checkedAtKey), isNotNull);

      // 앱을 다시 켰다(확인하는 쪽이 새로 만들어졌다). 23시간 뒤에는 묻지 않는다.
      now = now.add(const Duration(hours: 23));
      answer = (200, jsonEncode({...manifest, 'latest': '1.11.0'}));
      expect((await checker('1.9.0').check())?.latest, '1.10.0');
      expect(requests, 1);
      // 그사이 앱을 올렸으면 받아 둔 내용으로도 알림이 사라진다.
      expect(await checker('1.10.0').check(), isNull);
      expect(requests, 1);

      // 하루가 지나면 다시 묻는다.
      now = now.add(const Duration(hours: 2));
      expect((await checker('1.9.0').check())?.latest, '1.11.0');
      expect(requests, 2);
    });

    test('기기의 시계가 뒤로 갔으면 다시 묻는다', () async {
      await checker('1.9.0').check();
      now = now.subtract(const Duration(days: 3));
      await checker('1.9.0').check();
      expect(requests, 2);
    });

    test('파일을 못 읽으면 조용히 넘어가고, 다음에 다시 묻는다', () async {
      // 연결이 끊겼거나, 파일이 없거나, 내용이 JSON 객체가 아니다.
      for (final failure in <(int, String)?>[
        null,
        (404, 'Not Found'),
        (500, jsonEncode(manifest)),
        (200, '<html>'),
        (200, '[]'),
      ]) {
        answer = failure;
        expect(await checker('1.9.0').check(), isNull, reason: '$failure');
        // 읽지 못한 것은 본 것으로 치지 않는다.
        expect(prefs.getString(UpdateChecker.checkedAtKey), isNull);
      }
      expect(requests, 5);

      answer = (200, jsonEncode(manifest));
      expect((await checker('1.9.0').check())?.latest, '1.10.0');
      expect(requests, 6);
    });

    test('파일의 버전이 이상하면 알리지 않는다', () async {
      for (final latest in <Object?>[3, 'soon', null, '']) {
        prefs = MemoryDevicePrefs();
        answer = (200, jsonEncode({...manifest, 'latest': latest}));
        expect(await checker('1.9.0').check(), isNull, reason: '$latest');
      }
      // min이 이상하면 꼭 올리라고 하지는 않는다.
      prefs = MemoryDevicePrefs();
      answer = (200, jsonEncode({...manifest, 'min': 'x'}));
      expect((await checker('0.1.0').check())?.required, isFalse);
    });

    test('못 읽었을 때는 전에 받아 둔 내용으로 알린다', () async {
      await checker('1.9.0').check();
      now = now.add(const Duration(days: 2));
      answer = null;
      expect((await checker('1.9.0').check())?.latest, '1.10.0');
      expect(requests, 2);
    });

    test('주소가 없거나 https가 아니면 릴리스 페이지로 보낸다', () async {
      for (final address in [
        null,
        '',
        'http://example.com/a.apk',
        'file:///x',
      ]) {
        prefs = MemoryDevicePrefs();
        answer = (200, jsonEncode({...manifest, 'android': address}));
        final info = (await checker('1.9.0').check())!;
        expect(info.download, UpdateChecker.releases, reason: '$address');
      }
    });

    test('앱의 버전을 알 수 없으면 묻지 않는다', () async {
      expect(await checker(null).check(), isNull);
      expect(await checker('dev').check(), isNull);
      expect(requests, 0);
    });

    test('Windows · Android 앱이 아니면 아무것도 하지 않는다', () async {
      for (final platform in [
        TargetPlatform.linux,
        TargetPlatform.macOS,
        TargetPlatform.iOS,
        TargetPlatform.fuchsia,
      ]) {
        debugDefaultTargetPlatformOverride = platform;
        expect(await checker('1.9.0').check(), isNull, reason: '$platform');
      }
      expect(requests, 0);
      expect(prefs.getString(UpdateChecker.checkedAtKey), isNull);
    });
  });

  group('알림 띠', () {
    final opened = <Uri>[];

    /// 설정 화면을 띄운다. [info]가 있으면 새 버전이 있는 것으로 한다.
    Future<AppServices> pumpSettings(
      WidgetTester tester, {
      required UpdateInfo? info,
      Size size = phone,
    }) async {
      opened.clear();
      final services = await createTestServices();
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appServicesProvider.overrideWithValue(services),
            clockProvider.overrideWithValue(() => testNow),
            updateInfoProvider.overrideWith((ref) async => info),
            updateLauncherProvider.overrideWithValue((url) async {
              opened.add(url);
              return true;
            }),
          ],
          child: GagyebuApp(router: createRouter(initialLocation: '/settings')),
        ),
      );
      await tester.pumpAndSettle();
      return services;
    }

    UpdateInfo info({bool required = false}) => UpdateInfo(
      current: '1.9.0',
      latest: '1.10.0',
      required: required,
      download: Uri.parse('https://example.com/gagyebu.apk'),
      notes: '예산 화면을 고쳤습니다. 내역의 달력에서 날짜를 눌러 그날의 거래를 볼 수 있습니다.',
    );

    testWidgets('새 버전이 없으면 아무것도 그리지 않는다', (tester) async {
      final services = await pumpSettings(tester, info: null);
      expect(find.byKey(const ValueKey('update-banner')), findsNothing);
      await disposeApp(tester, services);
    });

    testWidgets('새 버전이 있으면 알리고, 누르면 내려받기 주소를 연다', (tester) async {
      final services = await pumpSettings(tester, info: info());
      expect(find.byKey(const ValueKey('update-banner')), findsOneWidget);
      expect(find.text('새 버전이 나왔습니다'), findsOneWidget);
      expect(find.textContaining('1.10.0'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('update-download')));
      await tester.pumpAndSettle();
      expect(opened, [Uri.parse('https://example.com/gagyebu.apk')]);
      await disposeApp(tester, services);
    });

    testWidgets('꼭 올려야 하는 버전이면 그렇게 적는다', (tester) async {
      final services = await pumpSettings(tester, info: info(required: true));
      expect(find.text('꼭 업데이트해야 합니다'), findsOneWidget);
      expect(find.textContaining('더 지원하지 않습니다'), findsOneWidget);
      // 막지는 않는다. 설정의 나머지는 그대로 쓸 수 있다.
      expect(find.text('설정'), findsWidgets);
      expect(find.byKey(const ValueKey('nav-bottom')), findsOneWidget);
      await disposeApp(tester, services);
    });

    for (final (name, size) in [
      ('360×640', phone),
      ('412×915', largePhone),
      ('700×800', foldable),
      ('1280×800', desktop),
    ]) {
      testWidgets('$name에서 넘치지 않는다', (tester) async {
        final services = await pumpSettings(
          tester,
          info: info(required: true),
          size: size,
        );
        expect(find.byKey(const ValueKey('update-banner')), findsOneWidget);
        expect(tester.takeException(), isNull);
        await disposeApp(tester, services);
      });
    }
  });
}
