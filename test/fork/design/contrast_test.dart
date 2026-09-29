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
      expectAA(c.text2, c.tonal, 'text2/tonal');
      expectAA(c.orioleText, c.tonal, 'orioleText/tonal');
      expectAA(c.accentText, c.navIndicator, 'accentText/navIndicator');
      expectAA(c.orioleText, c.orioleContainer, 'orioleText/container');
    });

    test('rarity pills (J6h)', () {
      for (final bg in [c.surface1, c.background]) {
        expectAA(c.text2, on(c.line, bg), 'uncommon: text2/line');
        expectAA(
          c.orioleText,
          on(c.orioleContainer, bg),
          'rare: orioleText/container',
        );
      }
    });

    test('J6h hero captions', () {
      for (final bg in [c.background, c.surface1]) {
        expectAA(
          c.accentText,
          on(c.tonal, bg),
          'Bilan caption: accentText/tonal',
        );
        expectAA(c.text2, on(c.sure.background, bg), 'Fiche line: text2/sure');
      }
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
      expectAA(c.text2, on(c.tonal, c.background), 'text2/tonal');
      expectAA(c.orioleText, on(c.tonal, c.background), 'orioleText/tonal');
      expectAA(
        c.orioleText,
        on(c.orioleContainer, c.surface1),
        'orioleText/container',
      );
      expectAA(BirdyBrand.ink, BirdyBrand.mist, 'stop button');
    });

    test('rarity pills (J6h)', () {
      for (final bg in [c.surface1, c.background]) {
        expectAA(c.text2, on(c.line, bg), 'uncommon: text2/line');
        expectAA(
          c.orioleText,
          on(c.orioleContainer, bg),
          'rare: orioleText/container',
        );
      }
    });

    test('J6h hero captions', () {
      for (final bg in [c.background, c.surface1]) {
        expectAA(
          c.accentText,
          on(c.tonal, bg),
          'Bilan caption (dark): accentText/tonal',
        );
        expectAA(c.text2, on(c.sure.background, bg), 'Fiche line: text2/sure');
      }
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

  test('volume alert block reaches AA in both themes (J6h)', () {
    for (final (mode, c) in [
      ('light', BirdyColors.light),
      ('dark', BirdyColors.dark),
    ]) {
      for (final bg in [c.background, c.surface1]) {
        final tint = on(c.orioleContainer, bg);
        expectAA(c.text1, tint, '$mode title/tint');
        expectAA(c.text2, tint, '$mode caption/tint');
      }
      expectAA(c.onOriole, c.oriole, '$mode disc icon and button/oriole');
    }
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

  group('listening mode colors reach AA (J6f)', () {
    const light = BirdyColors.light;
    const dark = BirdyColors.dark;

    test('light theme: on the sheet surfaces', () {
      for (final (name, color) in [
        ('normal', ListeningModeColors.normalLight),
        ('wind', ListeningModeColors.windLight),
        ('boost', ListeningModeColors.boostLight),
        ('city', ListeningModeColors.cityLight),
      ]) {
        expectAA(color, light.background, '$name/background');
        expectAA(color, light.surface1, '$name/surface1');
        expectAA(color, light.surface2, '$name/surface2');
      }
    });

    test('dark theme (live screen and options sheet)', () {
      for (final (name, color) in [
        ('normal', ListeningModeColors.normalDark),
        ('wind', ListeningModeColors.windDark),
        ('boost', ListeningModeColors.boostDark),
        ('city', ListeningModeColors.cityDark),
      ]) {
        expectAA(color, dark.background, '$name/background');
        expectAA(color, dark.surface1, '$name/surface1');
        expectAA(color, dark.surface2, '$name/surface2');
        expectAA(color, dark.surface3, '$name/surface3');
      }
    });

    test('distinct in hue: no two modes share a color', () {
      final lightColors = {
        ListeningModeColors.normalLight,
        ListeningModeColors.windLight,
        ListeningModeColors.boostLight,
        ListeningModeColors.cityLight,
      };
      final darkColors = {
        ListeningModeColors.normalDark,
        ListeningModeColors.windDark,
        ListeningModeColors.boostDark,
        ListeningModeColors.cityDark,
      };
      expect(lightColors, hasLength(4));
      expect(darkColors, hasLength(4));
    });
  });

  group('light listening screen reaches AA (J6h)', () {
    const c = BirdyColors.light;

    test('text and mode colors on the page and the control bar', () {
      for (final (name, bg) in [
        ('background', c.background),
        ('backgroundDeep', c.backgroundDeep),
        ('surface1', c.surface1),
      ]) {
        expectAA(c.text1, bg, 'text1/$name');
        expectAA(c.text2, bg, 'text2/$name');
        expectAA(c.accentText, bg, 'accentText/$name');
        for (final (mode, color) in [
          ('normal', ListeningModeColors.normalLight),
          ('wind', ListeningModeColors.windLight),
          ('boost', ListeningModeColors.boostLight),
          ('city', ListeningModeColors.cityLight),
        ]) {
          expectAA(color, bg, '$mode/$name');
        }
      }
    });

    test('« Arrêter »: Brume text on ink', () {
      expectAA(BirdyBrand.mist, BirdyBrand.ink, 'mist/ink');
    });

    test('rarity pills on the rows and the page', () {
      for (final bg in [c.surface1, c.background, c.backgroundDeep]) {
        expectAA(c.text2, on(c.line, bg), 'uncommon: text2/line');
        expectAA(
          c.orioleText,
          on(c.orioleContainer, bg),
          'rare: orioleText/container',
        );
      }
    });
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

  test('day sheet and strip (J6h)', () {
    for (final c in [BirdyColors.light, BirdyColors.dark]) {
      final tonal = on(c.tonal, c.surface1);
      final oriole = on(c.orioleContainer, c.surface1);
      expectAA(c.text1, tonal, 'sheet title/tonal');
      expectAA(c.text2, tonal, 'sheet text/tonal');
      expectAA(c.accentText, tonal, 'sheet header/tonal');
      expectAA(c.text1, oriole, 'sheet title/oriole');
      expectAA(c.text2, oriole, 'sheet text/oriole');
      expectAA(c.orioleText, oriole, 'sheet header/oriole');
      // Strip pills and the sheet's white discs.
      expectAA(c.text1, c.surface1, 'pill text/surface1');
      expectAA(c.orioleText, c.surface1, 'sunrise icon/surface1');
      expectAA(
        c.probable.foreground,
        c.surface1,
        'sunset icon/surface1',
        min: 3,
      );
    }
  });
  test('first-encounter countdown and series (J6h)', () {
    for (final c in [BirdyColors.light, BirdyColors.dark]) {
      final card = c.surface2;
      final track = c.progressTrack;
      // Text under the bar, and the series position, on the card.
      expectAA(c.text2, card, 'countdown text/card');
      expectAA(c.text1, card, 'series title/card');
      // Non-text UI: 3:1 (WCAG 1.4.11) for the fill and the current dot.
      expectAA(c.accentText, on(track, card), 'countdown fill/track', min: 3);
      expectAA(c.accentText, on(track, card), 'series dot/idle dot', min: 3);
      expectAA(c.accentText, card, 'countdown fill/card', min: 3);
      // Tip card step dots.
      expectAA(c.orioleText, on(track, c.surface1), 'tip dot/idle dot', min: 3);
    }
  });
}
