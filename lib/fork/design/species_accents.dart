/// Accent color of each species (J6c), until the species icons of J6d carry
/// their own colors.
///
/// The species of the mockup keep their accent (fork/maquette/SPEC.md 2.5);
/// every other species gets a stable hue derived from its scientific name,
/// so it keeps the same color from one session to the next.
library;

import 'package:flutter/painting.dart';

import 'species_tint.dart';

/// Accents of the mockup, by scientific name (SPEC.md 2.5).
const Map<String, Color> kSpeciesAccents = {
  'Erithacus rubecula': Color(0xFFEC7A3C),
  'Cyanistes caeruleus': Color(0xFF3B8FDB),
  'Parus major': Color(0xFFE9C13C),
  'Turdus merula': Color(0xFFF6B12A),
  'Dendrocopos major': Color(0xFFD8343A),
  'Fringilla coelebs': Color(0xFFDD8C6E),
  'Pica pica': Color(0xFF2A9486),
  'Troglodytes troglodytes': Color(0xFFC69A6A),
  'Passer domesticus': Color(0xFFC28A55),
  'Phylloscopus collybita': Color(0xFFA6AA73),
  'Strix aluco': Color(0xFFC49A6C),
  'Upupa epops': Color(0xFFE3A07A),
  'Alcedo atthis': Color(0xFF29A9D6),
  'Oriolus oriolus': Color(0xFFF4C542),
};

/// Saturation and lightness of derived accents: bright enough to read on the
/// dark listening background, soft enough to sit next to the mockup ones.
const double _derivedSaturation = 0.55;
const double _derivedLightness = 0.58;

/// Accent of [scientificName]: the mockup's, else a hue from the name.
Color speciesAccentFor(String scientificName) =>
    kSpeciesAccents[scientificName] ??
    HSLColor.fromAHSL(
      1,
      (_fnv1a(scientificName) % 360).toDouble(),
      _derivedSaturation,
      _derivedLightness,
    ).toColor();

final Map<String, SpeciesTint> _tintCache = {};

/// Shades of [scientificName]'s accent, computed once per species.
SpeciesTint speciesTintFor(String scientificName) => _tintCache.putIfAbsent(
  scientificName,
  () => SpeciesTint.fromAccent(speciesAccentFor(scientificName)),
);

/// 32-bit FNV-1a: unlike [String.hashCode], stable across runs and platforms.
int _fnv1a(String text) {
  var hash = 0x811C9DC5;
  for (final unit in text.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0xFFFFFFFF;
  }
  return hash;
}
