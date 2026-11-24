import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:gagyebu/app/theme/palettes.dart';
import 'package:gagyebu/app/theme/theme_setting.dart';
import 'package:gagyebu/app/theme/tokens.dart';
import 'package:gagyebu/data/prefs/device_prefs.dart';
import 'package:material_ui/material_ui.dart';

import '../features/test_app.dart';

String _hex(Color color) =>
    '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

/// WCAG의 대비.
double _contrast(Color a, Color b) {
  double channel(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  double luminance(Color c) =>
      0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
  final la = luminance(a), lb = luminance(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  test('팔레트의 색은 docs/ui-palettes.json과 같다', () {
    final json = jsonDecode(
      File('../docs/ui-palettes.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final palettes = json['palettes'] as Map<String, dynamic>;
    expect(allPalettes.map((p) => p.id), unorderedEquals(palettes.keys));
    for (final palette in allPalettes) {
      final source = palettes[palette.id] as Map<String, dynamic>;
      expect(palette.name, source['name']);
      final colors = {
        'bg': palette.bg,
        'surface': palette.surface,
        'surface2': palette.surface2,
        'border': palette.border,
        'text': palette.text,
        'sub': palette.sub,
        'accent': palette.accent,
        'onAccent': palette.onAccent,
        'accentSoft': palette.accentSoft,
        'income': palette.income,
        'expense': palette.expense,
        'transfer': palette.transfer,
        'warn': palette.warn,
        'warnSoft': palette.warnSoft,
        'ok': palette.ok,
      };
      colors.forEach((key, color) {
        expect(_hex(color), source[key], reason: '${palette.id}.$key');
      });
    }
    final category = json['category'] as Map<String, dynamic>;
    expect(categoryColorsLight.map(_hex), category['light']);
    expect(categoryColorsDark.map(_hex), category['dark']);
  });

  test('글자와 금액의 대비는 4.5 이상이다', () {
    for (final p in allPalettes) {
      final pairs = {
        '글자/바탕': (p.text, p.bg),
        '글자/면': (p.text, p.surface),
        '보조 글자/면': (p.sub, p.surface),
        '수입/면': (p.income, p.surface),
        '지출/면': (p.expense, p.surface),
        '확인 필요/면': (p.warn, p.surface),
        '강조/면': (p.accent, p.surface),
        '강조 위 글자': (p.onAccent, p.accent),
      };
      pairs.forEach((name, pair) {
        expect(
          _contrast(pair.$1, pair.$2),
          greaterThanOrEqualTo(4.5),
          reason: '${p.id} $name',
        );
      });
    }
  });

  group('ThemeController', () {
    test('처음에는 시스템에 맞춘다: 밝으면 금융, 어두우면 도구', () {
      final controller = ThemeController(MemoryDevicePrefs());
      expect(controller.value.tone, ThemeTone.system);
      expect(controller.mode, ThemeMode.system);
      expect(controller.light.scaffoldBackgroundColor, quietLight.bg);
      expect(controller.dark.scaffoldBackgroundColor, toolDark.bg);
      expect(controller.light.extension<AppTokens>()!.radius, 16);
      expect(controller.dark.extension<AppTokens>()!.radius, 8);
    });

    test('고른 톤과 밝기를 기기에 적고 다시 읽는다', () async {
      final prefs = MemoryDevicePrefs();
      final controller = ThemeController(prefs);
      await controller.setTone(ThemeTone.ledger);
      await controller.setBrightness(ThemeBrightness.dark);
      expect(controller.mode, ThemeMode.dark);
      expect(controller.dark.scaffoldBackgroundColor, ledgerDark.bg);

      final again = ThemeController(prefs);
      expect(
        again.value,
        const ThemeSetting(
          tone: ThemeTone.ledger,
          brightness: ThemeBrightness.dark,
        ),
      );
      expect(
        again.resolve(Brightness.light).scaffoldBackgroundColor,
        ledgerDark.bg,
      );
    });

    test('모르는 값이 적혀 있으면 기본값을 쓴다', () {
      final controller = ThemeController(
        MemoryDevicePrefs({ThemeController.toneKey: '없는 톤'}),
      );
      expect(controller.value, const ThemeSetting());
    });
  });

  testWidgets('설정에서 톤을 고르면 화면이 바로 바뀐다', (tester) async {
    final services = await createTestServices();
    await pumpApp(tester, services, size: desktop, location: '/settings');
    Color background() =>
        Theme.of(tester.element(find.text('설정').last)).scaffoldBackgroundColor;
    expect(background(), quietLight.bg);
    // 시스템에 맞출 때는 밝기를 고르지 않는다.
    expect(find.byKey(const ValueKey('theme-brightness-dark')), findsNothing);

    await tester.ensureVisible(find.byKey(const ValueKey('theme-tone-ledger')));
    await tester.tap(find.byKey(const ValueKey('theme-tone-ledger')));
    await tester.pumpAndSettle();
    expect(background(), ledgerLight.bg);

    await tester.ensureVisible(
      find.byKey(const ValueKey('theme-brightness-dark')),
    );
    await tester.tap(find.byKey(const ValueKey('theme-brightness-dark')));
    await tester.pumpAndSettle();
    expect(background(), ledgerDark.bg);
    await disposeApp(tester, services);
  });
}
