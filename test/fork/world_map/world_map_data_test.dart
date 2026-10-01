/// World map data (J7): the land asset, point-in-polygon, the land grid, the
/// four seasons with a fake geo-model, and the legend.
library;

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:birdnet_live/fork/world_map/land_outline.dart';
import 'package:birdnet_live/fork/world_map/season_legend.dart';
import 'package:birdnet_live/fork/world_map/season_presence.dart';
import 'package:birdnet_live/fork/world_map/world_grid.dart';
import 'package:birdnet_live/fork/world_map/world_map_config.dart';
import 'package:flutter_test/flutter_test.dart';

LandOutline _realOutline() {
  final bytes = File(WorldMapConfig.landAsset).readAsBytesSync();
  return LandOutline.parse(ByteData.sublistView(bytes));
}

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

void main() {
  group('land asset', () {
    test('is small and holds the continents', () {
      final size = File(WorldMapConfig.landAsset).lengthSync();
      expect(size, lessThan(150 * 1024));
      final outline = _realOutline();
      expect(outline.ringCount, greaterThan(50));
    });

    test('point in polygon: land and sea', () {
      final outline = _realOutline();
      expect(outline.contains(2.35, 48.85), isTrue, reason: 'Paris');
      expect(outline.contains(10, 25), isTrue, reason: 'Sahara');
      expect(outline.contains(37, 0), isTrue, reason: 'Kenya');
      expect(outline.contains(-20, 30), isFalse, reason: 'Atlantic');
      expect(outline.contains(18, 34), isFalse, reason: 'Mediterranean');
      expect(outline.contains(0, -10), isFalse, reason: 'Gulf of Guinea');
    });

    test('parses the documented binary format', () {
      // One triangle: (0,0) (10,0) (0,10), degrees x 100.
      final data =
          ByteData(2 + 2 + 3 * 4)
            ..setUint16(0, 1, Endian.little)
            ..setUint16(2, 3, Endian.little);
      var o = 4;
      for (final (lon, lat) in [(0, 0), (1000, 0), (0, 1000)]) {
        data
          ..setInt16(o, lon, Endian.little)
          ..setInt16(o + 2, lat, Endian.little);
        o += 4;
      }
      final outline = LandOutline.parse(data);
      expect(outline.ringCount, 1);
      expect(outline.contains(2, 2), isTrue);
      expect(outline.contains(8, 8), isFalse);
    });

    test('the drawing path is built once', () {
      final outline = _realOutline();
      expect(identical(outline.unitPath, outline.unitPath), isTrue);
      final bounds = outline.unitPath.getBounds();
      expect(bounds.isEmpty, isFalse);
    });
  });

  group('land grid', () {
    test('keeps only cells on land, inside the view', () {
      final cells = landCells(_realOutline());
      expect(cells.length, inInclusiveRange(100, 400));
      for (final c in cells) {
        expect(
          c.longitude,
          inInclusiveRange(WorldMapConfig.lonMin, WorldMapConfig.lonMax),
        );
        expect(
          c.latitude,
          inInclusiveRange(WorldMapConfig.latMin, WorldMapConfig.latMax),
        );
      }
      expect(cells, contains((latitude: 47.5, longitude: 2.5)));
      expect(cells, isNot(contains((latitude: 32.5, longitude: -17.5))));
    });
  });

  group('four seasons with a fake geo-model', () {
    final cells = landCells(_realOutline());

    test('a migrant moves, a resident stays', () async {
      var calls = 0;
      final watch = Stopwatch()..start();
      final migrant = await computeSeasonPresence(
        scientificName: _migrant,
        predict: _fake(_migrant, _migrantPresence, onCall: () => calls++),
        cells: cells,
        pause: Duration.zero,
      );
      watch.stop();
      // ignore: avoid_print
      print(
        '[world_map] ${cells.length} cells x 4 seasons = $calls predictions '
        'in ${watch.elapsedMilliseconds} ms (fake model, no pauses)',
      );
      expect(calls, cells.length * 4);
      expect(migrant.cellsOf(Season.summer), isNotEmpty);
      expect(migrant.cellsOf(Season.winter), isNotEmpty);
      expect(migrant.cellsOf(Season.spring), isEmpty);
      expect(
        migrant.cellsOf(Season.summer).every((c) => c.latitude >= 55),
        isTrue,
      );
      expect(
        migrant.cellsOf(Season.winter).every((c) => c.latitude <= 15),
        isTrue,
      );

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

    test(
      'uses the shared presence threshold and ignores unknown species',
      () async {
        final none = await computeSeasonPresence(
          scientificName: 'Unknown species',
          predict: _fake(_migrant, (_, _, _) => true),
          cells: cells,
          pause: Duration.zero,
        );
        expect(none.isEmpty, isTrue);
      },
    );

    test('pauses between batches so the UI keeps its frames', () async {
      var pauses = 0;
      const pause = Duration(milliseconds: 1);
      // 1 cell x 4 seasons = 4 predictions, batch of 2 -> 2 pauses.
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
      // The cell being worked on (4 seasons) finishes, then nothing more.
      expect(calls, 8);
    });

    test('season of a month', () {
      expect(Season.ofMonth(12), Season.winter);
      expect(Season.ofMonth(3), Season.spring);
      expect(Season.ofMonth(7), Season.summer);
      expect(Season.ofMonth(11), Season.autumn);
    });
  });

  group('legend', () {
    final cells = landCells(_realOutline());

    test('a migrant: summer and winter regions, and the distance', () async {
      final presence = await computeSeasonPresence(
        scientificName: _migrant,
        predict: _fake(_migrant, _migrantPresence),
        cells: cells,
        pause: Duration.zero,
      );
      final legend = buildLegend(presence);
      expect(legend.kind, LegendKind.seasons);
      expect(legend.summer, WorldRegion.northernEurope);
      expect(legend.winter, WorldRegion.westAfrica);
      expect(legend.distanceKm, inInclusiveRange(4000, 6500));
      expect(legend.distanceKm! % 100, 0);
    });

    test('a resident: present all year in this area', () async {
      final presence = await computeSeasonPresence(
        scientificName: _migrant,
        predict: _fake(
          _migrant,
          (lat, lon, w) => lat > 45 && lat < 52 && lon < 10,
        ),
        cells: cells,
        pause: Duration.zero,
      );
      expect(buildLegend(presence).kind, LegendKind.allYear);
    });

    test('nowhere, passage only, one season only', () async {
      Future<SeasonPresence> run(bool Function(double, double, int) f) =>
          computeSeasonPresence(
            scientificName: _migrant,
            predict: _fake(_migrant, f),
            cells: cells,
            pause: Duration.zero,
          );
      expect(buildLegend(await run((_, _, _) => false)).kind, LegendKind.none);
      expect(
        buildLegend(await run((_, _, w) => w == 14 || w == 38)).kind,
        LegendKind.passage,
      );
      final summerOnly = buildLegend(
        await run((lat, _, w) => w == 26 && lat > 55),
      );
      expect(summerOnly.kind, LegendKind.seasons);
      expect(summerOnly.winter, isNull);
      expect(summerOnly.summer, isNotNull);
    });

    /// Cells of a block: [n] cells around ([lat], [lon]), one level.
    SeasonPresence blocks(
      Map<Season, List<({double lat, double lon, int n, int level})>> spec,
    ) {
      final all = <GridCell>[];
      final flags = {for (final s in Season.values) s: <bool>[]};
      final levels = {for (final s in Season.values) s: <int>[]};
      for (final MapEntry(:key, :value) in spec.entries) {
        for (final b in value) {
          for (var i = 0; i < b.n; i++) {
            all.add((latitude: b.lat + i * 0.01, longitude: b.lon));
            for (final s in Season.values) {
              flags[s]!.add(s == key);
              levels[s]!.add(s == key ? b.level : 0);
            }
          }
        }
      }
      return SeasonPresence(all, flags, step: 0.7, levels: levels);
    }

    test('two separate groups: the densest one, not a point between them', () {
      // Winter: 100 cells in Europe (France), 10 in West Africa. The mean of
      // all of them would fall in the Mediterranean / North Africa.
      final presence = blocks({
        Season.winter: [
          (lat: 46, lon: 2, n: 100, level: 2),
          (lat: 8, lon: -5, n: 10, level: 2),
        ],
        Season.summer: [(lat: 62, lon: 20, n: 50, level: 2)],
      });
      final legend = buildLegend(presence);
      expect(legend.winter, WorldRegion.westernEurope);
      expect(legend.summer, WorldRegion.northernEurope);
      // France to Finland, not Dakar to Finland.
      expect(legend.distanceKm, inInclusiveRange(1500, 2200));
    });

    test('the intensity decides: a few strong cells beat many faint ones', () {
      final presence = blocks({
        Season.winter: [
          (lat: 46, lon: 2, n: 30, level: 1),
          (lat: 8, lon: -5, n: 20, level: 3),
        ],
      });
      expect(dominantCenter(presence, Season.winter)!.region,
          WorldRegion.westAfrica);
      expect(dominantCenter(presence, Season.summer), isNull);
    });

    test('a species of the southern hemisphere is told in months', () {
      final presence = blocks({
        Season.summer: [(lat: -25, lon: 25, n: 20, level: 2)],
        Season.winter: [(lat: -5, lon: 35, n: 20, level: 2)],
      });
      final legend = buildLegend(presence);
      expect(isSouthern(presence), isTrue);
      expect(legend.southern, isTrue);
      expect(legend.summer, WorldRegion.southernAfrica);
      expect(legend.winter, WorldRegion.eastAfrica);
      expect(
        buildLegend(
          blocks({
            Season.summer: [(lat: 55, lon: 10, n: 5, level: 2)],
          }),
        ).southern,
        isFalse,
      );
    });

    test('regions and distance', () {
      expect(regionOf(48, 2), WorldRegion.westernEurope);
      expect(regionOf(65, 20), WorldRegion.northernEurope);
      expect(regionOf(10, -5), WorldRegion.westAfrica);
      expect(regionOf(-25, 25), WorldRegion.southernAfrica);
      expect(regionOf(-30, -20), WorldRegion.other);
      // Paris to Dakar is about 4 200 km.
      expect(
        distanceKm(
          (latitude: 48.85, longitude: 2.35),
          (latitude: 14.7, longitude: -17.4),
        ),
        closeTo(4200, 150),
      );
      expect(centerOf(const []), isNull);
    });
  });
}
