import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gagyebu/app/providers.dart';
import 'package:gagyebu/core/local_date.dart';
import 'package:gagyebu/data/repositories/input_batch_repository.dart';
import 'package:gagyebu/data/repositories/ledger_repository.dart';
import 'package:gagyebu/domain/enums.dart';
import 'package:gagyebu/features/review/review_panel.dart';
import 'package:gagyebu/features/review/review_state.dart';
import 'package:material_ui/material_ui.dart';

import 'composer_support.dart';
import 'test_app.dart';

const _cardSms = '''
[Web발신]
신한카드(1234)승인 홍*동
12,500원(일시불) 11/16 12:31
김밥천국 강남점 누적 345,600원''';

const _twoSms =
    '$_cardSms\n\n'
    '삼성1234승인 홍*동 4,800원 일시불 11/15 09:07 스타벅스 누적80,090원';

const _cardPaymentSms =
    '우리 11/14 09:00 *123456 출금 1,250,000원 신한카드 잔액 2,000,000원';

Finder _key(String key) => find.byKey(ValueKey(key));

String _text(WidgetTester tester, String key) =>
    tester.widget<Text>(_key(key)).data!;

bool _saveEnabled(WidgetTester tester) =>
    tester.widget<FilledButton>(_key('review-save')).onPressed != null;

Finder _reviewScrollable() => find
    .descendant(of: _key('review-list'), matching: find.byType(Scrollable))
    .first;

/// 드롭다운을 열어 [item]을 고른다.
Future<void> _choose(WidgetTester tester, String key, String item) async {
  await tester.ensureVisible(_key(key));
  await tester.pumpAndSettle();
  await tester.tap(_key(key));
  await tester.pumpAndSettle();
  await tester.tap(find.text(item).last);
  await tester.pumpAndSettle();
}

Future<void> _save(WidgetTester tester) async {
  await tester.tap(_key('review-save'));
  await tester.pumpAndSettle();
}

