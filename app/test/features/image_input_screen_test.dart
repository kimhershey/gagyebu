import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gagyebu/ai/vision/vision_engine.dart';
import 'package:gagyebu/app/providers.dart';
import 'package:gagyebu/app/theme/tokens.dart';
import 'package:gagyebu/domain/enums.dart';
import 'package:gagyebu/features/image_input/dib.dart';
import 'package:gagyebu/features/image_input/image_input_available.dart';
import 'package:gagyebu/features/image_input/image_input_screen.dart';
import 'package:gagyebu/features/image_input/image_input_state.dart';
import 'package:gagyebu/features/image_input/image_intake.dart';
import 'package:gagyebu/features/review/review_panel.dart';
import 'package:gagyebu/features/review/review_state.dart';
import 'package:material_ui/material_ui.dart';

import 'composer_support.dart';
import 'image_input_support.dart';
import 'test_app.dart';

Finder _key(String key) => find.byKey(ValueKey(key));

Future<void> _open(
  WidgetTester tester,
  AppServices services, {
  required VisionEngine? engine,
  required ImageIntake intake,
  Size size = desktop,
}) => pumpAppWith(
  tester,
  services,
  size: size,
  location: '/image-input',
  overrides: [
    visionEngineProvider.overrideWithValue(engine),
    imageIntakeProvider.overrideWithValue(intake),
  ],
);

ImageInputState _state(WidgetTester tester) =>
    containerOf(tester).read(imageInputControllerProvider);

/// 좁은 창에서는 줄이 굴러 내려가 있다. 보이게 당긴다.
Future<void> _reveal(
  WidgetTester tester,
  String key, {
  String within = 'image-result',
}) async {
  await tester.scrollUntilVisible(
    _key(key),
    80,
    scrollable: find
        .descendant(of: _key(within), matching: find.byType(Scrollable))
        .first,
  );
  await tester.pump();
}

/// 첫 장에서 예외를 던지는 가짜 이미지 모델.
class _FailingOnceEngine extends FakeVisionEngine {
  _FailingOnceEngine() : super([consistentStatement, consistentStatement]);

  @override
  Future<String> generateJsonFromImage({
    required Uint8List image,
    required String system,
    required String user,
    required Map<String, Object?> schema,
    String? grammar,
    int maxTokens = 1024,
  }) {
    if (calls == 0) {
      images.add(image);
      throw StateError('모델이 죽었다');
    }
    return super.generateJsonFromImage(
      image: image,
      system: system,
      user: user,
      schema: schema,
      grammar: grammar,
      maxTokens: maxTokens,
    );
  }
}

