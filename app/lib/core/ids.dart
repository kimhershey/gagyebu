import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// 기기에서 만드는 행 ID. UUIDv7이라 오프라인에서도 겹치지 않고 만든 순서대로 정렬된다.
String newRowId() => _uuid.v7();

/// 기기 · 묶음 식별자처럼 순서가 필요 없는 ID.
String newRandomId() => _uuid.v4();
