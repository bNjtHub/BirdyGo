/// GBIF range asset (J7): the pure decoder, the shipped demo asset (made by
/// tools/fork_gbif_ranges.py, so this also checks Python and Dart agree), the
/// GBIF-or-geo-model choice and the provider.
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:birdnet_live/fork/world_map/gbif_ranges.dart';
import 'package:birdnet_live/fork/world_map/land_outline.dart';
import 'package:birdnet_live/fork/world_map/season_legend.dart';
import 'package:birdnet_live/fork/world_map/season_presence.dart';
import 'package:birdnet_live/fork/world_map/world_grid.dart';
import 'package:birdnet_live/fork/world_map/world_map_config.dart';
import 'package:birdnet_live/fork/world_map/world_map_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Uint8List _demo() => File(WorldMapConfig.gbifAsset).readAsBytesSync();

GbifIndex _demoIndex() => GbifIndex.parse(_demo());

SeasonPresence _decode(GbifIndex index, String name) => decodeGbifSpecies(
  GbifDecodeRequest(index.blockOf(name)!, index.grid),
);

List<int> _varint(int value) {
  final out = <int>[];
  do {
    var b = value & 0x7F;
    value >>= 7;
    if (value != 0) b |= 0x80;
    out.add(b);
  } while (value != 0);
  return out;
}

/// A one-species asset on a 4 x 2 grid, built by hand (format of
/// tools/fork_gbif_ranges.py). [seasons]: per season, (level, run) pairs.
Uint8List _tiny(List<List<(int, int)>> seasons, {int cols = 4, int rows = 2}) {
  final block = <int>[];
  for (final runs in seasons) {
    final stream = [for (final (level, run) in runs) ..._varint(run << 2 | level)];
    block
      ..addAll([stream.length & 0xFF, stream.length >> 8])
      ..addAll(stream);
  }
  const name = 'Tiny bird';
  final index = <int>[name.length, ...name.codeUnits];
  final data = ByteData(8)
    ..setUint32(0, 0, Endian.little)
    ..setUint32(4, block.length, Endian.little);
  index.addAll(data.buffer.asUint8List());
  final header = ByteData(20);
  final bytes = <int>[0x42, 0x47, 0x52, 0x31];
  header
    ..setUint16(4, 100, Endian.little) // step 1 degree
    ..setInt16(6, -2500, Endian.little)
    ..setInt16(8, -3500, Endian.little)
    ..setUint16(10, cols, Endian.little)
    ..setUint16(12, rows, Endian.little)
    ..setUint16(14, 1, Endian.little)
    ..setUint32(16, 20 + index.length, Endian.little);
  return Uint8List.fromList([
    ...bytes,
    ...header.buffer.asUint8List().sublist(4),
    ...index,
    ...block,
  ]);
}

