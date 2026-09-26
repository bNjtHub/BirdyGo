import 'package:birdnet_live/fork/design/birdy_theme.dart';
import 'package:birdnet_live/fork/design/birdy_tokens.dart';
import 'package:birdnet_live/fork/design/species_tint.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Opaque color of [color] drawn on [under].
Color on(Color color, Color under) => Color.alphaBlend(color, under);

void expectAA(Color text, Color background, String name, {double min = 4.5}) {
  final ratio = contrastRatio(text, background);
  expect(
    ratio,
    greaterThanOrEqualTo(min),
    reason: '$name: ${ratio.toStringAsFixed(2)}:1 < $min:1',
  );
}

void main() {
  group('light tokens reach AA', () {
    const c = BirdyColors.light;
    test('text on surfaces', () {
      for (final (name, bg) in [
        ('background', c.background),
        ('surface1', c.surface1),
      ]) {
        expectAA(c.text1, bg, 'text1/$name');
        expectAA(c.text2, bg, 'text2/$name');
        expectAA(c.accentText, bg, 'accentText/$name');
        expectAA(c.orioleText, bg, 'orioleText/$name');
      }
    });

    test('text on fills', () {
      expectAA(c.onAccent, c.accent, 'onAccent/accent');
      expectAA(c.onOriole, c.oriole, 'onOriole/oriole');
      expectAA(c.accentText, c.tonal, 'accentText/tonal');
      expectAA(c.accentText, c.navIndicator, 'accentText/navIndicator');
      expectAA(c.orioleText, c.orioleContainer, 'orioleText/container');
    });

    test('reliability badges', () {
      for (final (name, level) in [
        ('sure', c.sure),
        ('probable', c.probable),
        ('toCheck', c.toCheck),
      ]) {
        expectAA(level.foreground, on(level.background, c.surface1), name);
      }
    });
  });

  group('dark tokens reach AA', () {
    const c = BirdyColors.dark;
    test('text on surfaces', () {
      for (final (name, bg) in [
        ('background', c.background),
        ('backgroundDeep', c.backgroundDeep),
        ('surface1', c.surface1),
        ('surface2', c.surface2),
        ('surface3', c.surface3),
      ]) {
        expectAA(c.text1, bg, 'text1/$name');
        expectAA(c.text2, bg, 'text2/$name');
      }
      for (final (name, bg) in [
        ('background', c.background),
        ('surface1', c.surface1),
      ]) {
        expectAA(c.accentText, bg, 'accentText/$name');
        expectAA(c.orioleText, bg, 'orioleText/$name');
      }
    });

    test('text on fills', () {
      expectAA(c.onAccent, c.accent, 'onAccent/accent');
      expectAA(c.onOriole, c.oriole, 'onOriole/oriole');
      expectAA(c.accentText, on(c.tonal, c.surface1), 'accentText/tonal');
      expectAA(
        c.orioleText,
        on(c.orioleContainer, c.surface1),
        'orioleText/container',
      );
      expectAA(BirdyBrand.ink, BirdyBrand.mist, 'stop button');
    });

    test('reliability badges', () {
      for (final (name, level) in [
        ('sure', c.sure),
        ('probable', c.probable),
        ('toCheck', c.toCheck),
      ]) {
        expectAA(level.foreground, on(level.background, c.surface1), name);
        expectAA(level.foreground, on(level.background, c.background), name);
      }
    });
  });

  test('Material roles of both themes reach AA', () {
    for (final theme in [BirdyTheme.light(), BirdyTheme.dark()]) {
      final s = theme.colorScheme;
      final mode = s.brightness.name;
      expectAA(s.onSurface, s.surface, '$mode onSurface');
      expectAA(s.onSurfaceVariant, s.surface, '$mode onSurfaceVariant');
      expectAA(
        s.onSurfaceVariant,
        s.surfaceContainer,
        '$mode onSurfaceVariant/container',
      );
      expectAA(s.primary, s.surface, '$mode primary as text');
      expectAA(s.primary, s.surfaceContainer, '$mode primary on card');
      expectAA(s.onPrimary, s.primary, '$mode onPrimary');
      expectAA(s.onPrimaryContainer, s.primaryContainer, '$mode primaryC');
      expectAA(s.onSecondaryContainer, s.secondaryContainer, '$mode secC');
      expectAA(s.onTertiaryContainer, s.tertiaryContainer, '$mode tertC');
      expectAA(s.tertiary, s.surface, '$mode tertiary as text');
      expectAA(s.onInverseSurface, s.inverseSurface, '$mode inverse');
    }
  });

  test('contrastRatio matches WCAG reference values', () {
    expect(
      contrastRatio(const Color(0xFF000000), const Color(0xFFFFFFFF)),
      closeTo(21, 0.01),
    );
    expect(contrastRatio(BirdyBrand.ink, BirdyBrand.mist), closeTo(13.9, 0.1));
    expect(
      contrastRatio(BirdyColors.light.accentText, BirdyBrand.mist),
      closeTo(5.25, 0.05),
    );
  });
}
