import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gagyebu/core/local_date.dart';
import 'package:gagyebu/data/db/database.dart';
import 'package:gagyebu/data/repositories/ledger_repository.dart';
import 'package:gagyebu/domain/enums.dart';

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('gagyebu-migration'));
  tearDown(() => dir.deleteSync(recursive: true));

  test('1판으로 만든 DB를 열면 2판의 표가 생기고 내용은 남는다', () async {
    final file = File('${dir.path}/app.sqlite');

    // 1판의 DB를 만든다: 2판에서 더한 표를 없애고 판 번호를 1로 되돌린다.
    var db = AppDatabase(NativeDatabase(file));
    final repository = LedgerRepository(db);
    final ledgerId = await repository.ensureLocalLedger();
    final cash = (await repository.accounts(ledgerId)).single.id;
    await repository.addTransaction(
      ledgerId,
      TransactionInput(
        type: TxType.expense,
        occurredOn: LocalDate(2026, 11, 16),
        amount: 8000,
        accountId: cash,
        counterparty: '김밥천국',
      ),
    );
    for (final table in ['input_batches', 'input_batch_items', 'model_files']) {
      await db.customStatement('DROP TABLE $table');
    }
    await db.customStatement('PRAGMA user_version = 1');
    await db.close();

    db = AppDatabase(NativeDatabase(file));
    final tables = await db
        .customSelect("SELECT name FROM sqlite_master WHERE type = 'table'")
        .map((row) => row.read<String>('name'))
        .get();
    expect(
      tables,
      containsAll(['input_batches', 'input_batch_items', 'model_files']),
    );
    expect(
      (await db.select(db.ledgerTransactions).get()).single.receiver,
      '김밥천국',
    );
    expect(await db.select(db.outbox).get(), isNotEmpty);
    expect(
      (await db.customSelect('PRAGMA user_version').getSingle()).read<int>(
        'user_version',
      ),
      2,
    );
    // 새 표에 쓸 수 있다.
    await db
        .into(db.inputBatches)
        .insert(
          InputBatchesCompanion.insert(
            id: 'batch-1',
            ledgerId: ledgerId,
            createdAt: DateTime.utc(2026, 11, 24),
            source: TxSource.paste,
            itemCount: 1,
          ),
        );
    expect(await db.select(db.inputBatches).get(), hasLength(1));
    await db.close();
  });
}
