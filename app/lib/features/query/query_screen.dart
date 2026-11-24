import 'package:material_ui/material_ui.dart';

import '../common/placeholder_screen.dart';

/// 조회 화면. `docs/SPEC.md` 7.15.
class QueryScreen extends StatelessWidget {
  const QueryScreen({super.key, required this.question});

  /// 사용자가 적은 물음.
  final String question;

  @override
  Widget build(BuildContext context) => const PlaceholderScreen(title: '조회');
}
