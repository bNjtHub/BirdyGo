import 'dart:convert';
import 'dart:io';

import 'package:birdnet_live/fork/species_photo/inat_photo_service.dart';
import 'package:birdnet_live/fork/species_photo/species_photo_config.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _s3 = 'https://inaturalist-open-data.s3.amazonaws.com/photos';

Map<String, dynamic> _photo(
  int id, {
  String? license = 'cc-by',
  int width = 2048,
  int height = 1365,
}) => {
  'id': id,
  'license_code': license,
  'attribution': '(c) Author $id, some rights reserved (CC BY)',
  'url': '$_s3/$id/square.jpg',
  'original_dimensions': {'width': width, 'height': height},
};

Map<String, dynamic> _taxon(
  int id,
  List<Map<String, dynamic>> photos, {
  Map<String, dynamic>? defaultPhoto,
}) => {
  'id': id,
  'default_photo': defaultPhoto,
  'taxon_photos': [
    for (final p in photos) {'photo': p},
  ],
};

/// A fake iNaturalist: one taxon, photo bytes for any photo URL.
class _FakeInat {
  _FakeInat(this.taxon);

  Map<String, dynamic>? taxon;
  bool offline = false;
  int apiCalls = 0;
  int downloads = 0;
  List<int> photoBytes = List.filled(1000, 7);
  String photoType = 'image/jpeg';

  late final client = MockClient((request) async {
    if (offline) throw http.ClientException('offline');
    if (request.url.host == 'api.inaturalist.org') {
      apiCalls++;
      final taxon = this.taxon;
      if (taxon == null) return http.Response('', 404);
      return http.Response(
        jsonEncode({
          'results': [taxon],
        }),
        200,
      );
    }
    downloads++;
    return http.Response.bytes(
      photoBytes,
      200,
      headers: {'content-type': photoType},
    );
  });
}

