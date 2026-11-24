import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gagyebu/app/providers.dart';
import 'package:gagyebu/core/local_date.dart';
import 'package:gagyebu/data/db/database.dart';
import 'package:gagyebu/data/prefs/device_prefs.dart';
import 'package:gagyebu/data/repositories/ledger_repository.dart';
import 'package:gagyebu/domain/enums.dart';
import 'package:gagyebu/features/composer/composer_state.dart';
import 'package:gagyebu/features/onboarding/onboarding_card.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import 'test_app.dart';

/// 저장소 유지를 흉내 낸다.
class FakePersistence {
  FakePersistence({this.persisted = false, this.grant = true});

  bool persisted;

  /// 청하면 허락하는지.
  bool grant;
  int requests = 0;

  StoragePersistence get value => StoragePersistence(
    isPersisted: () async => persisted,
    request: () async {
      requests++;
      return persisted = grant;
    },
  );
}

void main() {
  late MemoryDevicePrefs prefs;

  setUp(() => prefs = MemoryDevicePrefs());

  /// 홈 화면처럼 목록 맨 위에 카드를 둔 작은 앱을 띄운다.
  Future<void> pumpCard(
    WidgetTester tester,
    AppServices services, {
    Size size = phone,
    double textScale = 1,
    bool forWeb = false,
    FakePersistence? persistence,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    Widget page(String text) => Scaffold(body: Center(child: Text(text)));
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(
            body: ListView(
              padding: const EdgeInsets.all(16),
              children: const [OnboardingCard(), Text('홈의 내용')],
            ),
          ),
        ),
        GoRoute(path: '/accounts', builder: (_, _) => page('자산 화면')),
        GoRoute(path: '/settings/models', builder: (_, _) => page('모델 화면')),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appServicesProvider.overrideWithValue(services),
          clockProvider.overrideWithValue(() => testNow),
          devicePrefsProvider.overrideWithValue(prefs),
          onboardingForWebProvider.overrideWithValue(forWeb),
          storagePersistenceProvider.overrideWithValue(
            (persistence ?? FakePersistence()).value,
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> addCard(AppServices services) => services.repository.addAccount(
    ledgerId: services.ledgerId,
    name: '신한카드',
    kind: AccountKind.creditCard,
  );

  Future<void> addLunch(AppServices services) async {
    final repo = services.repository;
    await repo.addTransaction(
      services.ledgerId,
      TransactionInput(
        type: TxType.expense,
        occurredOn: LocalDate(2026, 11, 16),
        amount: 8000,
        accountId: (await repo.accounts(services.ledgerId)).first.id,
        counterparty: '김밥천국',
      ),
    );
  }

  Future<void> addModel(AppServices services, {String status = 'ready'}) =>
      services.db
          .into(services.db.modelFiles)
          .insert(
            ModelFilesCompanion.insert(
              id: 'model-$status',
              kind: 'text',
              fileName: 'm.gguf',
              path: '/models/m.gguf',
              sizeBytes: 10,
              sha256: 'abc',
              status: status,
              updatedAt: testNow,
            ),
          );

  final card = find.byKey(const ValueKey('onboarding-card'));
  Finder done(String id) => find.byKey(ValueKey('onboarding-done-$id'));
  Finder todo(String id) => find.byKey(ValueKey('onboarding-todo-$id'));

  /// 클립보드에 [text]가 들어 있는 것처럼 한다.
  void mockClipboard(WidgetTester tester, String? text) {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async =>
          call.method == 'Clipboard.getData' ? {'text': text} : null,
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
  }

  testWidgets('처음에는 세 단계가 모두 남아 있다', (tester) async {
    final services = await createTestServices();
    await pumpCard(tester, services);

    expect(card, findsOneWidget);
    expect(find.text('자산 등록하기'), findsOneWidget);
    expect(find.text('결제 문자 붙여넣어 보기'), findsOneWidget);
    expect(find.text('AI 모델 내려받기'), findsOneWidget);
    expect(find.text('홈 화면에 추가하기'), findsNothing);
    for (final id in ['account', 'paste', 'model']) {
      expect(todo(id), findsOneWidget, reason: id);
      expect(done(id), findsNothing, reason: id);
    }
    // 현금은 처음부터 있다. 자산을 등록한 것으로 치지 않는다.
    expect(prefs.getString(onboardingDoneKey), isNull);
    await disposeApp(tester, services);
  });

  testWidgets('하나씩 끝내면 표시가 바뀌고, 다 끝내면 사라져 다시 보이지 않는다', (tester) async {
    final services = await createTestServices();
    await pumpCard(tester, services);

    await addCard(services);
    await tester.pumpAndSettle();
    expect(done('account'), findsOneWidget);
    expect(todo('paste'), findsOneWidget);
    expect(find.text('끝냈습니다'), findsOneWidget);

    await addLunch(services);
    await tester.pumpAndSettle();
    expect(done('paste'), findsOneWidget);
    expect(todo('model'), findsOneWidget);
    expect(card, findsOneWidget);

    // 받는 중인 모델은 끝낸 것이 아니다.
    await addModel(services, status: 'downloading');
    await tester.pumpAndSettle();
    expect(todo('model'), findsOneWidget);

    await addModel(services);
    await tester.pumpAndSettle();
    expect(card, findsNothing);
    expect(find.text('홈의 내용'), findsOneWidget);
    expect(prefs.getString(onboardingDoneKey), 'true');

    // 다시 띄워도, 모델을 지워도 보이지 않는다.
    await services.db.delete(services.db.modelFiles).go();
    await tester.pumpWidget(const SizedBox());
    await pumpCard(tester, services);
    expect(card, findsNothing);
    await disposeApp(tester, services);
  });

  testWidgets('닫기를 누르면 사라지고 다시 보이지 않는다', (tester) async {
    final services = await createTestServices();
    await pumpCard(tester, services);

    await tester.tap(find.byKey(const ValueKey('onboarding-close')));
    await tester.pumpAndSettle();
    expect(card, findsNothing);
    expect(prefs.getString(onboardingDoneKey), 'true');

    await tester.pumpWidget(const SizedBox());
    await pumpCard(tester, services);
    expect(card, findsNothing);
    await disposeApp(tester, services);
  });

  testWidgets('이미 쓰던 사람(끝냈다고 적혀 있음)에게는 보이지 않는다', (tester) async {
    await prefs.setString(onboardingDoneKey, 'true');
    final services = await createTestServices();
    await pumpCard(tester, services);
    expect(card, findsNothing);
    expect(find.text('홈의 내용'), findsOneWidget);
    await disposeApp(tester, services);
  });

  testWidgets('단계를 누르면 그 일을 하는 화면으로 간다', (tester) async {
    final services = await createTestServices();
    await pumpCard(tester, services);

    await tester.tap(find.byKey(const ValueKey('onboarding-step-account')));
    await tester.pumpAndSettle();
    expect(find.text('자산 화면'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await pumpCard(tester, services);
    await tester.tap(find.byKey(const ValueKey('onboarding-step-model')));
    await tester.pumpAndSettle();
    expect(find.text('모델 화면'), findsOneWidget);
    await disposeApp(tester, services);
  });

  testWidgets('붙여넣어 보기는 복사해 둔 글을 입력창에 채운다', (tester) async {
    final services = await createTestServices();
    mockClipboard(tester, ' [Web발신] 신한카드 승인 8,000원 김밥천국 ');
    await pumpCard(tester, services);
    final container = ProviderScope.containerOf(tester.element(card));
    // 입력창이 보고 있어야 올려 둔 글이 남는다.
    final watching = container.listen(incomingTextProvider, (_, _) {});
    addTearDown(watching.close);

    await tester.tap(find.byKey(const ValueKey('onboarding-step-paste')));
    await tester.pumpAndSettle();
    expect(container.read(incomingTextProvider), '[Web발신] 신한카드 승인 8,000원 김밥천국');
    expect(find.textContaining('입력창에 채웠습니다'), findsOneWidget);
    // 채우기만 한다. 저장한 것은 없다.
    expect(todo('paste'), findsOneWidget);
    await disposeApp(tester, services);
  });

  testWidgets('복사해 둔 글이 없으면 어떻게 하는지 알린다', (tester) async {
    final services = await createTestServices();
    mockClipboard(tester, null);
    await pumpCard(tester, services);
    final container = ProviderScope.containerOf(tester.element(card));

    await tester.tap(find.byKey(const ValueKey('onboarding-step-paste')));
    await tester.pumpAndSettle();
    expect(container.read(incomingTextProvider), isNull);
    expect(find.textContaining('복사해 둔 글이 없습니다'), findsOneWidget);
    await disposeApp(tester, services);
  });

  group('웹', () {
    testWidgets('모델 대신 홈 화면에 추가를 안내하고 저장소 유지를 청한다', (tester) async {
      final services = await createTestServices();
      final persistence = FakePersistence();
      await pumpCard(tester, services, forWeb: true, persistence: persistence);

      expect(find.text('홈 화면에 추가하기'), findsOneWidget);
      expect(find.text('AI 모델 내려받기'), findsNothing);
      expect(todo('install'), findsOneWidget);
      expect(persistence.requests, 0);

      await tester.tap(find.byKey(const ValueKey('onboarding-step-install')));
      await tester.pumpAndSettle();
      expect(persistence.requests, 1);
      expect(find.text('홈 화면에 추가'), findsOneWidget);
      expect(find.textContaining('iPhone · iPad(Safari)'), findsOneWidget);
      expect(find.text('이 브라우저가 가계부의 저장소를 지우지 않기로 했습니다.'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('onboarding-install-ok')));
      await tester.pumpAndSettle();
      expect(done('install'), findsOneWidget);
      expect(card, findsOneWidget);
      await disposeApp(tester, services);
    });

    testWidgets('브라우저가 허락하지 않아도 안내는 끝낸 것으로 친다', (tester) async {
      final services = await createTestServices();
      await pumpCard(
        tester,
        services,
        forWeb: true,
        persistence: FakePersistence(grant: false),
      );
      await tester.tap(find.byKey(const ValueKey('onboarding-step-install')));
      await tester.pumpAndSettle();
      expect(find.textContaining('아직 정하지 않았습니다'), findsOneWidget);
      expect(find.textContaining('로그인해 있으면 가계부를 다시 받습니다'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('onboarding-install-ok')));
      await tester.pumpAndSettle();
      expect(done('install'), findsOneWidget);
      await disposeApp(tester, services);
    });

    testWidgets('이미 저장소 유지를 허락받았으면 끝낸 것이다', (tester) async {
      final services = await createTestServices();
      await addCard(services);
      await addLunch(services);
      await pumpCard(
        tester,
        services,
        forWeb: true,
        persistence: FakePersistence(persisted: true),
      );
      // 세 단계가 모두 끝나 있으므로 바로 닫힌다.
      expect(card, findsNothing);
      expect(prefs.getString(onboardingDoneKey), 'true');
      await disposeApp(tester, services);
    });

    testWidgets('내려받은 모델이 있어도 웹의 단계와는 상관없다', (tester) async {
      final services = await createTestServices();
      await addCard(services);
      await addLunch(services);
      await addModel(services);
      await pumpCard(tester, services, forWeb: true);
      expect(card, findsOneWidget);
      expect(todo('install'), findsOneWidget);
      await disposeApp(tester, services);
    });
  });

  group('넘치지 않는다', () {
    for (final (name, size) in [
      ('소형 폰', phone),
      ('큰 폰', largePhone),
      ('폴더블', foldable),
      ('PC', desktop),
    ]) {
      for (final forWeb in [false, true]) {
        testWidgets('$name${forWeb ? '(웹)' : ''}', (tester) async {
          final services = await createTestServices();
          await addCard(services);
          await pumpCard(tester, services, size: size, forWeb: forWeb);
          expect(card, findsOneWidget);
          expect(tester.takeException(), isNull);
          if (forWeb) {
            await tester.tap(
              find.byKey(const ValueKey('onboarding-step-install')),
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
          }
          await disposeApp(tester, services);
        });
      }
    }

    testWidgets('소형 폰에서 글자를 200%로 키워도', (tester) async {
      final services = await createTestServices();
      await pumpCard(tester, services, textScale: 2, forWeb: true);
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(
        find.byKey(const ValueKey('onboarding-step-install')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('onboarding-step-install')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await disposeApp(tester, services);
    });
  });
}
