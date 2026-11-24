import 'package:material_ui/material_ui.dart';

import 'palettes.dart';
import 'theme_setting.dart';

/// 테마가 정하는 색과 치수 가운데 `ColorScheme`에 없는 것.
///
/// 화면은 `context.tokens`로 읽는다. 값은 `docs/SPEC.md` 6.1에 있다.
@immutable
class AppTokens extends ThemeExtension<AppTokens> {
  const AppTokens({
    required this.income,
    required this.expense,
    required this.transfer,
    required this.warn,
    required this.warnSoft,
    required this.ok,
    required this.accentSoft,
    required this.border,
    required this.radius,
    required this.rowHeight,
    required this.bigAmountSize,
    required this.surfaceBorderWidth,
    required this.categoryColors,
  });

  /// [palette]의 색과 [tone]의 치수로 만든다.
  factory AppTokens.of(AppPalette palette, ThemeTone tone) {
    final (radius, rowHeight, bigAmount, borderWidth) = switch (tone) {
      ThemeTone.tool => (8.0, 40.0, 28.0, 1.0),
      ThemeTone.ledger => (12.0, 48.0, 32.0, 1.0),
      ThemeTone.quiet || ThemeTone.system => (16.0, 52.0, 34.0, 0.0),
    };
    return AppTokens(
      income: palette.income,
      expense: palette.expense,
      transfer: palette.transfer,
      warn: palette.warn,
      warnSoft: palette.warnSoft,
      ok: palette.ok,
      accentSoft: palette.accentSoft,
      border: palette.border,
      radius: radius,
      rowHeight: rowHeight,
      bigAmountSize: bigAmount,
      surfaceBorderWidth: borderWidth,
      categoryColors: palette.brightness == Brightness.dark
          ? categoryColorsDark
          : categoryColorsLight,
    );
  }

  /// 금액의 색.
  final Color income;
  final Color expense;
  final Color transfer;

  /// '확인 필요'의 글자색과 바탕, '잘 됨'.
  final Color warn;
  final Color warnSoft;
  final Color ok;

  final Color accentSoft;
  final Color border;

  /// 면의 모서리 반지름.
  final double radius;

  /// 목록 한 줄의 높이. 터치 기기에서는 이 값이 48보다 작아도 누름 영역은 48을 지킨다.
  final double rowHeight;

  /// 화면에서 가장 큰 금액의 글자 크기.
  final double bigAmountSize;

  /// 면의 테두리 굵기. 0이면 테두리가 없다.
  final double surfaceBorderWidth;

  /// 분류에 차례로 주는 열두 색.
  final List<Color> categoryColors;

  /// 면의 테두리. 굵기가 0이면 없다.
  BorderSide get surfaceBorder => surfaceBorderWidth == 0
      ? BorderSide.none
      : BorderSide(color: border, width: surfaceBorderWidth);

  /// 금액을 쓰는 글자 모양: 고정폭 숫자로 자릿수가 줄 맞게 한다.
  TextStyle amountStyle(TextStyle? base) => (base ?? const TextStyle())
      .copyWith(fontFeatures: const [FontFeature.tabularFigures()]);

  @override
  AppTokens copyWith() => this;

  @override
  AppTokens lerp(covariant AppTokens? other, double t) {
    if (other == null) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    double num(double a, double b) => a + (b - a) * t;
    return AppTokens(
      income: mix(income, other.income),
      expense: mix(expense, other.expense),
      transfer: mix(transfer, other.transfer),
      warn: mix(warn, other.warn),
      warnSoft: mix(warnSoft, other.warnSoft),
      ok: mix(ok, other.ok),
      accentSoft: mix(accentSoft, other.accentSoft),
      border: mix(border, other.border),
      radius: num(radius, other.radius),
      rowHeight: num(rowHeight, other.rowHeight),
      bigAmountSize: num(bigAmountSize, other.bigAmountSize),
      surfaceBorderWidth: num(surfaceBorderWidth, other.surfaceBorderWidth),
      categoryColors: t < 0.5 ? categoryColors : other.categoryColors,
    );
  }
}

extension AppTokensOf on BuildContext {
  /// 지금 테마의 토큰. 테마에 토큰이 없으면(시험의 맨 위젯) 기본 팔레트의 것을 쓴다.
  AppTokens get tokens {
    final theme = Theme.of(this);
    return theme.extension<AppTokens>() ??
        AppTokens.of(
          theme.brightness == Brightness.dark ? toolDark : quietLight,
          ThemeTone.system,
        );
  }
}
