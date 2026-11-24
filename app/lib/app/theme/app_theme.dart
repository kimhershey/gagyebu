import 'package:material_ui/material_ui.dart';

import 'palettes.dart';
import 'theme_setting.dart';
import 'tokens.dart';

/// [palette]의 색과 [tone]의 치수로 앱의 테마를 만든다.
///
/// 색은 팔레트의 값을 그대로 쓴다. 씨앗 색에서 만들면 면에 색이 섞여 흰 바탕이나
/// 종이색, 거의 검정을 낼 수 없다.
ThemeData buildTheme(AppPalette palette, ThemeTone tone) {
  final tokens = AppTokens.of(palette, tone);
  final dark = palette.brightness == Brightness.dark;
  final scheme = ColorScheme(
    brightness: palette.brightness,
    primary: palette.accent,
    onPrimary: palette.onAccent,
    primaryContainer: palette.accentSoft,
    onPrimaryContainer: palette.text,
    secondary: palette.accent,
    onSecondary: palette.onAccent,
    secondaryContainer: palette.accentSoft,
    onSecondaryContainer: palette.text,
    tertiary: palette.income,
    onTertiary: palette.bg,
    // 오류는 지출과 같은 빨강을 쓴다. '확인 필요'는 따로 둔 경고색(tokens.warn)이다.
    error: palette.expense,
    onError: dark ? palette.bg : const Color(0xFFFFFFFF),
    errorContainer: Color.alphaBlend(
      palette.expense.withValues(alpha: 0.14),
      palette.surface,
    ),
    onErrorContainer: palette.text,
    surface: palette.bg,
    onSurface: palette.text,
    onSurfaceVariant: palette.sub,
    surfaceContainerLowest: palette.bg,
    surfaceContainerLow: palette.surface,
    surfaceContainer: palette.surface,
    surfaceContainerHigh: palette.surface2,
    surfaceContainerHighest: palette.surface2,
    outline: palette.sub,
    outlineVariant: palette.border,
    inverseSurface: palette.text,
    onInverseSurface: palette.bg,
    inversePrimary: palette.accentSoft,
    // 면에 강조색을 섞지 않는다.
    surfaceTint: const Color(0x00000000),
  );
  final shape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(tokens.radius),
  );
  // 단추와 입력 칸은 면보다 덜 둥글게 한다.
  final controlRadius = BorderRadius.circular(
    tokens.radius < 12 ? tokens.radius : 12,
  );
  final controlShape = RoundedRectangleBorder(borderRadius: controlRadius);

  return ThemeData(
    colorScheme: scheme,
    scaffoldBackgroundColor: palette.bg,
    // 한글 글꼴을 앱에 넣어, 웹에서도 외부 글꼴 서버 없이 같은 모양으로 보이게 한다.
    fontFamily: 'Pretendard',
    visualDensity: VisualDensity.standard,
    extensions: [tokens],
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: palette.surface,
      shape: shape.copyWith(side: tokens.surfaceBorder),
    ),
    dividerTheme: DividerThemeData(color: palette.border, space: 1),
    inputDecorationTheme: InputDecorationTheme(
      isDense: true,
      border: OutlineInputBorder(borderRadius: controlRadius),
      enabledBorder: OutlineInputBorder(
        borderRadius: controlRadius,
        borderSide: BorderSide(color: palette.border),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(shape: controlShape),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: controlShape,
        side: BorderSide(color: palette.border),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(shape: controlShape),
    ),
    dialogTheme: DialogThemeData(backgroundColor: palette.bg, shape: shape),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: palette.surface,
      indicatorColor: palette.accentSoft,
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: palette.bg,
      indicatorColor: palette.accentSoft,
    ),
    listTileTheme: ListTileThemeData(shape: controlShape),
    chipTheme: ChipThemeData(
      side: BorderSide(color: palette.border),
      shape: controlShape,
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}
