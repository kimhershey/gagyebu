import 'dart:io';

import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'opened_database.dart';

Future<OpenedDatabase> openAppDatabase() async {
  final dir = await getApplicationSupportDirectory();
  final file = File(p.join(dir.path, 'gagyebu.sqlite'));
  return OpenedDatabase(
    // 질의는 백그라운드 isolate에서 돌려 화면이 끊기지 않게 한다.
    executor: NativeDatabase.createInBackground(file),
    storage: '기기 파일',
    persistent: true,
  );
}
