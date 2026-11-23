import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:gagyebu/app/bootstrap.dart';
import 'package:gagyebu/app/providers.dart';

import '../features/test_app.dart';

void main() {
  /// [takenOver]를 붙인 시험용 서비스.
  Future<AppServices> servicesWith(Future<void>? takenOver) async {
    final base = await createTestServices();
    return AppServices(
      db: base.db,
      repository: base.repository,
      ledgerId: base.ledgerId,
      storage: base.storage,
      persistent: base.persistent,
      startedAt: base.startedAt,
      takenOver: takenOver,
    );
  }

  Future<void> settle(WidgetTester tester) async {
    tester.view.physicalSize = desktop;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpAndSettle();
  }

  testWidgets('다른 탭이 저장소를 가져가면 이 탭은 멈추고 DB를 닫는다', (tester) async {
    final takenOver = Completer<void>();
    final opened = <AppServices>[];
    Future<AppServices> open() async {
      final services = await servicesWith(
        opened.isEmpty ? takenOver.future : null,
      );
      opened.add(services);
      return services;
    }

    await tester.pumpWidget(Bootstrap(open: open));
    await settle(tester);
    expect(find.text('설정'), findsWidgets);
    expect(find.text('다른 탭에서 가계부를 열었다'), findsNothing);
    // 설정 화면으로 가 둔다.
    await tester.tap(find.text('설정').first);
    await tester.pumpAndSettle();
    expect(find.text('월 시작일'), findsOneWidget);

    takenOver.complete();
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('다른 탭에서 가계부를 열었다'), findsOneWidget);
    // 앱 화면은 내려갔다. 오래된 사본으로 더 저장할 수 없다.
    expect(find.text('설정'), findsNothing);
    await expectLater(
      opened.single.db.customSelect('select 1').get(),
      throwsA(anything),
    );

    // '이 탭에서 계속 쓰기'를 누르면 DB를 다시 열어 최신 내용으로 시작한다.
    await tester.tap(find.text('이 탭에서 계속 쓰기'));
    await tester.pumpAndSettle();
    expect(opened, hasLength(2));
    expect(find.text('다른 탭에서 가계부를 열었다'), findsNothing);
    // 보던 화면(설정)으로 돌아온다.
    expect(find.text('월 시작일'), findsOneWidget);

    await disposeApp(tester, opened.last);
  });

  testWidgets('신호가 없는 환경(앱, 공유 워커가 있는 브라우저)에서는 그대로 쓴다', (tester) async {
    late AppServices services;
    await tester.pumpWidget(
      Bootstrap(open: () async => services = await servicesWith(null)),
    );
    await settle(tester);
    expect(find.text('설정'), findsWidgets);
    expect(find.text('다른 탭에서 가계부를 열었다'), findsNothing);
    await disposeApp(tester, services);
  });

  testWidgets('DB를 열지 못하면 이유를 보여 주고 다시 시도할 수 있다', (tester) async {
    var attempts = 0;
    late AppServices services;
    Future<AppServices> open() async {
      attempts++;
      if (attempts == 1) throw StateError('저장소를 열 수 없다');
      return services = await servicesWith(null);
    }

    await tester.pumpWidget(Bootstrap(open: open));
    await settle(tester);
    expect(find.text('데이터를 열지 못했다'), findsOneWidget);
    expect(find.textContaining('저장소를 열 수 없다'), findsOneWidget);

    await tester.tap(find.text('다시 시도'));
    await tester.pumpAndSettle();
    expect(attempts, 2);
    expect(find.text('설정'), findsWidgets);
    await disposeApp(tester, services);
  });
}
