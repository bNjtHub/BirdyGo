/// Shared data of the world map tests: the real region assets and observation
/// counts taken from the design prototype (see fixtures/).
library;

import 'dart:convert';
import 'dart:io';

import 'package:birdnet_live/fork/world_map/range_class.dart';
import 'package:birdnet_live/fork/world_map/world_map_config.dart';
import 'package:birdnet_live/fork/world_map/world_regions.dart';

WorldRegions realRegions() => WorldRegions.fromGzip(
  File(WorldMapConfig.regionsAsset).readAsBytesSync(),
);

GadmJoin realJoin() =>
    GadmJoin.fromGzip(File(WorldMapConfig.gadmJoinAsset).readAsBytesSync());

/// GBIF facet counts of [scientificName] and of every bird, as asked of GBIF
/// in October 2026 (regions with fewer than 5 records of the species left
/// out). Only 'Apus apus' and 'Turdus merula'.
({SeasonCounts species, SeasonCounts effort}) fixtureCounts(
  String scientificName,
) {
  final json =
      jsonDecode(
            utf8.decode(
              gzip.decode(
                File(
                  'test/fork/world_map/fixtures/facets_sample.json.gz',
                ).readAsBytesSync(),
              ),
            ),
          )
          as Map<String, dynamic>;
  final entry = json[scientificName] as Map<String, dynamic>;
  SeasonCounts read(String key) {
    final m = entry[key] as Map<String, dynamic>;
    return {
      for (final s in Season.values)
        s: {
          for (final e in (m[s.name] as Map<String, dynamic>).entries)
            e.key: e.value as int,
        },
    };
  }

  return (species: read('species'), effort: read('effort'));
}

/// Region classes of a fixture species, through the real join.
Map<String, RangeClass> fixtureClasses(String scientificName) {
  final f = fixtureCounts(scientificName);
  return classesOnRegions(classifyGadm(f.species, f.effort), realJoin());
}
