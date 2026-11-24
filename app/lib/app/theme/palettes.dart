import 'package:material_ui/material_ui.dart';

/// 한 팔레트의 색. 값의 원본은 `docs/ui-palettes.json`이고 시험이 둘을 대조한다.
///
/// 화면 코드는 이 값을 직접 쓰지 않는다. `Theme.of(context).colorScheme`과
/// `context.tokens`로 읽는다.
class AppPalette {
  const AppPalette({
    required this.id,
    required this.name,
    required this.brightness,
    required this.bg,
    required this.surface,
    required this.surface2,
    required this.border,
    required this.text,
    required this.sub,
    required this.accent,
    required this.onAccent,
    required this.accentSoft,
    required this.income,
    required this.expense,
    required this.transfer,
    required this.warn,
    required this.warnSoft,
    required this.ok,
  });

  /// `docs/ui-palettes.json`의 키.
  final String id;
  final String name;
  final Brightness brightness;

  /// 바탕과, 그 위에 올리는 면 두 단계.
  final Color bg;
  final Color surface;
  final Color surface2;
  final Color border;

  /// 글자와 보조 글자.
  final Color text;
  final Color sub;

  /// 강조색(단추, 고른 것)과 그 위의 글자, 옅은 강조 바탕.
  final Color accent;
  final Color onAccent;
  final Color accentSoft;

  /// 금액의 색. 색만으로 구분하지 않고 부호를 함께 쓴다.
  final Color income;
  final Color expense;
  final Color transfer;

  /// '확인 필요'와 그 바탕, 그리고 '잘 됨'.
  final Color warn;
  final Color warnSoft;
  final Color ok;
}

const quietLight = AppPalette(
  id: 'quiet-light',
  name: '금융 · 밝게',
  brightness: Brightness.light,
  bg: Color(0xFFFFFFFF),
  surface: Color(0xFFF4F6F9),
  surface2: Color(0xFFE9EDF2),
  border: Color(0xFFDDE2E8),
  text: Color(0xFF191F28),
  sub: Color(0xFF5C6773),
  accent: Color(0xFF1E3A8A),
  onAccent: Color(0xFFFFFFFF),
  accentSoft: Color(0xFFE6ECFA),
  income: Color(0xFF1B64DA),
  expense: Color(0xFFD22B2B),
  transfer: Color(0xFF5C6773),
  warn: Color(0xFF9A5B00),
  warnSoft: Color(0xFFFFF3D6),
  ok: Color(0xFF167A46),
);

const quietDark = AppPalette(
  id: 'quiet-dark',
  name: '금융 · 어둡게',
  brightness: Brightness.dark,
  bg: Color(0xFF101318),
  surface: Color(0xFF181C23),
  surface2: Color(0xFF222730),
  border: Color(0xFF2C323D),
  text: Color(0xFFEEF1F5),
  sub: Color(0xFFA3ACB8),
  accent: Color(0xFF8FB0FF),
  onAccent: Color(0xFF0B1730),
  accentSoft: Color(0xFF1C2A4A),
  income: Color(0xFF7FB2FF),
  expense: Color(0xFFFF8A80),
  transfer: Color(0xFFA3ACB8),
  warn: Color(0xFFF2B75C),
  warnSoft: Color(0xFF3A2C10),
  ok: Color(0xFF6FD39A),
);

const toolLight = AppPalette(
  id: 'tool-light',
  name: '도구 · 밝게',
  brightness: Brightness.light,
  bg: Color(0xFFFAFAFB),
  surface: Color(0xFFFFFFFF),
  surface2: Color(0xFFF0F1F3),
  border: Color(0xFFD9DCE1),
  text: Color(0xFF1B1F24),
  sub: Color(0xFF59616C),
  accent: Color(0xFF3451B2),
  onAccent: Color(0xFFFFFFFF),
  accentSoft: Color(0xFFE8ECFB),
  income: Color(0xFF0B62C4),
  expense: Color(0xFFC9302C),
  transfer: Color(0xFF59616C),
  warn: Color(0xFF8F5600),
  warnSoft: Color(0xFFFCEFD2),
  ok: Color(0xFF1A7F4B),
);