void main() {
  group('쓸 수 있는지', () {
    test('Windows이고 이미지 모델이 있을 때만 쓸 수 있다', () {
      bool available(TargetPlatform platform, VisionEngine? engine) {
        debugDefaultTargetPlatformOverride = platform;
        final container = ProviderContainer(
          overrides: [visionEngineProvider.overrideWithValue(engine)],
        );
        try {
          return container.read(imageInputAvailableProvider);
        } finally {
          container.dispose();
          debugDefaultTargetPlatformOverride = null;
        }
      }

      final engine = FakeVisionEngine([]);
      expect(available(TargetPlatform.windows, engine), isTrue);
      expect(available(TargetPlatform.windows, null), isFalse);
      expect(available(TargetPlatform.android, engine), isFalse);
      expect(available(TargetPlatform.linux, engine), isFalse);
    });
  });

  group('엔진이 없을 때', () {
    testWidgets('모델이 없다고 알리고 AI 모델 설정으로 보낸다', (tester) async {
      final services = await createTestServices();
      await _open(tester, services, engine: null, intake: FakeImageIntake());

      expect(find.textContaining('이미지 모델이 없습니다'), findsOneWidget);
      expect(find.textContaining('설정 → AI 모델에서 내려받을 수 있습니다'), findsOneWidget);
      // 이미지를 넣는 단추는 보이지 않는다.
      expect(_key('image-pick'), findsNothing);

      await tester.tap(_key('image-go-models'));
      await tester.pumpAndSettle();
      expect(find.byType(ImageInputScreen), findsNothing);
      expect(tester.takeException(), isNull);
      await disposeApp(tester, services);
    });
  });

  group('추출 → 검산 → 검토함', () {
    testWidgets('잔액이 이어지는 거래내역을 읽어 검토함으로 보낸다', (tester) async {
      final services = await createTestServices();
      final engine = FakeVisionEngine([consistentStatement]);
      await _open(
        tester,
        services,
        engine: engine,
        intake: FakeImageIntake(files: [picked('내역.png')]),
      );
      expect(_key('image-empty'), findsOneWidget);
      expect(_key('image-send'), findsNothing);

      await tester.tap(_key('image-pick'));
      await tester.pumpAndSettle();

      // 엔진은 넣은 바이트를 그대로 받는다.
      expect(engine.images.single, tinyPng);
      expect(find.text('끝남 · 3건'), findsOneWidget);
      expect(_key('image-original-0'), findsOneWidget);
      expect(
        tester.widget<Text>(_key('image-page-summary')).data,
        '거래내역 화면 · 3건 · 검산 맞음 2건',
      );
      expect(_key('image-row-verified-0'), findsOneWidget);
      expect(_key('image-row-verified-1'), findsOneWidget);
      expect(_key('image-row-flag-0'), findsNothing);
      expect(
        tester.widget<Text>(_key('image-row-amount-text-0')).data,
        '-15,000원',
      );
      expect(
        tester.widget<Text>(_key('image-row-amount-text-1')).data,
        '+500,000원',
      );
      expect(tester.widget<Text>(_key('image-send-summary')).data, '3건 포함');

      // 한 줄을 빼고 보낸다.
      await tester.tap(_key('image-row-include-2'));
      await tester.pump();
      expect(tester.widget<Text>(_key('image-send-summary')).data, '2건 포함');
      await tester.tap(_key('image-send'));
      await tester.pumpAndSettle();

      // 화면은 닫히고, 초안은 출처가 이미지인 채로 검토함에 올라간다.
      expect(find.byType(ImageInputScreen), findsNothing);
      final review = containerOf(tester).read(reviewSessionProvider)!;
      expect(review.drafts, hasLength(2));
      expect(review.drafts.every((d) => d.source == TxSource.image), isTrue);
      expect(review.drafts[0].amount, 15000);
      expect(review.drafts[0].type, TxType.expense);
      expect(review.drafts[0].counterparty, '한빛서점');
      expect(review.drafts[0].parsed.balanceAfter, 985000);
      expect(review.drafts[0].parsed.ruleId, 'vlm:fake-vlm');
      expect(review.drafts[1].type, TxType.income);
      expect(review.drafts[1].amount, 500000);
      // 넓은 창에서는 뼈대의 옆 칸에 검토함이 뜬다.
      expect(find.byType(ReviewPanel), findsOneWidget);
      expect(tester.takeException(), isNull);
      await disposeApp(tester, services);
    });

    testWidgets('한 줄이 틀리면 그 줄만 확인 필요로 두고, 풀기 전에는 보내지 않는다', (tester) async {
      final services = await createTestServices();
      await _open(
        tester,
        services,
        engine: FakeVisionEngine([brokenStatement]),
        intake: FakeImageIntake(files: [picked('내역.png')]),
      );
      await tester.tap(_key('image-pick'));
      await tester.pumpAndSettle();

      expect(find.text('끝남 · 확인 필요 1건'), findsOneWidget);
      expect(_key('image-row-flag-1'), findsOneWidget);
      expect(_key('image-row-flag-0'), findsNothing);
      expect(_key('image-row-flag-2'), findsNothing);
      expect(
        tester.widget<Text>(_key('image-row-issue-1')).data,
        contains('잔액이 이어지지 않습니다'),
      );
      expect(
        tester.widget<Text>(_key('image-row-issue-1')).data,
        contains('1,100,000원'),
      );
      // 경고색으로 표시한다.
      final tokens = tester.element(_key('image-row-1')).tokens;
      expect(
        tester.widget<Material>(_key('image-row-1')).color,
        tokens.warnSoft,
      );
      expect(tester.widget<Icon>(_key('image-row-flag-1')).color, tokens.warn);
      expect(
        tester.widget<Material>(_key('image-row-0')).color,
        isNot(tokens.warnSoft),
      );
      expect(tester.widget<FilledButton>(_key('image-send')).onPressed, isNull);
      expect(
        tester.widget<Text>(_key('image-send-summary')).data,
        contains('확인 필요 1건'),
      );

      // 금액을 원본대로 고치면 검산이 맞아 표시가 풀린다.
      await tester.tap(_key('image-row-edit-1'));
      await tester.pump();
      await tester.enterText(_key('image-row-amount-1'), '500000');
      await tester.pump();
      expect(_key('image-row-flag-1'), findsNothing);
      expect(_key('image-row-verified-1'), findsOneWidget);
      expect(
        tester.widget<FilledButton>(_key('image-send')).onPressed,
        isNotNull,
      );

      await tester.tap(_key('image-send'));
      await tester.pumpAndSettle();
      final review = containerOf(tester).read(reviewSessionProvider)!;
      expect(review.drafts, hasLength(4));
      expect(review.drafts[1].amount, 500000);
      await disposeApp(tester, services);
    });

    testWidgets('방향 · 상대방 · 날짜를 고치고, 뺀 줄의 경고는 세지 않는다', (tester) async {
      final services = await createTestServices();
      await _open(
        tester,
        services,
        engine: FakeVisionEngine([brokenStatement]),
        intake: FakeImageIntake(files: [picked('내역.png')]),
      );
      await tester.tap(_key('image-pick'));
      await tester.pumpAndSettle();

      // 확인 필요한 줄을 빼면 보낼 수 있다.
      await tester.tap(_key('image-row-include-1'));
      await tester.pump();
      expect(_key('image-row-flag-1'), findsNothing);
      expect(
        tester.widget<FilledButton>(_key('image-send')).onPressed,
        isNotNull,
      );

      await tester.tap(_key('image-row-edit-0'));
      await tester.pump();
      await tester.enterText(_key('image-row-who-0'), '한빛문고');
      await tester.tap(_key('image-row-in-0'));
      await tester.pump();
      await tester.tap(_key('image-row-date-0'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('10').last);
      await tester.tap(find.text('확인'));
      await tester.pumpAndSettle();

      final row = _state(tester).pages.single.rows[0];
      expect(row.counterparty, '한빛문고');
      expect(row.date.toString(), '2026-11-10');
      expect(
        tester.widget<Text>(_key('image-row-amount-text-0')).data,
        '+15,000원',
      );
      // 방향을 바꿨더니 잔액과 맞지 않게 됐다.
      expect(_key('image-row-flag-0'), findsOneWidget);
      // 원본과 견주어 맞으면 "맞음"으로 푼다.
      await tester.tap(_key('image-row-confirm-0'));
      await tester.pump();
      expect(_key('image-row-flag-0'), findsNothing);
      expect(tester.takeException(), isNull);
      await disposeApp(tester, services);
    });

    testWidgets('영수증은 한 건으로 만들고, 합이 총액과 다르면 확인을 청한다', (tester) async {
      final services = await createTestServices();
      await _open(
        tester,
        services,
        engine: FakeVisionEngine([mismatchedReceipt]),
        intake: FakeImageIntake(files: [picked('영수증.jpg')]),
      );
      await tester.tap(_key('image-pick'));
      await tester.pumpAndSettle();

      expect(
        tester.widget<Text>(_key('image-page-summary')).data,
        '영수증 · 1건 · 확인 필요 1건',
      );
      expect(_key('image-receipt-items'), findsOneWidget);
      expect(find.textContaining('품목 2줄 · 합 9,500원'), findsOneWidget);
      expect(
        tester.widget<Text>(_key('image-row-issue-0')).data,
        contains('품목의 합(9,500원)이 금액(8,500원)과 다릅니다'),
      );
      expect(tester.widget<FilledButton>(_key('image-send')).onPressed, isNull);

      await tester.tap(_key('image-row-confirm-0'));
      await tester.pump();
      await tester.tap(_key('image-send'));
      await tester.pumpAndSettle();

      final draft = containerOf(tester).read(reviewSessionProvider)!.drafts;
      expect(draft, hasLength(1));
      expect(draft.single.source, TxSource.image);
      expect(draft.single.amount, 8500);
      expect(draft.single.counterparty, '새봄커피');
      expect(draft.single.memo, '아메리카노 외 1건');
      await disposeApp(tester, services);
    });

    testWidgets('좁은 창에서는 보낸 뒤 검토함 화면을 연다', (tester) async {
      final services = await createTestServices();
      await _open(
        tester,
        services,
        engine: FakeVisionEngine([consistentStatement]),
        intake: FakeImageIntake(files: [picked('내역.png')]),
        size: phone,
      );
      await tester.tap(_key('image-pick'));
      await tester.pumpAndSettle();
      await tester.tap(_key('image-send'));
      await tester.pumpAndSettle();

      expect(find.byType(ImageInputScreen), findsNothing);
      expect(find.byType(ReviewScreen), findsOneWidget);
      expect(
        containerOf(tester).read(reviewSessionProvider)!.drafts,
        hasLength(3),
      );
      expect(tester.takeException(), isNull);
      await disposeApp(tester, services);
    });
  });

  group('읽지 못한 이미지', () {
    testWidgets('JSON이 깨지면 한 번 다시 부른다', (tester) async {
      final services = await createTestServices();
      final engine = FakeVisionEngine([
        '{"kind":"statement","rows":[{"d":"11.1',
        consistentStatement,
      ]);
      await _open(
        tester,
        services,
        engine: engine,
        intake: FakeImageIntake(files: [picked('내역.png')]),
      );
      await tester.tap(_key('image-pick'));
      await tester.pumpAndSettle();

      expect(engine.calls, 2);
      expect(find.text('끝남 · 3건'), findsOneWidget);
      await disposeApp(tester, services);
    });

    testWidgets('두 번 모두 깨지면 읽지 못함이고, 다시 읽을 수 있다', (tester) async {
      final services = await createTestServices();
      final engine = FakeVisionEngine(['앗', '{', consistentStatement]);
      await _open(
        tester,
        services,
        engine: engine,
        intake: FakeImageIntake(files: [picked('내역.png')]),
      );
      await tester.tap(_key('image-pick'));
      await tester.pumpAndSettle();

      expect(engine.calls, 2);
      expect(find.text('읽지 못함'), findsOneWidget);
      expect(_key('image-page-failed'), findsOneWidget);
      expect(tester.widget<FilledButton>(_key('image-send')).onPressed, isNull);

      await tester.tap(_key('image-retry'));
      await tester.pumpAndSettle();
      expect(engine.calls, 3);
      expect(find.text('끝남 · 3건'), findsOneWidget);
      await disposeApp(tester, services);
    });

    testWidgets('거래가 없는 이미지는 그렇게 알린다', (tester) async {
      final services = await createTestServices();
      await _open(
        tester,
        services,
        engine: FakeVisionEngine([
          {'kind': 'other', 'shop': null, 'rows': <Object?>[], 'total': null},
        ]),
        intake: FakeImageIntake(files: [picked('풍경.png')]),
      );
      await tester.tap(_key('image-pick'));
      await tester.pumpAndSettle();

      expect(find.text('끝남 · 거래 없음'), findsOneWidget);
      expect(_key('image-page-empty'), findsOneWidget);
      expect(tester.widget<FilledButton>(_key('image-send')).onPressed, isNull);
      await disposeApp(tester, services);
    });

    testWidgets('이미지가 아닌 파일은 넣지 않고 알린다', (tester) async {
      final services = await createTestServices();
      final engine = FakeVisionEngine([consistentStatement]);
      await _open(
        tester,
        services,
        engine: engine,
        intake: FakeImageIntake(
          files: [
            PickedImage(
              name: '메모.txt',
              bytes: Uint8List.fromList('안녕하세요'.codeUnits),
            ),
          ],
        ),
      );
      await tester.tap(_key('image-pick'));
      await tester.pumpAndSettle();

      expect(engine.calls, 0);
      expect(_state(tester).pages, isEmpty);
      expect(
        tester.widget<Text>(_key('image-notice')).data,
        '이미지가 아닌 파일 1개는 넣지 않았습니다.',
      );
      await disposeApp(tester, services);
    });
  });

  group('대기열', () {
    testWidgets('여러 장을 한 장씩 읽고, 그만과 이어서 읽기가 된다', (tester) async {
      final services = await createTestServices();
      final engine = HeldVisionEngine();
      await _open(
        tester,
        services,
        engine: engine,
        intake: FakeImageIntake(
          files: [picked('1.png'), picked('2.png'), picked('3.png')],
        ),
      );
      await tester.tap(_key('image-pick'));
      await tester.pump();
      await tester.pump();

      // 한 번에 한 장만 엔진에 넘긴다.
      expect(engine.calls, hasLength(1));
      String status(int id) =>
          tester.widget<Text>(_key('image-page-status-$id')).data!;
      expect(status(0), '읽는 중');
      expect(status(1), '기다림');
      expect(status(2), '기다림');
      expect(tester.widget<Text>(_key('image-progress')).data, '읽는 중 · 1/3');
      expect(_key('image-page-reading'), findsOneWidget);
      // 읽는 동안에는 보내지 못한다.
      expect(tester.widget<FilledButton>(_key('image-send')).onPressed, isNull);

      engine.calls[0].complete(
        '{"kind":"statement","shop":null,"rows":[{"d":"11.15","t":null,'
        '"a":"3,000","io":"out","who":"첫 장","bal":null}],"total":null}',
      );
      await tester.pump();
      await tester.pump();
      expect(status(0), '끝남 · 1건');
      expect(status(1), '읽는 중');
      expect(engine.calls, hasLength(2));
      expect(tester.widget<Text>(_key('image-progress')).data, '읽는 중 · 2/3');
      // 견줄 잔액이 없으면 검산하지 못했다고 알린다.
      expect(_key('image-page-unchecked'), findsOneWidget);

      // 그만: 읽던 장은 기다림으로 돌아가고 더 넘기지 않는다.
      await tester.tap(_key('image-stop'));
      await tester.pump();
      expect(status(1), '기다림');
      expect(tester.widget<Text>(_key('image-progress')).data, '멈춤 · 2장 남음');
      // 멈춘 뒤에는 읽은 것만 보낼 수 있다.
      expect(
        tester.widget<FilledButton>(_key('image-send')).onPressed,
        isNotNull,
      );
      expect(
        tester.widget<Text>(_key('image-send-summary')).data,
        contains('읽지 않은 이미지 2장'),
      );

      // 멈춘 사이에 온 답은 버린다.
      engine.calls[1].complete(
        '{"kind":"statement","shop":null,"rows":[{"d":"11.15","t":null,'
        '"a":"9,999","io":"out","who":"버릴 답","bal":null}],"total":null}',
      );
      await tester.pump();
      await tester.pump();
      expect(status(1), '기다림');
      expect(engine.calls, hasLength(2));

      // 이어서 읽기: 둘째 장부터 다시 읽는다.
      await tester.tap(_key('image-resume'));
      await tester.pump();
      await tester.pump();
      expect(status(1), '읽는 중');
      expect(engine.calls, hasLength(3));

      // 기다리는 장을 뺀다.
      await tester.tap(_key('image-page-remove-2'));
      await tester.pump();
      expect(_key('image-page-2'), findsNothing);
      expect(_state(tester).pages, hasLength(2));

      engine.calls[2].complete(
        '{"kind":"statement","shop":null,"rows":[{"d":"11.14","t":null,'
        '"a":"4,000","io":"out","who":"둘째 장","bal":null}],"total":null}',
      );
      await tester.pumpAndSettle();
      expect(status(1), '끝남 · 1건');
      expect(_key('image-progress'), findsNothing);

      // 장을 누르면 그 장의 줄을 본다.
      expect(find.text('첫 장'), findsOneWidget);
      await tester.tap(_key('image-page-1'));
      await tester.pump();
      expect(find.text('둘째 장'), findsOneWidget);
      expect(find.text('첫 장'), findsNothing);

      // 두 장의 줄을 함께 보낸다.
      await tester.tap(_key('image-send'));
      await tester.pumpAndSettle();
      final drafts = containerOf(tester).read(reviewSessionProvider)!.drafts;
      expect([for (final d in drafts) d.counterparty], ['첫 장', '둘째 장']);
      expect(tester.takeException(), isNull);
      await disposeApp(tester, services);
    });

    testWidgets('그만둔 장을 엔진이 아직 읽고 있으면 이어서 읽을 때 그 답을 받는다', (tester) async {
      final services = await createTestServices();
      final engine = HeldVisionEngine();
      await _open(
        tester,
        services,
        engine: engine,
        intake: FakeImageIntake(files: [picked('1.png')]),
      );
      await tester.tap(_key('image-pick'));
      await tester.pump();
      await tester.pump();
      await tester.tap(_key('image-stop'));
      await tester.pump();
      await tester.tap(_key('image-resume'));
      await tester.pump();
      expect(find.text('읽는 중'), findsOneWidget);
      // 엔진을 한 번 더 부르지 않는다.
      expect(engine.calls, hasLength(1));

      engine.calls[0].complete(
        '{"kind":"statement","shop":null,"rows":[{"d":"11.15","t":null,'
        '"a":"3,000","io":"out","who":"첫 장","bal":null}],"total":null}',
      );
      await tester.pumpAndSettle();
      expect(find.text('끝남 · 1건'), findsOneWidget);
      expect(engine.calls, hasLength(1));
      await disposeApp(tester, services);
    });

    testWidgets('Ctrl+V로 클립보드의 이미지를 넣는다', (tester) async {
      final services = await createTestServices();
      final engine = FakeVisionEngine([consistentStatement]);
      final intake = FakeImageIntake();
      await _open(tester, services, engine: engine, intake: intake);

      Future<void> pressPaste() async {
        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyV);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        await tester.pumpAndSettle();
      }

      // 클립보드에 이미지가 없으면 알린다.
      await pressPaste();
      expect(
        tester.widget<Text>(_key('image-notice')).data,
        '클립보드에 이미지가 없습니다.',
      );
      expect(engine.calls, 0);

      intake.clipboard = picked('붙여넣은 이미지');
      await pressPaste();
      expect(engine.calls, 1);
      expect(find.text('1. 붙여넣은 이미지'), findsOneWidget);
      expect(_key('image-notice'), findsNothing);

      // 글 칸에서 누른 Ctrl+V는 글 붙여넣기다. 이미지를 넣지 않는다.
      await tester.tap(_key('image-row-edit-0'));
      await tester.pump();
      await tester.tap(_key('image-row-who-0'));
      await tester.pump();
      await pressPaste();
      expect(_state(tester).pages, hasLength(1));

      // 단추로도 넣는다.
      await tester.tap(_key('image-paste'));
      await tester.pump();
      await tester.pump();
      expect(_state(tester).pages, hasLength(2));
      await disposeApp(tester, services);
    });

    testWidgets('클립보드를 읽을 수 없는 기기에서는 붙여넣기 단추를 숨긴다', (tester) async {
      final services = await createTestServices();
      await _open(
        tester,
        services,
        engine: FakeVisionEngine([]),
        intake: FakeImageIntake(canReadClipboard: false),
      );
      expect(_key('image-pick'), findsOneWidget);
      expect(_key('image-paste'), findsNothing);
      await disposeApp(tester, services);
    });

    testWidgets('닫으려 하면 넣어 둔 이미지를 버릴지 묻는다', (tester) async {
      final services = await createTestServices();
      await _open(
        tester,
        services,
        engine: FakeVisionEngine([consistentStatement]),
        intake: FakeImageIntake(files: [picked('내역.png')]),
      );
      await tester.tap(_key('image-pick'));
      await tester.pumpAndSettle();

      await tester.tap(_key('image-close'));
      await tester.pumpAndSettle();
      await tester.tap(_key('image-close-cancel'));
      await tester.pumpAndSettle();
      expect(find.byType(ImageInputScreen), findsOneWidget);
      expect(_state(tester).pages, hasLength(1));

      await tester.tap(_key('image-close'));
      await tester.pumpAndSettle();
      await tester.tap(_key('image-close-confirm'));
      await tester.pumpAndSettle();
      expect(find.byType(ImageInputScreen), findsNothing);
      // 검토함에는 아무것도 올라가지 않았다.
      expect(containerOf(tester).read(reviewSessionProvider), isNull);
      await disposeApp(tester, services);
    });
  });

  group('입력창에서 열었을 때', () {
    Future<void> openFromComposer(
      WidgetTester tester,
      AppServices services,
      Size size,
    ) async {
      await pumpAppWith(
        tester,
        services,
        size: size,
        overrides: [
          visionEngineProvider.overrideWithValue(
            FakeVisionEngine([consistentStatement]),
          ),
          imageIntakeProvider.overrideWithValue(
            FakeImageIntake(files: [picked('내역.png')]),
          ),
          // 시험은 Windows에서 돌지 않는다. 이미지 단추가 보이게 덮어쓴다.
          imageInputAvailableProvider.overrideWithValue(true),
        ],
      );
      await tester.tap(_key('composer-image'));
      await tester.pumpAndSettle();
      expect(find.byType(ImageInputScreen), findsOneWidget);
      await tester.tap(_key('image-pick'));
      await tester.pumpAndSettle();
    }

    testWidgets('넓은 창: 보내면 닫히고 옆 칸에 검토함이 뜬다', (tester) async {
      final services = await createTestServices();
      await openFromComposer(tester, services, desktop);
      await tester.tap(_key('image-send'));
      await tester.pumpAndSettle();

      expect(find.byType(ImageInputScreen), findsNothing);
      expect(find.byType(ReviewPanel), findsOneWidget);
      expect(find.byType(ReviewScreen), findsNothing);
      expect(
        containerOf(tester).read(reviewSessionProvider)!.drafts,
        hasLength(3),
      );
      expect(tester.takeException(), isNull);
      await disposeApp(tester, services);
    });

    testWidgets('좁은 창: 보내면 닫히고 검토함 화면이 열린다', (tester) async {
      final services = await createTestServices();
      await openFromComposer(tester, services, phone);
      await tester.tap(_key('image-send'));
      await tester.pumpAndSettle();

      expect(find.byType(ImageInputScreen), findsNothing);
      expect(find.byType(ReviewScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
      await disposeApp(tester, services);
    });

    testWidgets('뒤로 가기도 버릴지 묻고, 버리면 이미지를 메모리에서 내린다', (tester) async {
      final services = await createTestServices();
      await openFromComposer(tester, services, desktop);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('이미지 입력을 닫을까요?'), findsOneWidget);
      await tester.tap(_key('image-close-confirm'));
      await tester.pumpAndSettle();
      expect(find.byType(ImageInputScreen), findsNothing);

      // 화면을 떠나면 상태가 버려진다. 다시 열면 비어 있다.
      await tester.tap(_key('composer-image'));
      await tester.pumpAndSettle();
      expect(_state(tester).pages, isEmpty);
      expect(_key('image-empty'), findsOneWidget);
      await disposeApp(tester, services);
    });
  });

  group('대기열의 한도와 엔진 실패', () {
    testWidgets('엔진이 실패하면 읽지 못함으로 두고 다음 장을 읽는다', (tester) async {
      final services = await createTestServices();
      final engine = _FailingOnceEngine();
      await _open(
        tester,
        services,
        engine: engine,
        intake: FakeImageIntake(files: [picked('1.png'), picked('2.png')]),
      );
      await tester.tap(_key('image-pick'));
      await tester.pumpAndSettle();

      expect(_state(tester).pages.map((p) => p.status), [
        PageStatus.failed,
        PageStatus.done,
      ]);
      // 예외 문구를 그대로 보이지 않는다.
      expect(find.textContaining('모델이 죽었다'), findsNothing);
      expect(_key('image-page-failed'), findsOneWidget);
      await disposeApp(tester, services);
    });

    testWidgets('너무 큰 이미지와 한도를 넘는 장은 넣지 않는다', (tester) async {
      final services = await createTestServices();
      final huge = Uint8List(maxImageBytes + 1)
        ..setRange(0, tinyPng.length, tinyPng);
      await _open(
        tester,
        services,
        engine: HeldVisionEngine(),
        intake: FakeImageIntake(
          files: [
            PickedImage(name: '큰 사진.png', bytes: huge),
            for (var i = 0; i < maxQueuedImages + 2; i++) picked('$i.png'),
          ],
        ),
      );
      await tester.tap(_key('image-pick'));
      await tester.pump();
      await tester.pump();

      expect(_state(tester).pages, hasLength(maxQueuedImages));
      final notice = tester.widget<Text>(_key('image-notice')).data!;
      expect(notice, contains('20MB를 넘는 이미지 1장'));
      expect(notice, contains('2장은 넣지 않았습니다'));
      await disposeApp(tester, services);
    });
  });

  group('네 화면 크기', () {
    for (final (name, size) in [
      ('휴대폰', phone),
      ('큰 휴대폰', largePhone),
      ('폴더블', foldable),
      ('데스크톱', desktop),
    ]) {
      testWidgets('$name: 모델이 없을 때와 빈 대기열이 넘치지 않는다', (tester) async {
        final services = await createTestServices();
        await _open(
          tester,
          services,
          engine: null,
          intake: FakeImageIntake(),
          size: size,
        );
        expect(tester.takeException(), isNull);
        await disposeApp(tester, services);

        final again = await createTestServices();
        await _open(
          tester,
          again,
          engine: FakeVisionEngine([]),
          intake: FakeImageIntake(),
          size: size,
        );
        expect(_key('image-empty'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await disposeApp(tester, again);
      });

      testWidgets('$name: 읽은 줄과 고치는 칸, 영수증, 읽지 못함이 넘치지 않는다', (tester) async {
        final services = await createTestServices();
        final longRows = statementAnswer([
          for (var i = 0; i < 12; i++)
            visionRow(
              a: i == 3 ? '1,234,567,890' : '${i + 1},000',
              io: i.isEven ? 'out' : 'in',
              who: '이름이 아주 길어서 한 줄에 다 들어가지 않는 가맹점 $i호점',
              bal: '${900 + i},000',
            ),
        ]);
        await _open(
          tester,
          services,
          engine: FakeVisionEngine([longRows, mismatchedReceipt, '앗', '앗']),
          intake: FakeImageIntake(
            files: [
              picked('아주 긴 이름의 거래내역 화면 캡처 파일.png'),
              picked('영수증.jpg'),
              picked('흐린 사진.jpg'),
            ],
          ),
          size: size,
        );
        await tester.tap(_key('image-pick'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(_state(tester).pages.map((p) => p.status), [
          PageStatus.done,
          PageStatus.done,
          PageStatus.failed,
        ]);

        // 창이 840 미만이면 원본과 줄을 위아래로 쌓는다.
        final original = tester.getRect(_key('image-original-0'));
        final firstRow = tester.getRect(_key('image-row-0'));
        if (size.width >= 840) {
          expect(original.right, lessThanOrEqualTo(firstRow.left));
        } else {
          expect(original.bottom, lessThanOrEqualTo(firstRow.top));
        }

        // 확인 필요한 줄의 고치는 칸을 편다.
        await _reveal(tester, 'image-row-edit-3');
        await tester.tap(_key('image-row-edit-3'));
        await tester.pumpAndSettle();
        expect(_key('image-row-amount-3'), findsOneWidget);
        expect(tester.takeException(), isNull);

        await tester.tap(_key('image-page-1'));
        await tester.pumpAndSettle();
        expect(_key('image-row-issue-0'), findsOneWidget);
        expect(tester.takeException(), isNull);

        // 좁은 창에서는 대기열도 옆으로 굴린다.
        await _reveal(tester, 'image-page-remove-2', within: 'image-queue');
        await tester.tap(_key('image-page-2'));
        await tester.pumpAndSettle();
        expect(_key('image-page-failed'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await disposeApp(tester, services);
      });
    }
  });

  group('클립보드의 그림', () {
    /// 2×2, 24비트 DIB(머리 40바이트 + 줄마다 8바이트).
    Uint8List dib24() {
      final bytes = Uint8List(40 + 16);
      ByteData.sublistView(bytes)
        ..setUint32(0, 40, Endian.little)
        ..setInt32(4, 2, Endian.little)
        ..setInt32(8, 2, Endian.little)
        ..setUint16(12, 1, Endian.little)
        ..setUint16(14, 24, Endian.little)
        ..setUint32(20, 16, Endian.little);
      for (var i = 40; i < bytes.length; i++) {
        bytes[i] = 0x80;
      }
      return bytes;
    }

    test('DIB 앞에 파일 머리를 붙여 BMP로 만든다', () {
      final bmp = dibToBmp(dib24())!;
      final data = ByteData.sublistView(bmp);
      expect(String.fromCharCodes(bmp.sublist(0, 2)), 'BM');
      expect(data.getUint32(2, Endian.little), 14 + 56);
      expect(data.getUint32(10, Endian.little), 14 + 40);
      expect(sniffImageFormat(bmp), 'bmp');

      // 색 가리개가 머리 뒤에 붙는 32비트 그림(화면 캡처에 흔하다).
      final masked = Uint8List(40 + 12 + 16);
      ByteData.sublistView(masked)
        ..setUint32(0, 40, Endian.little)
        ..setUint16(14, 32, Endian.little)
        ..setUint32(16, 3, Endian.little);
      expect(
        ByteData.sublistView(dibToBmp(masked)!).getUint32(10, Endian.little),
        14 + 40 + 12,
      );

      // 색상표가 있는 8비트 그림.
      final indexed = Uint8List(40 + 256 * 4 + 4);
      ByteData.sublistView(indexed)
        ..setUint32(0, 40, Endian.little)
        ..setUint16(14, 8, Endian.little);
      expect(
        ByteData.sublistView(dibToBmp(indexed)!).getUint32(10, Endian.little),
        14 + 40 + 1024,
      );

      expect(dibToBmp(Uint8List(10)), isNull);
      expect(dibToBmp(Uint8List(64)), isNull);
    });

    testWidgets('만든 BMP를 Flutter가 그림으로 읽는다', (tester) async {
      final bmp = dibToBmp(dib24())!;
      final image = await tester.runAsync(() async {
        final codec = await ui.instantiateImageCodec(bmp);
        return (await codec.getNextFrame()).image;
      });
      expect(image!.width, 2);
      expect(image.height, 2);
    });

    test('바이트의 머리로 이미지인지 가린다', () {
      expect(sniffImageFormat(tinyPng), 'png');
      expect(
        sniffImageFormat(Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0])),
        'jpeg',
      );
      expect(
        sniffImageFormat(Uint8List.fromList('RIFF0000WEBPVP8 '.codeUnits)),
        'webp',
      );
      expect(sniffImageFormat(Uint8List.fromList('GIF89a'.codeUnits)), 'gif');
      expect(sniffImageFormat(Uint8List.fromList('안녕'.codeUnits)), isNull);
      expect(sniffImageFormat(Uint8List(0)), isNull);
    });
  });
}
