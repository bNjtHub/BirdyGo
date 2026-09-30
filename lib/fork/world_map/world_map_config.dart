/// Fork-owned values of the species page world map (J7 « Dans le monde »).
library;

/// The four seasons of the selector, calendar seasons of the northern
/// hemisphere (the default view is Europe, Africa and West Asia).
enum Season {
  winter,
  spring,
  summer,
  autumn;

  /// Season of calendar [month] (1 to 12): December to February is winter,
  /// and so on.
  static Season ofMonth(int month) => switch (month) {
    12 || 1 || 2 => winter,
    3 || 4 || 5 => spring,
    6 || 7 || 8 => summer,
    _ => autumn,
  };
}

abstract final class WorldMapConfig {
  /// Asset holding the Natural Earth 1:110m land outline
  /// (see tools/fork_land_110m.py and assets/fork/world/LICENSE.txt).
  static const String landAsset = 'assets/fork/world/land_110m.bin';

  /// Units per degree of the outline asset's integer coordinates.
  static const double landScale = 100;

  /// Default view: Europe, Africa and West Asia (degrees).
  static const double lonMin = -25;
  static const double lonMax = 65;
  static const double latMin = -35;
  static const double latMax = 70;

  /// Width over height of the drawn map. Slightly wider than the true
  /// proportions of the view (about 0.82), so the block stays short on a
  /// phone.
  static const double aspect = 0.9;

  /// Grid step, in degrees, of the geo-model queries. Also the size of a
  /// drawn cell.
  static const double gridStep = 5;

  /// Geo-model week (1 to 48, 4 per month) asked for each season: the second
  /// week of January, April, July and October.
  static const Map<Season, int> seasonWeeks = {
    Season.winter: 2,
    Season.spring: 14,
    Season.summer: 26,
    Season.autumn: 38,
  };

  /// Predictions made before a pause, so the UI thread keeps its frames while
  /// the four seasons are computed.
  static const int batchSize = 6;

  /// Pause after each batch.
  static const Duration batchPause = Duration(milliseconds: 8);

  /// Summer and winter centres closer than this (km) are not a migration.
  static const double migrationMinKm = 1000;

  /// Rounding of the distance shown in the legend (km).
  static const double distanceRoundKm = 100;

  /// Fraction of a cell left empty around it when drawn.
  static const double cellInset = 0.08;

  /// Corner radius of a cell, as a fraction of its size.
  static const double cellRadius = 0.22;

  /// Opacity of the cells where the species is expected in another season
  /// only (they show where it moves to and from).
  static const double ghostAlpha = 0.3;

  /// Dot of the user's position and its outline, in dp.
  static const double userDot = 11;
  static const double userDotRing = 3;

  /// Legend key swatch, in dp.
  static const double keySwatch = 14;
}
