import 'package:drift/drift.dart' show Variable;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gagyebu/core/local_date.dart';
import 'package:gagyebu/data/db/database.dart';
import 'package:gagyebu/data/repositories/ledger_repository.dart';
import 'package:gagyebu/data/sync/sync_engine.dart';
import 'package:gagyebu/data/sync/sync_gateway.dart';
import 'package:gagyebu/domain/enums.dart';

import 'fake_sync_server.dart';

/// 시험용 기기 한 대: 로컬 DB, 저장소, 동기화 엔진, 자기 시계.
class Device {
  Device(FakeSyncServer server, this.name, this.now, {int pullPageSize = 500})
    : db = AppDatabase(NativeDatabase.memory()),
      gateway = InterceptingGateway(server) {
    repo = LedgerRepository(db, clock: () => now);
    var batch = 0;
    engine = SyncEngine(
      db: db,
      gateway: gateway,
      deviceId: name,
      clock: () => now,
      batchIdGenerator: () => '$name-batch-${++batch}',
      pullPageSize: pullPageSize,
    );
  }

  final String name;
  final AppDatabase db;
  final InterceptingGateway gateway;
  late final LedgerRepository repo;
  late final SyncEngine engine;
  DateTime now;

  Future<List<TransactionView>> transactions(String ledgerId) => repo
      .watchTransactions(
        ledgerId,
        from: LocalDate(2026, 1, 1),
        toExclusive: LocalDate(2027, 1, 1),
      )
      .first;

  Future<String> cashId(String ledgerId) async =>
      (await repo.accounts(ledgerId)).single.id;

  Future<String> addExpense(String ledgerId, int amount, String party) async =>
      repo.addTransaction(
        ledgerId,
        TransactionInput(
          type: TxType.expense,
          occurredOn: LocalDate(2026, 11, 16),
          occurredTime: '12:31',
          amount: amount,
          accountId: await cashId(ledgerId),
          counterparty: party,
        ),
      );

  Future<void> editExpense(String id, int amount, String party) async {
    final row = (await repo.transactionById(id))!;
    await repo.updateTransaction(
      id,
      TransactionInput(
        type: TxType.expense,
        occurredOn: row.occurredOn,
        occurredTime: row.occurredTime,
        amount: amount,
        accountId: row.accountId,
        counterparty: party,
      ),
    );
  }

  Future<int> outboxCount() async => (await db.select(db.outbox).get()).length;
}

