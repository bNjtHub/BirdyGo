import 'package:birdnet_live/fork/design/birdy_tokens.dart';
import 'package:birdnet_live/fork/design/species_tint.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// SPEC.md 2.5: accent and tintDark of the 14 species icons.
const _spec = <(int, int)>[
  (0xFFEC7A3C, 0xFF47383A),
  (0xFF3B8FDB, 0xFF1D3D61),
  (0xFFE9C13C, 0xFF46493A),
  (0xFFF6B12A, 0xFF494536),
  (0xFFD8343A, 0xFF42273A),
  (0xFFDD8C6E, 0xFF433C46),
  (0xFF2A9486, 0xFF193E4C),
  (0xFFC69A6A, 0xFF3E4046),
  (0xFFC28A55, 0xFF3D3C40),
  (0xFFA6AA73, 0xFF364348),
  (0xFFC49A6C, 0xFF3D4046),
  (0xFFE3A07A, 0xFF454149),
  (0xFF29A9D6, 0xFF18435F),
  (0xFFF4C542, 0xFF494A3C),
];

void expectReadable(SpeciesTint t) {
  expect(
    contrastRatio(BirdyBrand.ink, t.tintLight),
    greaterThanOrEqualTo(SpeciesTint.minInkContrast),
  );
  expect(
    contrastRatio(t.deep, const Color(0xFFFFFFFF)),
    greaterThanOrEqualTo(SpeciesTint.minDeepContrast),
  );
  expect(contrastRatio(BirdyBrand.mist, t.tintDark), greaterThanOrEqualTo(4.5));
}

int _rgb(Color c) => c.toARGB32() & 0xFFFFFF;

void main() {
  test('tintDark matches the spec table', () {
    for (final (accent, tintDark) in _spec) {
      final t = SpeciesTint.fromAccent(Color(accent));
      expect(
        (_rgb(t.tintDark) - (tintDark & 0xFFFFFF)).abs(),
        lessThanOrEqualTo(0x010101),
        reason: accent.toRadixString(16),
      );
    }
  });

  test('every spec species gets readable shades', () {
    for (final (accent, _) in _spec) {
      expectReadable(SpeciesTint.fromAccent(Color(accent)));
    }
  });

  test('deep keeps the accent when it is already dark enough', () {
    const woodpecker = Color(0xFFD8343A);
    expect(SpeciesTint.fromAccent(woodpecker).deep, woodpecker);
  });

  test('extreme accents stay readable', () {
    for (final accent in const [
      Color(0xFFFFFFFF),
      Color(0xFF000000),
      Color(0xFFFFFF00),
      Color(0xFF00FF00),
      Color(0x8019A7B3),
    ]) {
      expectReadable(SpeciesTint.fromAccent(accent));
    }
  });

  test('neutral tint and helpers', () {
    expectReadable(SpeciesTint.neutral);
    final t = SpeciesTint.fromAccent(const Color(0xFFEC7A3C));
    expect(t.halo.a, closeTo(0.20, 0.01));
    expect(t.glow.a, closeTo(0.22, 0.01));
    expect(t.cardBackground(Brightness.dark), t.tintDark);
    expect(t.cardBackground(Brightness.light), t.tintLight);
    expect(t, SpeciesTint.fromAccent(const Color(0xFFEC7A3C)));
  });
}
