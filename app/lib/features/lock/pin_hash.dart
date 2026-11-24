/// 잠금 번호의 해시: PBKDF2-HMAC-SHA256(RFC 8018).
library;

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

/// PBKDF2의 첫 블록(32바이트)을 한 바퀴씩 계산한다.
///
/// 해시 길이와 같은 32바이트만 쓰므로 블록은 하나면 된다.
class _Pbkdf2Block {
  _Pbkdf2Block(List<int> password, List<int> salt)
    : _hmac = Hmac(sha256, password) {
    // U1 = HMAC(password, salt || INT(1))
    _u = _hmac.convert([...salt, 0, 0, 0, 1]).bytes;
    result = Uint8List.fromList(_u);
  }

  final Hmac _hmac;
  late List<int> _u;

  /// 지금까지의 U1 ^ U2 ^ … 값.
  late final Uint8List result;

  /// [rounds]바퀴를 더 돈다.
  void run(int rounds) {
    final t = result;
    for (var i = 0; i < rounds; i++) {
      _u = _hmac.convert(_u).bytes;
      for (var j = 0; j < t.length; j++) {
        t[j] ^= _u[j];
      }
    }
  }
}

/// PBKDF2-HMAC-SHA256의 32바이트 키. [iterations]는 1 이상이어야 한다.
Uint8List pbkdf2HmacSha256(List<int> password, List<int> salt, int iterations) {
  if (iterations < 1) {
    throw ArgumentError.value(iterations, 'iterations', '1 이상이어야 한다');
  }
  return (_Pbkdf2Block(password, salt)..run(iterations - 1)).result;
}

/// 이 횟수보다 적으면 그 자리에서 계산한다. 격리 영역을 띄우는 값이 더 크다.
const _inlineBelow = 5000;

/// 웹에서 한 번에 도는 바퀴 수. 이만큼 돌 때마다 화면이 그려질 틈을 준다.
const _webSlice = 4000;

/// [pbkdf2HmacSha256]을 화면을 멈추지 않고 계산한다.
///
/// 10만 번은 0.5초쯤 걸린다. 앱에서는 다른 격리 영역에서 돈다. 웹에는 격리 영역이 없어
/// (`compute`도 같은 스레드에서 돈다) 여러 토막으로 나눠 사이사이에 화면을 그리게 한다.
Future<Uint8List> derivePinHash(
  List<int> password,
  List<int> salt,
  int iterations,
) async {
  if (iterations < _inlineBelow) {
    return pbkdf2HmacSha256(password, salt, iterations);
  }
  if (!kIsWeb) {
    return compute(_deriveInIsolate, (password, salt, iterations));
  }
  final block = _Pbkdf2Block(password, salt);
  var left = iterations - 1;
  while (left > 0) {
    final rounds = left < _webSlice ? left : _webSlice;
    block.run(rounds);
    left -= rounds;
    await Future<void>.delayed(Duration.zero);
  }
  return block.result;
}

Uint8List _deriveInIsolate((List<int>, List<int>, int) args) =>
    pbkdf2HmacSha256(args.$1, args.$2, args.$3);
