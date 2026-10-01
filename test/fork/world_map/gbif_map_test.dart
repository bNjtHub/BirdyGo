/// GBIF species maps on demand (J7): URL and filters, tiles that cover the
/// area, reading squares into cells, disk cache (hit, expiry, eviction) and
/// the service's behaviour with a fake HTTP client. No test touches the
/// network.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:birdnet_live/fork/world_map/gbif_cache.dart';
import 'package:birdnet_live/fork/world_map/gbif_map.dart';
import 'package:birdnet_live/fork/world_map/gbif_service.dart';
import 'package:birdnet_live/fork/world_map/world_map_config.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _species = 'Turdus merula';

/// A square of one cell (4 x 4 pixels) at global cell [col], [row] of the
/// tile that holds it, drawn in the given color.
GbifRaster _raster(
  List<({int col, int row, int dx, List<int> rgba})> squares,
) {
  const size = 512;
  final rgba = Uint8List(size * size * 4);
  for (final s in squares) {
    final px = (s.col % 128) * 4 + s.dx;
    final py = (s.row % 128) * 4;
    for (var y = 0; y < 4; y++) {
      for (var x = 0; x < 4; x++) {
        final o = ((py + y) * size + px + x) * 4;
        rgba.setRange(o, o + 4, s.rgba);
      }
    }
  }
  return GbifRaster(size, size, rgba);
}