/// 검토함(`docs/SPEC.md` 7.6).
void main() {
  group('고치기', () {
    testWidgets('이체로 바꿔 받는 자산을 고르고 저장한다', (tester) async {
      final services = await createTestServices();
      final bank = await services.repository.addAccount(
        ledgerId: services.ledgerId,
        name: '우리은행',
        kind: AccountKind.bank,
      );
      await pumpApp(tester, services, size: desktop);

      await sendFromComposer(tester, '어제 저금 30만원');
      expect(_text(tester, 'review-amount-label-0'), '-300,000원');

      await tester.tap(_key('review-type-transfer-0'));
      await tester.pumpAndSettle();
      // 이체에는 상대방과 분류가 없고, 받는 자산을 골라야 저장된다.
      expect(_key('review-party-0'), findsNothing);
      expect(_key('review-category-0'), findsNothing);
      expect(find.text('받는 자산을 골라야 합니다'), findsOneWidget);
      expect(find.text('채워야 하는 건이 1건 있습니다'), findsOneWidget);
      expect(_saveEnabled(tester), isFalse);

      await _choose(tester, 'review-to-account-0', '우리은행');
      expect(_text(tester, 'review-title-0'), '현금 → 우리은행');
      // 이체에는 부호를 붙이지 않는다.
      expect(_text(tester, 'review-amount-label-0'), '300,000원');
      expect(_saveEnabled(tester), isTrue);

      await _save(tester);
      final saved = (await allTransactions(services)).single;
      expect(saved.type, TxType.transfer);
      expect(saved.amount, 300000);
      expect(saved.toAccountId, bank);
      expect(saved.categoryId, isNull);
      expect(saved.sender, '현금');
      expect(saved.receiver, '우리은행');
      expect(saved.occurredOn, LocalDate(2026, 11, 16));
      await disposeApp(tester, services);
    });

    testWidgets('같은 자산으로는 이체하지 못한다', (tester) async {
      final services = await createTestServices();
      await pumpApp(tester, services, size: desktop);

      await sendFromComposer(tester, '어제 저금 30만원');
      await tester.tap(_key('review-type-transfer-0'));
      await tester.pumpAndSettle();
      await _choose(tester, 'review-to-account-0', '현금');

      expect(find.text('보내는 자산과 받는 자산이 같습니다'), findsOneWidget);
      expect(_saveEnabled(tester), isFalse);
      await disposeApp(tester, services);
    });

    testWidgets('상대방 · 금액 · 분류 · 메모 · 종류를 고쳐 저장한다', (tester) async {
      final services = await createTestServices();
      await pumpApp(tester, services, size: desktop);

      await sendFromComposer(tester, '어제 점심 김밥천국 8천원');
      await tester.enterText(_key('review-party-0'), '김밥나라');
      await tester.enterText(_key('review-amount-0'), '8,500');
      await tester.pumpAndSettle();
      await _choose(tester, 'review-category-0', '생활');
      await tester.ensureVisible(_key('review-memo-0'));
      await tester.enterText(_key('review-memo-0'), '동료와');
      await tester.pumpAndSettle();
      expect(_text(tester, 'review-title-0'), '김밥나라');
      expect(_text(tester, 'review-amount-label-0'), '-8,500원');
      expect(_text(tester, 'review-subtitle-0'), contains('생활'));

      await _save(tester);
      final saved = (await allTransactions(services)).single;
      expect(saved.receiver, '김밥나라');
      expect(saved.amount, 8500);
      expect(saved.memo, '동료와');
      final categories = await services.repository.categories(
        services.ledgerId,
      );
      expect(categories.firstWhere((c) => c.id == saved.categoryId).name, '생활');
      // 고른 분류는 다음에 같은 상대방이 오면 먼저 제안한다.
      expect(
        await services.repository.categoryForCounterparty(
          services.ledgerId,
          '김밥나라',
        ),
        saved.categoryId,
      );
      await disposeApp(tester, services);
    });

    testWidgets('수입으로 바꾸면 분류를 비우고 수입 분류에서 고른다', (tester) async {
      final services = await createTestServices();
      await pumpApp(tester, services, size: desktop);

      await sendFromComposer(tester, '어제 점심 김밥천국 8천원');
      expect(_text(tester, 'review-subtitle-0'), contains('식비'));
      await tester.tap(_key('review-type-income-0'));
      await tester.pumpAndSettle();
      expect(_text(tester, 'review-amount-label-0'), '+8,000원');
      expect(_text(tester, 'review-subtitle-0'), contains('분류 없음'));

      await _save(tester);
      final saved = (await allTransactions(services)).single;
      expect(saved.type, TxType.income);
      expect(saved.sender, '김밥천국');
      expect(saved.categoryId, isNull);
      await disposeApp(tester, services);
    });
  });

  group('확인 필요', () {
    testWidgets('경고를 둔 채 저장하면 needs_review가 붙는다', (tester) async {
      final services = await createTestServices();
      await pumpApp(tester, services, size: desktop);

      // 금액에 '원'이 없다.
      await sendFromComposer(tester, '점심 9000');
      expect(_key('review-flag-0'), findsOneWidget);
      expect(find.text('1건 읽음 · 1건 확인 필요'), findsOneWidget);
      expect(find.textContaining('금액에 ‘원’이 없었습니다'), findsOneWidget);
      expect(_key('review-needs-review-note'), findsOneWidget);

      await _save(tester);
      final saved = (await allTransactions(services)).single;
      expect(saved.amount, 9000);
      expect(saved.status, TxStatus.needsReview);
      await disposeApp(tester, services);
    });

    testWidgets('그 건을 고치면 표시가 풀리고 confirmed로 저장된다', (tester) async {
      final services = await createTestServices();
      await pumpApp(tester, services, size: desktop);

      await sendFromComposer(tester, '점심 9000');
      expect(_key('review-flag-0'), findsOneWidget);

      await tester.enterText(_key('review-amount-0'), '9,500');
      await tester.pumpAndSettle();
      expect(_key('review-flag-0'), findsNothing);
      expect(find.text('1건 읽음'), findsOneWidget);
      expect(_key('review-needs-review-note'), findsNothing);

      await _save(tester);
      final saved = (await allTransactions(services)).single;
      expect(saved.amount, 9500);
      expect(saved.status, TxStatus.confirmed);
      await disposeApp(tester, services);
    });

    testWidgets('고칠 것이 없으면 "확인함"으로 표시를 푼다', (tester) async {
      final services = await createTestServices();
      await pumpApp(tester, services, size: desktop);

      await sendFromComposer(tester, '점심 9000');
      await tester.tap(_key('review-confirm-0'));
      await tester.pumpAndSettle();
      expect(_key('review-flag-0'), findsNothing);

      await _save(tester);
      expect(
        (await allTransactions(services)).single.status,
        TxStatus.confirmed,
      );
      await disposeApp(tester, services);
    });

    testWidgets('제외한 건의 경고는 세지 않는다', (tester) async {
      final services = await createTestServices();
      await pumpApp(tester, services, size: desktop);

      await sendFromComposer(tester, '점심 9000');
      await tester.tap(_key('review-include-0'));
      await tester.pumpAndSettle();

      expect(find.text('1건 읽음'), findsOneWidget);
      expect(find.text('저장할 건이 없습니다'), findsOneWidget);
      expect(_saveEnabled(tester), isFalse);
      await disposeApp(tester, services);
    });
  });

  group('중복과 취소', () {
    testWidgets('이미 있는 거래와 같은 건은 기본이 제외다', (tester) async {
      final services = await createTestServices();
      await services.repository.addTransaction(
        services.ledgerId,
        TransactionInput(
          type: TxType.expense,
          occurredOn: LocalDate(2026, 11, 16),
          amount: 12500,
          accountId: (await services.repository.accounts(services.ledgerId))
              .first
              .id,
          counterparty: '김밥천국 강남점',
        ),
      );
      await pumpApp(tester, services, size: desktop);

      await sendFromComposer(tester, _twoSms);

      expect(tester.widget<Checkbox>(_key('review-include-0')).value, isFalse);
      expect(tester.widget<Checkbox>(_key('review-include-1')).value, isTrue);
      expect(find.text('중복이라 제외'), findsOneWidget);
      expect(find.text('모두 승인하고 저장 (1건)'), findsOneWidget);

      // 다른 거래가 맞다면 포함할 수 있다.
      await tester.tap(_key('review-include-0'));
      await tester.pumpAndSettle();
      expect(find.text('중복일 수 있음'), findsOneWidget);
      expect(find.text('모두 승인하고 저장 (2건)'), findsOneWidget);
      await tester.tap(_key('review-include-0'));
      await tester.pumpAndSettle();

      await _save(tester);
      final saved = await allTransactions(services);
      expect(saved.map((t) => t.amount), [12500, 4800]);
      await disposeApp(tester, services);
    });

    testWidgets('같은 문자를 두 번 붙여넣으면 뒤의 것을 제외해 둔다', (tester) async {
      final services = await createTestServices();
      await pumpApp(tester, services, size: desktop);

      await sendFromComposer(tester, '$_cardSms\n\n$_cardSms');

      expect(find.text('2건 읽음'), findsOneWidget);
      expect(tester.widget<Checkbox>(_key('review-include-0')).value, isTrue);
      expect(tester.widget<Checkbox>(_key('review-include-1')).value, isFalse);
      expect(find.text('모두 승인하고 저장 (1건)'), findsOneWidget);
      await disposeApp(tester, services);
    });

    testWidgets('취소 문자는 원 거래를 찾아 취소로 표시한다', (tester) async {
      final services = await createTestServices();
      final original = await services.repository.addTransaction(
        services.ledgerId,
        TransactionInput(
          type: TxType.expense,
          occurredOn: LocalDate(2026, 11, 16),
          amount: 12500,
          accountId: (await services.repository.accounts(services.ledgerId))
              .first
              .id,
          counterparty: '김밥천국',
        ),
      );
      await pumpApp(tester, services, size: desktop);

      await sendFromComposer(
        tester,
        '우리(1234)승인취소 홍*동님 12,500원 일시불 11/16 20:29 김밥천국 누적123,456원',
      );

      expect(_text(tester, 'review-title-0'), '취소: 김밥천국');
      expect(_text(tester, 'review-amount-label-0'), '12,500원 취소');
      expect(
        find.textContaining('11월 16일 김밥천국 12,500원 거래를 취소로 표시합니다'),
        findsOneWidget,
      );
      // 고칠 값이 없다.
      expect(_key('review-amount-0'), findsNothing);

      await _save(tester);
      final rows = await allTransactions(services);
      expect(rows, hasLength(1));
      expect(rows.single.id, original);
      expect(rows.single.canceledAt, isNotNull);
      final item =
          (await services.db.select(services.db.inputBatchItems).get()).single;
      expect(item.txId, original);
      expect(item.kind, BatchItemKind.canceled);
      await disposeApp(tester, services);
    });

    testWidgets('원 거래를 찾지 못한 취소는 환불로 적는다', (tester) async {
      final services = await createTestServices();
      await pumpApp(tester, services, size: desktop);

      await sendFromComposer(
        tester,
        '우리(1234)승인취소 홍*동님 12,500원 일시불 11/16 20:29 김밥천국 누적123,456원',
      );
      expect(find.textContaining('원 거래를 찾지 못해 환불로 적습니다'), findsOneWidget);
      expect(_text(tester, 'review-amount-label-0'), '+12,500원');

      await _save(tester);
      final saved = (await allTransactions(services)).single;
      expect(saved.type, TxType.expense);
      expect(saved.amount, -12500);
      expect(saved.memo, '취소 · 환불');
      await disposeApp(tester, services);
    });
  });

  group('카드대금', () {
    testWidgets('카드의 결제 계좌에서 나간 카드대금은 이체로 제안한다', (tester) async {
      final services = await createTestServices();
      final bank = await services.repository.addAccount(
        ledgerId: services.ledgerId,
        name: '우리은행 통장',
        kind: AccountKind.bank,
        institution: '우리은행',
        matchHints: ['우리', '123456'],
      );
      final card = await services.repository.addAccount(
        ledgerId: services.ledgerId,
        name: '신한카드',
        kind: AccountKind.creditCard,
        billingDay: 14,
        paymentAccountId: bank,
      );
      await pumpApp(tester, services, size: desktop);

      await sendFromComposer(tester, _cardPaymentSms);

      expect(_text(tester, 'review-title-0'), '우리은행 통장 → 신한카드');
      expect(_text(tester, 'review-amount-label-0'), '1,250,000원');
      expect(find.text('이체로 제안'), findsOneWidget);
      expect(find.textContaining('이체(계좌 → 카드)로 제안했습니다'), findsOneWidget);
      // 제안이므로 확인을 청한다.
      expect(_key('review-flag-0'), findsOneWidget);

      await tester.tap(_key('review-confirm-0'));
      await tester.pumpAndSettle();
      await _save(tester);
      final saved = (await allTransactions(services)).single;
      expect(saved.type, TxType.transfer);
      expect(saved.accountId, bank);
      expect(saved.toAccountId, card);
      expect(saved.status, TxStatus.confirmed);
      // 이체는 지출 합계에 잡히지 않는다.
      final summary = await services.repository.monthSummary(
        services.ledgerId,
        containerOf(tester).read(selectedPeriodProvider),
        today: LocalDate(2026, 11, 17),
      );
      expect(summary.expense, 0);
      await disposeApp(tester, services);
    });

    testWidgets('맞는 카드 자산이 없으면 지출로 두고 이체로 바꾸라고 알린다', (tester) async {
      final services = await createTestServices();
      await pumpApp(tester, services, size: desktop);

      await sendFromComposer(tester, _cardPaymentSms);

      expect(_text(tester, 'review-title-0'), '신한카드');
      expect(_text(tester, 'review-amount-label-0'), '-1,250,000원');
      expect(find.text('이체로 제안'), findsNothing);
      expect(find.textContaining('이체로 바꿔 주세요'), findsOneWidget);
      expect(_key('review-flag-0'), findsOneWidget);
      await disposeApp(tester, services);
    });

    testWidgets('다른 계좌에서 나간 출금은 이체로 제안하지 않는다', (tester) async {
      final services = await createTestServices();
      await services.repository.addAccount(
        ledgerId: services.ledgerId,
        name: '우리은행 통장',
        kind: AccountKind.bank,
        matchHints: ['우리', '123456'],
      );
      final other = await services.repository.addAccount(
        ledgerId: services.ledgerId,
        name: '국민은행 통장',
        kind: AccountKind.bank,
      );
      await services.repository.addAccount(
        ledgerId: services.ledgerId,
        name: '신한카드',
        kind: AccountKind.creditCard,
        paymentAccountId: other,
      );
      await pumpApp(tester, services, size: desktop);

      await sendFromComposer(tester, _cardPaymentSms);

      expect(_text(tester, 'review-title-0'), '신한카드');
      expect(find.text('이체로 제안'), findsNothing);
      await disposeApp(tester, services);
    });
  });

  group('저장', () {
    testWidgets('한 건이라도 저장하지 못하면 아무것도 저장하지 않고 검토를 남긴다', (tester) async {
      final services = await createTestServices();
      await pumpApp(tester, services, size: desktop);

      await sendFromComposer(tester, _twoSms);
      // 둘째 건의 자산이 그사이에 사라졌다.
      containerOf(tester)
          .read(reviewSessionProvider.notifier)
          .edit(1, (d) => d.copyWith(accountId: 'gone'));
      await tester.pumpAndSettle();

      await _save(tester);

      expect(
        find.textContaining('저장하지 못했습니다. 한 건도 저장되지 않았습니다'),
        findsOneWidget,
      );
      expect(await allTransactions(services), isEmpty);
      expect(await services.db.select(services.db.inputBatches).get(), isEmpty);
      expect(_key('review-save-error'), findsOneWidget);
      // 예외 문구는 보이지 않는다.
      expect(find.textContaining('없는 자산'), findsNothing);
      // 검토하던 내용은 그대로다.
      expect(_key('review-0'), findsOneWidget);
      expect(_key('review-1'), findsOneWidget);
      expect(_saveEnabled(tester), isTrue);

      // 고쳐서 다시 누르면 저장되고, 알림은 사라진다.
      final cash = (await services.repository.accounts(services.ledgerId))
          .first
          .id;
      containerOf(tester)
          .read(reviewSessionProvider.notifier)
          .edit(1, (d) => d.copyWith(accountId: cash));
      await tester.pumpAndSettle();
      expect(_key('review-save-error'), findsNothing);
      await _save(tester);
      expect(await allTransactions(services), hasLength(2));
      await disposeApp(tester, services);
    });

    testWidgets('저장하면 첫 건의 달로 옮겨 간다', (tester) async {
      final services = await createTestServices();
      await pumpApp(tester, services, size: desktop);

      // 오늘은 2026-11-17이고, 9월 3일의 지출이다.
      await sendFromComposer(
        tester,
        '삼성1234승인 홍*동 4,800원 일시불 09/03 09:07 스타벅스 누적80,090원',
      );
      await _save(tester);

      expect(find.text('2026년 9월'), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('total-expense'))).data,
        '4,800원',
      );
      await disposeApp(tester, services);
    });

    testWidgets('검토하는 중에 또 보내면 뒤에 덧붙인다', (tester) async {
      final services = await createTestServices();
      await pumpApp(tester, services, size: desktop);

      await sendFromComposer(tester, _cardSms);
      await sendFromComposer(tester, '택시 12000원');

      expect(find.text('2건 읽음'), findsOneWidget);
      expect(
        containerOf(tester)
            .read(reviewSessionProvider)!
            .drafts
            .map((d) => d.counterparty),
        ['김밥천국 강남점', '택시'],
      );
      expect(_text(tester, 'review-title-0'), '김밥천국 강남점');
      // 펼쳐 둔 첫 건을 접으면 둘째 건이 보인다.
      await tester.tap(_key('review-edit-0'));
      await tester.pumpAndSettle();
      expect(_text(tester, 'review-title-1'), '택시');

      await _save(tester);
      final saved = await allTransactions(services);
      // 건마다 들어온 경로를 따로 적는다.
      expect(saved.map((t) => t.source), [TxSource.paste, TxSource.nl]);
      await disposeApp(tester, services);
    });
  });

  group('닫기', () {
    testWidgets('닫으려 하면 버릴지 묻는다', (tester) async {
      final services = await createTestServices();
      await pumpApp(tester, services, size: desktop);
      await sendFromComposer(tester, _twoSms);

      await tester.tap(_key('review-close'));
      await tester.pumpAndSettle();
      expect(find.text('검토하던 내용을 버릴까요?'), findsOneWidget);
      expect(find.text('저장하지 않은 초안 2건이 사라집니다.'), findsOneWidget);

      await tester.tap(_key('review-keep'));
      await tester.pumpAndSettle();
      expect(_key('review-0'), findsOneWidget);

      await tester.tap(_key('review-close'));
      await tester.pumpAndSettle();
      await tester.tap(_key('review-discard'));
      await tester.pumpAndSettle();

      expect(_key('review-0'), findsNothing);
      expect(_key('review-panel'), findsNothing);
      expect(containerOf(tester).read(reviewSessionProvider), isNull);
      expect(await allTransactions(services), isEmpty);
      await disposeApp(tester, services);
    });

    testWidgets('휴대폰: 버리면 검토함 화면을 닫고 돌아간다', (tester) async {
      final services = await createTestServices();
      await pumpApp(tester, services, size: phone);
      await sendFromComposer(tester, _cardSms);
      expect(find.byType(ReviewScreen), findsOneWidget);

      await tester.tap(_key('review-close'));
      await tester.pumpAndSettle();
      await tester.tap(_key('review-discard'));
      await tester.pumpAndSettle();

      expect(find.byType(ReviewScreen), findsNothing);
      expect(find.byKey(const ValueKey('nav-bottom')), findsOneWidget);
      expect(_key('composer-review-open'), findsNothing);
      await disposeApp(tester, services);
    });

    testWidgets('휴대폰: 뒤로 가도 검토하던 것은 남고, 입력창에서 다시 연다', (tester) async {
      final services = await createTestServices();
      await pumpApp(tester, services, size: phone);
      await sendFromComposer(tester, _twoSms);
      await tester.tap(_key('review-include-1'));
      await tester.pumpAndSettle();

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(ReviewScreen), findsNothing);
      expect(find.text('검토하던 2건이 남아 있습니다'), findsOneWidget);

      await tester.tap(_key('composer-review-open'));
      await tester.pumpAndSettle();
      expect(find.byType(ReviewScreen), findsOneWidget);
      expect(tester.widget<Checkbox>(_key('review-include-1')).value, isFalse);
      await disposeApp(tester, services);
    });

    testWidgets('검토할 것이 없이 주소로 들어오면 빈 상태를 보이고 돌아갈 수 있다', (tester) async {
      final services = await createTestServices();
      await pumpApp(tester, services, size: phone, location: '/review');

      expect(_key('review-empty'), findsOneWidget);
      expect(find.textContaining('검토할 내용이 없습니다'), findsOneWidget);
      await tester.tap(_key('review-back'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('nav-bottom')), findsOneWidget);
      await disposeApp(tester, services);
    });
  });

  group('세 배치에서 내용이 남는다', () {
    testWidgets('창 크기를 바꿔 옆 칸 · 겹친 칸 · 전체 화면을 오가도 고친 값이 남는다', (tester) async {
      final services = await createTestServices();
      await pumpApp(tester, services, size: desktop);

      await sendFromComposer(tester, _twoSms);
      // 둘째 건을 제외하고, 첫 건을 펼쳐 금액을 고친다.
      await tester.tap(_key('review-include-1'));
      await tester.pumpAndSettle();
      await tester.tap(_key('review-edit-0'));
      await tester.pumpAndSettle();
      await tester.enterText(_key('review-amount-0'), '13,000');
      await tester.pumpAndSettle();

      void expectKept() {
        expect(_key('review-0'), findsOneWidget);
        expect(_text(tester, 'review-amount-label-0'), '-13,000원');
        // 펼쳐 둔 편집 칸도 그대로다.
        expect(find.widgetWithText(TextField, '13,000'), findsOneWidget);
        final state = containerOf(tester).read(reviewSessionProvider)!;
        expect(state.drafts.map((d) => d.include), [true, false]);
        expect(state.expanded, 0);
        expect(find.text('모두 승인하고 저장 (1건)'), findsOneWidget);
      }

      // PC(1280): 내용 옆에 고정된 칸
      expect(_key('review-panel'), findsOneWidget);
      expect(tester.getSize(_key('review-panel')).width, 400);
      expectKept();

      // 태블릿(700): 내용 위에 겹친 칸
      tester.view.physicalSize = foldable;
      await tester.pumpAndSettle();
      expect(_key('review-panel'), findsOneWidget);
      expectKept();

      // 휴대폰(360): 뼈대에 칸이 없다. 입력창의 줄로 전체 화면을 연다.
      tester.view.physicalSize = phone;
      await tester.pumpAndSettle();
      expect(_key('review-panel'), findsNothing);
      expect(_key('review-0'), findsNothing);
      await tester.tap(_key('composer-review-open'));
      await tester.pumpAndSettle();
      expect(find.byType(ReviewScreen), findsOneWidget);
      expectKept();

      // 다시 넓히면 전체 화면이 물러나고 옆 칸에 한 번만 그려진다.
      tester.view.physicalSize = desktop;
      await tester.pumpAndSettle();
      expect(find.byType(ReviewScreen), findsNothing);
      expect(_key('review-panel'), findsOneWidget);
      expectKept();

      await _save(tester);
      final saved = await allTransactions(services);
      expect(saved.single.amount, 13000);
      await disposeApp(tester, services);
    });

    testWidgets('다른 탭에 다녀와도 검토 중인 내용이 남는다', (tester) async {
      final services = await createTestServices();
      await pumpApp(tester, services, size: desktop);
      await sendFromComposer(tester, _twoSms);
      await tester.tap(_key('review-include-1'));
      await tester.pumpAndSettle();

      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey('nav-side')),
          matching: find.text('통계'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('날짜별 지출'), findsOneWidget);
      expect(_key('review-0'), findsOneWidget);

      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey('nav-side')),
          matching: find.text('홈'),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.widget<Checkbox>(_key('review-include-1')).value, isFalse);
      await disposeApp(tester, services);
    });

    for (final (name, size) in [
      ('휴대폰', phone),
      ('큰 휴대폰', largePhone),
      ('태블릿', foldable),
      ('PC', desktop),
    ]) {
      testWidgets('$name: 글자를 200%로 키워도 넘치지 않는다', (tester) async {
        final services = await createTestServices();
        await pumpApp(tester, services, size: size, textScale: 2);

        await sendFromComposer(tester, '''
$_twoSms

우리 11/14 09:00 *123456 출금 1,250,000원 신한카드 잔액 2,000,000원

[롯데카드]11/16출금예정2,668,841원

오늘 저녁은 뭐 먹지''');
        expect(tester.takeException(), isNull);
        expect(_key('review-0'), findsOneWidget);

        // 편집 칸을 펼치고 이체로 바꿔 본다.
        await tester.tap(_key('review-edit-0'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(_key('review-type-transfer-0'));
        await tester.pumpAndSettle();
        await tester.tap(_key('review-type-transfer-0'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        // 접어 둔 칸까지 내려가 펼친다.
        await tester.scrollUntilVisible(
          _key('review-unknown'),
          300,
          scrollable: _reviewScrollable(),
        );
        await tester.ensureVisible(find.text('읽지 못한 내용 1건'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('읽지 못한 내용 1건'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        // 닫을 때의 물음도 넘치지 않는다.
        await confirmDiscardAndWait(tester);
        expect(tester.takeException(), isNull);
        await disposeApp(tester, services);
      });
    }
  });

  group('키보드', () {
    testWidgets('↑/↓로 옮기고 Space로 포함 · 제외, Enter로 펼치고, Delete로 제외한다', (
      tester,
    ) async {
      final services = await createTestServices();
      await pumpApp(tester, services, size: desktop);
      await sendFromComposer(tester, _twoSms);
      ReviewState state() => containerOf(tester).read(reviewSessionProvider)!;

      // 건을 누르면 검토함이 초점을 갖는다(누른 건은 펼쳐진다).
      await tester.tap(_key('review-row-0'));
      await tester.pumpAndSettle();
      expect(state().focused, 0);
      expect(state().expanded, 0);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(state().focused, 1);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(state().focused, 1, reason: '끝에서 멈춘다');

      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(state().drafts[1].include, isFalse);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(state().drafts[1].include, isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(state().expanded, 1);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.sendKeyEvent(LogicalKeyboardKey.delete);
      await tester.pumpAndSettle();
      expect(state().drafts[0].include, isFalse);

      // Esc는 닫기다. 버릴지 묻는다.
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('검토하던 내용을 버릴까요?'), findsOneWidget);
      await tester.tap(_key('review-keep'));
      await tester.pumpAndSettle();
      await disposeApp(tester, services);
    });

    testWidgets('Ctrl+Enter로 모두 승인하고 저장한다', (tester) async {
      final services = await createTestServices();
      await pumpApp(tester, services, size: desktop);
      await sendFromComposer(tester, _twoSms);

      await tester.tap(_key('review-row-0'));
      await tester.pumpAndSettle();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();

      expect(await allTransactions(services), hasLength(2));
      expect(find.text('2건을 저장했습니다'), findsOneWidget);
      await disposeApp(tester, services);
    });

    testWidgets('글 칸에서는 Space와 Delete가 글자 키다', (tester) async {
      final services = await createTestServices();
      await pumpApp(tester, services, size: desktop);
      await sendFromComposer(tester, _cardSms);

      await tester.tap(_key('review-party-0'));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.sendKeyEvent(LogicalKeyboardKey.delete);
      await tester.pumpAndSettle();

      final state = containerOf(tester).read(reviewSessionProvider)!;
      expect(state.drafts.single.include, isTrue);
      await disposeApp(tester, services);
    });
  });
}

/// 닫기를 눌러 물음을 띄웠다가 "계속 검토"로 돌아온다.
Future<void> confirmDiscardAndWait(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('review-close')));
  await tester.pumpAndSettle();
  expect(find.text('검토하던 내용을 버릴까요?'), findsOneWidget);
  await tester.tap(find.byKey(const ValueKey('review-keep')));
  await tester.pumpAndSettle();
}
