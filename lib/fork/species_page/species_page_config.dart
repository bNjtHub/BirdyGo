/// Fork-owned values of the species page (J6c « Fiche espèce »).
library;

abstract final class SpeciesPageConfig {
  /// Recordings listed under « Mes sons » (the sound library has them all).
  static const int clipsShown = 3;

  /// Most places drawn on the mini map.
  static const int mapSpots = 30;

  /// Mini map zoom when every contact is at one place.
  static const double miniMapSingleZoom = 12;

  /// Places closer than this rounding (decimals of a degree) share a dot.
  static const int spotDecimals = 3;
}
