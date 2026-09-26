import 'dart:async';
import 'dart:io';

import 'package:birdnet_live/fork/photos/species_photo_cache.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

final _url = Uri.parse('https://example.org/photos/42/large.jpg');
const _jpeg = {'content-type': 'image/jpeg'};

void main() {
  late Directory dir;
  late int calls;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('species_photos_test');
    calls = 0;
  });

  tearDown(() async {
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  SpeciesPhotoCache cache(
    Future<http.Response> Function(http.Request) handler, {
    int maxBytes = 1 << 20,
    int maxPhotoBytes = 1 << 20,
    Duration timeout = const Duration(seconds: 5),
  }) => SpeciesPhotoCache(
    directory: () async => dir,
    client: MockClient((request) {
      calls++;
      return handler(request);
    }),
    maxBytes: maxBytes,
    maxPhotoBytes: maxPhotoBytes,
    timeout: timeout,
  );

  Future<http.Response> photo(http.Request _) async =>
      http.Response.bytes(List.filled(10, 7), 200, headers: _jpeg);

  List<String> names() =>
      dir.listSync().map((e) => e.uri.pathSegments.last).toList()..sort();

  test('downloads once, then reads the disk', () async {
    final c = cache(photo);
    final first = await c.file('42', _url);
    final second = await c.file('42', _url);
    expect(first, isNotNull);
    expect(second!.path, first!.path);
    expect(await second.readAsBytes(), List.filled(10, 7));
    expect(calls, 1);
    expect(names(), ['42.img']);
  });

  test('a new cache instance finds the photo on disk', () async {
    await cache(photo).file('42', _url);
    final again = cache(photo);
    expect(await again.file('42', _url), isNotNull);
    expect(calls, 1);
  });

  test('concurrent requests share one download', () async {
    final gate = Completer<void>();
    final c = cache((request) async {
      await gate.future;
      return photo(request);
    });
    final a = c.file('42', _url);
    final b = c.file('42', _url);
    gate.complete();
    expect((await a)!.path, (await b)!.path);
    expect(calls, 1);
  });

  test('failures return null and leave no file', () async {
    final cases = <String, Future<http.Response> Function(http.Request)>{
      'not found': (_) async => http.Response('nope', 404),
      'not an image':
          (_) async => http.Response(
            '<html>',
            200,
            headers: {'content-type': 'text/html'},
          ),
      'empty': (_) async => http.Response.bytes([], 200, headers: _jpeg),
      'offline': (_) async => throw const SocketException('offline'),
    };
    for (final entry in cases.entries) {
      expect(
        await cache(entry.value).file(entry.key, _url),
        isNull,
        reason: entry.key,
      );
    }
    expect(names(), isEmpty);
  });

  test('refuses too large bodies', () async {
    final c = cache(photo, maxPhotoBytes: 5);
    expect(await c.file('42', _url), isNull);
    expect(names(), isEmpty);
  });

  test('gives up after the timeout', () async {
    final c = cache(
      (_) => Completer<http.Response>().future,
      timeout: const Duration(milliseconds: 20),
    );
    expect(await c.file('42', _url), isNull);
  });

  test('only https', () async {
    final c = cache(photo);
    expect(await c.file('42', Uri.parse('http://example.org/a.jpg')), isNull);
    expect(calls, 0);
  });

  test('keys are safe file names', () async {
    await cache(photo).file('../evil/42', _url);
    expect(names(), ['___evil_42.img']);
  });

  test('evicts the least recently shown photos over budget', () async {
    final c = cache(photo, maxBytes: 25);
    final a = (await c.file('a', _url))!;
    final b = (await c.file('b', _url))!;
    a.setLastModifiedSync(DateTime(2020));
    b.setLastModifiedSync(DateTime(2021));

    // Showing a again makes b the oldest.
    await c.file('a', _url);
    expect(a.lastModifiedSync().year, greaterThan(2021));

    await c.file('c', _url);
    expect(names(), ['a.img', 'c.img']);
  });

  test('the new photo stays even when alone over budget', () async {
    final c = cache(photo, maxBytes: 5);
    expect(await c.file('a', _url), isNotNull);
    expect(names(), ['a.img']);
  });
}
