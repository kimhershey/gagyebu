import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

/// 이 탭이 쥔 잠금.
class TabClaim {
  const TabClaim(this.takenOver);

  /// 다른 탭이 잠금을 가져갔을 때 끝난다.
  final Future<void> takenOver;
}

/// 이 탭이 [name] 잠금을 가져온다. 먼저 쥐고 있던 탭은 빼앗긴다(Web Locks의 steal).
///
/// 잠금을 쥔 뒤에 끝난다. 브라우저가 Web Locks를 지원하지 않거나 요청이 거절되면 null을
/// 돌려준다. 잠금은 탭을 닫거나 새로 고치면 브라우저가 알아서 푼다.
Future<TabClaim?> claimSingleTab(String name) async {
  final navigator = web.window.navigator;
  if (!(navigator as JSObject).has('locks')) return null;

  final acquired = Completer<bool>();
  final takenOver = Completer<void>();
  // 끝내지 않는 약속. 탭이 살아 있는 동안 잠금을 쥐고 있게 한다.
  final hold = Completer<JSAny?>();

  JSPromise<JSAny?> granted(web.Lock? _) {
    if (!acquired.isCompleted) acquired.complete(true);
    return hold.future.toJS;
  }

  try {
    navigator.locks
        .request(name, web.LockOptions(steal: true), granted.toJS)
        .toDart
        .then(
          (_) {},
          onError: (Object _) {
            if (!acquired.isCompleted) {
              // 잠금을 받기도 전에 거절됐다. 막는 장치 없이 연다.
              acquired.complete(false);
            } else if (!takenOver.isCompleted) {
              // 다른 탭이 steal로 가져갔다.
              takenOver.complete();
            }
          },
        );
  } catch (_) {
    return null;
  }

  return await acquired.future ? TabClaim(takenOver.future) : null;
}
