import 'package:flutter_test/flutter_test.dart';
import 'package:gagyebu/app/providers.dart';
import 'package:gagyebu/core/local_date.dart';
import 'package:gagyebu/data/repositories/input_batch_repository.dart';
import 'package:gagyebu/data/repositories/ledger_repository.dart';
import 'package:gagyebu/domain/enums.dart';
import 'package:gagyebu/features/history/history_actions.dart';
import 'package:gagyebu/features/history/history_screen.dart';
import 'package:gagyebu/features/settings/settings_screen.dart';
import 'package:gagyebu/features/shell/app_shell.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import 'composer_support.dart';
import 'test_app.dart';

const _twoSms = '''
[Web발신]
신한카드(1234)승인 홍*동
12,500원(일시불) 11/16 12:31
김밥천국 강남점 누적 345,600원

삼성1234승인 홍*동 4,800원 일시불 11/15 09:07 스타벅스 누적80,090원''';

Finder _key(String key) => find.byKey(ValueKey(key));

Future<SavedBatch> _saveBatch(AppServices services, List<(int, String)> rows) {
  return InputBatchRepository(services.repository)
      .saveBatch(services.ledgerId, [
        for (final (amount, party) in rows)
          BatchCreate(_expense(services, amount, party)),
      ], source: TxSource.paste);
}

late String _cash;

TransactionInput _expense(AppServices services, int amount, String party) =>
    TransactionInput(
      type: TxType.expense,
      occurredOn: LocalDate(2026, 11, 16),
      amount: amount,
      accountId: _cash,
      counterparty: party,
      source: TxSource.paste,
    );

Future<AppServices> _services() async {
  final services = await createTickingServices();
  _cash = (await services.repository.accounts(services.ledgerId)).first.id;
  return services;
}

