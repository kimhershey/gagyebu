import 'package:material_ui/material_ui.dart';

/// 처음 들어온 사용자에게 할 일을 알려 주는 카드(`docs/SPEC.md` 7.19).
/// 보여 줄 것이 없으면 아무것도 그리지 않는다. 홈 화면 맨 위에 둔다.
class OnboardingCard extends StatelessWidget {
  const OnboardingCard({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