void main() {
  group('InatPhotoChoice.pick', () {
    test('first open landscape photo, in curated order, at large size', () {
      final choice =
          InatPhotoChoice.pick(
            _taxon(1, [
              _photo(10, license: null),
              _photo(11, license: 'cc-by-nc-nd'),
              _photo(12, width: 1000, height: 1000),
              _photo(13, license: 'cc-by-nc'),
              _photo(14),
            ]),
          )!;
      expect(choice.url, '$_s3/13/large.jpg');
      expect(choice.credit.author, 'Author 13');
      expect(choice.credit.license, 'cc-by-nc');
      expect(choice.credit.source, 'iNaturalist');
      expect(choice.credit.pageUrl, 'https://www.inaturalist.org/photos/13');
    });

    test('falls back to the default photo, or gives nothing', () {
      expect(
        InatPhotoChoice.pick(
          _taxon(1, [], defaultPhoto: _photo(20, license: 'cc0')),
        )!.url,
        '$_s3/20/large.jpg',
      );
      expect(
        InatPhotoChoice.pick(_taxon(1, [_photo(1, width: 800, height: 1200)])),
        isNull,
      );
      expect(InatPhotoChoice.pick({}), isNull);
    });

    test('sized URLs and authors', () {
      expect(
        inatSizedUrl({'large_url': 'https://x/1/large.jpeg'}, 'large'),
        'https://x/1/large.jpeg',
      );
      expect(
        inatSizedUrl({'url': 'https://x/photos/5/square.png?17'}, 'large'),
        'https://x/photos/5/large.png?17',
      );
      expect(inatSizedUrl({'url': 'https://x/other'}, 'large'), isNull);
      expect(inatAuthor({'attribution_name': 'Jo'}), 'Jo');
      expect(
        inatAuthor({'attribution': '(c) Jo Doe, no rights reserved (CC0)'}),
        'Jo Doe',
      );
      expect(inatAuthor({}), isNull);
    });
  });

  group('InatPhotoService', () {
    late Directory dir;
    late DateTime now;
    late _FakeInat inat;

    InatPhotoService service({int maxCacheBytes = kPhotoCacheMaxBytes}) =>
        InatPhotoService(
          client: inat.client,
          cacheDir: () async => dir,
          now: () => now,
          maxCacheBytes: maxCacheBytes,
        );

    setUp(() {
      dir = Directory.systemTemp.createTempSync('species_photos_');
      now = DateTime(2026, 9, 26, 8);
      inat = _FakeInat(_taxon(13094, [_photo(2, license: 'cc-by-sa')]));
    });

    tearDown(() => dir.deleteSync(recursive: true));

    test('downloads the photo once, then serves it from the cache', () async {
      final photo = (await service().photoFor(13094))!;
      expect(photo.file.readAsBytesSync(), inat.photoBytes);
      expect(photo.credit.author, 'Author 2');
      expect(photo.credit.license, 'cc-by-sa');

      final again = (await service().photoFor(13094))!;
      expect(again.file.path, photo.file.path);
      expect(again.credit.author, 'Author 2');
      expect(inat.apiCalls, 1);
      expect(inat.downloads, 1);
    });

    test('two requests at once make one download', () async {
      final photos = service();
      final both = await Future.wait([
        photos.photoFor(13094),
        photos.photoFor(13094),
      ]);
      expect(both[0]!.file.path, both[1]!.file.path);
      expect(inat.apiCalls, 1);
      expect(inat.downloads, 1);
    });

    test('a taxon without an open photo is remembered for a while', () async {
      inat.taxon = _taxon(13094, [_photo(1, license: null)]);
      expect(await service().photoFor(13094), isNull);
      expect(await service().photoFor(13094), isNull);
      expect(inat.apiCalls, 1);
      expect(inat.downloads, 0);

      now = now.add(kPhotoInfoMaxAge + const Duration(days: 1));
      expect(await service().photoFor(13094), isNull);
      expect(inat.apiCalls, 2);
    });

    test('an unknown taxon gives nothing', () async {
      inat.taxon = null;
      expect(await service().photoFor(13094), isNull);
    });

    test('offline: nothing at first, the old photo later', () async {
      inat.offline = true;
      expect(await service().photoFor(13094), isNull);

      inat.offline = false;
      final photo = (await service().photoFor(13094))!;
      now = now.add(kPhotoInfoMaxAge + const Duration(days: 1));
      inat.offline = true;
      final stale = (await service().photoFor(13094))!;
      expect(stale.file.path, photo.file.path);
      expect(stale.credit.author, 'Author 2');
    });

    test('an old record is checked again, the same photo is kept', () async {
      final photo = (await service().photoFor(13094))!;
      now = now.add(kPhotoInfoMaxAge + const Duration(days: 1));
      final again = (await service().photoFor(13094))!;
      expect(again.file.path, photo.file.path);
      expect(inat.apiCalls, 2);
      expect(inat.downloads, 1);
    });

    test('a new photo on iNaturalist replaces the old file', () async {
      final photo = (await service().photoFor(13094))!;
      now = now.add(kPhotoInfoMaxAge + const Duration(days: 1));
      inat.taxon = _taxon(13094, [_photo(3)]);
      final fresh = (await service().photoFor(13094))!;
      expect(fresh.file.path, isNot(photo.file.path));
      expect(fresh.credit.author, 'Author 3');
      expect(photo.file.existsSync(), isFalse);
    });

    test('refuses what is not an image or is too big', () async {
      inat.photoType = 'text/html';
      expect(await service().photoFor(13094), isNull);

      inat.photoType = 'image/jpeg';
      inat.photoBytes = List.filled(kOnlinePhotoMaxBytes + 1, 0);
      now = now.add(const Duration(seconds: 1));
      expect(await service().photoFor(13094), isNull);
    });

    test(
      'keeps the cache under its size, least recently shown first',
      () async {
        final photos = service(maxCacheBytes: 2500);
        inat.taxon = _taxon(1, [_photo(1)]);
        final first = (await photos.photoFor(1))!;
        now = now.add(const Duration(minutes: 1));
        inat.taxon = _taxon(2, [_photo(2)]);
        final second = (await photos.photoFor(2))!;

        // Showing the first again makes the second the oldest.
        now = now.add(const Duration(minutes: 1));
        await photos.photoFor(1);
        now = now.add(const Duration(minutes: 1));
        inat.taxon = _taxon(3, [_photo(3)]);
        final third = (await photos.photoFor(3))!;

        expect(first.file.existsSync(), isTrue);
        expect(second.file.existsSync(), isFalse);
        expect(third.file.existsSync(), isTrue);

        // The evicted photo comes back without asking the API again.
        final calls = inat.apiCalls;
        inat.taxon = _taxon(2, [_photo(2)]);
        expect(await photos.photoFor(2), isNotNull);
        expect(inat.apiCalls, calls);
      },
    );
  });
}