const toolDark = AppPalette(
  id: 'tool-dark',
  name: '도구 · 어둡게',
  brightness: Brightness.dark,
  bg: Color(0xFF0E1014),
  surface: Color(0xFF15181E),
  surface2: Color(0xFF1D2129),
  border: Color(0xFF2A2F3A),
  text: Color(0xFFE6E8EC),
  sub: Color(0xFF9AA3B2),
  accent: Color(0xFF7AA2F7),
  onAccent: Color(0xFF0B1220),
  accentSoft: Color(0xFF1A2540),
  income: Color(0xFF6CB6FF),
  expense: Color(0xFFFF7B72),
  transfer: Color(0xFF9AA3B2),
  warn: Color(0xFFE3B341),
  warnSoft: Color(0xFF33290F),
  ok: Color(0xFF56D364),
);

const ledgerLight = AppPalette(
  id: 'ledger-light',
  name: '가계부 · 밝게',
  brightness: Brightness.light,
  bg: Color(0xFFFAF6EF),
  surface: Color(0xFFF3ECDF),
  surface2: Color(0xFFEADFCC),
  border: Color(0xFFDCCFB8),
  text: Color(0xFF33291F),
  sub: Color(0xFF6B5C4B),
  accent: Color(0xFF9C4A2A),
  onAccent: Color(0xFFFFFFFF),
  accentSoft: Color(0xFFF3DDD0),
  income: Color(0xFF1F6680),
  expense: Color(0xFFB03A26),
  transfer: Color(0xFF6B5C4B),
  warn: Color(0xFF855200),
  warnSoft: Color(0xFFF6E3BD),
  ok: Color(0xFF3C6E3A),
);

const ledgerDark = AppPalette(
  id: 'ledger-dark',
  name: '가계부 · 어둡게',
  brightness: Brightness.dark,
  bg: Color(0xFF1C1814),
  surface: Color(0xFF26211B),
  surface2: Color(0xFF322B23),
  border: Color(0xFF43392E),
  text: Color(0xFFF1E9DD),
  sub: Color(0xFFB8AA97),
  accent: Color(0xFFE6A07E),
  onAccent: Color(0xFF2A140A),
  accentSoft: Color(0xFF3D2A20),
  income: Color(0xFF7CC0D8),
  expense: Color(0xFFF09480),
  transfer: Color(0xFFB8AA97),
  warn: Color(0xFFE8B866),
  warnSoft: Color(0xFF3B2E14),
  ok: Color(0xFF9CCB8E),
);

/// 여섯 팔레트 전부.
const allPalettes = [
  quietLight,
  quietDark,
  toolLight,
  toolDark,
  ledgerLight,
  ledgerDark,
];

/// 분류에 차례로 주는 열두 색(밝은 바탕용).
const categoryColorsLight = [
  Color(0xFFC2410C),
  Color(0xFF1864AB),
  Color(0xFF2B8A3E),
  Color(0xFF862E9C),
  Color(0xFFB25E00),
  Color(0xFF0B7285),
  Color(0xFFA61E4D),
  Color(0xFF4C6EF5),
  Color(0xFF8F6400),
  Color(0xFF5C940D),
  Color(0xFF5F3DC4),
  Color(0xFF5F6B76),
];

/// 분류에 차례로 주는 열두 색(어두운 바탕용).
const categoryColorsDark = [
  Color(0xFFFF922B),
  Color(0xFF74C0FC),
  Color(0xFF69DB7C),
  Color(0xFFDA77F2),
  Color(0xFFFFA94D),
  Color(0xFF66D9E8),
  Color(0xFFF783AC),
  Color(0xFF91A7FF),
  Color(0xFFFFD43B),
  Color(0xFF8CE99A),
  Color(0xFFB197FC),
  Color(0xFFADB5BD),
];
