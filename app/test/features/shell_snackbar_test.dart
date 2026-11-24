import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'test_app.dart';

void main() {
  testWidgets('휴대폰 배치에서 알림은 입력창을 덮지 않고 그 위에 뜬다', (tester) async {
    final services = await createTestServices();
    await pumpApp(tester, services, size: phone);

    ScaffoldMessenger.of(
      tester.element(find.byKey(const ValueKey('composer-input'))),
    ).showSnackBar(
      SnackBar(
        content: const Text('1건을 저장했습니다'),
        action: SnackBarAction(label: '되돌리기', onPressed: () {}),
      ),
    );
    await tester.pumpAndSettle();

    // SnackBar 위젯의 자리에는 바깥 여백이 들어 있다. 눌리는 단추의 자리로 본다.
    final notice = tester.getRect(find.text('되돌리기'));
    final composer = tester.getRect(
      find.byKey(const ValueKey('composer-input')),
    );
    // 알림의 아래쪽 끝이 입력창의 위쪽 끝보다 위에 있다.
    expect(notice.bottom, lessThanOrEqualTo(composer.top));

    // 입력창이 여러 줄로 늘어나면 알림도 따라 올라간다.
    await tester.enterText(
      find.byKey(const ValueKey('composer-input')),
      '첫 줄\n둘째 줄\n셋째 줄',
    );
    await tester.pumpAndSettle();
    expect(
      tester.getRect(find.text('되돌리기')).bottom,
      lessThanOrEqualTo(
        tester.getRect(find.byKey(const ValueKey('composer-input'))).top,
      ),
    );
    await disposeApp(tester, services);
  });
}
