/// 플랫폼에 맞는 [LocalModelRuntime]을 만든다.
///
/// 네이티브 라이브러리(llama.cpp)는 `dart:io`가 있는 플랫폼에만 있다. 웹 빌드에는
/// 빈 구현이 들어가고, llamadart를 부르는 파일은 아예 컴파일되지 않는다.
library;

export 'local_model_runtime_stub.dart'
    if (dart.library.io) 'local_model_runtime_io.dart';
