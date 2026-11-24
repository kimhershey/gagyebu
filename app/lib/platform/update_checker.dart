import 'package:material_ui/material_ui.dart';

/// 새 버전이 있으면 알려 주는 띠(`docs/SPEC.md` 7.21). 없으면 아무것도 그리지 않는다.
class UpdateBanner extends StatelessWidget {
  const UpdateBanner({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
