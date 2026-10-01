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

  // ---- GBIF observations, asked on demand for the species being viewed ----

  /// GBIF API and website (the credit under the map links to the site).
  static const String gbifApiHost = 'api.gbif.org';
  static const String gbifSiteUrl = 'https://www.gbif.org';

  /// Species match: finds the GBIF taxon key of a scientific name. Birds only,
  /// so a homonym in another group is not picked.
  static const String gbifMatchPath = '/v1/species/match';
  static const String gbifMatchClass = 'Aves';

  /// Match types accepted as « this is the species ».
  static const Set<String> gbifMatchTypes = {'EXACT', 'FUZZY'};

  /// Ad hoc occurrence map: PNG tiles, filtered by taxon, months and years.
  /// `{z}/{x}/{y}` are filled in per tile.
  static const String gbifMapPath = '/v2/map/occurrence/adhoc';

  /// Projection of the tiles: plate carree, like this map (EPSG:4326). Zoom 0
  /// is two tiles of 180 degrees, each zoom halves the tile.
  static const String gbifSrs = 'EPSG:4326';

  /// Open licenses only (CC0 and CC BY, never the NonCommercial ones) and
  /// human observations only; records from this year on.
  static const List<String> gbifLicenses = ['CC0_1_0', 'CC_BY_4_0'];
  static const String gbifBasisOfRecord = 'HUMAN_OBSERVATION';
  static const int gbifFirstYear = 2010;

  /// Calendar months of each season (the winter one spans two years; the
  /// year filter is on the observation date, so it is fine).
  static const Map<Season, List<int>> gbifSeasonMonths = {
    Season.winter: [12, 1, 2],
    Season.spring: [3, 4, 5],
    Season.summer: [6, 7, 8],
    Season.autumn: [9, 10, 11],
  };

  /// Zoom of the tiles asked for. Zoom 1 covers the map area with 2 x 2 tiles
  /// of 90 degrees (16 requests for the four seasons); a higher zoom is
  /// finer but costs 4 times the requests.
  static const int gbifZoom = 1;

  /// Tile size in pixels, and the tile extent GBIF measures `squareSize` in.
  static const int gbifTilePx = 512;
  static const int gbifTileExtent = 4096;

  /// Side, in pixels, of one observation square: one cell of the map (0.70
  /// degrees at zoom 1). The `squareSize` parameter follows from it.
  static const int gbifBinPx = 4;
  static int get gbifSquareSize => gbifBinPx * gbifTileExtent ~/ gbifTilePx;

  /// Style of the squares: a count ramp from yellow (few) to red (many), no
  /// outline. Only its green channel is read, which falls with the count.
  static const String gbifStyle = 'classic-noborder.poly';

  /// Green channel (0 to 255) from which a square counts as level 1, then as
  /// level 2; below the second one it is level 3 (the most observed).
  static const List<int> gbifGreenLevelFloors = [200, 100];

  /// A square pixel is observed when its alpha is at least this.
  static const int gbifMinAlpha = 128;

  /// Share of a cell's pixels that must be observed for the cell to count
  /// (the tile rounds a square's position by a pixel or so).
  static const double gbifCellCoverage = 0.5;

  /// Requests in flight at once, and their time limits.
  static const int gbifMaxParallel = 4;
  static const Duration gbifMatchTimeout = Duration(seconds: 6);
  static const Duration gbifTileTimeout = Duration(seconds: 8);

  /// Disk cache of a species map: folder under the app cache directory, how
  /// long a map stays fresh, and the size above which the least recently
  /// shown maps are deleted.
  static const String gbifCacheDirName = 'gbif_maps';
  static const Duration gbifCacheMaxAge = Duration(days: 90);
  static const int gbifCacheMaxBytes = 20 * 1024 * 1024;

  /// Citation required by GBIF for the maps' data: the year is the current
  /// one when the page is read.
  static const String gbifLicenseUrl =
      'https://creativecommons.org/licenses/by/4.0/';

  /// Intensity levels of a GBIF cell (1 faint to this, the strongest). The
  /// asset stores them in two bits.
  static const int gbifLevels = 3;

  /// Opacity of the present color for GBIF level 1, 2 and 3 (index = level -
  /// 1). Same tint, so the map keeps one color meaning (DESIGN.md); the
  /// strongest level is the full color. The geo-model fallback has a single
  /// level, drawn as the strongest.
  static const List<double> levelAlphas = [0.55, 0.78, 1.0];

  /// Grid step, in degrees, of the geo-model queries (the fallback). Also the
  /// size of a drawn geo-model cell; GBIF cells carry their own step.
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

  /// Cells drawn smaller than this (dp, the smaller side) have no gap and no
  /// rounded corners: fine GBIF cells join into areas instead of a hatching.
  static const double cellGapMinSize = 12;

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
