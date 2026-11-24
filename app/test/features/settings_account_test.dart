import 'package:drift/native.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:gagyebu/app/providers.dart';
import 'package:gagyebu/app/sync_controller.dart';
import 'package:gagyebu/core/local_date.dart';
import 'package:gagyebu/data/db/database.dart';
import 'package:gagyebu/data/repositories/ledger_repository.dart';
import 'package:gagyebu/data/server/server_connection.dart';
import 'package:gagyebu/domain/enums.dart';
import 'package:gagyebu/features/settings/account_deletion.dart';
import 'package:material_ui/material_ui.dart';

import 'settings_harness.dart';

/// 가계부 · 대기열 · 충돌 기록 · 작업 기록 · 동기화 상태를 조금씩 채운다.
Future<void> fillLocalData(AppDatabase db, LedgerRepository repo) async {
  final ledgerId = await repo.ensureLocalLedger();
  final cash = (await repo.accounts(ledgerId)).first.id;
  final txId = await repo.addTransaction(
    ledgerId,
    TransactionInput(
      type: TxType.expense,
      occurredOn: LocalDate(2026, 11, 16),
      amount: 8000,
      accountId: cash,
      counterparty: '김밥천국',
    ),
  );
  await db
      .into(db.syncConflicts)
      .insert(
        SyncConflictsCompanion.insert(
          ledgerId: ledgerId,
          targetTable: 'transactions',
          rowId: txId,
          loser: {'deleted': true},
          loserSide: 'local',
          detectedAt: testNow,
        ),
      );
  await db
      .into(db.inputBatches)
      .insert(
        InputBatchesCompanion.insert(
          id: 'batch-1',
          ledgerId: ledgerId,
          createdAt: testNow,
          source: TxSource.paste,
          itemCount: 1,
        ),
      );
  await db
      .into(db.inputBatchItems)
      .insert(
        InputBatchItemsCompanion.insert(
          batchId: 'batch-1',
          txId: txId,
          kind: 'created',
          stamp: testNow,
        ),
      );
  for (final (key, value) in [
    ('device_id', 'device-1'),
    ('owner_user_id', 'user-1'),
    ('cursor:$ledgerId', '42'),
  ]) {
    await db
        .into(db.syncState)
        .insert(SyncStateCompanion.insert(key: key, value: value));
  }
  await db
      .into(db.modelFiles)
      .insert(
        ModelFilesCompanion.insert(
          id: 'model-1',
          kind: 'text',
          fileName: 'm.gguf',
          path: '/models/m.gguf',
          sizeBytes: 10,
          sha256: 'abc',
          status: 'ready',
          updatedAt: testNow,
        ),
      );
}

/// 표마다 남은 줄 수.
Future<Map<String, int>> rowCounts(AppDatabase db) async {
  final counts = <String, int>{};
  for (final table in db.allTables) {
    final rows = await db
        .customSelect('SELECT COUNT(*) AS n FROM ${table.actualTableName}')
        .getSingle();
    counts[table.actualTableName] = rows.read<int>('n');
  }
  return counts;
}

