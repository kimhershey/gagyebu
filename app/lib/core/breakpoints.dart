import 'package:material_ui/material_ui.dart';

/// 창 너비 등급. 화면은 기기 종류가 아니라 창 너비로 배치를 고른다.
///
/// 같은 규칙이 Windows 창, Android 폰과 태블릿, 브라우저에 그대로 적용된다.
enum WindowSize {
  /// 600dp 미만: 휴대폰 세로. 하단 탭, 한 화면에 목록 하나.
  compact,

  /// 600–839dp: 휴대폰 가로, 폴더블, 작은 태블릿. 옆 메뉴, 목록과 상세 두 칸.
  medium,

  /// 840dp 이상: 태블릿 가로, PC. 왼쪽 메뉴, 표 편집과 상세 패널.
  expanded;

  static const mediumMinWidth = 600.0;
  static const expandedMinWidth = 840.0;

  static WindowSize fromWidth(double width) {
    if (width < mediumMinWidth) return compact;
    if (width < expandedMinWidth) return medium;
    return expanded;
  }

  static WindowSize of(BuildContext context) =>
      fromWidth(MediaQuery.sizeOf(context).width);

  bool get isCompact => this == compact;
  bool get isExpanded => this == expanded;
}
