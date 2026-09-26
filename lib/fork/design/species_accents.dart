/// Accent color of each species (J6c), until the species icons of J6d bring
/// their own color table.
///
/// Known species take the accent of fork/maquette/SPEC.md (section 2.5).
/// Others get a stable color from a small palette, picked from a hash of the
/// scientific name, so a species keeps its color from one outing to the next.
library;

import 'package:flutter/painting.dart';

import 'species_tint.dart';

abstract final class SpeciesAccents {
  /// SPEC.md 2.5, keyed by scientific name.
  static const Map<String, Color> known = {
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

  /// Fallback accents: distinct hues, each at least 3:1 on Encre de nuit so
  /// a mark or a halo stays visible on the listening screen.
  static const List<Color> palette = [
    Color(0xFFE38B5B),
    Color(0xFF5AA9E6),
    Color(0xFFD9B84A),
    Color(0xFF6FBF8E),
    Color(0xFFC7849E),
    Color(0xFF9C8FD6),
    Color(0xFF4DB6AC),
    Color(0xFFD98C4A),
    Color(0xFFA7B85C),
    Color(0xFFE07A7A),
  ];

  static final Map<String, SpeciesTint> _tints = {};

  /// Accent of [scientificName].
  static Color accentOf(String scientificName) =>
      known[scientificName] ?? palette[_hash(scientificName) % palette.length];

  /// Species colors of [scientificName], computed once per species.
  static SpeciesTint tintOf(String scientificName) => _tints.putIfAbsent(
    scientificName,
    () => SpeciesTint.fromAccent(accentOf(scientificName)),
  );

  /// FNV-1a: stable across runs and platforms, unlike [String.hashCode].
  static int _hash(String value) {
    var hash = 0x811c9dc5;
    for (final unit in value.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return hash;
  }
}
