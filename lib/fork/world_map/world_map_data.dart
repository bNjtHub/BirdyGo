/// What the species page world map shows (J7). Pure Dart.
library;

import 'range_class.dart';

/// Where the map of a species comes from.
enum WorldMapSource { gbif, geomodel }

/// What the map shows: the class of each region (by Natural Earth id; absent
/// = not there), where it comes from and, for GBIF, the generation date of
/// the bundled data (yyyymmdd).
class WorldMapData {
  const WorldMapData(this.classes, this.source, {this.generation});

  final Map<String, RangeClass> classes;
  final WorldMapSource source;
  final int? generation;
}
