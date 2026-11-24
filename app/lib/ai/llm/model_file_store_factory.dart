/// 플랫폼에 맞는 모델 파일 저장소를 만든다.
///
/// Windows · Android는 기기의 파일 시스템을 쓴다. 웹에는 저장소가 없다(모델이 없다).
library;

export 'model_file_store_stub.dart'
    if (dart.library.io) 'model_file_store_io.dart';