void main() {
  final grid = GbifGrid.forZone();

  group('request', () {
    test('tile URL: taxon, licenses, observations, years, months, style', () {
      final uri = gbifTileUri(
        taxonKey: 2490719,
        season: Season.summer,
        tile: (x: 2, y: 0),
        lastYear: 2026,
      );
      expect(uri.scheme, 'https');
      expect(uri.host, 'api.gbif.org');
      expect(uri.path, '/v2/map/occurrence/adhoc/1/2/0@1x.png');
      final q = uri.queryParametersAll;
      expect(q['srs'], ['EPSG:4326']);
      expect(q['taxonKey'], ['2490719']);
      expect(q['license'], ['CC0_1_0', 'CC_BY_4_0']);
      expect(q['basisOfRecord'], ['HUMAN_OBSERVATION']);
      expect(q['year'], ['2010,2026']);
      expect(q['month'], ['6', '7', '8']);
      expect(q['bin'], ['square']);
      expect(q['squareSize'], ['32']);
      expect(q['style'], [WorldMapConfig.gbifStyle]);
    });

    test('each season asks its own months, winter wraps the year', () {
      List<String> months(Season s) =>
          gbifTileUri(
            taxonKey: 1,
            season: s,
            tile: (x: 1, y: 0),
            lastYear: 2026,
          ).queryParametersAll['month']!;
      expect(months(Season.winter), ['12', '1', '2']);
      expect(months(Season.spring), ['3', '4', '5']);
      expect(months(Season.autumn), ['9', '10', '11']);
    });

    test('species match asks for a bird', () {
      final uri = gbifMatchUri(_species);
      expect(uri.path, '/v1/species/match');
      expect(uri.queryParameters['scientificName'], _species);
      expect(uri.queryParameters['class'], 'Aves');
    });
  });

  group('grid', () {
    test('cells of 0.7 degrees, 4 tiles per season (16 requests)', () {
      expect(grid.step, closeTo(0.703125, 1e-9));
      expect(grid.tiles.toSet(), {
        (x: 1, y: 0),
        (x: 2, y: 0),
        (x: 1, y: 1),
        (x: 2, y: 1),
      });
      expect(grid.tiles.length * Season.values.length, lessThanOrEqualTo(16));
    });

    test('cells sit on the projection of the map area', () {
      final first = grid.centerOf(0);
      final last = grid.centerOf(grid.cellCount - 1);
      expect(first.longitude, closeTo(WorldMapConfig.lonMin, grid.step));
      expect(first.latitude, closeTo(WorldMapConfig.latMax, grid.step));
      expect(last.longitude, closeTo(WorldMapConfig.lonMax, grid.step));
      expect(last.latitude, closeTo(WorldMapConfig.latMin, grid.step));
    });

    test('colors of the count ramp give three levels, alpha gates', () {
      expect(GbifGrid.pixelLevel(255, 255), 1);
      expect(GbifGrid.pixelLevel(204, 255), 1);
      expect(GbifGrid.pixelLevel(153, 255), 2);
      expect(GbifGrid.pixelLevel(102, 255), 2);
      expect(GbifGrid.pixelLevel(10, 255), 3);
      expect(GbifGrid.pixelLevel(10, 0), 0);
    });

    test('a square becomes the cell under it, at its level', () {
      final levels = Uint8List(grid.cellCount);
      // Global cell column 230, row 40: tile (1, 0), cell (10, 12) of the grid.
      grid.readTile(
        (x: 1, y: 0),
        _raster([(col: 230, row: 40, dx: 0, rgba: [255, 153, 0, 255])]),
        levels,
      );
      expect(levels[12 * grid.cols + 10], 2);
      expect(levels.where((l) => l != 0).length, 1);
    });

    test('a square shifted by a pixel counts in the cell it mostly covers', () {
      final levels = Uint8List(grid.cellCount);
      grid.readTile(
        (x: 1, y: 0),
        _raster([(col: 230, row: 40, dx: 1, rgba: [214, 10, 0, 255])]),
        levels,
      );
      expect(levels[12 * grid.cols + 10], 3);
      expect(levels[12 * grid.cols + 11], 0);
    });

    test('a tile only fills its own cells', () {
      final levels = Uint8List(grid.cellCount);
      grid.readTile(
        (x: 2, y: 0),
        _raster([(col: 230, row: 40, dx: 0, rgba: [255, 255, 0, 255])]),
        levels,
      );
      // Cell column 230 is in tile x = 1: reading tile x = 2 skips it.
      expect(levels[12 * grid.cols + 10], 0);
    });

    test('the presence keeps observed cells only, with the cells step', () {
      final levels = [for (final _ in Season.values) Uint8List(grid.cellCount)];
      levels[2][5] = 3;
      levels[0][9] = 1;
      final presence =
          GbifSpeciesMap(
            taxonKey: 1,
            fetchedAt: DateTime(2026),
            cols: grid.cols,
            rows: grid.rows,
            levels: levels,
          ).toPresence(grid);
      expect(presence.cells.length, 2);
      expect(presence.step, grid.step);
      expect(presence.cellsOf(Season.summer).length, 1);
      expect(presence.cellsOf(Season.winter).length, 1);
      expect(presence.cellsOf(Season.spring), isEmpty);
    });
  });

  group('cache', () {
    late Directory dir;
    var now = DateTime(2026, 10, 1);
    GbifMapCache cache({int? maxBytes}) => GbifMapCache(
      directory: () async => dir,
      now: () => now,
      maxBytes: maxBytes ?? WorldMapConfig.gbifCacheMaxBytes,
    );

    GbifSpeciesMap map(int mark) => GbifSpeciesMap(
      taxonKey: mark,
      fetchedAt: now,
      cols: grid.cols,
      rows: grid.rows,
      levels: [
        for (final s in Season.values)
          Uint8List(grid.cellCount)..[s.index + mark] = 2,
      ],
    );

    setUp(() async {
      now = DateTime(2026, 10, 1);
      dir = await Directory.systemTemp.createTemp('gbif_cache_test');
    });
    tearDown(() => dir.delete(recursive: true));

    test('a written map is read back, fresh', () async {
      final c = cache();
      await c.write(_species, map(7));
      final got = await c.read(_species, cols: grid.cols, rows: grid.rows);
      expect(got!.fresh, isTrue);
      expect(got.map.taxonKey, 7);
      expect(got.map.levels[2][2 + 7], 2);
      expect(got.map.fetchedAt, DateTime(2026, 10, 1));
    });

    test('nothing for an unknown species or another grid', () async {
      final c = cache();
      expect(await c.read(_species, cols: grid.cols, rows: grid.rows), isNull);
      await c.write(_species, map(1));
      expect(await c.read(_species, cols: grid.cols + 1, rows: grid.rows), isNull);
    });

    test('a map older than the validity is stale, not lost', () async {
      final c = cache();
      await c.write(_species, map(1));
      now = now.add(WorldMapConfig.gbifCacheMaxAge - const Duration(days: 1));
      expect(
        (await c.read(_species, cols: grid.cols, rows: grid.rows))!.fresh,
        isTrue,
      );
      now = now.add(const Duration(days: 2));
      final stale = await c.read(_species, cols: grid.cols, rows: grid.rows);
      expect(stale!.fresh, isFalse);
      expect(stale.map.taxonKey, 1);
    });

    test('a damaged file is ignored', () async {
      final c = cache();
      await c.write(_species, map(1));
      await File('${dir.path}/${GbifMapCache.fileNameOf(_species)}')
          .writeAsBytes([1, 2, 3]);
      expect(await c.read(_species, cols: grid.cols, rows: grid.rows), isNull);
    });

    test('the size is capped: least recently shown goes first', () async {
      final big = cache();
      await big.write('Aa aa', map(1));
      final size = await File('${dir.path}/${GbifMapCache.fileNameOf('Aa aa')}').length();
      final capped = cache(maxBytes: size * 2 + size ~/ 2);
      Future<void> age(String name, int minutes) => File(
        '${dir.path}/${GbifMapCache.fileNameOf(name)}',
      ).setLastModified(DateTime.now().subtract(Duration(minutes: minutes)));
      await age('Aa aa', 30);
      await capped.write('Bb bb', map(1));
      await age('Bb bb', 20);
      await capped.write('Cc cc', map(1));
      final names =
          dir.listSync().map((e) => e.uri.pathSegments.last).toList()..sort();
      expect(names, [
        GbifMapCache.fileNameOf('Bb bb'),
        GbifMapCache.fileNameOf('Cc cc'),
      ]);
    });
  });

  group('service', () {
    late Directory dir;
    late List<Uri> requests;
    late Map<String, String> lastHeaders;
    var inFlight = 0;
    var maxInFlight = 0;
    var offline = false;
    var matchType = 'EXACT';
    var now = DateTime(2026, 10, 1);

    http.Client client() => MockClient((request) async {
      requests.add(request.url);
      lastHeaders = request.headers;
      if (offline) throw const SocketException('offline');
      inFlight++;
      if (inFlight > maxInFlight) maxInFlight = inFlight;
      await Future<void>.delayed(const Duration(milliseconds: 5));
      inFlight--;
      if (request.url.path == '/v1/species/match') {
        return http.Response(
          jsonEncode({'usageKey': 2490719, 'matchType': matchType}),
          200,
        );
      }
      final parts = request.url.path.split('/');
      final x = parts[parts.length - 2];
      final y = parts.last.split('@').first;
      final months = request.url.queryParametersAll['month']!.join('-');
      return http.Response('$x,$y,$months', 200);
    });

    /// Decoder of the fake tiles: tile (1, 0) holds one square, a level 3 one
    /// in winter and a level 1 one in the other seasons.
    Future<GbifRaster> decode(Uint8List body) async {
      final parts = utf8.decode(body).split(',');
      if (parts[0] == '1' && parts[1] == '0') {
        final winter = parts[2] == '12-1-2';
        return _raster([
          (
            col: 230,
            row: 40,
            dx: 0,
            rgba: winter ? [214, 10, 0, 255] : [255, 255, 0, 255],
          ),
        ]);
      }
      return _raster([]);
    }

    GbifMapService service({int? maxBytes}) => GbifMapService(
      client: client(),
      cache: GbifMapCache(
        directory: () async => dir,
        now: () => now,
        maxBytes: maxBytes ?? WorldMapConfig.gbifCacheMaxBytes,
      ),
      decode: decode,
      now: () => now,
    );

    setUp(() async {
      requests = [];
      lastHeaders = {};
      inFlight = 0;
      maxInFlight = 0;
      offline = false;
      matchType = 'EXACT';
      now = DateTime(2026, 10, 1);
      dir = await Directory.systemTemp.createTemp('gbif_service_test');
    });
    tearDown(() => dir.delete(recursive: true));

    test('one match and 16 tiles, 4 at a time, the app identifies itself', () async {
      final map = await service().load(_species);
      expect(requests.where((u) => u.path == '/v1/species/match').length, 1);
      final tiles = requests.where((u) => u.path.startsWith('/v2/map')).toList();
      expect(tiles.length, 16);
      expect(requests.length, 17);
      expect(tiles.every((u) => u.queryParameters['taxonKey'] == '2490719'), isTrue);
      expect(tiles.every((u) => u.queryParameters['year'] == '2010,2026'), isTrue);
      expect(maxInFlight, lessThanOrEqualTo(WorldMapConfig.gbifMaxParallel));
      expect(lastHeaders['User-Agent'], contains('BirdyGo'));
      expect(map.taxonKey, 2490719);
      final cell = 12 * grid.cols + 10;
      expect(map.levels[Season.winter.index][cell], 3);
      expect(map.levels[Season.summer.index][cell], 1);
      expect(map.levels[Season.summer.index].where((l) => l != 0).length, 1);
    });

    test('a second opening is served from the cache, with no request', () async {
      await service().load(_species);
      requests.clear();
      final map = await service().load(_species);
      expect(requests, isEmpty);
      expect(map.levels[Season.winter.index][12 * grid.cols + 10], 3);
    });

    test('offline with a cached map: it is shown, even when expired', () async {
      await service().load(_species);
      now = now.add(WorldMapConfig.gbifCacheMaxAge + const Duration(days: 1));
      offline = true;
      requests.clear();
      final map = await service().load(_species);
      expect(map.taxonKey, 2490719);
    });

    test('an expired map is asked again, without a new match', () async {
      await service().load(_species);
      now = now.add(WorldMapConfig.gbifCacheMaxAge + const Duration(days: 1));
      requests.clear();
      await service().load(_species);
      expect(requests.where((u) => u.path == '/v1/species/match'), isEmpty);
      expect(requests.length, 16);
    });

    test('offline with nothing cached: it fails (the caller falls back)', () async {
      offline = true;
      await expectLater(service().load(_species), throwsA(anything));
    });

    test('an unknown species fails before any tile is asked', () async {
      matchType = 'NONE';
      await expectLater(
        service().load(_species),
        throwsA(isA<GbifUnavailable>()),
      );
      expect(requests.length, 1);
    });
  });
}
