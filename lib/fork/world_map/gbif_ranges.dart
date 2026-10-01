/// GBIF observation counts of one species per administrative region (J7
/// world map), asked on demand: URLs and the data kept in the disk cache.
/// Pure Dart.
library;

import 'range_class.dart';
import 'world_map_config.dart';

/// Where the map of a species comes from.
enum WorldMapSource { gbif, geomodel }

/// What the map shows: the class of each region (by Natural Earth id; absent
/// = not there) and where it comes from.
class WorldMapData {
  const WorldMapData(this.classes, this.source);

  final Map<String, RangeClass> classes;
  final WorldMapSource source;
}

/// Counts of the four seasons, with the day they were fetched. For a species
/// it carries its GBIF taxon key (kept so a refresh skips the match).
class GbifCounts {
  const GbifCounts({
    required this.fetchedAt,
    required this.counts,
    this.taxonKey,
  });

  final DateTime fetchedAt;
  final SeasonCounts counts;
  final int? taxonKey;
}

/// A species' counts and the all-birds counts they are compared to.
class GbifRange {
  const GbifRange({required this.species, required this.effort});

  final SeasonCounts species;
  final SeasonCounts effort;
}

/// URL of the counts per GADM level-1 region of one [season]: all human
/// observations under open licenses since [WorldMapConfig.gbifFirstYear],
/// of the species [taxonKey], or of every bird when it is null.
Uri gbifFacetUri({
  required int? taxonKey,
  required Season season,
  required int lastYear,
}) => Uri.https(
  WorldMapConfig.gbifApiHost,
  WorldMapConfig.gbifSearchPath,
  {
    'limit': '0',
    'facet': WorldMapConfig.gbifFacet,
    'facetLimit': '${WorldMapConfig.gbifFacetLimit}',
    if (taxonKey != null)
      'taxonKey': '$taxonKey'
    else
      'classKey': '${WorldMapConfig.gbifBirdsClassKey}',
    'basisOfRecord': WorldMapConfig.gbifBasisOfRecord,
    'year': '${WorldMapConfig.gbifFirstYear},$lastYear',
    'license': WorldMapConfig.gbifLicenses,
    'occurrenceStatus': WorldMapConfig.gbifOccurrenceStatus,
    'hasGeospatialIssue': 'false',
    'month': [for (final m in WorldMapConfig.gbifSeasonMonths[season]!) '$m'],
  },
);

/// URL of the species match for [scientificName].
Uri gbifMatchUri(String scientificName) => Uri.https(
  WorldMapConfig.gbifApiHost,
  WorldMapConfig.gbifMatchPath,
  {
    'scientificName': scientificName,
    'class': WorldMapConfig.gbifMatchClass,
  },
);

/// Reads the counts out of a facet answer: GADM id to count.
Map<String, int> parseFacetCounts(Map<String, dynamic> json) {
  final out = <String, int>{};
  final facets = json['facets'];
  if (facets is! List || facets.isEmpty) return out;
  final counts = (facets.first as Map<String, dynamic>)['counts'];
  if (counts is! List) return out;
  for (final c in counts) {
    if (c is Map<String, dynamic> && c['name'] is String && c['count'] is int) {
      out[c['name'] as String] = c['count'] as int;
    }
  }
  return out;
}
