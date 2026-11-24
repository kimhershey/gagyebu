import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gagyebu/app/providers.dart';
import 'package:gagyebu/app/sync_controller.dart';
import 'package:gagyebu/core/local_date.dart';
import 'package:gagyebu/data/db/database.dart';
import 'package:gagyebu/data/repositories/ledger_repository.dart';
import 'package:gagyebu/data/repositories/recurring_repository.dart';
import 'package:gagyebu/domain/enums.dart';
import 'package:gagyebu/features/recurring/recurring_runner.dart';

/// 동기화 상태를 시험이 직접 바꾸는 가짜.
class FakeSync extends SyncController {
  @override
  SyncStatus build() => const SyncStatus(SyncPhase.signedOut);

  void emit(SyncPhase phase) => state = SyncStatus(phase);
}

void main() {
  late AppDatabase db;
  late LedgerRepository ledger;
  late RecurringRepository recurring;
  late String ledgerId;
  late ProviderContainer container;
  var now = DateTime(2026, 11, 17, 12);

  setUp(() async {
    now = DateTime(2026, 11, 17, 12);
    db = AppDatabase(NativeDatabase.memory());
    ledger = LedgerRepository(db, clock: () => now);
    recurring = RecurringRepository(ledger);
    ledgerId = await ledger.ensureLocalLedger();
    container = ProviderContainer(
      overrides: [
        appServicesProvider.overrideWithValue(
          AppServices(
            db: db,
            repository: ledger,
            ledgerId: ledgerId,
            storage: '시험용 메모리',
            persistent: true,
          ),
        ),
        clockProvider.overrideWithValue(() => now),
        syncControllerProvider.overrideWith(FakeSync.new),
      ],
    );
  });
  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<String> addRule(String next) async => recurring.addRule(
    ledgerId,
    RecurringRuleInput(
      template: RecurringTemplate(
        type: TxType.expense,
        amount: 9900,
        accountId: (await ledger.accounts(ledgerId)).single.id,
        counterparty: '구독',
      ),
      frequency: RecurringFrequency.monthly,
      nextRunOn: LocalDate.parse(next),
    ),
  );

  Future<List<String>> madeDates() async => [
    for (final tx in await db.select(db.ledgerTransactions).get())
      tx.occurredOn.toString(),
  ]..sort();

  /// 뒤에서 도는 일이 끝나기를 기다린다.
  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 50));

  FakeSync sync() =>
      container.read(syncControllerProvider.notifier) as FakeSync;

  test('켜 두면 바로 밀린 거래를 만든다', () async {
    await addRule('2026-10-17');
    container.listen(recurringRunnerProvider, (_, _) {});
    await settle();
    expect(await madeDates(), ['2026-10-17', '2026-11-17']);
  });

  test('동기화가 끝나 쉬는 상태로 바뀔 때마다 다시 돈다', () async {
    container.listen(recurringRunnerProvider, (_, _) {});
    await settle();
    expect(await madeDates(), isEmpty);

    // 동기화로 다른 기기의 규칙을 받았다.
    await addRule('2026-11-10');
    sync().emit(SyncPhase.syncing);
    await settle();
    expect(await madeDates(), isEmpty, reason: '주고받는 중에는 돌지 않는다');
    sync().emit(SyncPhase.idle);
    await settle();
    expect(await madeDates(), ['2026-11-10']);

    // 쉬는 상태가 이어지는 동안에는 다시 돌지 않고, 다음 동기화 뒤에 돈다.
    now = DateTime(2026, 12, 10, 9);
    sync().emit(SyncPhase.idle);
    await settle();
    expect(await madeDates(), ['2026-11-10']);
    sync().emit(SyncPhase.syncing);
    sync().emit(SyncPhase.idle);
    await settle();
    expect(await madeDates(), ['2026-11-10', '2026-12-10']);
  });

  test('동기화가 실패하면 돌지 않는다', () async {
    container.listen(recurringRunnerProvider, (_, _) {});
    await settle();
    await addRule('2026-11-10');
    sync().emit(SyncPhase.syncing);
    sync().emit(SyncPhase.failed);
    await settle();
    expect(await madeDates(), isEmpty);
  });

  test('만들다 실패해도 멈추지 않고 다음 차례에 다시 한다', () async {
    container.listen(recurringRunnerProvider, (_, _) {});
    await settle();
    await addRule('2026-11-10');
    // DB를 닫아 실패하게 만든다. 예외가 밖으로 새지 않아야 한다.
    await db.close();
    sync().emit(SyncPhase.syncing);
    sync().emit(SyncPhase.idle);
    await settle();
  });
}
