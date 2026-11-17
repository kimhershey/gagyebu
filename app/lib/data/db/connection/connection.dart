/// 플랫폼에 맞는 DB 연결을 연다.
///
/// Windows · Android는 앱 데이터 폴더의 SQLite 파일을, 웹은 브라우저 저장소 위의
/// SQLite WebAssembly를 쓴다.
library;

export 'connection_stub.dart'
    if (dart.library.io) 'connection_native.dart'
    if (dart.library.js_interop) 'connection_web.dart';
