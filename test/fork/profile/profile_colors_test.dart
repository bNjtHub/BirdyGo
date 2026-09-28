import 'package:birdnet_live/fork/design/birdy_tokens.dart';
import 'package:birdnet_live/fork/design/species_tint.dart';
import 'package:birdnet_live/fork/design/widgets/birdy_block.dart';
import 'package:birdnet_live/fork/profile/profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Colored pairs added to the Profil in J6f reach AA in both themes.
void main() {
  void expectAA(Color text, Color fill, String name) {
    final ratio = contrastRatio(text, fill);
    expect(
      ratio,
      greaterThanOrEqualTo(4.5),
      reason: '$name: ${ratio.toStringAsFixed(2)}:1',
    );
  }

  for (final (theme, c) in [
    ('light', BirdyColors.light),
    ('dark', BirdyColors.dark),
  ]) {
    group(theme, () {
      test('badge tiles, inside the white badges block', () {
        for (final tone in kBadgeTileTones) {
          final fill = Color.alphaBlend(birdyBlockColor(c, tone), c.surface1);
          expectAA(c.text1, fill, 'text1/${tone.name}');
          expectAA(c.text2, fill, 'text2/${tone.name}');
        }
      });

      test('current status number on its tonal pill', () {
        expectAA(
          c.accentText,
          Color.alphaBlend(c.tonal, c.surface1),
          'accentText/tonal',
        );
      });

      test('quiz block', () {
        final fill = Color.alphaBlend(c.tonal, c.background);
        expectAA(c.text1, fill, 'text1/tonal');
        expectAA(c.text2, fill, 'text2/tonal');
        expectAA(c.accentText, fill, 'chevron/tonal');
        expectAA(c.onAccent, c.accent, 'headphones/accent');
        expectAA(c.onOriole, c.oriole, 'question mark/oriole');
      });

      test('challenge met', () {
        final fill = Color.alphaBlend(c.orioleContainer, c.background);
        expectAA(c.text1, fill, 'text1/oriole');
        expectAA(c.text2, fill, 'text2/oriole');
        expectAA(c.orioleText, fill, 'orioleText/oriole');
        expectAA(c.onOriole, c.oriole, 'check/oriole');
      });
    });
  }

  test('badge tiles rotate so neighbours differ', () {
    for (var i = 1; i < 8; i++) {
      expect(badgeTileTone(i), isNot(badgeTileTone(i - 1)));
    }
    // Next row (4 columns): the tile below differs too.
    for (var i = 4; i < 8; i++) {
      expect(badgeTileTone(i), isNot(badgeTileTone(i - 4)));
    }
  });
}
