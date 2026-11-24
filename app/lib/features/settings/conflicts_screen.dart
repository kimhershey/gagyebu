import 'package:material_ui/material_ui.dart';

import '../common/placeholder_screen.dart';

/// 동기화 충돌 화면. `docs/SPEC.md` 4.6.
class ConflictsScreen extends StatelessWidget {
  const ConflictsScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      const PlaceholderScreen(title: '동기화 충돌');
}
