import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gagyebu/core/local_date.dart';
import 'package:gagyebu/data/db/database.dart';
import 'package:gagyebu/data/repositories/ledger_repository.dart';
import 'package:gagyebu/data/sync/ledger_adoption.dart';
import 'package:gagyebu/data/sync/sync_engine.dart';
import 'package:gagyebu/domain/enums.dart';

import 'fake_sync_server.dart';

/// 로그인 전의 기기 한 대.
class _Device {
  _Device(FakeSyncServer server, String name) {
    repo = LedgerRepository(db, clock: () => now);
    var batch = 0;
    engine = SyncEngine(
      db: db,
      gateway: server,
      deviceId: name,
      clock: () => now,
      batchIdGenerator: () => '$name-batch-${++batch}',
    );
    adoption = LedgerAdoption(db: db, engine: engine, repository: repo);
  }

  final db = AppDatabase(NativeDatabase.memory());
  final now = DateTime.utc(2026, 11, 17, 3);
  late final LedgerRepository repo;
  late final SyncEngine engine;
  late final LedgerAdoption adoption;

  Future<String> categoryId(String ledgerId, String name) async =>
      (await repo.categories(ledgerId)).singleWhere((c) => c.name == name).id;

  Future<List<TransactionView>> transactions(String ledgerId) => repo
      .watchTransactions(
        ledgerId,
        from: LocalDate(2026, 1, 1),
        toExclusive: LocalDate(2027, 1, 1),
      )
      .first;
}

