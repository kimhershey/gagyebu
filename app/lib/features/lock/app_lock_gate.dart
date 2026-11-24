import 'package:material_ui/material_ui.dart';

/// 앱 잠금이 켜져 있으면 [child] 대신 잠금 화면을 보여 준다(`docs/SPEC.md` 7.17).
///
/// 아직 잠금이 없다. 자식을 그대로 돌려준다.
class AppLockGate extends StatelessWidget {
  const AppLockGate({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}
