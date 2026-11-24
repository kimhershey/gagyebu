import 'package:flutter_test/flutter_test.dart';

import 'test_app.dart';

void main() {
  testWidgets('설정은 어디에 저장되는지와 로그인이 없는 빌드라는 것을 알려 준다', (tester) async {
    final services = await createTestServices();
    await pumpApp(tester, services, size: desktop, location: '/settings');

    expect(find.text('저장과 동기화'), findsOneWidget);
    // 저장을 시작한 날을 보여 준다. 들어올 때마다 오늘로 바뀌면 저장소가 비워진 것이다.
    expect(
      find.textContaining('2026년 11월 17일부터 여기에 저장하고 있습니다'),
      findsOneWidget,
    );
    expect(find.text('이 앱에는 로그인이 들어 있지 않습니다'), findsOneWidget);
    expect(find.text('가계부는 이 기기 안에만 저장됩니다'), findsOneWidget);

    await disposeApp(tester, services);
  });

  testWidgets('올리지 않은 변경이 있으면 몇 건인지 알려 준다', (tester) async {
    final services = await createTestServices();
    await services.repository.setMonthStartDay(services.ledgerId, 25);
    await pumpApp(tester, services, size: desktop, location: '/settings');

    expect(find.textContaining('올리지 않은 변경 1건'), findsOneWidget);

    await disposeApp(tester, services);
  });
}
