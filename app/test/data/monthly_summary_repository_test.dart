import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gagyebu/ai/llm/narrative_writer.dart';
import 'package:gagyebu/core/local_date.dart';
import 'package:gagyebu/data/db/database.dart';
import 'package:gagyebu/data/repositories/ledger_repository.dart';
import 'package:gagyebu/data/repositories/monthly_summary_repository.dart';
import 'package:gagyebu/domain/enums.dart';
import 'package:gagyebu/domain/month_period.dart';

void main() {
  late AppDatabase db;
  late LedgerRepository ledger;
  late MonthlySummaryRepository summaries;
  late String ledgerId;
  var now = DateTime.utc(2026, 11, 17, 3);

  final stats = <String, Object?>{
    'month': '2026-10',
    'income': 3000000,
    'expense': 1860250,
    'by_category': [
      {'name': '식비', 'amount': 595280, 'ratio': 0.32},
    ],
    'budget': null,
  };

  /// 부른 횟수를 세는 글쓴이.
  var writes = 0;
  Future<NarrativeResult> writer(Map<String, Object?> stats) async {
    writes++;
    return NarrativeResult(
      text: '총평 $writes번째입니다.',
      aiModel: 'fake-model',
      attempts: 1,
    );
  }

  Future<List<OutboxRow>> queued() => (db.select(
    db.outbox,
  )..where((o) => o.targetTable.equals('monthly_summaries'))).get();

  setUp(() async {
    now = DateTime.utc(2026, 11, 17, 3);
    writes = 0;
    db = AppDatabase(NativeDatabase.memory());
    ledger = LedgerRepository(db, clock: () => now);
    summaries = MonthlySummaryRepository(db, ledger.outbox);
    ledgerId = await ledger.ensureLocalLedger();
  });
  tearDown(() => db.close());

  test('해시는 값이 같으면 같고, 키의 순서와 상관없다', () {
    final hash = statsHash(stats);
    expect(hash, hasLength(64));
    expect(hash, matches(RegExp(r'^[0-9a-f]{64}$')));
    final reordered = <String, Object?>{
      'budget': null,
      'by_category': [
        {'ratio': 0.32, 'amount': 595280, 'name': '식비'},
      ],
      'expense': 1860250,
      'income': 3000000,
      'month': '2026-10',
    };
    expect(statsHash(reordered), hash);
    expect(statsHash({...stats, 'expense': 1860251}), isNot(hash));
    // 목록의 순서는 뜻이 있다(금액이 큰 순서).
    expect(
      statsHash({
        'list': [1, 2],
      }),
      isNot(
        statsHash({
          'list': [2, 1],
        }),
      ),
    );
    // 알려진 값: 빈 객체 '{}'의 SHA-256
    expect(
      statsHash(const {}),
      '44136fa355b3678a1146ad16f7e8649e94fb4fc21fe77e8310c060f61caaff8a',
    );
  });

  test('처음에는 만들어 보관하고 대기열에 올린다', () async {
    final text = await summaries.narrativeFor(
      ledgerId,
      month: '2026-10',
      stats: stats,
      write: writer,
    );
    expect(text, '총평 1번째입니다.');
    expect(writes, 1);

    final row = (await summaries.latest(ledgerId, '2026-10'))!;
    expect(row.narrative, '총평 1번째입니다.');
    expect(row.dataHash, statsHash(stats));
    expect(row.aiModel, 'fake-model');
    expect(row.stats['expense'], 1860250);
    expect(row.version, 0);
    expect(row.clientUpdatedAt, now);

    final outbox = await queued();
    expect(outbox, hasLength(1));
    expect(outbox.single.rowId, row.id);
    expect(outbox.single.op, 'upsert');
    expect(outbox.single.baseVersion, 0);
    expect(outbox.single.ledgerId, ledgerId);
  });

  test('해시가 같으면 다시 만들지 않는다', () async {
    await summaries.narrativeFor(
      ledgerId,
      month: '2026-10',
      stats: stats,
      write: writer,
    );
    now = now.add(const Duration(hours: 1));
    final again = await summaries.narrativeFor(
      ledgerId,
      month: '2026-10',
      stats: {...stats},
      write: writer,
    );
    expect(again, '총평 1번째입니다.');
    expect(writes, 1);
    // 행도 고치지 않는다(동기화로 올릴 것이 생기지 않는다).
    final row = (await summaries.latest(ledgerId, '2026-10'))!;
    expect(row.clientUpdatedAt, DateTime.utc(2026, 11, 17, 3));
    expect(await queued(), hasLength(1));
  });

  test('같은 달을 겹쳐 물어도 한 번만 만든다', () async {
    final both = await Future.wait([
      summaries.narrativeFor(
        ledgerId,
        month: '2026-10',
        stats: stats,
        write: writer,
      ),
      summaries.narrativeFor(
        ledgerId,
        month: '2026-10',
        stats: stats,
        write: writer,
      ),
    ]);
    expect(both, ['총평 1번째입니다.', '총평 1번째입니다.']);
    expect(writes, 1);
    expect(await db.select(db.monthlySummaries).get(), hasLength(1));

    // 앞의 요청이 실패해도 뒤의 요청은 처리한다.
    final failed = summaries.narrativeFor(
      ledgerId,
      month: '2026-09',
      stats: stats,
      write: (_) async => throw StateError('모델이 내려갔다'),
    );
    final next = summaries.narrativeFor(
      ledgerId,
      month: '2026-09',
      stats: stats,
      write: writer,
    );
    await expectLater(failed, throwsStateError);
    expect(await next, '총평 2번째입니다.');
  });

  test('집계가 달라지면 다시 만들어 같은 행을 고친다', () async {
    await summaries.narrativeFor(
      ledgerId,
      month: '2026-10',
      stats: stats,
      write: writer,
    );
    final first = (await summaries.latest(ledgerId, '2026-10'))!;
    // 서버에 올라간 뒤라고 치자.
    await (db.update(db.monthlySummaries)..where((s) => s.id.equals(first.id)))
        .write(const MonthlySummariesCompanion(version: Value(3)));
    await db.delete(db.outbox).go();

    now = now.add(const Duration(hours: 1));
    final changed = {...stats, 'expense': 1900000};
    final text = await summaries.narrativeFor(
      ledgerId,
      month: '2026-10',
      stats: changed,
      write: writer,
    );
    expect(text, '총평 2번째입니다.');
    expect(writes, 2);

    final rows = await db.select(db.monthlySummaries).get();
    expect(rows, hasLength(1));
    expect(rows.single.id, first.id);
    expect(rows.single.dataHash, statsHash(changed));
    expect(rows.single.stats['expense'], 1900000);
    expect(rows.single.clientUpdatedAt, now);
    final outbox = await queued();
    expect(outbox.single.rowId, first.id);
    // 서버가 충돌을 가릴 수 있게 마지막으로 본 판 번호를 싣는다.
    expect(outbox.single.baseVersion, 3);
  });

  test('다른 달과 다른 가계부의 요약은 따로다', () async {
    await summaries.narrativeFor(
      ledgerId,
      month: '2026-10',
      stats: stats,
      write: writer,
    );
    await summaries.narrativeFor(
      ledgerId,
      month: '2026-09',
      stats: stats,
      write: writer,
    );
    expect(writes, 2);
    expect(await summaries.latest('다른-가계부', '2026-10'), isNull);
    expect(
      (await summaries.latest(ledgerId, '2026-09'))!.narrative,
      '총평 2번째입니다.',
    );
  });

  group('같은 달의 행이 겹칠 때', () {
    Future<void> insert(
      String id, {
      required DateTime at,
      required String narrative,
      String? hash,
      DateTime? deletedAt,
    }) => db
        .into(db.monthlySummaries)
        .insert(
          MonthlySummariesCompanion.insert(
            id: id,
            ledgerId: ledgerId,
            month: '2026-10',
            stats: stats,
            narrative: Value(narrative),
            dataHash: Value(hash),
            clientUpdatedAt: at,
            createdAt: at,
            updatedAt: at,
            deletedAt: Value(deletedAt),
          ),
        );

    test('client_updated_at이 가장 늦은 것을 쓴다', () async {
      // 두 기기가 따로 만든 행이 동기화로 함께 들어왔다.
      await insert(
        'b-휴대폰',
        at: DateTime.utc(2026, 11, 2, 9),
        narrative: '휴대폰이 쓴 총평입니다.',
        hash: statsHash(stats),
      );
      await insert(
        'a-PC',
        at: DateTime.utc(2026, 11, 3, 9),
        narrative: 'PC가 쓴 총평입니다.',
        hash: statsHash(stats),
      );
      await insert(
        'c-지운 것',
        at: DateTime.utc(2026, 11, 5, 9),
        narrative: '지운 총평입니다.',
        hash: statsHash(stats),
        deletedAt: DateTime.utc(2026, 11, 5, 10),
      );
      expect((await summaries.latest(ledgerId, '2026-10'))!.id, 'a-PC');

      // 해시가 같으니 그 글을 그대로 쓴다.
      final text = await summaries.narrativeFor(
        ledgerId,
        month: '2026-10',
        stats: stats,
        write: writer,
      );
      expect(text, 'PC가 쓴 총평입니다.');
      expect(writes, 0);
      expect(await queued(), isEmpty);
    });

    test('다시 만들 때는 가장 늦은 행만 고친다', () async {
      await insert(
        'old',
        at: DateTime.utc(2026, 11, 2, 9),
        narrative: '옛 총평입니다.',
        hash: 'x',
      );
      await insert(
        'new',
        at: DateTime.utc(2026, 11, 3, 9),
        narrative: '새 총평입니다.',
        hash: 'y',
      );
      final text = await summaries.narrativeFor(
        ledgerId,
        month: '2026-10',
        stats: stats,
        write: writer,
      );
      expect(text, '총평 1번째입니다.');
      final rows = {
        for (final r in await db.select(db.monthlySummaries).get()) r.id: r,
      };
      expect(rows, hasLength(2));
      expect(rows['new']!.narrative, '총평 1번째입니다.');
      expect(rows['old']!.narrative, '옛 총평입니다.');
      expect((await queued()).single.rowId, 'new');
    });

    test('같은 때에 고친 행은 ID로 가른다', () async {
      final at = DateTime.utc(2026, 11, 3, 9);
      await insert('aaa', at: at, narrative: 'aaa의 총평입니다.');
      await insert('bbb', at: at, narrative: 'bbb의 총평입니다.');
      expect((await summaries.latest(ledgerId, '2026-10'))!.id, 'bbb');
    });

    test('글이 빈 행은 해시가 같아도 다시 만든다', () async {
      await insert(
        'empty',
        at: DateTime.utc(2026, 11, 3, 9),
        narrative: '  ',
        hash: statsHash(stats),
      );
      final text = await summaries.narrativeFor(
        ledgerId,
        month: '2026-10',
        stats: stats,
        write: writer,
      );
      expect(text, '총평 1번째입니다.');
    });
  });

  test('집계에 드는 것이 바뀌면 표지가 달라진다', () async {
    final period = MonthPeriod(2026, 10);
    final stamps = <String>[];
    final subscription = summaries
        .watchDataStamp(ledgerId, period)
        .listen(stamps.add);
    await pumpEventQueue();
    expect(stamps, hasLength(1));

    // 총평을 보관하는 것만으로는 달라지지 않는다(다시 만들기가 맴돌지 않는다).
    await summaries.narrativeFor(
      ledgerId,
      month: '2026-10',
      stats: stats,
      write: writer,
    );
    await pumpEventQueue();
    expect(stamps, hasLength(1));

    final cash = (await ledger.accounts(ledgerId)).first.id;
    now = now.add(const Duration(minutes: 1));
    await ledger.addTransaction(
      ledgerId,
      TransactionInput(
        type: TxType.expense,
        occurredOn: LocalDate(2026, 10, 5),
        amount: 9000,
        accountId: cash,
      ),
    );
    await pumpEventQueue();
    expect(stamps, hasLength(2));

    // 다른 달의 거래는 상관없다. 전달(9월)의 거래는 전달 대비에 들어가므로 상관있다.
    now = now.add(const Duration(minutes: 1));
    await ledger.addTransaction(
      ledgerId,
      TransactionInput(
        type: TxType.expense,
        occurredOn: LocalDate(2026, 11, 5),
        amount: 9000,
        accountId: cash,
      ),
    );
    await pumpEventQueue();
    expect(stamps, hasLength(2));
    now = now.add(const Duration(minutes: 1));
    await ledger.addTransaction(
      ledgerId,
      TransactionInput(
        type: TxType.expense,
        occurredOn: LocalDate(2026, 9, 30),
        amount: 9000,
        accountId: cash,
      ),
    );
    await pumpEventQueue();
    expect(stamps, hasLength(3));
    await subscription.cancel();
  });
}
