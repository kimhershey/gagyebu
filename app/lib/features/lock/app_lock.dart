import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../data/prefs/device_prefs.dart';
import 'pin_hash.dart';

/// 잠금 번호를 넣어 본 결과.
enum UnlockResult {
  /// 맞았다.
  ok,

  /// 틀렸다.
  wrong,

  /// 여러 번 틀려 기다리는 중이라 확인하지 않았다.
  waiting,
}

/// 앱 잠금(`docs/SPEC.md` 7.17).
///
/// 잠금 번호는 솔트를 섞은 PBKDF2-SHA256 해시로 기기 설정(`lock.pin`)에만 둔다. 서버로
/// 가지 않는다. 이 잠금은 화면을 가릴 뿐이고 기기의 DB 파일을 암호화하지 않는다.
class AppLock {
  AppLock(
    this._prefs, {
    this.iterations = defaultIterations,
    DateTime Function()? clock,
    Random? random,
  }) : _clock = clock ?? DateTime.now,
       _random = random ?? Random.secure();

  /// 기기 설정의 키.
  static const pinKey = 'lock.pin';
  static const biometricKey = 'lock.biometric';

  static const defaultIterations = 100000;

  /// 잠금 번호의 길이.
  static const minLength = 4;
  static const maxLength = 6;

  /// 이만큼 잇달아 틀리면 [waitAfterFailures] 동안 기다려야 한다.
  static const maxAttempts = 5;
  static const waitAfterFailures = Duration(seconds: 30);

  /// 앱을 뒤로 보낸 채 이보다 오래 있으면 돌아올 때 다시 잠근다.
  static const relockAfter = Duration(minutes: 1);

  static const _scheme = 'pbkdf2-sha256';
  static final _pinPattern = RegExp('^[0-9]{$minLength,$maxLength}\$');

  final DevicePrefs _prefs;

  /// 새 번호를 정할 때 쓰는 반복 횟수. 확인할 때는 저장할 때 적어 둔 횟수를 쓴다.
  final int iterations;
  final DateTime Function() _clock;
  final Random _random;

  int _failures = 0;
  DateTime? _retryAt;

  /// 숫자 4–6자리인지.
  static bool isValidPin(String pin) => _pinPattern.hasMatch(pin);

  /// 잠금이 켜져 있는지.
  bool get isEnabled => _stored() != null;

  /// [pin]이 저장한 번호와 같은지. 틀린 횟수는 세지 않는다([unlock]이 센다).
  Future<bool> verify(String pin) async {
    final stored = _stored();
    if (stored == null || !isValidPin(pin)) return false;
    final hash = await derivePinHash(
      utf8.encode(pin),
      stored.salt,
      stored.iterations,
    );
    return _sameBytes(hash, stored.hash);
  }

  /// 잠금 번호를 정한다(켜기와 바꾸기). 숫자 4–6자리가 아니면 [ArgumentError].
  Future<void> setPin(String pin) async {
    if (!isValidPin(pin)) {
      throw ArgumentError('잠금 번호는 숫자 $minLength–$maxLength자리여야 한다');
    }
    final salt = Uint8List.fromList([
      for (var i = 0; i < 16; i++) _random.nextInt(256),
    ]);
    final hash = await derivePinHash(utf8.encode(pin), salt, iterations);
    await _prefs.setString(
      pinKey,
      [_scheme, iterations, base64Encode(salt), base64Encode(hash)].join(r'$'),
    );
    _failures = 0;
    _retryAt = null;
  }

  /// 잠금을 끈다. 생체 인증 설정도 함께 지운다.
  Future<void> clear() async {
    await _prefs.remove(pinKey);
    await _prefs.remove(biometricKey);
    _failures = 0;
    _retryAt = null;
  }

  /// 다시 넣어 볼 수 있을 때까지 남은 시간. 기다릴 것이 없으면 0이다.
  Duration get waitRemaining {
    final at = _retryAt;
    if (at == null) return Duration.zero;
    final left = at.difference(_clock());
    if (left <= Duration.zero) {
      _retryAt = null;
      return Duration.zero;
    }
    return left;
  }

  /// 기다리기 전까지 더 틀려도 되는 횟수.
  int get attemptsLeft => maxAttempts - _failures;

  /// [pin]으로 잠금을 풀어 본다. 틀린 횟수를 세고, [maxAttempts]번 잇달아 틀리면
  /// [waitAfterFailures] 동안은 확인하지 않고 [UnlockResult.waiting]을 돌려준다.
  Future<UnlockResult> unlock(String pin) async {
    if (waitRemaining > Duration.zero) return UnlockResult.waiting;
    if (await verify(pin)) {
      _failures = 0;
      return UnlockResult.ok;
    }
    _failures++;
    if (_failures >= maxAttempts) {
      _failures = 0;
      _retryAt = _clock().add(waitAfterFailures);
    }
    return UnlockResult.wrong;
  }

  /// 생체 인증으로도 풀게 해 두었는지.
  bool get biometricEnabled => _prefs.getString(biometricKey) == 'true';

  Future<void> setBiometric(bool enabled) => enabled
      ? _prefs.setString(biometricKey, 'true')
      : _prefs.remove(biometricKey);

  /// 저장한 값을 읽는다. 없거나 꼴이 다르면 null(잠금 꺼짐).
  ({int iterations, Uint8List salt, Uint8List hash})? _stored() {
    final parts = _prefs.getString(pinKey)?.split(r'$');
    if (parts == null || parts.length != 4 || parts[0] != _scheme) return null;
    final count = int.tryParse(parts[1]);
    if (count == null || count < 1) return null;
    try {
      return (
        iterations: count,
        salt: base64Decode(parts[2]),
        hash: base64Decode(parts[3]),
      );
    } on FormatException {
      return null;
    }
  }

  /// 앞에서 다른 글자를 만나도 끝까지 견준다(걸린 시간으로 맞은 자리를 짐작하지 못하게).
  static bool _sameBytes(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }
}

final appLockProvider = Provider<AppLock>(
  (ref) =>
      AppLock(ref.watch(devicePrefsProvider), clock: ref.watch(clockProvider)),
);

/// 기기의 생체 인증을 띄우는 함수. 통과하면 true.
///
/// 플랫폼 쪽(Android)이 이어 주기 전에는 null이다. null이면 생체 인증에 관한 것을 모두
/// 숨긴다.
final biometricAuthProvider = Provider<Future<bool> Function()?>((ref) => null);