void main() {
  group('decoder (pure)', () {
    test('reads the header and the index', () {
      final index = _tiny([
        [(0, 8)],
        [(0, 8)],
        [(0, 8)],
        [(0, 8)],
      ]);
      final parsed = GbifIndex.parse(index);
      expect(parsed.grid.step, 1);
      expect(parsed.grid.lonMin, -25);
      expect(parsed.grid.latMin, -35);
      expect(parsed.grid.cols, 4);
      expect(parsed.grid.rows, 2);
      expect(parsed.speciesCount, 1);
      expect(parsed.contains('Tiny bird'), isTrue);
      expect(parsed.contains('Other'), isFalse);
      expect(parsed.blockOf('Other'), isNull);
    });

    test('runs become levels, row 0 is the north row', () {
      final bytes = _tiny([
        [(3, 2), (0, 6)], // winter: the two first cells, level 3
        [(0, 8)], // spring: nothing
        [(0, 5), (1, 1), (2, 2)], // summer
        [(0, 8)],
      ]);
      final index = GbifIndex.parse(bytes);
      final levels = decodeGbifBlock(index.blockOf('Tiny bird')!, 8);
      expect(levels[0], [3, 3, 0, 0, 0, 0, 0, 0]);
      expect(levels[1], everyElement(0));
      expect(levels[2], [0, 0, 0, 0, 0, 1, 2, 2]);

      final presence = _decode(index, 'Tiny bird');
      // Cells with data in any season only: 0, 1 (winter), 5, 6, 7 (summer).
      expect(presence.cells.length, 5);
      expect(presence.step, 1);
      // Cell 0: row 0 (north, 2 rows of 1 degree from -35), col 0.
      expect(presence.cells[0], (latitude: -33.5, longitude: -24.5));
      expect(presence.cells[2], (latitude: -34.5, longitude: -24.5 + 1));
      expect(presence.levelOf(Season.winter, 0), 3);
      expect(presence.levelOf(Season.summer, 2), 1);
      expect(presence.levelOf(Season.summer, 3), 2);
      expect(presence.levelOf(Season.spring, 0), 0);
      expect(presence.isPresent(Season.winter, 1), isTrue);
    });

    test('bad magic, truncated data and runs past the grid are refused', () {
      expect(() => GbifIndex.parse(Uint8List(30)), throwsFormatException);
      expect(() => GbifIndex.parse(Uint8List(5)), throwsFormatException);
      final bytes = _tiny([
        [(0, 9)], // 9 cells on a grid of 8
        [(0, 8)],
        [(0, 8)],
        [(0, 8)],
      ]);
      final index = GbifIndex.parse(bytes);
      expect(
        () => decodeGbifBlock(index.blockOf('Tiny bird')!, 8),
        throwsFormatException,
      );
      final short = _tiny([
        [(0, 7)], // does not cover the grid
        [(0, 8)],
        [(0, 8)],
        [(0, 8)],
      ]);
      expect(
        () => decodeGbifBlock(GbifIndex.parse(short).blockOf('Tiny bird')!, 8),
        throwsFormatException,
      );
      expect(
        () => GbifIndex.parse(Uint8List.sublistView(bytes, 0, bytes.length - 3)),
        throwsFormatException,
      );
    });
  });

  group('the shipped demo asset', () {
    test('is tiny and marked fictitious', () {
      expect(_demo().length, lessThan(10 * 1024));
      final meta = GbifMeta.parse(
        File(WorldMapConfig.gbifMetaAsset).readAsStringSync(),
      );
      expect(meta.demo, isTrue);
      expect(meta.usableIn(release: true), isFalse);
      expect(meta.usableIn(release: false), isTrue);
      expect(meta.doi, isNull);
    });

    test('three species on the 1 degree grid of the map', () {
      final index = _demoIndex();
      expect(index.speciesCount, 3);
      expect(index.grid.step, 1);
      expect(index.grid.lonMin, WorldMapConfig.lonMin);
      expect(index.grid.latMin, WorldMapConfig.latMin);
      expect(index.grid.cols, WorldMapConfig.lonMax - WorldMapConfig.lonMin);
      expect(index.grid.rows, WorldMapConfig.latMax - WorldMapConfig.latMin);
      expect(
        index.names,
        containsAll(['Hirundo rustica', 'Erithacus rubecula', 'Turdus pilaris']),
      );
    });

    test('the migrant decodes like the Python fixture says', () {
      final presence = _decode(_demoIndex(), 'Hirundo rustica');
      expect(presence.step, 1);
      expect(presence.levels, isNotNull);
      final summer = presence.cellsOf(Season.summer);
      final winter = presence.cellsOf(Season.winter);
      expect(summer, isNotEmpty);
      expect(winter, isNotEmpty);
      expect(summer.every((c) => c.latitude >= 40), isTrue);
      expect(winter.every((c) => c.latitude < 15), isTrue);
      // Strongest in the north in summer.
      final i = presence.cells.indexWhere(
        (c) => c.latitude == 55.5 && c.longitude == 10.5,
      );
      expect(presence.levelOf(Season.summer, i), 3);
      // The legend works on GBIF cells: summer in the north, real migration.
      final legend = buildLegend(presence);
      expect(legend.kind, LegendKind.seasons);
      expect(legend.distanceKm, greaterThan(WorldMapConfig.migrationMinKm));
    });

    test('the resident is there all year', () {
      final presence = _decode(_demoIndex(), 'Erithacus rubecula');
      expect(buildLegend(presence).kind, LegendKind.allYear);
    });
  });

  group('GBIF or the geo-model', () {
    test('the asset wins for a species it has', () {
      final index = _demoIndex();
      expect(chooseWorldMapSource(index, 'Hirundo rustica'), WorldMapSource.gbif);
      expect(chooseWorldMapSource(index, 'Parus major'), WorldMapSource.geomodel);
      expect(chooseWorldMapSource(null, 'Hirundo rustica'), WorldMapSource.geomodel);
    });

    Future<GeoPredict?> never() async => null;

    test('provider: GBIF species are instant and never ask the geo-model', () async {
      var asked = 0;
      final container = ProviderContainer(
        overrides: [
          gbifIndexProvider.overrideWith((ref) async => _demoIndex()),
          gbifDecodeProvider.overrideWithValue(
            (request) async => decodeGbifSpecies(request),
          ),
          worldMapPredictProvider.overrideWith((ref) async {
            asked++;
            return never();
          }),
        ],
      );
      addTearDown(container.dispose);
      final data = await container.read(
        worldMapDataProvider('Hirundo rustica').future,
      );
      expect(data!.source, WorldMapSource.gbif);
      expect(data.presence.step, 1);
      expect(asked, 0);
    });

    test('provider: other species fall back to the geo-model', () async {
      final container = ProviderContainer(
        overrides: [
          gbifIndexProvider.overrideWith((ref) async => _demoIndex()),
          landCellsProvider.overrideWith(
            (ref) async => <GridCell>[(latitude: 48, longitude: 2)],
          ),
          worldMapPredictProvider.overrideWith(
            (ref) async =>
                ({
                  required double latitude,
                  required double longitude,
                  required int week,
                }) async => {'Parus major': 0.5},
          ),
        ],
      );
      addTearDown(container.dispose);
      final data = await container.read(worldMapDataProvider('Parus major').future);
      expect(data!.source, WorldMapSource.geomodel);
      expect(data.presence.step, WorldMapConfig.gridStep);
      expect(data.presence.levelOf(Season.summer, 0), WorldMapConfig.gbifLevels);
    });

    test('provider: without the asset, the geo-model answers', () async {
      final container = ProviderContainer(
        overrides: [
          gbifIndexProvider.overrideWith((ref) async => null),
          worldMapPredictProvider.overrideWith((ref) async => null),
        ],
      );
      addTearDown(container.dispose);
      expect(
        await container.read(worldMapDataProvider('Hirundo rustica').future),
        isNull,
      );
    });

    test('provider: a real decode in an isolate gives the same map', () async {
      final container = ProviderContainer(
        overrides: [gbifIndexProvider.overrideWith((ref) async => _demoIndex())],
      );
      addTearDown(container.dispose);
      final data = await container.read(
        worldMapDataProvider('Turdus pilaris').future,
      );
      expect(data!.source, WorldMapSource.gbif);
      expect(
        data.presence.cells.length,
        _decode(_demoIndex(), 'Turdus pilaris').cells.length,
      );
    });

    test('the outline asset still loads next to it', () {
      final bytes = File(WorldMapConfig.landAsset).readAsBytesSync();
      expect(
        LandOutline.parse(ByteData.sublistView(bytes)).ringCount,
        greaterThan(50),
      );
    });
  });
}