/// 작업 기록과 되돌리기(`docs/SPEC.md` 7.7).
void main() {
  group('작업 기록 화면', () {
    testWidgets('기록이 없으면 빈 상태를 보인다', (tester) async {
      final services = await _services();
      await pumpApp(tester, services, size: desktop, location: '/history');

      expect(find.byType(HistoryScreen), findsOneWidget);
      expect(find.text('작업 기록'), findsOneWidget);
      expect(_key('history-empty'), findsOneWidget);
      expect(find.textContaining('아직 기록이 없습니다'), findsOneWidget);
      await disposeApp(tester, services);
    });

    testWidgets('묶음마다 때 · 경로 · 건수를 보이고, 누르면 거래가 보인다', (tester) async {
      final services = await _services();
      final batch = await _saveBatch(services, [
        (12500, '김밥천국'),
        (4800, '스타벅스'),
      ]);
      await pumpApp(tester, services, size: desktop, location: '/history');

      expect(_key('history-batch-${batch.batchId}'), findsOneWidget);
      expect(find.text('11월 17일 (화) 오후 12:00'), findsOneWidget);
      expect(find.text('붙여넣기 · 2건'), findsOneWidget);
      // 접혀 있을 때는 거래가 보이지 않는다.
      expect(find.text('김밥천국'), findsNothing);

      await tester.tap(_key('history-open-${batch.batchId}'));
      await tester.pumpAndSettle();
      expect(find.text('김밥천국'), findsOneWidget);
      expect(find.text('-12,500원'), findsOneWidget);
      expect(find.text('스타벅스'), findsOneWidget);
      expect(find.text('-4,800원'), findsOneWidget);
      expect(find.text('이 묶음 되돌리기'), findsOneWidget);
      await disposeApp(tester, services);
    });

    testWidgets('묶음을 되돌리면 고치지 않은 거래를 지우고 "되돌림"으로 남긴다', (tester) async {
      final services = await _services();
      final batch = await _saveBatch(services, [
        (12500, '김밥천국'),
        (4800, '스타벅스'),
        (900, '편의점'),
      ]);
      // 한 건을 저장한 뒤에 고쳤다.
      await services.repository.updateTransaction(
        batch.createdIds[1],
        _expense(services, 5300, '스타벅스'),
      );
      await pumpApp(tester, services, size: desktop, location: '/history');

      await tester.tap(_key('history-open-${batch.batchId}'));
      await tester.pumpAndSettle();
      expect(find.textContaining('저장한 뒤에 고침'), findsOneWidget);

      await tester.tap(_key('history-undo-${batch.batchId}'));
      await tester.pumpAndSettle();
      expect(find.text('이 묶음을 되돌릴까요?'), findsOneWidget);
      await tester.tap(_key('history-undo-confirm'));
      await tester.pumpAndSettle();

      expect(find.text('2건을 되돌리고, 고친 1건은 남겼습니다'), findsOneWidget);
      expect(_key('history-undone-${batch.batchId}'), findsOneWidget);
      // 다시 되돌릴 수는 없다.
      expect(_key('history-undo-${batch.batchId}'), findsNothing);
      expect(find.textContaining('다시 되돌릴 수 없습니다'), findsOneWidget);
      // 고친 거래는 남고, 나머지는 지워졌다고 보인다.
      expect(find.text('스타벅스'), findsOneWidget);
      expect(find.text('지워진 거래'), findsNWidgets(2));

      final rows = await allTransactions(services);
      expect(rows.where((r) => r.deletedAt == null).map((r) => r.amount), [
        5300,
      ]);
      await disposeApp(tester, services);
    });

    testWidgets('되돌리기를 그만두면 아무것도 바뀌지 않는다', (tester) async {
      final services = await _services();
      final batch = await _saveBatch(services, [(12500, '김밥천국')]);
      await pumpApp(tester, services, size: desktop, location: '/history');

      await tester.tap(_key('history-open-${batch.batchId}'));
      await tester.pumpAndSettle();
      await tester.tap(_key('history-undo-${batch.batchId}'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('그만두기'));
      await tester.pumpAndSettle();

      expect(_key('history-undone-${batch.batchId}'), findsNothing);
      expect(await allTransactions(services), hasLength(1));
      await disposeApp(tester, services);
    });

    testWidgets('취소로 표시한 원 거래는 되돌리면 취소가 풀린다', (tester) async {
      final services = await _services();
      final original = await services.repository.addTransaction(
        services.ledgerId,
        _expense(services, 30000, '서점'),
      );
      final batch = await InputBatchRepository(services.repository).saveBatch(
        services.ledgerId,
        [BatchCancel(original)],
        source: TxSource.paste,
      );
      await pumpApp(tester, services, size: desktop, location: '/history');

      await tester.tap(_key('history-open-${batch.batchId}'));
      await tester.pumpAndSettle();
      expect(find.textContaining('이 묶음이 취소로 표시함'), findsOneWidget);

      await tester.tap(_key('history-undo-${batch.batchId}'));
      await tester.pumpAndSettle();
      await tester.tap(_key('history-undo-confirm'));
      await tester.pumpAndSettle();

      expect(find.text('1건을 되돌렸습니다'), findsOneWidget);
      final row = await services.repository.transactionById(original);
      expect(row!.canceledAt, isNull);
      expect(row.deletedAt, isNull);
      await disposeApp(tester, services);
    });

    testWidgets('좁은 창에서는 설정으로 돌아가는 단추가 있다', (tester) async {
      final services = await _services();
      await pumpApp(tester, services, size: phone, location: '/history');

      await tester.tap(find.byTooltip('설정으로'));
      await tester.pumpAndSettle();
      expect(find.byType(SettingsScreen), findsOneWidget);
      await disposeApp(tester, services);
    });

    for (final (name, size) in [
      ('휴대폰', phone),
      ('큰 휴대폰', largePhone),
      ('태블릿', foldable),
      ('PC', desktop),
    ]) {
      testWidgets('$name: 글자를 200%로 키워도 넘치지 않는다', (tester) async {
        final services = await _services();
        final batch = await _saveBatch(services, [
          (12500000, '이름이 아주 긴 가맹점 강남역 2호점 지하 1층'),
          (4800, '스타벅스'),
        ]);
        final undone = await _saveBatch(services, [(900, '편의점')]);
        await InputBatchRepository(services.repository).undo(undone.batchId);
        await pumpApp(
          tester,
          services,
          size: size,
          location: '/history',
          textScale: 2,
        );
        expect(tester.takeException(), isNull);

        final open = _key('history-open-${batch.batchId}');
        await tester.ensureVisible(open);
        await tester.pumpAndSettle();
        await tester.tap(open);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        final undo = _key('history-undo-${batch.batchId}');
        await tester.ensureVisible(undo);
        await tester.pumpAndSettle();
        await tester.tap(undo);
        await tester.pumpAndSettle();
        expect(find.text('이 묶음을 되돌릴까요?'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await disposeApp(tester, services);
      });
    }
  });

  group('저장 직후의 되돌리기', () {
    testWidgets('알림의 "되돌리기"로 방금 저장한 묶음을 되돌린다', (tester) async {
      final services = await _services();
      await pumpApp(tester, services, size: desktop);

      await sendFromComposer(tester, _twoSms);
      await tester.tap(_key('review-save'));
      await tester.pumpAndSettle();
      expect(find.text('2건을 저장했습니다'), findsOneWidget);
      expect(
        tester.widget<Text>(_key('total-expense')).data,
        '17,300원',
        reason: '저장한 달의 합계',
      );

      await tester.tap(find.text('되돌리기'));
      await tester.pumpAndSettle();

      expect(find.text('2건을 되돌렸습니다'), findsOneWidget);
      expect(tester.widget<Text>(_key('total-expense')).data, '0원');
      // 서버에 올라간 적 없는 거래는 흔적 없이 지운다.
      expect(await allTransactions(services), isEmpty);
      final batch =
          (await services.db.select(services.db.inputBatches).get()).single;
      expect(batch.undoneAt, isNotNull);
      await disposeApp(tester, services);
    });

    testWidgets('휴대폰에서도 검토함이 닫힌 뒤에 알림의 "되돌리기"가 듣는다', (tester) async {
      final services = await _services();
      await pumpApp(tester, services, size: phone);

      await sendFromComposer(tester, _twoSms);
      await tester.tap(_key('review-save'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('nav-bottom')), findsOneWidget);
      expect(find.text('2건을 저장했습니다'), findsOneWidget);

      await tester.tap(find.text('되돌리기'));
      await tester.pumpAndSettle();
      expect(find.text('2건을 되돌렸습니다'), findsOneWidget);
      expect(await allTransactions(services), isEmpty);
      await disposeApp(tester, services);
    });

    testWidgets('저장한 묶음이 작업 기록에 한 줄 입력 · 붙여넣기로 남는다', (tester) async {
      final services = await _services();
      await pumpApp(tester, services, size: desktop);

      await sendFromComposer(tester, _twoSms);
      await tester.tap(_key('review-save'));
      await tester.pumpAndSettle();
      await sendFromComposer(tester, '택시 12000원');
      await tester.tap(_key('review-save'));
      await tester.pumpAndSettle();

      // 설정 → 관리 → 작업 기록과 같은 주소로 간다.
      GoRouter.of(tester.element(find.byType(AppShell))).go('/history');
      await tester.pumpAndSettle();

      expect(find.byType(HistoryScreen), findsOneWidget);
      expect(find.text('붙여넣기 · 2건'), findsOneWidget);
      expect(find.text('한 줄 입력 · 1건'), findsOneWidget);
      await disposeApp(tester, services);
    });
  });

  group('마지막 묶음 되돌리기(명령창 · Ctrl+Z가 쓰는 함수)', () {
    testWidgets('가장 최근 묶음부터 되돌리고, 더 없으면 그렇게 알린다', (tester) async {
      final services = await _services();
      await _saveBatch(services, [(12500, '김밥천국')]);
      await _saveBatch(services, [(4800, '스타벅스'), (900, '편의점')]);
      await pumpApp(tester, services, size: desktop);
      final messenger = ScaffoldMessenger.of(
        tester.element(find.byType(Scaffold).first),
      );
      final container = containerOf(tester);

      final first = await undoLastBatch(messenger, container);
      await tester.pumpAndSettle();
      expect(first!.undone, 2);
      expect(find.text('2건을 되돌렸습니다'), findsOneWidget);

      final second = await undoLastBatch(messenger, container);
      await tester.pumpAndSettle();
      expect(second!.undone, 1);
      expect(find.text('1건을 되돌렸습니다'), findsOneWidget);

      final third = await undoLastBatch(messenger, container);
      await tester.pumpAndSettle();
      expect(third, isNull);
      expect(find.text('되돌릴 입력이 없습니다'), findsOneWidget);
      await disposeApp(tester, services);
    });

    testWidgets('이미 되돌린 묶음을 또 되돌리려 하면 알리기만 한다', (tester) async {
      final services = await _services();
      final batch = await _saveBatch(services, [(12500, '김밥천국')]);
      await pumpApp(tester, services, size: desktop);
      final messenger = ScaffoldMessenger.of(
        tester.element(find.byType(Scaffold).first),
      );
      final container = containerOf(tester);

      await undoBatchAndNotify(messenger, container, batch.batchId);
      await tester.pumpAndSettle();
      final again = await undoBatchAndNotify(
        messenger,
        container,
        batch.batchId,
      );
      await tester.pumpAndSettle();

      expect(again, isNull);
      expect(find.text('이미 되돌린 묶음입니다'), findsOneWidget);
      await disposeApp(tester, services);
    });
  });

  test('되돌린 결과를 알리는 문장', () {
    expect(
      undoResultMessage(const UndoResult(undone: 3, kept: 1)),
      '3건을 되돌리고, 고친 1건은 남겼습니다',
    );
    expect(
      undoResultMessage(const UndoResult(undone: 3, kept: 0)),
      '3건을 되돌렸습니다',
    );
    expect(
      undoResultMessage(const UndoResult(undone: 0, kept: 2)),
      '되돌린 건이 없습니다. 고친 2건은 남겼습니다',
    );
    expect(
      undoResultMessage(const UndoResult(undone: 0, kept: 0)),
      '되돌릴 거래가 남아 있지 않습니다',
    );
  });
}