void main() {
  final t0 = DateTime.utc(2026, 11, 17, 3);
  late DateTime serverNow;
  late FakeSyncServer server;
  late String ledgerId;
  late Device a;
  late Device b;
  final devices = <Device>[];

  Device device(String name, {DateTime? now, int pullPageSize = 500}) {
    final d = Device(server, name, now ?? t0, pullPageSize: pullPageSize);
    devices.add(d);
    return d;
  }

  setUp(() async {
    serverNow = t0;
    server = FakeSyncServer(clock: () => serverNow);
    ledgerId = server.seedLedger();
    a = device('a');
    b = device('b');
    await a.engine.syncOnce(ledgerId);
    await b.engine.syncOnce(ledgerId);
  });

  tearDown(() async {
    for (final d in devices) {
      await d.db.close();
    }
    devices.clear();
  });

  /// 모든 시계를 [minutes]분 뒤로 옮긴다.
  void advance(int minutes) {
    serverNow = serverNow.add(Duration(minutes: minutes));
    for (final d in devices) {
      d.now = d.now.add(Duration(minutes: minutes));
    }
  }

  test('새 기기는 가계부 전체를 내려받는다', () async {
    final c = device('c');
    final report = await c.engine.syncOnce(ledgerId);
    // 가계부 1 + 현금 자산 1 + 분류 16 + 프로필 1
    expect(report.pulled, 19);
    expect(await c.repo.categories(ledgerId), hasLength(16));
    expect((await c.repo.accounts(ledgerId)).single.name, '현금');
    expect((await c.repo.profile(ledgerId))!.monthStartDay, 1);
    expect(await c.engine.cursor(ledgerId), server.maxSeq);
    expect(await c.outboxCount(), 0);
  });

  test('나눠 받아도 빠짐없이 받는다', () async {
    final c = device('c', pullPageSize: 4);
    final report = await c.engine.syncOnce(ledgerId);
    expect(report.pulled, 19);
    expect(server.pullCalls, greaterThanOrEqualTo(5));
    expect(await c.engine.cursor(ledgerId), server.maxSeq);
  });

  test('한 기기에서 넣은 거래가 다른 기기에 보인다', () async {
    final id = await a.addExpense(ledgerId, 12500, '김밥천국 강남점');
    final pushed = await a.engine.syncOnce(ledgerId);
    expect(pushed.pushed, 1);
    expect(await a.outboxCount(), 0);
    expect((await a.repo.transactionById(id))!.version, 1);

    final pulled = await b.engine.syncOnce(ledgerId);
    expect(pulled.pulled, 1);
    final seen = (await b.transactions(ledgerId)).single;
    expect(seen.row.id, id);
    expect(seen.row.amount, 12500);
    expect(seen.row.receiver, '김밥천국 강남점');
    // 서버는 시각을 'HH:MM:SS'로 돌려준다. 기기에는 'HH:mm'으로 들어온다.
    expect(seen.row.occurredTime, '12:31');
    expect(seen.row.version, 1);
    expect(seen.accountName, '현금');
  });

  test('다른 기기에서 고친 내용이 반영된다', () async {
    final id = await a.addExpense(ledgerId, 12500, '김밥천국');
    await a.engine.syncOnce(ledgerId);
    await b.engine.syncOnce(ledgerId);

    advance(5);
    await b.editExpense(id, 13000, '김밥천국 강남점');
    await b.engine.syncOnce(ledgerId);
    expect((await b.repo.transactionById(id))!.version, 2);

    await a.engine.syncOnce(ledgerId);
    final row = (await a.repo.transactionById(id))!;
    expect(row.amount, 13000);
    expect(row.receiver, '김밥천국 강남점');
    expect(row.version, 2);
    expect(await a.db.select(a.db.syncConflicts).get(), isEmpty);
  });

  test('삭제가 다른 기기로 전파된다', () async {
    final id = await a.addExpense(ledgerId, 12500, '김밥천국');
    await a.engine.syncOnce(ledgerId);
    await b.engine.syncOnce(ledgerId);

    advance(1);
    await b.repo.deleteTransaction(id);
    await b.engine.syncOnce(ledgerId);
    expect(server.row('transactions', id)!['deleted_at'], isNotNull);

    await a.engine.syncOnce(ledgerId);
    expect(await a.transactions(ledgerId), isEmpty);
    expect((await a.repo.transactionById(id))!.deletedAt, isNotNull);
  });

  group('같은 거래를 두 기기가 따로 고쳤을 때', () {
    late String id;

    setUp(() async {
      id = await a.addExpense(ledgerId, 10000, '처음');
      await a.engine.syncOnce(ledgerId);
      await b.engine.syncOnce(ledgerId);
    });

    test('나중에 고친 쪽이 이기고, 진 쪽 값이 남는다', () async {
      advance(1);
      await a.editExpense(id, 11000, 'A가 고침');
      advance(1);
      await b.editExpense(id, 12000, 'B가 나중에 고침');

      // 먼저 고친 A가 먼저 올린다.
      await a.engine.syncOnce(ledgerId);
      final report = await b.engine.syncOnce(ledgerId);
      expect(report.conflicts, 1);

      // B가 이겼다: 서버와 B는 B의 값이다.
      expect(server.row('transactions', id)!['amount'], 12000);
      expect((await b.repo.transactionById(id))!.amount, 12000);
      // B에는 덮어쓴 A의 값이 기록된다.
      final conflict = (await b.db.select(b.db.syncConflicts).get()).single;
      expect(conflict.loserSide, 'remote');
      expect(conflict.loser['amount'], 11000);

      // A가 다시 받으면 같은 값으로 모인다.
      await a.engine.syncOnce(ledgerId);
      final onA = (await a.repo.transactionById(id))!;
      expect(onA.amount, 12000);
      expect(onA.receiver, 'B가 나중에 고침');
      expect(onA.version, (await b.repo.transactionById(id))!.version);
    });

    test('먼저 고친 쪽이 늦게 올리면 지고, 서버 값으로 바뀐다', () async {
      advance(1);
      await a.editExpense(id, 11000, 'A가 먼저 고침');
      advance(1);
      await b.editExpense(id, 12000, 'B가 나중에 고침');

      // 나중에 고친 B가 먼저 올린다.
      await b.engine.syncOnce(ledgerId);
      final report = await a.engine.syncOnce(ledgerId);
      expect(report.conflicts, 1);

      final onA = (await a.repo.transactionById(id))!;
      expect(onA.amount, 12000);
      expect(onA.receiver, 'B가 나중에 고침');
      expect(await a.outboxCount(), 0);
      // A에는 진 자기 값이 기록된다.
      final conflict = (await a.db.select(a.db.syncConflicts).get()).single;
      expect(conflict.loserSide, 'local');
      expect(conflict.loser['amount'], 11000);
      expect(server.row('transactions', id)!['amount'], 12000);
    });

    test('시계가 하루 앞선 기기가 계속 이기지 못한다', () async {
      final fast = device('fast', now: t0.add(const Duration(days: 1)));
      await fast.engine.syncOnce(ledgerId);

      advance(1);
      await fast.editExpense(id, 99000, '시계가 앞선 기기');
      await fast.engine.syncOnce(ledgerId);
      // 서버는 앞선 시각을 서버 시각으로 잘라 적는다.
      expect(
        DateTime.parse(
          server.row('transactions', id)!['client_updated_at']! as String,
        ),
        serverNow,
      );

      // 그 뒤에 시계가 맞는 A가 고치면 A가 이긴다.
      advance(1);
      await a.editExpense(id, 11000, 'A가 실제로 나중에 고침');
      final report = await a.engine.syncOnce(ledgerId);
      expect(report.conflicts, 1);
      expect(server.row('transactions', id)!['amount'], 11000);
    });

    test('보내지 않은 내 변경이 있는 행은 pull이 덮어쓰지 않는다', () async {
      advance(1);
      await b.editExpense(id, 12000, 'B가 먼저 고쳐 올림');
      await b.engine.syncOnce(ledgerId);

      advance(1);
      await a.editExpense(id, 11000, 'A가 나중에 고침');
      // pull만 한다. A의 편집은 아직 대기열에 있다.
      await a.engine.pullChanges(ledgerId);
      expect((await a.repo.transactionById(id))!.amount, 11000);
      expect(await a.outboxCount(), 1);

      // push하면 서버가 충돌을 판정한다. 나중에 고친 A가 이긴다.
      final report = await a.engine.pushPending(ledgerId);
      expect(report.conflicts, 1);
      expect(server.row('transactions', id)!['amount'], 11000);
    });
  });

  group('끊김과 재시도', () {
    test('응답을 못 받은 묶음은 같은 ID로 다시 보내 한 번만 적용된다', () async {
      final id = await a.addExpense(ledgerId, 12500, '김밥천국');
      a.gateway.dropNextPushResponse = true;
      await expectLater(a.engine.syncOnce(ledgerId), throwsStateError);
      // 서버에는 들어갔지만 기기는 모른다.
      expect(server.row('transactions', id), isNotNull);
      expect(await a.outboxCount(), 1);
      expect((await a.repo.transactionById(id))!.version, 0);

      final report = await a.engine.syncOnce(ledgerId);
      expect(report.pushed, 1);
      expect(server.appliedBatches, 1, reason: '서버는 한 번만 적용했다');
      expect(server.pushCalls, 2);
      expect(server.row('transactions', id)!['version'], 1);
      expect((await a.repo.transactionById(id))!.version, 1);
      expect(await a.outboxCount(), 0);
      expect(server.rows('transactions'), hasLength(1));
    });

    test('보내는 사이에 또 고친 행은 대기열에 남고 다음에 올라간다', () async {
      final id = await a.addExpense(ledgerId, 10000, '처음');
      a.gateway.afterNextPush = () async {
        a.now = a.now.add(const Duration(seconds: 30));
        await a.editExpense(id, 20000, '보내는 사이에 고침');
      };
      await a.engine.pushPending(ledgerId);

      // 첫 묶음(10000)은 적용됐고, 그 뒤의 편집은 기준 버전 1로 다시 올라갔다.
      final onServer = server.row('transactions', id)!;
      expect(onServer['amount'], 20000);
      expect(onServer['version'], 2);
      expect(server.appliedBatches, 2);
      expect(await a.outboxCount(), 0);
      expect((await a.repo.transactionById(id))!.version, 2);
      expect(await a.db.select(a.db.syncConflicts).get(), isEmpty);
    });

    test('서버가 거절한 변경은 횟수를 세고, 여러 번 뒤에는 보내지 않는다', () async {
      final id = await a.addExpense(ledgerId, 12500, '김밥천국');
      // 서버의 check 제약에 걸리는 값을 직접 넣는다.
      await a.db.customUpdate(
        "UPDATE transactions SET type = 'bogus' WHERE id = ?",
        variables: [Variable.withString(id)],
      );
      final good = await a.addExpense(ledgerId, 3000, '편의점');

      final first = await a.engine.pushPending(ledgerId);
      expect(first.rejected, 1);
      expect(first.pushed, 1, reason: '나머지 변경은 계속 처리된다');
      expect(server.row('transactions', good), isNotNull);
      expect(server.row('transactions', id), isNull);

      var entry = (await a.db.select(a.db.outbox).get()).single;
      expect(entry.attempts, 1);
      expect(entry.lastError, contains('type_check'));

      for (var i = 0; i < 6; i++) {
        await a.engine.pushPending(ledgerId);
      }
      entry = (await a.db.select(a.db.outbox).get()).single;
      expect(entry.attempts, 5);
      final callsAtLimit = server.pushCalls;
      await a.engine.pushPending(ledgerId);
      expect(server.pushCalls, callsAtLimit, reason: '더 보내지 않는다');
    });
  });

  test('자산 · 분류 · 분류 규칙도 함께 오간다', () async {
    final bankId = await a.repo.addAccount(
      ledgerId: ledgerId,
      name: '신한 체크',
      kind: AccountKind.checkCard,
      institution: '신한카드',
      matchHints: ['신한카드', '1234'],
      openingBalance: 500000,
    );
    final categoryId = await a.repo.addCategory(
      ledgerId: ledgerId,
      kind: CategoryKind.expense,
      name: '반려동물',
    );
    await a.repo.rememberCategory(ledgerId, '동물병원', categoryId);
    await a.repo.setMonthStartDay(ledgerId, 25);
    await a.engine.syncOnce(ledgerId);

    // 서버에는 배열이 배열로 들어간다.
    expect(server.row('accounts', bankId)!['match_hints'], ['신한카드', '1234']);

    await b.engine.syncOnce(ledgerId);
    final account = (await b.repo.accounts(ledgerId))
        .firstWhere((x) => x.id == bankId);
    expect(account.kind, AccountKind.checkCard);
    expect(account.matchHints, ['신한카드', '1234']);
    expect(account.openingBalance, 500000);
    expect(
      (await b.repo.categories(ledgerId)).map((c) => c.name),
      contains('반려동물'),
    );
    expect(await b.repo.categoryForCounterparty(ledgerId, '동물병원'), categoryId);
    expect((await b.repo.profile(ledgerId))!.monthStartDay, 25);
  });

  test('서버에 올린 적 없는 행을 지우면 서버로 아무것도 가지 않는다', () async {
    final id = await a.addExpense(ledgerId, 12500, '김밥천국');
    await a.repo.deleteTransaction(id);
    final report = await a.engine.syncOnce(ledgerId);
    expect(report.pushed, 0);
    expect(server.rows('transactions'), isEmpty);
  });

  group('오래 쉬었던 기기', () {
    test('전체를 다시 받고, 그 사이 서버에서 정리된 행을 지운다', () async {
      final kept = await a.addExpense(ledgerId, 1000, '남는 거래');
      final gone = await a.addExpense(ledgerId, 2000, '지워질 거래');
      await a.engine.syncOnce(ledgerId);
      await b.engine.syncOnce(ledgerId);
      expect(await b.transactions(ledgerId), hasLength(2));

      // A가 지우고, 서버가 90일 뒤 삭제 표시를 정리한다. B는 그동안 쉬었다.
      advance(1);
      await a.repo.deleteTransaction(gone);
      await a.engine.syncOnce(ledgerId);
      advance(100 * 24 * 60);
      expect(server.purgeTombstones(), 1);

      // B는 삭제를 받은 적이 없다. 커서만 보고 받으면 지워진 거래가 남는다.
      final unsynced = await b.addExpense(ledgerId, 3000, '쉬는 동안 적은 거래');
      await b.engine.syncOnce(ledgerId);

      final titles = [for (final t in await b.transactions(ledgerId)) t.title];
      expect(titles, containsAll(['남는 거래', '쉬는 동안 적은 거래']));
      expect(titles, isNot(contains('지워질 거래')));
      expect(await b.repo.transactionById(gone), isNull);
      expect(await b.repo.transactionById(kept), isNotNull);
      expect(server.row('transactions', unsynced), isNotNull);
      // 기본 분류와 자산은 그대로다.
      expect(await b.repo.categories(ledgerId), hasLength(16));
    });

    test('자주 받는 기기는 커서 뒤만 받는다', () async {
      await a.addExpense(ledgerId, 1000, '거래');
      await a.engine.syncOnce(ledgerId);
      advance(60);
      final report = await b.engine.syncOnce(ledgerId);
      expect(report.pulled, 1);
    });
  });

  test('NUL 문자는 서버로 보내지 않는다', () async {
    final id = await a.repo.addTransaction(
      ledgerId,
      TransactionInput(
        type: TxType.expense,
        occurredOn: LocalDate(2026, 11, 16),
        amount: 1000,
        accountId: await a.cashId(ledgerId),
        counterparty: '가게\u0000이름',
        memo: '메\u0000모',
      ),
    );
    await a.engine.syncOnce(ledgerId);
    final row = server.row('transactions', id)!;
    expect(row['receiver'], '가게이름');
    expect(row['memo'], '메모');
  });

  test('기기 ID는 한 번 만들어 계속 쓴다', () async {
    final first = await SyncEngine.ensureDeviceId(a.db);
    final second = await SyncEngine.ensureDeviceId(a.db);
    expect(second, first);
    expect(
      first,
      matches(
        RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        ),
      ),
    );
    expect(await SyncEngine.ensureDeviceId(b.db), isNot(first));
  });

  test('PushChange는 JSON으로 오가도 같은 값이다', () {
    final change = PushChange(
      table: 'transactions',
      op: 'upsert',
      id: 'x',
      baseVersion: 3,
      clientUpdatedAt: DateTime.utc(2026, 11, 17, 3, 0, 1, 250),
      data: {
        'amount': 12500,
        'tags': ['a'],
      },
    );
    final back = PushChange.fromJson(change.toJson());
    expect(back.toJson(), change.toJson());
    expect(back.clientUpdatedAt, change.clientUpdatedAt);
  });
}
