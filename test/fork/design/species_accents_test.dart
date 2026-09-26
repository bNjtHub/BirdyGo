import 'package:birdnet_live/fork/design/birdy_tokens.dart';
import 'package:birdnet_live/fork/design/species_accents.dart';
import 'package:birdnet_live/fork/design/species_tint.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('known species keep the SPEC.md 2.5 accent', () {
    expect(
      SpeciesAccents.accentOf('Erithacus rubecula'),
      const Color(0xFFEC7A3C),
    );
    expect(SpeciesAccents.accentOf('Alcedo atthis'), const Color(0xFF29A9D6));
  });

  test('other species get a stable palette color', () {
    const name = 'Sitta europaea';
    final accent = SpeciesAccents.accentOf(name);
    expect(SpeciesAccents.palette, contains(accent));
    expect(SpeciesAccents.accentOf(name), accent);
    expect(
      identical(SpeciesAccents.tintOf(name), SpeciesAccents.tintOf(name)),
      isTrue,
    );
  });

  test('the palette spreads species over several colors', () {
    final used = {
      for (final name in [
        'Sitta europaea',
        'Certhia brachydactyla',
        'Regulus regulus',
        'Aegithalos caudatus',
        'Sylvia atricapilla',
        'Columba palumbus',
        'Streptopelia decaocto',
        'Garrulus glandarius',
      ])
        SpeciesAccents.accentOf(name),
    };
    expect(used.length, greaterThan(3));
  });

  test('every accent stays visible on Encre de nuit (3:1)', () {
    for (final color in [
      ...SpeciesAccents.palette,
      ...SpeciesAccents.known.values,
    ]) {
      expect(
        contrastRatio(color, BirdyBrand.ink),
        greaterThanOrEqualTo(3),
        reason: color.toString(),
      );
    }
  });
}
