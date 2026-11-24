import 'dart:math' as math;

import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// 설정 아래 화면의 틀: 돌아가는 단추와 제목, 그 아래에 내용.
///
/// 뼈대에는 위쪽 막대가 없다. 휴대폰에서는 이 단추가 설정으로 돌아가는 길이다.
/// 내용은 넓은 창에서 너무 퍼지지 않게 가운데 한 칸에 둔다.
class SubScreen extends StatelessWidget {
  const SubScreen({
    super.key,
    required this.title,
    required this.children,
    this.maxWidth = 720,
  });

  final String title;
  final List<Widget> children;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          // 창 어디에서 굴려도 내려가게 목록은 창을 다 쓰고, 내용만 가운데로 모은다.
          final side = math.max(16.0, (constraints.maxWidth - maxWidth) / 2);
          return ListView(
            padding: EdgeInsets.fromLTRB(side, 8, side, 24),
            children: [
              Row(
                children: [
                  IconButton(
                    key: const ValueKey('back-to-settings'),
                    tooltip: '설정으로 돌아가기',
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => context.go('/settings'),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(title, style: theme.textTheme.headlineSmall),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...children,
            ],
          );
        },
      ),
    );
  }
}

/// 설명에 쓰는 흐린 글.
class HintText extends StatelessWidget {
  const HintText(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text,
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}
