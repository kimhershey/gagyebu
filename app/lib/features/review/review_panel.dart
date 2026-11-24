import 'package:material_ui/material_ui.dart';

import '../common/placeholder_screen.dart';

/// 검토함: 초안 묶음을 보고 건마다 포함 · 고치기 · 제외를 정한 뒤 한 번에 저장한다
/// (`docs/SPEC.md` 7.6). 넓은 창에서는 뼈대의 오른쪽 칸에 들어간다.
class ReviewPanel extends StatelessWidget {
  const ReviewPanel({super.key});

  @override
  Widget build(BuildContext context) => const PlaceholderScreen(title: '검토함');
}

/// 좁은 창에서 검토함을 전체 화면으로 보여 준다(`/review`).
class ReviewScreen extends StatelessWidget {
  const ReviewScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: SafeArea(child: ReviewPanel()));
}