void main() {
  late FakeSyncServer server;
  late String serverLedger;

  setUp(() {
    server = FakeSyncServer(clock: () => DateTime.utc(2026, 11, 17, 3));
    serverLedger = server.seedLedger(ownerId: 'user-1');
  });

  test('처음 쓰는 기기는 서버의 가계부만 남는다: 기본 분류와 자산이 겹치지 않는다', () async {
    final device = _Device(server, 'phone');
    final local = await device.repo.ensureLocalLedger();

    final changed = await device.adoption.adopt(
      userId: 'user-1',
      serverLedgerId: serverLedger,
      localLedgerId: local,
    );
    expect(changed, isTrue);
    // 앱이 다시 열 때 고르는 가계부가 서버의 것이다.
    expect(await device.repo.ensureLocalLedger(), serverLedger);
    expect(await device.repo.categories(serverLedger), hasLength(16));
    expect(await device.repo.accounts(serverLedger), hasLength(1));
    expect(await device.repo.categories(local), isEmpty);
    // 같은 것뿐이라 올릴 변경이 없다.
    final report = await device.engine.syncOnce(serverLedger);
    expect(report.pushed, 0);
    expect(server.rows('categories'), hasLength(16));
    expect(await device.adoption.owner(), 'user-1');
    await device.db.close();
  });

  test('로그인 전에 적은 거래 · 분류 · 자산 · 월 시작일을 계정으로 옮긴다', () async {
    final device = _Device(server, 'phone');
    final local = await device.repo.ensureLocalLedger();
    final localCash = (await device.repo.accounts(local)).single.id;
    final card = await device.repo.addAccount(
      ledgerId: local,
      name: '새봄카드',
      kind: AccountKind.creditCard,
      matchHints: const ['새봄카드', '1234'],
    );
    final pet = await device.repo.addCategory(
      ledgerId: local,
      kind: CategoryKind.expense,
      name: '반려동물',
    );
    await device.repo.addTransaction(
      local,
      TransactionInput(
        type: TxType.expense,
        occurredOn: LocalDate(2026, 11, 16),
        amount: 8000,
        accountId: localCash,
        categoryId: await device.categoryId(local, '식비'),
        counterparty: '김밥천국',
      ),
    );
    await device.repo.addTransaction(
      local,
      TransactionInput(
        type: TxType.expense,
        occurredOn: LocalDate(2026, 11, 15),
        amount: 32000,
        accountId: card,
        categoryId: pet,
        counterparty: '동물병원',
      ),
    );
    await device.repo.setMonthStartDay(local, 25);

    await device.adoption.adopt(
      userId: 'user-1',
      serverLedgerId: serverLedger,
      localLedgerId: local,
    );
    final report = await device.engine.syncOnce(serverLedger);
    expect(report.rejected, 0);
    expect(report.conflicts, 0);

    // 서버: 기본 분류 16개 + 새 분류 1개, 현금 + 카드, 거래 2건.
    expect(server.rows('categories'), hasLength(17));
    expect(server.rows('accounts'), hasLength(2));
    expect(server.rows('transactions'), hasLength(2));
    final serverCash = server
        .rows('accounts')
        .singleWhere((a) => a['name'] == '현금')['id'];
    final serverFood = server
        .rows('categories')
        .singleWhere((c) => c['name'] == '식비')['id'];
    final lunch = server
        .rows('transactions')
        .singleWhere((t) => t['amount'] == 8000);
    // 기본 자산 · 분류를 가리키던 거래는 서버의 것을 가리킨다.
    expect(lunch['account_id'], serverCash);
    expect(lunch['category_id'], serverFood);
    expect(lunch['ledger_id'], serverLedger);
    final vet = server
        .rows('transactions')
        .singleWhere((t) => t['amount'] == 32000);
    expect(vet['account_id'], card);
    expect(vet['category_id'], pet);
    expect(server.row('profiles', 'user-1')!['month_start_day'], 25);

    // 기기에도 그대로 보인다.
    expect(await device.transactions(serverLedger), hasLength(2));
    expect((await device.repo.profile(serverLedger))!.monthStartDay, 25);
    expect(await device.repo.watchPendingChangeCount().first, 0);
    await device.db.close();
  });

  test('두 번째 기기는 먼저 올라간 내용을 받고, 제 것을 겹치지 않게 더한다', () async {
    final first = _Device(server, 'pc');
    final firstLocal = await first.repo.ensureLocalLedger();
    await first.repo.addCategory(
      ledgerId: firstLocal,
      kind: CategoryKind.expense,
      name: '반려동물',
    );
    await first.adoption.adopt(
      userId: 'user-1',
      serverLedgerId: serverLedger,
      localLedgerId: firstLocal,
    );
    await first.engine.syncOnce(serverLedger);

    final second = _Device(server, 'phone');
    final secondLocal = await second.repo.ensureLocalLedger();
    // 같은 이름의 분류를 따로 만들어 두었다.
    await second.repo.addCategory(
      ledgerId: secondLocal,
      kind: CategoryKind.expense,
      name: '반려동물',
    );
    final cash = (await second.repo.accounts(secondLocal)).single.id;
    await second.repo.addTransaction(
      secondLocal,
      TransactionInput(
        type: TxType.expense,
        occurredOn: LocalDate(2026, 11, 16),
        amount: 4500,
        accountId: cash,
        counterparty: '카페',
      ),
    );
    await second.adoption.adopt(
      userId: 'user-1',
      serverLedgerId: serverLedger,
      localLedgerId: secondLocal,
    );
    final report = await second.engine.syncOnce(serverLedger);
    expect(report.rejected, 0);

    expect(server.rows('categories'), hasLength(17));
    expect(server.rows('transactions'), hasLength(1));
    await first.engine.syncOnce(serverLedger);
    expect(await first.transactions(serverLedger), hasLength(1));
    await first.db.close();
    await second.db.close();
  });

  test('같은 계정으로 다시 로그인하면 아무것도 바꾸지 않는다', () async {
    final device = _Device(server, 'phone');
    final local = await device.repo.ensureLocalLedger();
    await device.adoption.adopt(
      userId: 'user-1',
      serverLedgerId: serverLedger,
      localLedgerId: local,
    );
    final changed = await device.adoption.adopt(
      userId: 'user-1',
      serverLedgerId: serverLedger,
      localLedgerId: serverLedger,
    );
    expect(changed, isFalse);
    await device.db.close();
  });

  test('다른 계정이 쓰던 기기에서는 섞지 않는다', () async {
    final device = _Device(server, 'phone');
    final local = await device.repo.ensureLocalLedger();
    await device.adoption.adopt(
      userId: 'user-1',
      serverLedgerId: serverLedger,
      localLedgerId: local,
    );
    final cash = (await device.repo.accounts(serverLedger)).single.id;
    await device.repo.addTransaction(
      serverLedger,
      TransactionInput(
        type: TxType.expense,
        occurredOn: LocalDate(2026, 11, 16),
        amount: 9900,
        accountId: cash,
      ),
    );
    await device.engine.syncOnce(serverLedger);

    final otherLedger = server.seedLedger(ownerId: 'user-2');
    await expectLater(
      device.adoption.adopt(
        userId: 'user-2',
        serverLedgerId: otherLedger,
        localLedgerId: serverLedger,
      ),
      throwsA(isA<DifferentAccountException>()),
    );
    // 거절한 뒤에는 그대로다.
    expect(await device.transactions(serverLedger), hasLength(1));

    // 지우고 받기로 하면 새 계정의 가계부만 남는다.
    final changed = await device.adoption.adopt(
      userId: 'user-2',
      serverLedgerId: otherLedger,
      localLedgerId: serverLedger,
      replaceLocal: true,
    );
    expect(changed, isTrue);
    expect(await device.repo.ensureLocalLedger(), otherLedger);
    expect(await device.transactions(otherLedger), isEmpty);
    expect(await device.transactions(serverLedger), isEmpty);
    expect(await device.adoption.owner(), 'user-2');
    // 앞선 계정의 거래는 서버에 그대로 있다.
    expect(server.rows('transactions'), hasLength(1));
    await device.db.close();
  });
}
