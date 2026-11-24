import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:gagyebu/app/app.dart';
import 'package:gagyebu/app/providers.dart';
import 'package:gagyebu/app/router.dart';
import 'package:gagyebu/data/db/database.dart';
import 'package:gagyebu/data/repositories/ledger_repository.dart';
import 'package:material_ui/material_ui.dart';

import 'test_app.dart';

/// [pumpApp]과 같되 상태 제공자를 더 덮어쓸 수 있다(가짜 모델, 조회 판별 등).
Future<void> pumpAppWith(
  WidgetTester tester,
  AppServices services, {
  required Size size,
  String location = '/',
  double textScale = 1,
  List<Override> overrides = const [],
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appServicesProvider.overrideWithValue(services),
        clockProvider.overrideWithValue(() => testNow),
        ...overrides,
      ],
      child: GagyebuApp(router: createRouter(initialLocation: location)),
    ),
  );
  await tester.pumpAndSettle();
}

/// 쓸 때마다 1초씩 가는 시계로 앱 서비스를 만든다.
///
/// 되돌리기는 저장한 뒤에 고쳤는지를 `client_updated_at`으로 가리므로, 고친 거래를
/// 다루는 시험에는 멈춰 있지 않은 시계가 필요하다.
Future<AppServices> createTickingServices() async {
  var now = testNow.toUtc();
  final db = AppDatabase(NativeDatabase.memory());
  final repository = LedgerRepository(
    db,
    clock: () => now = now.add(const Duration(seconds: 1)),
  );
  final ledgerId = await repository.ensureLocalLedger();
  return AppServices(
    db: db,
    repository: repository,
    ledgerId: ledgerId,
    storage: '시험용 메모리',
    persistent: true,
    startedAt: testNow,
  );
}

/// 앱의 상태 제공자 그릇. 화면 밖에서 상태를 읽거나 바꿀 때 쓴다.
ProviderContainer containerOf(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(GagyebuApp)));

const composerInput = ValueKey('composer-input');
const composerSend = ValueKey('composer-send');

/// 입력창에 글을 넣고 보내기 단추를 누른다.
Future<void> sendFromComposer(WidgetTester tester, String text) async {
  await tester.enterText(find.byKey(composerInput), text);
  await tester.pump();
  await tester.tap(find.byKey(composerSend));
  await tester.pumpAndSettle();
}

/// 클립보드에 [text]가 들어 있는 것처럼 꾸민다. null이면 비어 있다.
void mockClipboard(WidgetTester tester, String? text) {
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async {
      if (call.method == 'Clipboard.getData') {
        return text == null ? null : <String, Object?>{'text': text};
      }
      return null;
    },
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    ),
  );
}

/// 모든 거래(지운 것 포함)를 만든 순서로.
Future<List<TxRow>> allTransactions(AppServices services) =>
    services.db.select(services.db.ledgerTransactions).get();
