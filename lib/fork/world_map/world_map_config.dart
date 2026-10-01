/// Fork-owned values of the species page world map (J7 « Dans le monde »).
library;

/// The four seasons asked of GBIF and of the geo-model, calendar seasons of
/// the northern hemisphere.
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
  // ---- Region assets (see tools/fork_world_regions.py) ----

  /// Natural Earth admin-1 regions of the whole world and the country borders
  /// (gzip, see the script's header for the format).
  static const String regionsAsset = 'assets/fork/world/regions_admin1.bin.gz';

  /// Precomputed GBIF ranges: class of each region per species (gzip, format
  /// in world_ranges.dart).
  static const String rangesAsset = 'assets/fork/world/ranges.bin.gz';

  /// Units per degree of the regions asset's integer coordinates.
  static const double regionsScale = 100;

  /// Area the assets cover (degrees): the whole world without Antarctica.
  static const double lonMin = -180;
  static const double lonMax = 180;
  static const double latMin = -60;
  static const double latMax = 85;

  /// A frame that crosses the antimeridian (a range on both sides of 180,
  /// drawn Pacific-centred) may reach up to this longitude: the map is drawn
  /// twice, the second copy shifted by [lonPeriod].
  static const double lonWrapMax = 540;
  static const double lonPeriod = 360;

  // ---- Framing: the map is cut to the species' range ----

  /// Margin around the range, in degrees.
  static const double frameMarginDeg = 3;

  /// A range region farther than this (degrees) from every other one is
  /// ignored when framing (a vagrant record must not zoom the map out).
  static const double frameIsolatedDeg = 10;

  /// The framed area is never smaller than this (degrees, per side).
  static const double frameMinSpanDeg = 20;

  /// Width over height of the drawn map, kept between these two by growing
  /// the frame (a very wide or very tall range stays readable on a phone).
  static const double aspectMin = 0.8;
  static const double aspectMax = 1.3;

  /// Latitude beyond which the horizontal scale stops shrinking (cosine of
  /// this latitude at most), so the far north is not squeezed to a sliver.
  static const double maxProjectionLatitude = 60;

  // ---- GBIF credit (the ranges are precomputed, see tools/) ----

  /// GBIF website (the credit under the map links to it).
  static const String gbifSiteUrl = 'https://www.gbif.org';

  /// First year of the observations behind the bundled ranges (shown on the
  /// licenses page).
  static const int gbifFirstYear = 2010;

  /// GBIF SQL download behind the bundled ranges (see tools/README.md): the
  /// citation GBIF asks for is "GBIF.org (date) GBIF Occurrence Download
  /// https://doi.org/doi". Update with the file when it is rebuilt.
  static const String gbifDownloadDoi = '10.15468/dl.yx7895';
  static const String gbifDownloadUrl = 'https://doi.org/$gbifDownloadDoi';

  /// Date of the download (the access date of the citation).
  static final DateTime gbifDownloadDate = DateTime(2026, 10, 2);

  /// Licence of the records kept in the download (CC0 and CC BY 4.0).
  static const String gbifLicenseUrl =
      'https://creativecommons.org/licenses/by/4.0/';

  // ---- Fallback: the geo-model, on a coarse grid ----

  /// Grid step, in degrees, of the geo-model queries (the fallback).
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

  // ---- Legend ----

  /// A class is named in the summary only when its regions make at least
  /// this share of the species' range (by area).
  static const double legendMinShare = 0.1;

  /// Breeding and wintering centres closer than this (km) are not a
  /// migration.
  static const double migrationMinKm = 1000;

  /// Rounding of the distance shown in the legend (km).
  static const double distanceRoundKm = 100;

  // ---- Drawing ----

  /// Width over height of the skeleton and of a map before it is framed.
  static const double aspect = 0.9;

  /// Stroke added to each class fill, in its own color, so the
  /// anti-aliasing seams between adjacent regions of a class vanish and they
  /// read as one zone (dp). Country borders are the only visible lines.
  static const double seamWidth = 0.6;
  static const double countryLineWidth = 1.2;

  /// Opacity of the country borders (the `text2` token).
  static const double countryLineAlpha = 0.6;

  /// Outline of the region the user tapped (dp).
  static const double selectedLineWidth = 2.5;

  /// Dot of the user's position and its outline, in dp.
  static const double userDot = 11;
  static const double userDotRing = 3;

  /// Legend key swatch, in dp.
  static const double keySwatch = 14;

  // ---- Full-screen map ----

  /// Zoom limits, relative to the species' range frame (1 = framed range).
  static const double minScale = 1;
  static const double maxScale = 8;

  /// Factor of a double tap (or of a zoom action of the screen reader).
  static const double doubleTapZoom = 2;

  /// Expand button on the inline map: 48 dp target around this visible disc.
  static const double expandDisc = 36;
}
