import 'package:drift/drift.dart';

/// 열린 DB 연결과 저장 방식에 대한 설명.
class OpenedDatabase {
  const OpenedDatabase({
    required this.executor,
    required this.storage,
    required this.persistent,
    this.takenOver,
  });

  final QueryExecutor executor;

  /// 설정 화면에 보여 줄 저장 방식(예: '기기 파일', 'OPFS', 'IndexedDB').
  final String storage;

  /// 앱을 닫아도 데이터가 남는지. 브라우저가 저장소를 허용하지 않으면 false다.
  final bool persistent;

  /// 다른 탭이 같은 저장소를 열어 이 연결을 더 쓰면 안 될 때 끝난다.
  ///
  /// 탭마다 DB 사본을 따로 드는 브라우저에서만 준다. 그 밖에는 null이다.
  final Future<void>? takenOver;
}
