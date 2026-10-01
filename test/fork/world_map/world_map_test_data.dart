/// Shared data of the world map tests: the real region assets and a small
/// ranges file written on the fly (same format as the bundled
/// `ranges.bin.gz`, see lib/fork/world_map/world_ranges.dart).
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:birdnet_live/fork/world_map/range_class.dart';
import 'package:birdnet_live/fork/world_map/world_map_config.dart';
import 'package:birdnet_live/fork/world_map/world_ranges.dart';
import 'package:birdnet_live/fork/world_map/world_regions.dart';

WorldRegions realRegions() => WorldRegions.fromGzip(
  File(WorldMapConfig.regionsAsset).readAsBytesSync(),
);

/// Decompressed bytes of a ranges file: [species] maps a scientific name to
/// the class of each region index. Names are written sorted, as the real
/// file has them.
Uint8List writeRanges(
  Map<String, Map<int, RangeClass>> species, {
  int generation = 20261001,
}) {
  final out = BytesBuilder();
  void u16(int v) => out.add([v & 0xFF, (v >> 8) & 0xFF]);
  out.add(ascii.encode('BGR1'));
  out.add([
    generation & 0xFF,
    (generation >> 8) & 0xFF,
    (generation >> 16) & 0xFF,
    (generation >> 24) & 0xFF,
  ]);
  u16(species.length);
  for (final name in species.keys.toList()..sort()) {
    final bytes = utf8.encode(name);
    out.addByte(bytes.length);
    out.add(bytes);
    final entries = species[name]!;
    u16(entries.length);
    for (final e in entries.entries) {
      u16((e.key << 2) | kRangeClassCodes.indexOf(e.value));
    }
  }
  return out.toBytes();
}

/// Same as [writeRanges], gzipped.
Uint8List writeRangesGzip(
  Map<String, Map<int, RangeClass>> species, {
  int generation = 20261001,
}) => Uint8List.fromList(
  gzip.encode(writeRanges(species, generation: generation)),
);

/// Regions of [regions] whose centroid satisfies [test], with [cls].
Map<int, RangeClass> _where(
  WorldRegions regions,
  RangeClass cls,
  bool Function(double lat, double lon) test,
) => {
  for (var i = 0; i < regions.regions.length; i++)
    if (test(
      regions.regions[i].centroid.latitude,
      regions.regions[i].centroid.longitude,
    ))
      i: cls,
};

/// Fixture ranges of two species over the real regions: 'Apus apus' nests in
/// Europe and winters in southern Africa, 'Turdus merula' stays all year in
/// Europe.
Map<String, Map<int, RangeClass>> fixtureSpecies(WorldRegions regions) => {
  'Apus apus': {
    ..._where(
      regions,
      RangeClass.breeding,
      (lat, lon) => lat >= 36 && lon >= -10 && lon <= 60,
    ),
    ..._where(
      regions,
      RangeClass.wintering,
      (lat, lon) => lat >= -35 && lat < 5 && lon >= -20 && lon <= 50,
    ),
  },
  'Turdus merula': _where(
    regions,
    RangeClass.resident,
    (lat, lon) => lat >= 30 && lon >= -10 && lon <= 60,
  ),
};

/// The fixture ranges as the app reads them.
WorldRanges fixtureRanges(WorldRegions regions) =>
    WorldRanges.fromGzip(writeRangesGzip(fixtureSpecies(regions)));

/// Region classes (by region id) of a fixture species, through the reader.
Map<String, RangeClass> fixtureClasses(
  WorldRegions regions,
  String scientificName,
) => {
  for (final e in fixtureRanges(regions).entriesOf(scientificName)!.entries)
    regions.regions[e.key].id: e.value,
};
