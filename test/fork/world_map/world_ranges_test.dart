/// Bundled GBIF ranges (J7): the reader (round trip with a writer of the
/// documented format, unknown species, corrupted data) and the provider's
/// fallback to the geo-model.
library;

import 'dart:typed_data';

import 'package:birdnet_live/fork/world_map/range_class.dart';
import 'package:birdnet_live/fork/world_map/season_presence.dart';
import 'package:birdnet_live/fork/world_map/world_map_data.dart';
import 'package:birdnet_live/fork/world_map/world_grid.dart';
import 'package:birdnet_live/fork/world_map/world_map_providers.dart';
import 'package:birdnet_live/fork/world_map/world_ranges.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'world_map_test_data.dart';

void main() {
  group('reader', () {
    test('round trip: names, generation date, the four classes', () {
      final ranges = WorldRanges.fromGzip(
        writeRangesGzip({
          'Turdus merula': {
            0: RangeClass.resident,
            1: RangeClass.breeding,
            2: RangeClass.wintering,
            3000: RangeClass.passage,
          },
          'Apus apus': {7: RangeClass.breeding},
          'Empty one': {},
        }, generation: 20261001),
      );
      expect(ranges.generation, 20261001);
      expect(ranges.speciesCount, 3);
      expect(ranges.entriesOf('Turdus merula'), {
        0: RangeClass.resident,
        1: RangeClass.breeding,
        2: RangeClass.wintering,
        3000: RangeClass.passage,
      });
      expect(ranges.entriesOf('Apus apus'), {7: RangeClass.breeding});
      expect(ranges.entriesOf('Empty one'), isEmpty);
      expect(ranges.contains('Apus apus'), isTrue);
    });

    test('non-ASCII names survive', () {
      final ranges = WorldRanges.parse(
        writeRanges({'Pica pica ×': {1: RangeClass.resident}}),
      );
      expect(ranges.entriesOf('Pica pica ×'), {1: RangeClass.resident});
    });

    test('an unknown species is null', () {
      final ranges = WorldRanges.parse(
        writeRanges({'Apus apus': {1: RangeClass.resident}}),
      );
      expect(ranges.entriesOf('Apus pallidus'), isNull);
      expect(ranges.contains('apus apus'), isFalse, reason: 'exact match');
    });

    test('a corrupted magic is refused', () {
      final bytes = writeRanges({'Apus apus': {1: RangeClass.resident}});
      bytes[0] = 0x58;
      expect(() => WorldRanges.parse(bytes), throwsFormatException);
      expect(
        () => WorldRanges.parse(Uint8List.fromList([1, 2, 3])),
        throwsFormatException,
      );
      expect(
        () => WorldRanges.fromGzip(Uint8List.fromList([1, 2, 3])),
        throwsA(anything),
      );
    });

    test('a truncated file is refused', () {
      final bytes = writeRanges({'Apus apus': {1: RangeClass.resident}});
      expect(
        () => WorldRanges.parse(
          Uint8List.sublistView(bytes, 0, bytes.length - 1),
        ),
        throwsFormatException,
      );
    });
  });

  group('provider', () {
    final regions = realRegions();

    ProviderContainer container({
      WorldRanges? ranges,
      GeoPredict? predict,
    }) {
      final c = ProviderContainer(
        overrides: [
          worldRegionsProvider.overrideWith((ref) async => regions),
          landCellsProvider.overrideWith((ref) async => landCells(regions)),
          worldRangesProvider.overrideWith((ref) async => ranges),
          worldMapPredictProvider.overrideWith((ref) async => predict),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    test('a species in the ranges: its regions by id, GBIF source, date', () async {
      final c = container(ranges: fixtureRanges(regions));
      final data = await c.read(worldMapDataProvider('Apus apus').future);
      expect(data!.source, WorldMapSource.gbif);
      expect(data.generation, 20261001);
      expect(data.classes, fixtureClasses(regions, 'Apus apus'));
      expect(data.classes.values.toSet(), {
        RangeClass.breeding,
        RangeClass.wintering,
      });
    });

    test('an index past the regions is ignored', () async {
      final c = container(
        ranges: WorldRanges.parse(
          writeRanges({
            'Apus apus': {0: RangeClass.resident, 60000: RangeClass.resident},
          }),
        ),
      );
      final data = await c.read(worldMapDataProvider('Apus apus').future);
      expect(data!.classes.keys, [regions.regions[0].id]);
    });

    test('a species missing from the ranges, no geo-model: null', () async {
      final c = container(ranges: fixtureRanges(regions));
      expect(await c.read(worldMapDataProvider('Nothing here').future), isNull);
    });

    test('no ranges asset: the geo-model answers', () async {
      GeoPredict fake() =>
          ({
            required double latitude,
            required double longitude,
            required int week,
          }) async => {'Apus apus': latitude > 50 ? 0.5 : 0.0};
      final c = container(predict: fake());
      c.listen(worldMapDataProvider('Apus apus'), (_, _) {});
      final data = await c.read(worldMapDataProvider('Apus apus').future);
      expect(data!.source, WorldMapSource.geomodel);
      expect(data.generation, isNull);
      expect(data.classes, isNotEmpty);
    });
  });
}
