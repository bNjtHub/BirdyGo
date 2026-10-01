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

  /// Natural Earth admin-1 regions of the map area and the country borders
  /// (gzip, see the script's header for the format).
  static const String regionsAsset = 'assets/fork/world/regions_admin1.bin.gz';

  /// Join table: GADM level-1 id -> Natural Earth region ids (gzip JSON).
  static const String gadmJoinAsset = 'assets/fork/world/gadm1_to_regions.json.gz';

  /// Units per degree of the regions asset's integer coordinates.
  static const double regionsScale = 100;

  /// Area the assets cover (degrees): Europe, Africa and West Asia.
  static const double lonMin = -25;
  static const double lonMax = 65;
  static const double latMin = -35;
  static const double latMax = 72;

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

  /// Occurrence search, counted per GADM level-1 region (a facet: no record is
  /// downloaded, only one count per region).
  static const String gbifSearchPath = '/v1/occurrence/search';
  static const String gbifFacet = 'gadmLevel1Gid';

  /// Most regions a facet answer holds (there are about 3 600 GADM level-1
  /// regions on Earth, 1 800 of them in the map area).
  static const int gbifFacetLimit = 5000;

  /// GBIF key of the class Aves: the « all birds » counts are the observation
  /// effort of each region.
  static const int gbifBirdsClassKey = 212;

  /// Open licenses only (CC0 and CC BY, never the NonCommercial ones) and
  /// human observations only; records from this year on.
  static const List<String> gbifLicenses = ['CC0_1_0', 'CC_BY_4_0'];
  static const String gbifBasisOfRecord = 'HUMAN_OBSERVATION';
  static const String gbifOccurrenceStatus = 'PRESENT';
  static const int gbifFirstYear = 2010;

  /// Calendar months of each season (the winter one spans two years; the
  /// year filter is on the observation date, so it is fine).
  static const Map<Season, List<int>> gbifSeasonMonths = {
    Season.winter: [12, 1, 2],
    Season.spring: [3, 4, 5],
    Season.summer: [6, 7, 8],
    Season.autumn: [9, 10, 11],
  };

  /// Requests in flight at once (GBIF is polite-use: two at most).
  static const int gbifMaxParallel = 2;

  /// Time limits: species match, then one facet count (slower, GBIF
  /// aggregates millions of records).
  static const Duration gbifMatchTimeout = Duration(seconds: 6);
  static const Duration gbifFacetTimeout = Duration(seconds: 25);

  /// A request answered 429 or 5xx is asked again after these pauses (so the
  /// number of retries is the list length); other errors are not retried.
  static const List<Duration> gbifRetryDelays = [
    Duration(seconds: 1),
    Duration(seconds: 3),
    Duration(seconds: 8),
  ];

  /// Disk cache: folder under the app cache directory; how long a species'
  /// counts stay fresh; how long the all-birds effort does (it changes
  /// slowly, and costs 4 requests shared by every species); the size above
  /// which the least recently shown files are deleted.
  static const String gbifCacheDirName = 'gbif_ranges';
  static const Duration gbifCacheMaxAge = Duration(days: 90);
  static const Duration gbifEffortMaxAge = Duration(days: 180);
  static const int gbifCacheMaxBytes = 20 * 1024 * 1024;

  /// Cache file name of the all-birds effort (no species file can have it:
  /// species names have a letter in them).
  static const String gbifEffortCacheName = '0_all_birds';

  /// Citation required by GBIF for the maps' data: the year is the current
  /// one when the page is read.
  static const String gbifLicenseUrl =
      'https://creativecommons.org/licenses/by/4.0/';

  // ---- Presence by region (thresholds of the classification) ----

  /// A region counts in a season when all birds were recorded there at least
  /// [minEffort] times (below that, a rate means nothing), the species at
  /// least [minSpeciesRecords] times, and its reporting rate (species over all
  /// birds) is at least [minRate].
  static const int minEffort = 200;
  static const int minSpeciesRecords = 5;
  static const double minRate = 0.003;

  /// Relative criterion against the noise of little-watched regions: a rate
  /// must also reach this fraction of the species' median rate over the
  /// regions and seasons that passed the thresholds above. At 0.1 a common
  /// bird's stray records are dropped while a scarce winter visitor, whose
  /// rate is a few times below its breeding rate, stays.
  static const double relativeRate = 0.1;

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

  /// Hairline between regions and the thicker line of country borders (dp).
  static const double regionLineWidth = 0.5;
  static const double countryLineWidth = 1.2;

  /// Opacity of the hairline between regions (the block's fill token): soft
  /// enough that small regions do not turn into lace.
  static const double regionLineAlpha = 0.6;

  /// Opacity of the country borders (the `text2` token).
  static const double countryLineAlpha = 0.6;

  /// Outline of the region the user tapped (dp).
  static const double selectedLineWidth = 2.5;

  /// Dot of the user's position and its outline, in dp.
  static const double userDot = 11;
  static const double userDotRing = 3;

  /// Legend key swatch, in dp.
  static const double keySwatch = 14;
}
