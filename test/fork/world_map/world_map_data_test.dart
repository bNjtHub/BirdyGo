/// World map data (J7): the region assets, the join GADM -> regions, the
/// classification of the observation counts (with counts of the prototype),
/// the fallback from the geo-model, framing, the legend, and the four seasons
/// with a fake geo-model.
library;

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:birdnet_live/fork/world_map/range_class.dart';
import 'package:birdnet_live/fork/world_map/range_frame.dart';
import 'package:birdnet_live/fork/world_map/range_legend.dart';
import 'package:birdnet_live/fork/world_map/season_presence.dart';
import 'package:birdnet_live/fork/world_map/world_grid.dart';
import 'package:birdnet_live/fork/world_map/world_map_config.dart';
import 'package:birdnet_live/fork/world_map/world_regions.dart';
import 'package:flutter_test/flutter_test.dart';

import 'world_map_test_data.dart';

/// A fake geo-model: [presence] says where and when [species] is expected.
GeoPredict _fake(
  String species,
  bool Function(double lat, double lon, int week) presence, {
  void Function()? onCall,
}) => ({
  required double latitude,
  required double longitude,
  required int week,
}) async {
  onCall?.call();
  return {
    species: presence(latitude, longitude, week) ? 0.4 : 0.0,
    'Other species': 0.9,
  };
};

const _migrant = 'Hirundo rustica';

/// Summer in the north (55N and up, 10W to 40E), winter in West Africa.
bool _migrantPresence(double lat, double lon, int week) {
  final summer = week >= 22 && week <= 30;
  final winter = week <= 6 || week >= 42;
  if (summer) return lat >= 55 && lon >= -10 && lon <= 40;
  if (winter) return lat >= 0 && lat <= 15 && lon >= -20 && lon <= 10;
  return false;
}

/// Counts of one region id, the same in every season given.
SeasonCounts _counts(Map<Season, Map<String, int>> by) => {
  for (final s in Season.values) s: by[s] ?? const {},
};

