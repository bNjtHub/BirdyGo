/// Contrast of the species page header tags and heard inset (J7), in the
/// four bird themes, light and dark: text 4.5:1, outline and icon 3:1.
library;
import 'package:flutter/painting.dart';

import 'package:birdnet_live/fork/design/birdy_theme.dart';
import 'package:birdnet_live/fork/design/birdy_theme_choice.dart';
import 'package:birdnet_live/fork/design/birdy_tokens.dart';
import 'package:birdnet_live/fork/design/species_accents.dart';
import 'package:flutter_test/flutter_test.dart';

double _ratio(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

Color _over(Color top, Color bottom) => Color.alphaBlend(top, bottom);

void main() {
  for (final bird in BirdyBird.values) {
    for (final dark in [false, true]) {
      test('header pills and inset: ${bird.name} ${dark ? 'dark' : 'light'}', () {
        final theme = dark ? BirdyTheme.dark(bird: bird) : BirdyTheme.light(bird: bird);
        final c = theme.extension<BirdyColors>()!;
        final tint = SpeciesAccents.tintOf('Erithacus rubecula');
        final bg = dark ? tint.tintDark : tint.tintLight;
        final ink = dark ? c.text1 : BirdyBrand.ink;
        final chip = _over(c.headerChip, bg);
        final inset = _over(c.headerInset, bg);

        expect(_ratio(ink, chip), greaterThanOrEqualTo(4.5), reason: 'ink on chip');
        expect(_ratio(ink, inset), greaterThanOrEqualTo(4.5), reason: 'ink on inset');
        expect(
          _ratio(c.sure.foreground, _over(c.sure.background, bg)),
          greaterThanOrEqualTo(4.5),
          reason: 'in notebook',
        );
        expect(
          _ratio(c.orioleText, _over(c.orioleContainer, bg)),
          greaterThanOrEqualTo(4.5),
          reason: 'rare',
        );
        expect(
          _ratio(c.sure.foreground, inset),
          greaterThanOrEqualTo(3),
          reason: 'inset icon',
        );
        expect(
          _ratio(c.toCheck.foreground, chip),
          greaterThanOrEqualTo(3),
          reason: 'dashed outline and icon',
        );
        expect(
          _ratio(c.toCheck.foreground, bg),
          greaterThanOrEqualTo(3),
          reason: 'dashed outline on the tint',
        );
      });
    }
  }
}
