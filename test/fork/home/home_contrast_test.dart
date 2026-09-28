import 'package:birdnet_live/fork/design/birdy_tokens.dart';
import 'package:birdnet_live/fork/design/species_accents.dart';
import 'package:birdnet_live/fork/design/species_tint.dart';
import 'package:birdnet_live/fork/home/home_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Contrast of the new color pairs of the J6f home blocks.
void main() {
  final accents = [
    ...SpeciesAccents.known.values,
    ...SpeciesAccents.palette,
    BirdyBrand.bark, // neutral tint
  ];

  void expectAtLeast(Color fg, Color bg, double min, String name) {
    final ratio = contrastRatio(fg, bg);
    expect(
      ratio,
      greaterThanOrEqualTo(min),
      reason: '$name: ${ratio.toStringAsFixed(2)}:1 < $min:1',
    );
  }

  for (final (theme, c) in [
    ('light', BirdyColors.light),
    ('dark', BirdyColors.dark),
  ]) {
    test('$theme: hero texts on every species tint', () {
      for (final accent in accents) {
        final fill = SpeciesTint.fromAccent(
          accent,
        ).cardBackground(c.brightness);
        final hex = accent.toARGB32().toRadixString(16);
        expectAtLeast(c.text1, fill, 4.5, 'text1 on $hex');
        expectAtLeast(c.text2, fill, 4.5, 'text2 on $hex');
      }
    });

    Color over(Color color) => Color.alphaBlend(color, c.background);

    test('$theme: block numbers and captions', () {
      // « 12 » and its icon on the to-check block.
      expectAtLeast(c.toCheck.foreground, c.surface1, 4.5, 'toCheck count');
      // « 24/35 » and the bar on the status block.
      expectAtLeast(
        c.sure.foreground,
        over(c.sure.background),
        4.5,
        'sure count',
      );
      // Goal title on the tonal block, série caption on Loriot.
      expectAtLeast(c.accentText, over(c.tonal), 4.5, 'goal title');
      expectAtLeast(
        c.orioleText,
        over(c.orioleContainer),
        4.5,
        'série caption',
      );
      // Listened day dots (non-text, 3:1).
      expectAtLeast(c.orioleText, over(c.orioleContainer), 3, 'day dot');
    });
  }

  test('replay icon keeps 3:1 on every species accent', () {
    for (final accent in accents) {
      expectAtLeast(
        inkOnAccent(accent),
        accent,
        3,
        accent.toARGB32().toRadixString(16),
      );
    }
    expect(inkOnAccent(const Color(0xFFEC7A3C)), BirdyBrand.ink);
    expect(inkOnAccent(const Color(0xFF1B2A3A)), BirdyBrand.mist);
  });
}
