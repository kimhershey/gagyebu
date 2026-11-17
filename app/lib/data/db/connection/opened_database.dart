import 'package:drift/drift.dart';

/// 열린 DB 연결과 저장 방식에 대한 설명.
class OpenedDatabase {
  const OpenedDatabase({
    required this.executor,
    required this.storage,
    required this.persistent,
  });

  final QueryExecutor executor;

  /// 설정 화면에 보여 줄 저장 방식(예: '기기 파일', 'OPFS', 'IndexedDB').
  final String storage;

  /// 앱을 닫아도 데이터가 남는지. 브라우저가 저장소를 허용하지 않으면 false다.
  final bool persistent;
}
