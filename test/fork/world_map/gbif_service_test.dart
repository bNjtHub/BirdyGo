/// GBIF requests and disk cache of the world map (J7): URLs, series of
/// requests, retries, cache freshness and fallbacks. No network (fake client).
library;

import 'dart:convert';
import 'dart:io';

import 'package:birdnet_live/fork/world_map/gbif_cache.dart';
import 'package:birdnet_live/fork/world_map/gbif_ranges.dart';
import 'package:birdnet_live/fork/world_map/gbif_service.dart';
import 'package:birdnet_live/fork/world_map/world_map_config.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _species = 'Apus apus';

String _facet(Map<String, int> counts) => jsonEncode({
  'count': 1,
  'facets': [
    {
      'field': 'GADM_LEVEL_1_GID',
      'counts': [
        for (final e in counts.entries) {'name': e.key, 'count': e.value},
      ],
    },
  ],
});

void main() {
  late Directory dir;
  late DateTime clock;
  late List<Uri> requests;
  late List<Duration> pauses;
  late int inFlight;
  late int maxInFlight;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('gbif_cache_test');
    clock = DateTime(2026, 10, 1);
    requests = [];
    pauses = [];
    inFlight = 0;
    maxInFlight = 0;
  });

  tearDown(() => dir.deleteSync(recursive: true));

  GbifCountsCache cache({int? maxBytes}) => GbifCountsCache(
    directory: () async => dir,
    now: () => clock,
    maxBytes: maxBytes ?? WorldMapConfig.gbifCacheMaxBytes,
  );

  /// A client answering like GBIF: the species key, a species count and an
  /// all-birds count (10 times bigger).
  GbifRangeService service({
    http.Response? Function(Uri uri)? override,
    GbifCountsCache? withCache,
  }) => GbifRangeService(
    client: MockClient((request) async {
      requests.add(request.url);
      inFlight++;
      if (inFlight > maxInFlight) maxInFlight = inFlight;
      await Future<void>.delayed(const Duration(milliseconds: 5));
      inFlight--;
      final o = override?.call(request.url);
      if (o != null) return o;
      if (request.url.path == WorldMapConfig.gbifMatchPath) {
        return http.Response(
          jsonEncode({'usageKey': 5228, 'matchType': 'EXACT'}),
          200,
        );
      }
      final isSpecies = request.url.queryParameters.containsKey('taxonKey');
      return http.Response(
        _facet({'FRA.1_1': isSpecies ? 50 : 1000}),
        200,
      );
    }),
    cache: withCache ?? cache(),
    now: () => clock,
    delay: (d) async => pauses.add(d),
  );

  group('URLs', () {
    test('species counts: open licenses, human observations, one season', () {
      final uri = gbifFacetUri(
        taxonKey: 5228,
        season: Season.summer,
        lastYear: 2026,
      );
      expect(uri.host, 'api.gbif.org');
      expect(uri.path, '/v1/occurrence/search');
      final q = uri.queryParametersAll;
      expect(q['limit'], ['0']);
      expect(q['facet'], ['gadmLevel1Gid']);
      expect(q['facetLimit'], ['5000']);
      expect(q['taxonKey'], ['5228']);
      expect(q.containsKey('classKey'), isFalse);
      expect(q['basisOfRecord'], ['HUMAN_OBSERVATION']);
      expect(q['year'], ['2010,2026']);
      expect(q['license'], ['CC0_1_0', 'CC_BY_4_0']);
      expect(q['occurrenceStatus'], ['PRESENT']);
      expect(q['hasGeospatialIssue'], ['false']);
      expect(q['month'], ['6', '7', '8']);
    });

    test('effort counts: every bird, the winter months', () {
      final q = gbifFacetUri(
        taxonKey: null,
        season: Season.winter,
        lastYear: 2026,
      ).queryParametersAll;
      expect(q['classKey'], ['212']);
      expect(q.containsKey('taxonKey'), isFalse);
      expect(q['month'], ['12', '1', '2']);
    });

    test('a facet answer is read into counts', () {
      expect(
        parseFacetCounts(jsonDecode(_facet({'A.1_1': 3, 'B.2_1': 9})) as Map<String, dynamic>),
        {'A.1_1': 3, 'B.2_1': 9},
      );
      expect(parseFacetCounts({}), isEmpty);
    });
  });

  group('load', () {
    test('1 match, 4 species and 4 effort requests, two at a time', () async {
      final range = await service().load(_species);
      expect(requests.length, 9);
      expect(
        requests.where((u) => u.path == '/v1/species/match').length,
        1,
      );
      expect(
        requests.where((u) => u.queryParameters['taxonKey'] == '5228').length,
        4,
      );
      expect(
        requests.where((u) => u.queryParameters['classKey'] == '212').length,
        4,
      );
      expect(maxInFlight, lessThanOrEqualTo(WorldMapConfig.gbifMaxParallel));
      for (final s in Season.values) {
        expect(range.species[s], {'FRA.1_1': 50});
        expect(range.effort[s], {'FRA.1_1': 1000});
      }
      // Only the name and filters left the phone.
      expect(
        requests.every((u) => !u.query.contains('lat') && !u.query.contains('lng')),
        isTrue,
      );
    });

    test('a second load comes from the cache, with no request', () async {
      await service().load(_species);
      requests.clear();
      final range = await service().load(_species);
      expect(requests, isEmpty);
      expect(range.species[Season.winter], {'FRA.1_1': 50});
    });

    test('the effort is shared by the species', () async {
      await service().load(_species);
      requests.clear();
      await service().load('Turdus merula');
      // Match + 4 species; the effort comes from the cache.
      expect(requests.length, 5);
      expect(requests.any((u) => u.queryParameters.containsKey('classKey')), isFalse);
    });

    test('a species is renewed after 90 days, its effort after 180', () async {
      await service().load(_species);
      requests.clear();
      clock = clock.add(WorldMapConfig.gbifCacheMaxAge + const Duration(days: 1));
      await service().load(_species);
      expect(requests.length, 4, reason: 'species only, taxon key kept');
      expect(requests.every((u) => u.queryParameters['taxonKey'] == '5228'), isTrue);
      requests.clear();
      clock = clock.add(WorldMapConfig.gbifEffortMaxAge + const Duration(days: 1));
      await service().load(_species);
      expect(requests.length, 8);
    });

    test('GBIF down: the old cached counts, else an error', () async {
      await service().load(_species);
      clock = clock.add(const Duration(days: 400));
      final range = await service(
        override: (_) => http.Response('no', 503),
      ).load(_species);
      expect(range.species[Season.summer], {'FRA.1_1': 50});

      await expectLater(
        service(
          override: (_) => http.Response('no', 503),
          withCache: GbifCountsCache(
            directory: () async => Directory('${dir.path}/other'),
          ),
        ).load(_species),
        throwsA(isA<GbifUnavailable>()),
      );
    });

    test('an unknown species is not asked for', () async {
      await expectLater(
        service(
          override: (u) =>
              u.path == WorldMapConfig.gbifMatchPath
                  ? http.Response(jsonEncode({'matchType': 'NONE'}), 200)
                  : null,
        ).load(_species),
        throwsA(isA<GbifUnavailable>()),
      );
      expect(requests.length, 1);
    });
  });

  group('retries', () {
    test('429 and 5xx are asked again after the pauses', () async {
      var failures = 2;
      final range = await service(
        override: (u) {
          if (u.path == WorldMapConfig.gbifMatchPath && failures > 0) {
            failures--;
            return http.Response('slow down', failures == 1 ? 429 : 502);
          }
          return null;
        },
      ).load(_species);
      expect(range.species, isNotEmpty);
      expect(pauses, WorldMapConfig.gbifRetryDelays.take(2).toList());
      expect(requests.where((u) => u.path == WorldMapConfig.gbifMatchPath).length, 3);
    });

    test('gives up after the configured retries', () async {
      await expectLater(
        service(override: (_) => http.Response('', 500)).load(_species),
        throwsA(isA<GbifUnavailable>()),
      );
      expect(pauses.length, WorldMapConfig.gbifRetryDelays.length);
    });

    test('another error is not retried', () async {
      await expectLater(
        service(override: (_) => http.Response('', 404)).load(_species),
        throwsA(isA<GbifUnavailable>()),
      );
      expect(requests.length, 1);
      expect(pauses, isEmpty);
    });
  });

  group('cache', () {
    GbifCounts counts(int n) => GbifCounts(
      fetchedAt: DateTime(2026, 9, 1),
      taxonKey: 7,
      counts: {for (final s in Season.values) s: {'X.1_1': n}},
    );

    test('round trip, with the fetch date and the taxon key', () async {
      final c = cache();
      await c.write('Apus apus', counts(3));
      final back = await c.read('Apus apus');
      expect(back!.taxonKey, 7);
      expect(back.fetchedAt, DateTime(2026, 9, 1));
      expect(back.counts[Season.autumn], {'X.1_1': 3});
      expect(await c.read('Unknown'), isNull);
    });

    test('a damaged or foreign file is ignored', () async {
      final c = cache();
      await c.write('Apus apus', counts(3));
      File('${dir.path}/${GbifCountsCache.fileNameOf('Apus apus')}')
          .writeAsBytesSync([1, 2, 3]);
      expect(await c.read('Apus apus'), isNull);
    });

    test('the least recently shown files go first above the size cap', () async {
      final c = cache(maxBytes: 1);
      await c.write('a b', counts(1));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await c.write('c d', counts(2));
      expect(await c.read('a b'), isNull);
      expect(await c.read('c d'), isNotNull, reason: 'the new one is kept');
    });
  });
}
