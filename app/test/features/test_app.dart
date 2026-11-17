import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gagyebu/app/app.dart';
import 'package:gagyebu/app/providers.dart';
import 'package:gagyebu/app/router.dart';
import 'package:gagyebu/data/db/database.dart';
import 'package:gagyebu/data/repositories/ledger_repository.dart';

/// 시험에서 쓰는 '지금'. 2026-11-17은 화요일이다.
final testNow = DateTime(2026, 11, 17, 12);

/// 메모리 DB로 앱 서비스를 만든다.
Future<AppServices> createTestServices() async {
  final db = AppDatabase(NativeDatabase.memory());
  final repository = LedgerRepository(db, clock: () => testNow);
  final ledgerId = await repository.ensureLocalLedger();
  return AppServices(
    db: db,
    repository: repository,
    ledgerId: ledgerId,
    storage: '시험용 메모리',
    persistent: true,
  );
}

/// 주어진 창 크기로 앱을 띄운다.
Future<void> pumpApp(
  WidgetTester tester,
  AppServices services, {
  required Size size,
  String location = '/',
  double textScale = 1,
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
      ],
      child: GagyebuApp(router: createRouter(initialLocation: location)),
    ),
  );
  await tester.pumpAndSettle();
}

/// 화면을 내리고 DB를 닫는다. drift의 스트림 정리 타이머가 남지 않게 한다.
Future<void> disposeApp(WidgetTester tester, AppServices services) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 1));
  await services.db.close();
  await tester.pump(const Duration(seconds: 1));
}

const phone = Size(360, 640);
const largePhone = Size(412, 915);
const foldable = Size(700, 800);
const desktop = Size(1280, 800);
