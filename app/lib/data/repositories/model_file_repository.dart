import 'package:drift/drift.dart';

import '../../ai/llm/model_catalog.dart';
import '../../ai/llm/model_manager.dart';
import '../db/database.dart';

/// 기기에 내려받은 모델 파일의 기록(`model_files` 표). 기기에만 있고 서버로 올리지
/// 않으므로 대기열에 올리지 않는다.
class ModelFileRepository implements ModelFileRegistry {
  ModelFileRepository(this.db);

  final AppDatabase db;

  /// 모델 파일의 기록. 바뀔 때마다 다시 준다.
  Stream<List<ModelFileRecord>> watch() => (db.select(
    db.modelFiles,
  )..orderBy([(m) => OrderingTerm.asc(m.id)])).watch().map(_records);

  @override
  Future<List<ModelFileRecord>> all() async => _records(
    await (db.select(
      db.modelFiles,
    )..orderBy([(m) => OrderingTerm.asc(m.id)])).get(),
  );

  @override
  Future<ModelFileRecord?> byId(String id) async {
    final row = await (db.select(
      db.modelFiles,
    )..where((m) => m.id.equals(id))).getSingleOrNull();
    return row == null ? null : _record(row);
  }

  @override
  Future<void> put(ModelFileRecord record) => db
      .into(db.modelFiles)
      .insertOnConflictUpdate(
        ModelFilesCompanion.insert(
          id: record.id,
          kind: record.kind.code,
          fileName: record.fileName,
          path: record.path,
          sizeBytes: record.sizeBytes,
          downloadedBytes: Value(record.downloadedBytes),
          sha256: record.sha256,
          status: record.status.code,
          updatedAt: record.updatedAt,
        ),
      );

  @override
  Future<void> remove(String id) =>
      (db.delete(db.modelFiles)..where((m) => m.id.equals(id))).go();

  List<ModelFileRecord> _records(List<ModelFileRow> rows) => [
    for (final row in rows) ?_record(row),
  ];

  /// 이 앱이 모르는 종류의 줄은 버린다(다른 판의 앱이 적은 것일 수 있다).
  ModelFileRecord? _record(ModelFileRow row) {
    final kind = ModelKind.fromCode(row.kind);
    if (kind == null) return null;
    return ModelFileRecord(
      id: row.id,
      kind: kind,
      fileName: row.fileName,
      path: row.path,
      sizeBytes: row.sizeBytes,
      downloadedBytes: row.downloadedBytes,
      sha256: row.sha256,
      status: ModelFileStatus.fromCode(row.status),
      updatedAt: row.updatedAt,
    );
  }
}
