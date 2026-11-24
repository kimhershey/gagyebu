/// 모델 파일을 두는 곳(`docs/SPEC.md` 5.4: 앱 지원 폴더의 `models/`).
///
/// 파일 접근은 `dart:io`라 웹에서 컴파일되지 않는다. 그래서 창구만 여기에 두고
/// 구현은 플랫폼별 파일로 나눈다(`model_file_store_factory.dart`). 시험에서는 메모리에
/// 두는 가짜를 쓴다.
library;

/// 파일에 이어 쓰는 통로.
abstract interface class ModelFileSink {
  Future<void> add(List<int> bytes);
  Future<void> close();
}

/// 모델 파일의 저장소.
abstract interface class ModelFileStore {
  /// [fileName]을 둘 경로. 폴더가 없으면 만든다.
  Future<String> pathFor(String fileName);

  Future<bool> exists(String path);

  /// 파일의 크기(바이트). 없으면 0.
  Future<int> length(String path);

  /// 쓰기 통로를 연다. [append]면 있던 내용 뒤에 잇고, 아니면 처음부터 쓴다.
  Future<ModelFileSink> openWrite(String path, {required bool append});

  /// 파일의 SHA-256(소문자 16진수).
  Future<String> sha256Of(String path);

  Future<void> rename(String from, String to);

  /// 지운다. 없으면 아무것도 하지 않는다.
  Future<void> delete(String path);

  /// 모델 폴더가 있는 저장 장치의 빈 공간(바이트). 알 수 없으면 null.
  Future<int?> freeSpace();
}
