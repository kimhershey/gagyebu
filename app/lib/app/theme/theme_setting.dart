import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/prefs/device_prefs.dart';
import 'app_theme.dart';
import 'palettes.dart';

/// 테마의 톤.
enum ThemeTone {
  /// 시스템이 밝으면 금융 · 밝게, 어두우면 도구 · 어둡게.
  system('시스템에 맞춤', '밝을 때는 금융, 어두울 때는 도구'),

  /// 밝고 조용한 금융 앱의 톤.
  quiet('금융', '흰 바탕에 큰 숫자'),

  /// 촘촘한 도구의 톤.
  tool('도구', '촘촘한 표와 가는 테두리'),

  /// 따뜻한 종이 가계부의 톤.
  ledger('가계부', '종이색 바탕과 따뜻한 색');

  const ThemeTone(this.label, this.description);

  final String label;
  final String description;
}

/// 밝기. 톤을 직접 골랐을 때만 고른다.
enum ThemeBrightness {
  system('시스템'),
  light('밝게'),
  dark('어둡게');

  const ThemeBrightness(this.label);

  final String label;
}

@immutable
class ThemeSetting {
  const ThemeSetting({
    this.tone = ThemeTone.system,
    this.brightness = ThemeBrightness.system,
  });

  final ThemeTone tone;
  final ThemeBrightness brightness;

  @override
  bool operator ==(Object other) =>
      other is ThemeSetting &&
      other.tone == tone &&
      other.brightness == brightness;

  @override
  int get hashCode => Object.hash(tone, brightness);
}

/// 고른 테마를 들고 있다가, 바꾸면 기기에 적고 앱에 알린다.
class ThemeController extends ValueNotifier<ThemeSetting> {
  ThemeController(this._prefs) : super(_read(_prefs));

  static const toneKey = 'theme.tone';
  static const brightnessKey = 'theme.brightness';

  final DevicePrefs _prefs;

  static ThemeSetting _read(DevicePrefs prefs) {
    T named<T extends Enum>(List<T> values, String? name, T fallback) =>
        values.where((v) => v.name == name).firstOrNull ?? fallback;
    return ThemeSetting(
      tone: named(ThemeTone.values, prefs.getString(toneKey), ThemeTone.system),
      brightness: named(
        ThemeBrightness.values,
        prefs.getString(brightnessKey),
        ThemeBrightness.system,
      ),
    );
  }

  Future<void> setTone(ThemeTone tone) async {
    value = ThemeSetting(tone: tone, brightness: value.brightness);
    await _prefs.setString(toneKey, tone.name);
  }

  Future<void> setBrightness(ThemeBrightness brightness) async {
    value = ThemeSetting(tone: value.tone, brightness: brightness);
    await _prefs.setString(brightnessKey, brightness.name);
  }

  /// 밝은 쪽과 어두운 쪽의 팔레트.
  (AppPalette, AppPalette) get palettes => switch (value.tone) {
    ThemeTone.system => (quietLight, toolDark),
    ThemeTone.quiet => (quietLight, quietDark),
    ThemeTone.tool => (toolLight, toolDark),
    ThemeTone.ledger => (ledgerLight, ledgerDark),
  };

  /// 밝을 때 쓸 톤과 어두울 때 쓸 톤. '시스템에 맞춤'은 둘이 다르다.
  (ThemeTone, ThemeTone) get _tones => value.tone == ThemeTone.system
      ? (ThemeTone.quiet, ThemeTone.tool)
      : (value.tone, value.tone);

  ThemeData get light => buildTheme(palettes.$1, _tones.$1);
  ThemeData get dark => buildTheme(palettes.$2, _tones.$2);

  /// 톤을 직접 고르지 않았으면 밝기는 시스템을 따른다.
  ThemeMode get mode => value.tone == ThemeTone.system
      ? ThemeMode.system
      : switch (value.brightness) {
          ThemeBrightness.system => ThemeMode.system,
          ThemeBrightness.light => ThemeMode.light,
          ThemeBrightness.dark => ThemeMode.dark,
        };

  /// 시스템의 밝기가 [platform]일 때 실제로 쓰는 테마. 앱이 뜨기 전의 화면이 쓴다.
  ThemeData resolve(Brightness platform) => switch (mode) {
    ThemeMode.light => light,
    ThemeMode.dark => dark,
    ThemeMode.system => platform == Brightness.dark ? dark : light,
  };
}

/// 테마 설정. 앱이 시작할 때 만든 것으로 덮어쓴다(`app/bootstrap.dart`).
final themeControllerProvider = Provider<ThemeController>((ref) {
  final controller = ThemeController(ref.watch(devicePrefsProvider));
  ref.onDispose(controller.dispose);
  return controller;
});
