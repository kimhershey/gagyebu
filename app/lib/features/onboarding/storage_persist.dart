/// 브라우저에 "이 사이트의 저장소를 지우지 말아 달라"고 청한다(`navigator.storage.persist`).
///
/// 웹에서만 뜻이 있다. 앱에서는 저장소가 지워지지 않으므로 늘 true다.
library;

export 'storage_persist_stub.dart'
    if (dart.library.js_interop) 'storage_persist_web.dart';
