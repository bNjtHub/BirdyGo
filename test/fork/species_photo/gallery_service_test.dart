import 'dart:convert';
import 'dart:io';

import 'package:birdnet_live/fork/species_photo/inat_photo_service.dart';
import 'package:birdnet_live/fork/species_photo/species_photo_config.dart';
import 'package:birdnet_live/fork/species_photo/species_photo_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Map<String, dynamic> _photo(int id, {String license = 'cc-by'}) => {
  'id': id,
  'license_code': license,
  'attribution': '(c) Author $id, some rights reserved (CC BY)',
  'url': 'https://photos.example/$id/square.jpg',
  'original_dimensions': {'width': 2000, 'height': 1300},
};

Map<String, dynamic> _obs(int id, {int? stage, int? sex, String? license}) => {
  'annotations': [
    if (stage != null)
      {'controlled_attribute_id': 1, 'controlled_value_id': stage},
    if (sex != null) {'controlled_attribute_id': 9, 'controlled_value_id': sex},
  ],
  'photos': [_photo(id, license: license ?? 'cc-by')],
};

class _Net {
  /// Results per "term:value" query.
  Map<String, List<Map<String, dynamic>>> observations = {};
  List<int> taxonPhotos = [];
  final queries = <String>[];
  int taxonCalls = 0;
  int downloads = 0;
  bool offline = false;
  final failDownloads = <String>{};

  late final client = MockClient((request) async {
    if (offline) throw http.ClientException('offline');
    final url = request.url;
    if (url.host == 'api.inaturalist.org') {
      if (url.path == '/v2/observations') {
        final key =
            '${url.queryParameters['term_id']}:'
            '${url.queryParameters['term_value_id']}';
        queries.add(key);
        return http.Response(
          jsonEncode({'results': observations[key] ?? const []}),
          200,
        );
      }
      taxonCalls++;
      return http.Response(
        jsonEncode({
          'results': [
            {
              'id': 7,
              'taxon_photos': [
                for (final id in taxonPhotos) {'photo': _photo(id)},
              ],
            },
          ],
        }),
        200,
      );
    }
    downloads++;
    if (failDownloads.any(url.path.contains)) {
      return http.Response('', 500);
    }
    return http.Response.bytes(
      List.filled(100, 3),
      200,
      headers: {'content-type': 'image/jpeg'},
    );
  });

  int get requests => queries.length + taxonCalls;
}