void main() {
  group('기기의 내용 지우기', () {
    test('가계부 · 대기열 · 충돌 기록 · 작업 기록을 지우고 기기 ID와 모델 기록은 남긴다', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final repo = LedgerRepository(db, clock: () => testNow);
      await fillLocalData(db, repo);
      final before = await rowCounts(db);
      // 동기화하는 표 가운데 이 시험이 채운 것과 기기에만 있는 표.
      for (final table in [
        'ledgers',
        'profiles',
        'accounts',
        'categories',
        'transactions',
        'outbox',
        'sync_conflicts',
        'input_batches',
        'input_batch_items',
      ]) {
        expect(before[table], greaterThan(0), reason: table);
      }

      await wipeLocalData(db);

      final after = await rowCounts(db);
      expect(after.remove('model_files'), 1);
      expect(after.remove('sync_state'), 1);
      expect(after.values.toSet(), {0}, reason: '$after');
      final state = await db.select(db.syncState).get();
      expect(state.single.key, 'device_id');
      expect(state.single.value, 'device-1');
    });

    test('동기화하는 표 9개와 기기에만 있는 표를 모두 다룬다', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      // 표가 늘면 지울지 남길지를 정해 이 목록과 wipeLocalData를 함께 고친다.
      expect(
        {for (final t in db.allTables) t.actualTableName},
        {
          'ledgers',
          'profiles',
          'accounts',
          'categories',
          'transactions',
          'budgets',
          'recurring_rules',
          'category_rules',
          'monthly_summaries',
          'outbox',
          'sync_state',
          'sync_conflicts',
          'input_batches',
          'input_batch_items',
          'model_files',
        },
      );
    });
  });

  group('탈퇴 흐름', () {
    late AppDatabase db;
    late LedgerRepository repo;
    late List<String> steps;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      repo = LedgerRepository(db, clock: () => testNow);
      await fillLocalData(db, repo);
      steps = [];
    });
    tearDown(() => db.close());

    test('서버에서 지우고, 기기를 지우고, 로그아웃한 뒤 앱을 다시 연다', () async {
      await deleteAccountAndLocalData(
        deleteOnServer: () async => steps.add('server'),
        db: db,
        signOut: () async {
          // 로그아웃할 때는 기기의 가계부가 이미 지워져 있다.
          expect(await db.select(db.ledgerTransactions).get(), isEmpty);
          steps.add('signOut');
        },
        restart: () => steps.add('restart'),
      );
      expect(steps, ['server', 'signOut', 'restart']);
      expect(await db.select(db.outbox).get(), isEmpty);
      expect(await db.select(db.inputBatches).get(), isEmpty);
    });

    test('서버에서 지우지 못하면 아무것도 지우지 않고 로그아웃도 하지 않는다', () async {
      await expectLater(
        deleteAccountAndLocalData(
          deleteOnServer: () async => throw StateError('서버에 닿지 못했다'),
          db: db,
          signOut: () async => steps.add('signOut'),
          restart: () => steps.add('restart'),
        ),
        throwsStateError,
      );
      expect(steps, isEmpty);
      expect(await db.select(db.ledgerTransactions).get(), hasLength(1));
      expect(await db.select(db.outbox).get(), isNotEmpty);
    });

    test('계정이 지워져 로그아웃 요청이 거절돼도 끝까지 간다', () async {
      await deleteAccountAndLocalData(
        deleteOnServer: () async {},
        db: db,
        signOut: () async => throw StateError('없는 사용자'),
        restart: () => steps.add('restart'),
      );
      expect(steps, ['restart']);
      expect(await db.select(db.ledgerTransactions).get(), isEmpty);
    });
  });

  group('계정 화면', () {
    const email = 'me@example.com';

    Future<void> open(
      WidgetTester tester,
      AppServices services, {
      Size size = desktop,
      double textScale = 1,
      FakeSyncController? sync,
      List<Override> overrides = const [],
    }) => pumpAppWith(
      tester,
      services,
      size: size,
      textScale: textScale,
      location: '/settings/account',
      sync: sync,
      overrides: overrides,
    );

    bool deleteEnabled(WidgetTester tester) =>
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('delete-account')))
            .onPressed !=
        null;

    Future<void> typeEmail(WidgetTester tester, String text) async {
      final field = find.byKey(const ValueKey('delete-email'));
      await tester.ensureVisible(field);
      await tester.enterText(field, text);
      await tester.pumpAndSettle();
    }

    Future<void> tapDelete(WidgetTester tester) async {
      final button = find.byKey(const ValueKey('delete-account'));
      await tester.ensureVisible(button);
      await tester.pumpAndSettle();
      await tester.tap(button);
      await tester.pumpAndSettle();
    }

    testWidgets('로그인이 없는 빌드에서는 계정이 없다고 알린다', (tester) async {
      final services = await createTestServices();
      await open(
        tester,
        services,
        overrides: [accountDeleterProvider.overrideWithValue(() async {})],
      );
      expect(find.textContaining('이 앱에는 로그인이 들어 있지 않습니다'), findsOneWidget);
      expect(find.byKey(const ValueKey('delete-account')), findsNothing);
      expect(find.byKey(const ValueKey('account-sign-out')), findsNothing);
      await disposeApp(tester, services);
    });

    testWidgets('이메일을 보여 주고 로그아웃한다', (tester) async {
      final services = await createTestServices();
      final sync = FakeSyncController.signedIn(email: email);
      await open(
        tester,
        services,
        sync: sync,
        overrides: [accountDeleterProvider.overrideWithValue(null)],
      );
      expect(find.byKey(const ValueKey('account-email')), findsOneWidget);
      expect(find.text(email), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('account-sign-out')));
      await tester.pumpAndSettle();
      expect(sync.signOuts, 1);
      await disposeApp(tester, services);
    });

    testWidgets('서버 쪽이 이어 주지 않았으면 계정 삭제가 보이지 않는다', (tester) async {
      final services = await createTestServices();
      await open(
        tester,
        services,
        sync: FakeSyncController.signedIn(),
        overrides: [accountDeleterProvider.overrideWithValue(null)],
      );
      expect(find.text(email), findsOneWidget);
      expect(find.byKey(const ValueKey('delete-account')), findsNothing);
      expect(find.byKey(const ValueKey('delete-email')), findsNothing);
      expect(find.text('계정 삭제'), findsNothing);
      await disposeApp(tester, services);
    });

    testWidgets('기기에 다른 계정의 가계부가 있는 동안에는 삭제할 수 없다', (tester) async {
      final services = await createTestServices();
      await open(
        tester,
        services,
        sync: FakeSyncController(
          const SyncStatus(
            SyncPhase.differentAccount,
            user: AuthUser(id: 'user-2', email: email),
          ),
        ),
        overrides: [accountDeleterProvider.overrideWithValue(() async {})],
      );
      expect(find.text(email), findsOneWidget);
      expect(find.byKey(const ValueKey('delete-blocked')), findsOneWidget);
      expect(find.byKey(const ValueKey('delete-account')), findsNothing);
      await disposeApp(tester, services);
    });

    testWidgets('무엇이 지워지는지 보여 주고, 이메일을 그대로 적어야 단추가 켜진다', (tester) async {
      final services = await createTestServices();
      // 아직 올리지 않은 변경을 하나 만든다.
      await services.repository.setMonthStartDay(services.ledgerId, 25);
      var deleted = 0;
      await open(
        tester,
        services,
        sync: FakeSyncController.signedIn(email: email),
        overrides: [
          accountDeleterProvider.overrideWithValue(() async => deleted++),
        ],
      );
      expect(find.textContaining('서버에 있는 가계부 전체'), findsOneWidget);
      expect(find.text('로그인 계정($email)'), findsOneWidget);
      expect(find.text('이 기기의 가계부와 아직 올리지 않은 변경 1건'), findsOneWidget);
      expect(find.text('이 기기의 작업 기록과 동기화 충돌 기록'), findsOneWidget);

      expect(deleteEnabled(tester), isFalse);
      await typeEmail(tester, 'me@example.co');
      expect(deleteEnabled(tester), isFalse);
      await typeEmail(tester, 'ME@example.com');
      expect(deleteEnabled(tester), isFalse);
      await typeEmail(tester, '계정 삭제');
      expect(deleteEnabled(tester), isFalse);
      await typeEmail(tester, email);
      expect(deleteEnabled(tester), isTrue);
      // 꺼져 있을 때 눌러 본 것은 아무 일도 하지 않았다.
      expect(deleted, 0);
      await disposeApp(tester, services);
    });

    testWidgets('삭제하면 서버 → 기기 → 로그아웃 → 다시 열기 순서로 간다', (tester) async {
      final services = await createTestServices();
      await fillLocalData(services.db, services.repository);
      final sync = FakeSyncController.signedIn(email: email);
      final steps = <String>[];
      await open(
        tester,
        services,
        sync: sync,
        overrides: [
          accountDeleterProvider.overrideWithValue(
            () async => steps.add('server'),
          ),
          appRestartProvider.overrideWithValue(() => steps.add('restart')),
        ],
      );
      await typeEmail(tester, email);
      await tapDelete(tester);

      expect(steps, ['server', 'restart']);
      expect(sync.signOuts, 1);
      final db = services.db;
      expect(await db.select(db.ledgerTransactions).get(), isEmpty);
      expect(await db.select(db.ledgers).get(), isEmpty);
      expect(await db.select(db.outbox).get(), isEmpty);
      expect(await db.select(db.syncConflicts).get(), isEmpty);
      expect(await db.select(db.inputBatches).get(), isEmpty);
      expect((await db.select(db.syncState).get()).single.key, 'device_id');
      await disposeApp(tester, services);
    });

    testWidgets('서버에서 지우지 못하면 알리고 기기의 것은 그대로 둔다', (tester) async {
      final services = await createTestServices();
      await fillLocalData(services.db, services.repository);
      final sync = FakeSyncController.signedIn(email: email);
      var restarts = 0;
      await open(
        tester,
        services,
        sync: sync,
        overrides: [
          accountDeleterProvider.overrideWithValue(
            () async => throw StateError('SocketException: 연결 실패'),
          ),
          appRestartProvider.overrideWithValue(() => restarts++),
        ],
      );
      await typeEmail(tester, email);
      await tapDelete(tester);

      expect(find.byKey(const ValueKey('delete-error')), findsOneWidget);
      expect(find.textContaining('아무것도 지워지지 않았습니다'), findsOneWidget);
      // 예외 문구를 그대로 보이지 않는다.
      expect(find.textContaining('SocketException'), findsNothing);
      expect(sync.signOuts, 0);
      expect(restarts, 0);
      expect(
        await services.db.select(services.db.ledgerTransactions).get(),
        hasLength(1),
      );
      // 다시 해 볼 수 있다.
      expect(deleteEnabled(tester), isTrue);
      await disposeApp(tester, services);
    });

    group('넘치지 않는다', () {
      for (final (name, size) in fourSizes) {
        testWidgets(name, (tester) async {
          final services = await createTestServices();
          await open(
            tester,
            services,
            size: size,
            sync: FakeSyncController.signedIn(
              email: 'a-very-long-address-for-testing@example-company.co.kr',
            ),
            overrides: [
              accountDeleterProvider.overrideWithValue(
                () async => throw StateError('x'),
              ),
            ],
          );
          expect(tester.takeException(), isNull);
          await typeEmail(
            tester,
            'a-very-long-address-for-testing@example-company.co.kr',
          );
          await tapDelete(tester);
          expect(find.byKey(const ValueKey('delete-error')), findsOneWidget);
          expect(tester.takeException(), isNull);
          await disposeApp(tester, services);
        });
      }

      testWidgets('소형 폰에서 글자를 200%로 키워도', (tester) async {
        final services = await createTestServices();
        await open(
          tester,
          services,
          size: phone,
          textScale: 2,
          sync: FakeSyncController.signedIn(),
          overrides: [accountDeleterProvider.overrideWithValue(() async {})],
        );
        expect(tester.takeException(), isNull);
        await scrollSubScreenTo(
          tester,
          find.byKey(const ValueKey('delete-account')),
        );
        expect(tester.takeException(), isNull);
        await disposeApp(tester, services);
      });
    });
  });
}
