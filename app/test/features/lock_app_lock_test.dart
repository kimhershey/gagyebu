import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gagyebu/data/prefs/device_prefs.dart';
import 'package:gagyebu/features/lock/app_lock.dart';
import 'package:gagyebu/features/lock/pin_hash.dart';

String _hex(List<int> bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

void main() {
  group('PBKDF2-HMAC-SHA256', () {
    // RFC 7914 11절의 시험 벡터(64바이트 가운데 첫 블록 32바이트).
    test('한 번 돌린 값이 표준의 값과 같다', () {
      expect(
        _hex(pbkdf2HmacSha256(utf8.encode('passwd'), utf8.encode('salt'), 1)),
        '55ac046e56e3089fec1691c22544b605f94185216dde0465e68b9d57c20dacbc',
      );
    });

    test('8만 번 돌린 값이 표준의 값과 같다', () {
      expect(
        _hex(
          pbkdf2HmacSha256(utf8.encode('Password'), utf8.encode('NaCl'), 80000),
        ),
        '4ddcd8f60b98be21830cee5ef22701f9641a4418d04c0414aeff08876b34ab56',
      );
    });

    test('두 번 돌린 값은 U1 ^ U2다', () {
      final password = utf8.encode('1234');
      final salt = [1, 2, 3, 4];
      final hmac = Hmac(sha256, password);
      final u1 = hmac.convert([...salt, 0, 0, 0, 1]).bytes;
      final u2 = hmac.convert(u1).bytes;
      expect(pbkdf2HmacSha256(password, salt, 2), [
        for (var i = 0; i < 32; i++) u1[i] ^ u2[i],
      ]);
    });

    test('횟수가 0이면 받지 않는다', () {
      expect(() => pbkdf2HmacSha256([1], [2], 0), throwsArgumentError);
    });

    test('많이 돌릴 때는 다른 격리 영역에서 돌고, 값은 같다', () async {
      final password = utf8.encode('135790');
      final salt = List<int>.generate(16, (i) => i * 7);
      expect(
        await derivePinHash(password, salt, 6000),
        pbkdf2HmacSha256(password, salt, 6000),
      );
    });
  });

  group('잠금 번호', () {
    late MemoryDevicePrefs prefs;
    late DateTime now;
    late AppLock lock;

    setUp(() {
      prefs = MemoryDevicePrefs();
      now = DateTime(2026, 11, 17, 12);
      lock = AppLock(
        prefs,
        iterations: 20,
        clock: () => now,
        random: Random(1),
      );
    });

    test('처음에는 꺼져 있고 어떤 번호도 맞지 않는다', () async {
      expect(lock.isEnabled, isFalse);
      expect(await lock.verify('1234'), isFalse);
    });

    test('정한 번호만 맞는다', () async {
      await lock.setPin('2580');
      expect(lock.isEnabled, isTrue);
      expect(await lock.verify('2580'), isTrue);
      expect(await lock.verify('2581'), isFalse);
      expect(await lock.verify('25800'), isFalse);
      expect(await lock.verify(''), isFalse);
    });

    test('번호 그대로가 아니라 솔트와 해시를 기기 설정에 둔다', () async {
      await lock.setPin('123456');
      final stored = prefs.getString(AppLock.pinKey)!;
      final parts = stored.split(r'$');
      expect(parts, hasLength(4));
      expect(parts[0], 'pbkdf2-sha256');
      expect(parts[1], '20');
      final salt = base64Decode(parts[2]);
      expect(salt, hasLength(16));
      expect(stored, isNot(contains('123456')));
      expect(
        base64Decode(parts[3]),
        pbkdf2HmacSha256(utf8.encode('123456'), salt, 20),
      );
    });

    test('같은 번호라도 정할 때마다 솔트가 달라 저장한 값이 다르다', () async {
      await lock.setPin('2580');
      final first = prefs.getString(AppLock.pinKey);
      await lock.setPin('2580');
      expect(prefs.getString(AppLock.pinKey), isNot(first));
      expect(await lock.verify('2580'), isTrue);
    });

    test('기본 횟수는 10만 번이고, 확인은 저장할 때의 횟수로 한다', () async {
      expect(AppLock.defaultIterations, 100000);
      expect(AppLock(prefs).iterations, 100000);
      await lock.setPin('2580');
      // 횟수를 다르게 잡은 앱(다음 판)에서도 예전에 정한 번호가 맞는다.
      final later = AppLock(prefs, iterations: 35);
      expect(await later.verify('2580'), isTrue);
    });

    test('숫자 4–6자리만 받는다', () async {
      expect(AppLock.isValidPin('1234'), isTrue);
      expect(AppLock.isValidPin('123456'), isTrue);
      expect(AppLock.isValidPin('123'), isFalse);
      expect(AppLock.isValidPin('1234567'), isFalse);
      expect(AppLock.isValidPin('12a4'), isFalse);
      expect(AppLock.isValidPin('１２３４'), isFalse);
      await expectLater(lock.setPin('12'), throwsArgumentError);
      expect(lock.isEnabled, isFalse);
    });

    test('끄면 번호와 생체 인증 설정이 지워진다', () async {
      await lock.setPin('2580');
      await lock.setBiometric(true);
      expect(lock.biometricEnabled, isTrue);
      await lock.clear();
      expect(lock.isEnabled, isFalse);
      expect(lock.biometricEnabled, isFalse);
      expect(prefs.getString(AppLock.pinKey), isNull);
      expect(prefs.getString(AppLock.biometricKey), isNull);
    });

    test('저장한 값이 깨져 있으면 꺼진 것으로 본다', () async {
      await prefs.setString(AppLock.pinKey, 'pbkdf2-sha256\$x\$??\$??');
      expect(lock.isEnabled, isFalse);
      await prefs.setString(AppLock.pinKey, '1234');
      expect(lock.isEnabled, isFalse);
    });

    test('다섯 번 틀리면 30초 동안 맞는 번호도 받지 않는다', () async {
      await lock.setPin('2580');
      for (var i = 0; i < 4; i++) {
        expect(await lock.unlock('0000'), UnlockResult.wrong);
        expect(lock.waitRemaining, Duration.zero);
        expect(lock.attemptsLeft, 4 - i);
      }
      expect(await lock.unlock('0000'), UnlockResult.wrong);
      expect(lock.waitRemaining, const Duration(seconds: 30));

      expect(await lock.unlock('2580'), UnlockResult.waiting);
      now = now.add(const Duration(seconds: 29));
      expect(await lock.unlock('2580'), UnlockResult.waiting);
      expect(lock.waitRemaining, const Duration(seconds: 1));

      now = now.add(const Duration(seconds: 1));
      expect(lock.waitRemaining, Duration.zero);
      expect(await lock.unlock('2580'), UnlockResult.ok);
    });

    test('맞히면 틀린 횟수를 처음부터 다시 센다', () async {
      await lock.setPin('2580');
      for (var i = 0; i < 4; i++) {
        await lock.unlock('0000');
      }
      expect(await lock.unlock('2580'), UnlockResult.ok);
      expect(lock.attemptsLeft, AppLock.maxAttempts);
      for (var i = 0; i < 4; i++) {
        expect(await lock.unlock('0000'), UnlockResult.wrong);
      }
      expect(lock.waitRemaining, Duration.zero);
    });

    test('기다린 뒤에는 다시 다섯 번을 넣어 볼 수 있다', () async {
      await lock.setPin('2580');
      for (var i = 0; i < 5; i++) {
        await lock.unlock('0000');
      }
      now = now.add(const Duration(seconds: 31));
      for (var i = 0; i < 4; i++) {
        expect(await lock.unlock('0000'), UnlockResult.wrong);
        expect(lock.waitRemaining, Duration.zero);
      }
      expect(await lock.unlock('0000'), UnlockResult.wrong);
      expect(lock.waitRemaining, const Duration(seconds: 30));
    });
  });
}
