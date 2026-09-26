import 'package:birdnet_live/core/theme/app_semantic_colors.dart';
import 'package:birdnet_live/core/theme/app_theme.dart';
import 'package:birdnet_live/core/theme/score_colors.dart';
import 'package:birdnet_live/fork/design/birdy_theme.dart';
import 'package:birdnet_live/fork/design/birdy_tokens.dart';
import 'package:birdnet_live/fork/design/birdy_typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final themes = {
    Brightness.light: BirdyTheme.light(),
    Brightness.dark: BirdyTheme.dark(),
  };

  test('palette of both themes', () {
    final light = themes[Brightness.light]!;
    final dark = themes[Brightness.dark]!;
    expect(light.brightness, Brightness.light);
    expect(dark.brightness, Brightness.dark);
    expect(light.scaffoldBackgroundColor, BirdyBrand.mist);
    expect(dark.scaffoldBackgroundColor, BirdyBrand.ink);
    expect(light.colorScheme.primary, const Color(0xFF0B6E77));
    expect(dark.colorScheme.primary, const Color(0xFF4FC3CC));
    expect(light.colorScheme.onSurface, BirdyBrand.ink);
    expect(dark.colorScheme.onSurface, BirdyBrand.mist);
    expect(light.cardTheme.color, Colors.white);
    expect(light.cardTheme.elevation, 0);
  });

  test('upstream extensions stay, score ramps unchanged', () {
    for (final MapEntry(key: brightness, value: theme) in themes.entries) {
      final isDark = brightness == Brightness.dark;
      expect(
        theme.extension<ScoreColors>(),
        isDark ? ScoreColors.dark : ScoreColors.light,
      );
      expect(theme.extension<AppSemanticColors>(), isNotNull);
      expect(
        theme.extension<BirdyColors>(),
        isDark ? BirdyColors.dark : BirdyColors.light,
      );
      expect(AppTheme.isHighContrastTheme(theme), isFalse);
    }
  });

  test('text roles use the BirdyGo fonts and scale', () {
    for (final theme in themes.values) {
      final t = theme.textTheme;
      for (final style in [t.headlineMedium, t.headlineSmall, t.titleLarge]) {
        expect(style!.fontFamily, BirdyFonts.serif);
      }
      for (final style in [
        t.bodyLarge,
        t.bodyMedium,
        t.bodySmall,
        t.labelLarge,
      ]) {
        expect(style!.fontFamily, BirdyFonts.sans);
      }
      expect(t.headlineLarge!.fontSize, 34);
      expect(t.headlineMedium!.fontSize, 26);
      expect(t.titleLarge!.fontSize, 20);
      expect(t.titleMedium!.fontSize, 17);
      expect(t.bodyMedium!.fontSize, 15);
      expect(t.bodySmall!.fontSize, 13);
      expect(t.bodyMedium!.color, theme.colorScheme.onSurface);
    }
  });

  test('Fraunces styles set SOFT and opsz, never wght', () {
    const serif = [
      BirdyText.display,
      BirdyText.title,
      BirdyText.heading,
      BirdyText.species,
      BirdyText.speciesCompact,
      BirdyText.latin,
      BirdyText.latinCompact,
    ];
    for (final style in serif) {
      final axes = {for (final v in style.fontVariations!) v.axis: v.value};
      expect(axes['SOFT'], 100);
      expect(axes['opsz'], style.fontSize);
      expect(axes.containsKey('wght'), isFalse);
      expect(style.fontWeight, isNotNull);
    }
    for (final style in [
      BirdyText.numberXL,
      BirdyText.numberL,
      BirdyText.numberM,
    ]) {
      expect(style.fontFeatures, contains(const FontFeature.tabularFigures()));
    }
  });

  test('buttons keep 48 dp touch targets', () {
    for (final theme in themes.values) {
      for (final style in [
        theme.filledButtonTheme.style,
        theme.outlinedButtonTheme.style,
        theme.textButtonTheme.style,
        theme.elevatedButtonTheme.style,
      ]) {
        expect(
          style!.minimumSize!.resolve({})!.height,
          greaterThanOrEqualTo(48),
        );
      }
    }
  });

  test('Material buttons are pills', () {
    for (final theme in themes.values) {
      for (final style in [
        theme.filledButtonTheme.style,
        theme.outlinedButtonTheme.style,
        theme.textButtonTheme.style,
        theme.elevatedButtonTheme.style,
      ]) {
        expect(style!.shape!.resolve({}), isA<StadiumBorder>());
      }
      expect(
        theme.textButtonTheme.style!.foregroundColor!.resolve({}),
        theme.colorScheme.primary,
      );
    }
  });

  test('BirdyColors falls back when the theme has none', () {
    expect(BirdyColors.fromTheme(ThemeData()), BirdyColors.light);
    expect(
      BirdyColors.fromTheme(ThemeData(brightness: Brightness.dark)),
      BirdyColors.dark,
    );
    expect(
      BirdyColors.fromTheme(AppTheme.highContrastDark()),
      BirdyColors.dark,
    );
  });

  test('BirdyColors lerp ends on each theme', () {
    const light = BirdyColors.light;
    const dark = BirdyColors.dark;
    expect(light.lerp(dark, 0).background, light.background);
    expect(light.lerp(dark, 1).background, dark.background);
    expect(light.lerp(dark, 1).toCheck.foreground, dark.toCheck.foreground);
    expect(light.lerp(null, 0.5), light);
  });

  testWidgets('ListeningTheme turns a light screen dark', (tester) async {
    late ThemeData seen;
    Widget probe() => ListeningTheme(
      child: Builder(
        builder: (context) {
          seen = Theme.of(context);
          return const SizedBox();
        },
      ),
    );

    await tester.pumpWidget(
      MaterialApp(theme: BirdyTheme.light(), home: probe()),
    );
    expect(seen.brightness, Brightness.dark);
    expect(seen.extension<BirdyColors>(), BirdyColors.dark);

    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.highContrastLight(), home: probe()),
    );
    await tester.pumpAndSettle(); // MaterialApp animates theme changes.
    expect(AppTheme.isHighContrastTheme(seen), isTrue);
    expect(seen.brightness, Brightness.dark);

    final custom = ThemeData(brightness: Brightness.dark);
    await tester.pumpWidget(MaterialApp(theme: custom, home: probe()));
    await tester.pumpAndSettle();
    expect(seen.colorScheme, custom.colorScheme);
  });
}
