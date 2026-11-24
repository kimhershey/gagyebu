import 'model_file_store.dart';

/// 이 플랫폼(웹)에는 모델 파일을 둘 곳이 없다.
const bool modelFileStoreAvailable = false;

/// 저장소가 없으므로 부르면 안 된다. [modelFileStoreAvailable]을 먼저 본다.
ModelFileStore createModelFileStore(Future<String> Function() baseDirectory) =>
    throw UnsupportedError('이 플랫폼에는 모델 파일을 둘 곳이 없다');
