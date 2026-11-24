import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

/// 이 브라우저에 저장소 관리자(StorageManager)가 있는지. 오래된 브라우저에는 없다.
bool get _supported => (web.window.navigator as JSObject).has('storage');

/// 저장소가 유지되도록 이미 허락받았는지.
Future<bool> isStoragePersisted() async {
  try {
    if (!_supported) return false;
    return (await web.window.navigator.storage.persisted().toDart).toDart;
  } on Object {
    return false;
  }
}

/// 저장소 유지를 청한다. 허락받았으면 true.
///
/// 브라우저마다 정하는 방식이 다르다. Chrome은 묻지 않고 사이트를 얼마나 쓰는지(홈 화면에
/// 추가했는지 등)를 보고 정하고, Firefox는 사용자에게 묻는다.
Future<bool> requestPersistentStorage() async {
  try {
    if (!_supported) return false;
    return (await web.window.navigator.storage.persist().toDart).toDart;
  } on Object {
    return false;
  }
}