void main() {
  late Directory dir;
  late DateTime now;
  late _Net net;

  InatPhotoService service() => InatPhotoService(
    client: net.client,
    cacheDir: () async => dir,
    now: () => now,
  );

  Future<List<GalleryPhoto>> gallery() => service().galleryFor(7).last;

  String describe(List<GalleryPhoto> photos) => [
    for (final p in photos)
      '${p.credit.author}:${p.label?.stage?.name}/${p.label?.sex?.name}',
  ].join(' ');

  setUp(() {
    dir = Directory.systemTemp.createTempSync('gallery_svc_');
    now = DateTime(2026, 10, 2, 9);
    net = _Net();
  });
  tearDown(() => dir.deleteSync(recursive: true));

  test('a juvenile is found by its targeted query, listed last', () async {
    net.observations = {
      '9:11': [_obs(1, stage: 2, sex: 11)],
      '9:10': [_obs(2, stage: 2, sex: 10)],
      '1:8': [_obs(3)],
    };
    final photos = await gallery();
    expect(
      describe(photos),
      'Author 1:adult/male Author 2:adult/female Author 3:juvenile/null',
    );
    expect(net.queries, ['9:11', '9:10', '1:8']);
  });

  test('at most 3 targeted requests, plus 1 taxon fallback', () async {
    net.taxonPhotos = [10, 11, 12, 13];
    final photos = await gallery();
    expect(net.queries.length, 3);
    expect(net.taxonCalls, 1);
    expect(net.requests, 4);
    expect(describe(photos), contains('Author 10:null/null'));
    expect(photos.length, kCarouselExtraPhotos);
  });

  test('a sex without photos is filled by another adult, "Adulte"', () async {
    net.observations = {
      '9:11': [_obs(1, stage: 2, sex: 11), _obs(2, stage: 2, sex: 11)],
      '1:8': [_obs(3)],
    };
    final photos = await gallery();
    expect(
      describe(photos),
      'Author 1:adult/male Author 2:adult/null Author 3:juvenile/null',
    );
  });

  test('a juvenile annotation never serves as adult; licences are '
      'filtered', () async {
    net.observations = {
      '9:11': [
        _obs(1, stage: 8, sex: 11),
        _obs(2, license: 'cc-by-nd'),
        _obs(3),
      ],
    };
    final photos = await gallery();
    expect(describe(photos), 'Author 3:null/male');
  });

  test(
    'the same selection comes from disk on a new service, offline',
    () async {
      net.observations = {
        '9:11': [_obs(1, stage: 2, sex: 11)],
        '1:8': [_obs(3)],
      };
      final first = await gallery();
      final requests = net.requests;
      final downloads = net.downloads;
      net.offline = true;
      final again = await gallery();
      expect(describe(again), describe(first));
      expect(again.first.bytes, first.first.bytes);
      expect(net.requests, requests);
      expect(net.downloads, downloads);
    },
  );

  test('after 30 days the selection is asked again', () async {
    net.observations = {
      '9:11': [_obs(1, stage: 2, sex: 11)],
    };
    await gallery();
    final before = net.requests;
    now = now.add(kPhotoInfoMaxAge - const Duration(days: 1));
    await gallery();
    expect(net.requests, before);

    net.observations = {
      '9:11': [_obs(5, stage: 2, sex: 11)],
    };
    now = now.add(const Duration(days: 2));
    final photos = await gallery();
    expect(net.requests, greaterThan(before));
    expect(describe(photos), 'Author 5:adult/male');
  });

  test('expired and offline: the old selection still shows', () async {
    net.observations = {
      '9:11': [_obs(1, stage: 2, sex: 11)],
    };
    await gallery();
    now = now.add(const Duration(days: 60));
    net.offline = true;
    expect(describe(await gallery()), 'Author 1:adult/male');
  });

  test('another cache version is ignored', () async {
    net.observations = {
      '9:11': [_obs(1, stage: 2, sex: 11)],
    };
    await gallery();
    final file = File('${dir.path}/gallery_7.json');
    final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    json['version'] = kGalleryCacheVersion + 1;
    file.writeAsStringSync(jsonEncode(json));
    final before = net.requests;
    await gallery();
    expect(net.requests, greaterThan(before));
  });

  group('the gallery state ends with loading false', () {
    Future<SpeciesGallery> lastOf(Stream<List<GalleryPhoto>> s) =>
        withGalleryProgress(s).last;

    test('all ok', () async {
      net.observations = {
        '9:11': [_obs(1, stage: 2, sex: 11)],
      };
      final last = await lastOf(service().galleryFor(7));
      expect(last.loading, isFalse);
      expect(last.photos.length, 1);
    });

    test('one download fails', () async {
      net.observations = {
        '9:11': [_obs(1, stage: 2, sex: 11)],
        '9:10': [_obs(2, stage: 2, sex: 10)],
      };
      net.failDownloads.add('/1/');
      final last = await lastOf(service().galleryFor(7));
      expect(last.loading, isFalse);
      expect(describe(last.photos), 'Author 2:adult/female');
    });

    test('everything filtered', () async {
      net.observations = {
        '9:11': [_obs(1, license: 'cc-by-nd')],
      };
      final last = await lastOf(service().galleryFor(7));
      expect(last.loading, isFalse);
      expect(last.photos, isEmpty);
    });

    test('taxon fallback', () async {
      net.taxonPhotos = [10];
      final last = await lastOf(service().galleryFor(7));
      expect(last.loading, isFalse);
      expect(last.photos.length, 1);
    });

    test('cache hit', () async {
      net.observations = {
        '9:11': [_obs(1, stage: 2, sex: 11)],
      };
      await gallery();
      final last = await lastOf(service().galleryFor(7));
      expect(last.loading, isFalse);
      expect(last.photos.length, 1);
    });

    test('the source stream throws', () async {
      final last = await lastOf(
        Stream<List<GalleryPhoto>>.error(StateError('boom')),
      );
      expect(last.loading, isFalse);
    });

    test('an errored provider state does not show the spinner', () {
      expect(
        galleryLoading(
          AsyncError<SpeciesGallery>(StateError('x'), StackTrace.empty),
        ),
        isFalse,
      );
      expect(galleryLoading(const AsyncLoading<SpeciesGallery>()), isTrue);
    });
  });
}
