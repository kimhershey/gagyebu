import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  test('sqlite3 opens through the build hook', () {
    final db = sqlite3.openInMemory();
    final rows = db.select('select sqlite_version() as v, 1 + 1 as two');
    // ignore: avoid_print
    print('sqlite ${rows.first['v']}');
    expect(rows.first['two'], 2);
    db.close();
  });
}
