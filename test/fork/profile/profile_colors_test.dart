import 'package:birdnet_live/fork/design/birdy_tokens.dart';
import 'package:birdnet_live/fork/design/species_tint.dart';
import 'package:birdnet_live/fork/game/game_config.dart';
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
      test('earned badge tiles, on their own medal tone', () {
        // Dark theme: a faint metal tint over the surface (see
        // ProfileScreen's `_Badges._badgeTile`), not the mockup's pale wash
        // (that one is light-theme only, it fails AA on dark). An earned
        // tile only ever shows `text1` (the badge name) and the tier dots
        // (ink/borderStrong), never `text2`.
        for (final metal in GameConfig.badgeMedals) {
          final fill =
              c.isDark
                  ? Color.alphaBlend(
                    metal.base.withValues(alpha: 0.22),
                    c.surface1,
                  )
                  : metal.tone;
          expectAA(c.text1, fill, 'text1/${metal.tone}');
        }
      });

      test('locked badge tiles, white with a dashed outline', () {
        expectAA(c.text1, c.surface1, 'text1/surface1');
        expectAA(c.text2, c.surface1, 'text2/surface1');
        expectAA(c.accentText, c.surface1, 'progress bar caption/surface1');
      });

      test('level ladder threshold numbers on the sure card', () {
        // `sure.background` is translucent on dark (composited over the
        // screen background, like every BirdyBlock fill).
        final fill = Color.alphaBlend(c.sure.background, c.background);
        expectAA(c.text1, fill, 'current threshold/sure');
        expectAA(c.sure.foreground, fill, 'other thresholds/sure');
      });

      test('quiz entry row, white with a line border', () {
        expectAA(c.text1, c.surface1, 'title/surface1');
        expectAA(c.text2, c.surface1, 'subtitle/surface1');
      });

      test('challenge met', () {
        final fill = Color.alphaBlend(c.orioleContainer, c.background);
        expectAA(c.text1, fill, 'text1/oriole');
        expectAA(c.text2, fill, 'text2/oriole');
        expectAA(c.orioleText, fill, 'orioleText/oriole');
        expectAA(c.onOriole, c.oriole, 'check/oriole');
      });

      test('weekly challenge inset, on the tonal color', () {
        final fill = Color.alphaBlend(c.tonal, c.surface1);
        expectAA(c.text1, fill, 'title/tonal');
        expectAA(c.accentText, fill, 'caption/tonal');
      });

      test('plumes counter pill, Loriot container', () {
        final fill = Color.alphaBlend(c.orioleContainer, c.background);
        expectAA(c.orioleText, fill, 'orioleText/orioleContainer');
      });
    });
  }
}