void main() {
  late WorldRegions regions;
  late GadmJoin join;

  setUpAll(() {
    regions = realRegions();
    join = realJoin();
  });

  group('region assets', () {
    test('are small and hold the regions of the area', () {
      final size =
          File(WorldMapConfig.regionsAsset).lengthSync() +
          File(WorldMapConfig.gadmJoinAsset).lengthSync();
      expect(size, lessThan(500 * 1024));
      expect(regions.regions.length, greaterThan(2500));
      expect(regions.borders, isNotEmpty);
    });

    test('point in polygon: a region, and the sea', () {
      final paris = regions.regionAt(2.35, 48.85);
      expect(paris, isNotNull);
      expect(paris!.name, 'Paris');
      expect(regions.regionAt(-20, 40), isNull, reason: 'Atlantic');
      expect(regions.byId(paris.id), same(paris));
      expect(paris.centroid.latitude, closeTo(48.86, 0.1));
      expect(paris.area, greaterThan(0));
    });

    test('ids are unique and every region has a ring', () {
      expect(
        regions.regions.map((r) => r.id).toSet().length,
        regions.regions.length,
      );
      final empty = regions.regions.where((r) => r.rings.isEmpty).length;
      expect(empty, lessThan(10), reason: 'only specks vanish in simplifying');
    });

    test('parses the documented format', () {
      // "BGR1", 1 region "A-1" named "Zed" with a triangle 0,0 / 1,0 / 0,1
      // (100 units per degree, zigzag varints, deltas), no border.
      final bytes = Uint8List.fromList([
        0x42, 0x47, 0x52, 0x31, 1, 0, //
        3, 0x41, 0x2D, 0x31, 3, 0x5A, 0x65, 0x64, //
        1, 3, 0, 0, 0xC8, 0x01, 0, 0xC7, 0x01, 0xC8, 0x01, //
        0,
      ]);
      final parsed = WorldRegions.parse(bytes);
      expect(parsed.regions.single.id, 'A-1');
      expect(parsed.regions.single.name, 'Zed');
      expect(parsed.regions.single.contains(0.2, 0.2), isTrue);
      expect(parsed.regions.single.contains(0.9, 0.9), isFalse);
      expect(parsed.borders, isEmpty);
    });

    test('the paths are built once', () {
      final r = regions.regionAt(2.35, 48.85)!;
      expect(identical(r.path, r.path), isTrue);
      expect(identical(regions.landPath, regions.landPath), isTrue);
    });

    test('the join is keys only and points at real regions', () {
      expect(join.regionsOf.length, greaterThan(1500));
      final seen = <String>{};
      for (final e in join.regionsOf.entries) {
        expect(e.key, matches(RegExp(r'^[A-Z]{3}[0-9.]*_[0-9]+$')));
        for (final id in e.value) {
          expect(regions.byId(id), isNotNull, reason: id);
          expect(seen.add(id), isTrue, reason: '$id joined twice');
        }
      }
      // Most regions of the area are reachable from GBIF counts.
      expect(seen.length, greaterThan(regions.regions.length * 0.9));
    });

    test('joins a GADM region onto its map regions', () {
      final fake = GadmJoin({
        'FRA.1_1': ['A', 'B'],
      });
      final out = classesOnRegions({
        'FRA.1_1': RangeClass.breeding,
        'XXX.1_1': RangeClass.resident,
      }, fake);
      expect(out, {'A': RangeClass.breeding, 'B': RangeClass.breeding});
    });
  });

  group('classification of the counts', () {
    test('a migrant: nesting in Europe, wintering in Africa, none between', () {
      final c = fixtureClasses('Apus apus');
      expect(c[regions.regionAt(2.35, 48.85)!.id], RangeClass.breeding);
      expect(c[regions.regionAt(10, 62)!.id], RangeClass.breeding);
      final africa = [
        for (final e in c.entries)
          if (regions.byId(e.key)!.centroid.latitude < 5 &&
              regions.byId(e.key)!.centroid.longitude > -20 &&
              regions.byId(e.key)!.centroid.longitude < 50)
            e.value,
      ];
      // The relative criterion must not erase the African winter.
      expect(
        africa.where((v) => v == RangeClass.wintering).length,
        greaterThan(15),
      );
      expect(africa.where((v) => v == RangeClass.breeding).length, lessThan(5));
    });

    test('a resident stays all year', () {
      final c = fixtureClasses('Turdus merula');
      expect(c[regions.regionAt(2.35, 48.85)!.id], RangeClass.resident);
      expect(c[regions.regionAt(20, 64)!.id], RangeClass.resident);
      final residents = c.values.where((v) => v == RangeClass.resident).length;
      expect(residents, greaterThan(c.length * 0.5));
    });

    test('summer and winter make a resident, one of them alone the rest', () {
      final effort = _counts({
        for (final s in Season.values) s: {'a': 1000, 'b': 1000, 'c': 1000, 'd': 1000, 'e': 1000},
      });
      final species = _counts({
        Season.summer: {'a': 50, 'b': 50, 'e': 50},
        Season.winter: {'a': 50, 'c': 50},
        Season.autumn: {'d': 50},
      });
      expect(classifyGadm(species, effort), {
        'a': RangeClass.resident,
        'b': RangeClass.breeding,
        'c': RangeClass.wintering,
        'd': RangeClass.passage,
        'e': RangeClass.breeding,
      });
    });

    test('noise: little effort, few records, a very low rate', () {
      final effort = _counts({
        Season.summer: {
          'ok': 1000,
          'lowEffort': 199,
          'fewRecords': 1000,
          'lowRate': 100000,
        },
      });
      final species = _counts({
        Season.summer: {
          'ok': 10,
          'lowEffort': 100,
          'fewRecords': 4,
          'lowRate': 200, // 0.2 %
        },
      });
      expect(classifyGadm(species, effort), {'ok': RangeClass.breeding});
      // Exactly at the thresholds counts.
      expect(
        classifyGadm(
          _counts({Season.summer: {'x': 5}}),
          _counts({Season.summer: {'x': 200}}),
          minRate: 0.0,
        ),
        {'x': RangeClass.breeding},
      );
      expect(classifyGadm(const {}, const {}), isEmpty);
    });

    test('the relative rate drops the stray records of a common bird', () {
      // Median rate 10 %: the floor is 1 %. 'stray' has 0.5 % (above the
      // absolute 0.3 %), 'rare' has 2 % and stays.
      final effort = _counts({
        Season.summer: {
          for (var i = 0; i < 9; i++) 'core$i': 10000,
          'stray': 10000,
          'rare': 10000,
        },
      });
      final species = _counts({
        Season.summer: {
          for (var i = 0; i < 9; i++) 'core$i': 1000,
          'stray': 50,
          'rare': 200,
        },
      });
      final out = classifyGadm(species, effort);
      expect(out.containsKey('stray'), isFalse);
      expect(out.containsKey('rare'), isTrue);
      expect(
        classifyGadm(species, effort, relativeRate: 0).containsKey('stray'),
        isTrue,
      );
    });
  });

  group('fallback from the geo-model', () {
    test('a region takes the class of the cell holding its centroid', () async {
      final cells = landCells(regions);
      final presence = await computeSeasonPresence(
        scientificName: _migrant,
        predict: _fake(_migrant, _migrantPresence),
        cells: cells,
        pause: Duration.zero,
      );
      final c = classesFromPresence(presence, regions);
      expect(c[regions.regionAt(10, 62)!.id], RangeClass.breeding);
      expect(c[regions.regionAt(-1, 8)!.id], RangeClass.wintering);
      expect(c.containsKey(regions.regionAt(2.35, 48.85)!.id), isFalse);
      expect(
        c.values.toSet(),
        {RangeClass.breeding, RangeClass.wintering},
      );
    });
  });

  group('framing', () {
    String? idAt(double lon, double lat) => regions.regionAt(lon, lat)?.id;

    test('a local range is cut tight, within the aspect bounds', () {
      final ids = [for (final p in [(2.3, 48.8), (4.8, 45.7), (-1.6, 47.2), (1.4, 43.6)]) idAt(p.$1, p.$2)!];
      final f = frameOf(regions, {for (final id in ids) id: RangeClass.resident});
      expect(f.lon1 - f.lon0, lessThan(40));
      expect(f.lon0, lessThan(2.3));
      expect(f.lon1, greaterThan(4.8));
      expect(f.lat0, lessThan(43.6));
      expect(f.lat1, greaterThan(48.8));
      expect(frameAspect(f), inInclusiveRange(WorldMapConfig.aspectMin - 1e-6, WorldMapConfig.aspectMax + 1e-6));
    });

    test('an isolated record far away is ignored', () {
      final france = [for (final p in [(2.3, 48.8), (4.8, 45.7), (-1.6, 47.2), (1.4, 43.6)]) idAt(p.$1, p.$2)!];
      final far = idAt(24, -3)!; // Congo basin
      final f = frameOf(regions, {
        for (final id in france) id: RangeClass.breeding,
        far: RangeClass.passage,
      });
      expect(f.lat0, greaterThan(20));
    });

    test('nothing to frame: the whole area; one region: the minimum span', () {
      expect(frameOf(regions, const {}), kWorldFrame);
      final one = frameOf(regions, {idAt(2.3, 48.8)!: RangeClass.resident});
      expect(one.lon1 - one.lon0, greaterThanOrEqualTo(WorldMapConfig.frameMinSpanDeg - 1e-6));
      expect(one.lat1 - one.lat0, greaterThanOrEqualTo(WorldMapConfig.frameMinSpanDeg - 1e-6));
    });

    test('never leaves the map area', () {
      for (final sci in ['Apus apus', 'Turdus merula']) {
        final f = frameOf(regions, fixtureClasses(sci));
        expect(f.lon0, greaterThanOrEqualTo(WorldMapConfig.lonMin));
        expect(f.lon1, lessThanOrEqualTo(WorldMapConfig.lonMax));
        expect(f.lat0, greaterThanOrEqualTo(WorldMapConfig.latMin));
        expect(f.lat1, lessThanOrEqualTo(WorldMapConfig.latMax));
      }
    });
  });

  group('legend', () {
    test('a migrant: nesting and wintering areas, and the distance', () {
      final l = buildRangeLegend(regions, fixtureClasses('Apus apus'));
      expect(l.regions[RangeClass.breeding], isNotNull);
      expect(l.regions[RangeClass.wintering], isNotNull);
      expect(
        {
          WorldRegion.southernAfrica,
          WorldRegion.centralAfrica,
          WorldRegion.eastAfrica,
          WorldRegion.westAfrica,
        },
        contains(l.regions[RangeClass.wintering]),
      );
      expect(l.distanceKm, greaterThan(WorldMapConfig.migrationMinKm));
      expect(l.distanceKm! % WorldMapConfig.distanceRoundKm.round(), 0);
    });

    test('a resident: told by its main region, no migration distance', () {
      final l = buildRangeLegend(regions, fixtureClasses('Turdus merula'));
      expect(l.regions[RangeClass.resident], isNotNull);
      expect(l.distanceKm, isNull);
    });

    test('nothing at all', () {
      expect(buildRangeLegend(regions, const {}).isEmpty, isTrue);
    });

    test('regions and distance', () {
      expect(regionOf(48.8, 2.3), WorldRegion.westernEurope);
      expect(regionOf(-30, 25), WorldRegion.southernAfrica);
      expect(regionOf(-60, 0), WorldRegion.other);
      expect(
        distanceKm((latitude: 0, longitude: 0), (latitude: 0, longitude: 1)),
        closeTo(111.2, 0.5),
      );
    });
  });

  group('land grid and four seasons with a fake geo-model', () {
    late List<GridCell> cells;
    setUpAll(() => cells = landCells(regions));

    test('keeps only cells on land, inside the view', () {
      expect(cells.length, inInclusiveRange(150, 400));
      for (final c in cells) {
        expect(c.longitude, inInclusiveRange(WorldMapConfig.lonMin, WorldMapConfig.lonMax));
        expect(c.latitude, inInclusiveRange(WorldMapConfig.latMin, WorldMapConfig.latMax));
      }
      expect(cells, contains((latitude: 49.5, longitude: 2.5)));
      expect(cells, isNot(contains((latitude: 34.5, longitude: -17.5))));
    });

    test('a migrant moves, a resident stays', () async {
      final migrant = await computeSeasonPresence(
        scientificName: _migrant,
        predict: _fake(_migrant, _migrantPresence),
        cells: cells,
        pause: Duration.zero,
      );
      expect(migrant.cellsOf(Season.summer), isNotEmpty);
      expect(migrant.cellsOf(Season.winter), isNotEmpty);
      expect(migrant.cellsOf(Season.spring), isEmpty);

      final resident = await computeSeasonPresence(
        scientificName: _migrant,
        predict: _fake(_migrant, (lat, lon, week) => lat > 40 && lat < 55),
        cells: cells,
        pause: Duration.zero,
      );
      for (final s in Season.values) {
        expect(resident.cellsOf(s), resident.cellsOf(Season.summer));
      }
    });

    test('ignores unknown species', () async {
      final none = await computeSeasonPresence(
        scientificName: 'Unknown species',
        predict: _fake(_migrant, (_, _, _) => true),
        cells: cells,
        pause: Duration.zero,
      );
      expect(none.isEmpty, isTrue);
    });

    test('pauses between batches so the UI keeps its frames', () async {
      var pauses = 0;
      const pause = Duration(milliseconds: 1);
      await runZoned(
        () => computeSeasonPresence(
          scientificName: _migrant,
          predict: _fake(_migrant, (_, _, _) => true),
          cells: [cells.first],
          batchSize: 2,
          pause: pause,
        ),
        zoneSpecification: ZoneSpecification(
          createTimer: (self, parent, zone, d, f) {
            if (d == pause) pauses++;
            return parent.createTimer(zone, d, f);
          },
        ),
      );
      expect(pauses, 2);
    });

    test('stops between two cells once cancelled', () async {
      var calls = 0;
      var cancelled = false;
      await expectLater(
        computeSeasonPresence(
          scientificName: _migrant,
          predict: _fake(_migrant, (_, _, _) => true, onCall: () {
            if (++calls == 8) cancelled = true;
          }),
          cells: cells,
          pause: Duration.zero,
          isCancelled: () => cancelled,
        ),
        throwsA(isA<WorldMapCancelled>()),
      );
      expect(calls, 8);
    });

    test('season of a month', () {
      expect(Season.ofMonth(12), Season.winter);
      expect(Season.ofMonth(3), Season.spring);
      expect(Season.ofMonth(7), Season.summer);
      expect(Season.ofMonth(11), Season.autumn);
    });
  });
}
