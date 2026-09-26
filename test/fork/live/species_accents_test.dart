import 'dart:ui';

import 'package:birdnet_live/fork/design/birdy_tokens.dart';
import 'package:birdnet_live/fork/design/species_accents.dart';
import 'package:birdnet_live/fork/design/species_tint.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('mockup species keep their accent (SPEC.md 2.5)', () {
    expect(speciesAccentFor('Erithacus rubecula'), const Color(0xFFEC7A3C));
    expect(speciesAccentFor('Alcedo atthis'), const Color(0xFF29A9D6));
    expect(kSpeciesAccents, hasLength(14));
  });

  test('other species get a stable accent of their own', () {
    final a = speciesAccentFor('Sitta europaea');
    expect(speciesAccentFor('Sitta europaea'), a);
    expect(speciesAccentFor('Certhia brachydactyla'), isNot(a));
  });

  test('derived accents read on the dark listening background', () {
    for (final name in [
      'Sitta europaea',
      'Certhia brachydactyla',
      'Aegithalos caudatus',
      'Columba palumbus',
      'Garrulus glandarius',
    ]) {
      expect(
        contrastRatio(speciesAccentFor(name), BirdyBrand.ink),
        greaterThanOrEqualTo(3),
        reason: name,
      );
    }
  });

  test('tints are cached', () {
    expect(
      identical(speciesTintFor('Pica pica'), speciesTintFor('Pica pica')),
      isTrue,
    );
  });
}
