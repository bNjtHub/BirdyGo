/// Disk cache of the large species photos (J6b).
///
/// One file per photo in the app cache directory. A photo is downloaded
/// once, written to a temporary file then renamed (never a half photo),
/// and the least recently shown photos go when the cache is over budget.
/// Any failure (offline, timeout, not an image) returns null: the bundled
/// photo simply stays.
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'photo_config.dart';

class SpeciesPhotoCache {
  SpeciesPhotoCache({
    required Future<Directory> Function() directory,
    required http.Client client,
    this.maxBytes = PhotoConfig.maxCacheBytes,
    this.maxPhotoBytes = PhotoConfig.maxPhotoBytes,
    this.timeout = PhotoConfig.downloadTimeout,
  }) : _directory = directory,
       _client = client;

  final Future<Directory> Function() _directory;
  final http.Client _client;
  final int maxBytes;
  final int maxPhotoBytes;
  final Duration timeout;

  Future<Directory>? _dir;
  final Map<String, Future<File?>> _inFlight = {};

  static const String _extension = '.img';

  /// The cached file of photo [key], downloaded from [url] when missing.
  /// Concurrent calls for the same key share one download.
  Future<File?> file(String key, Uri url) =>
      _inFlight[key] ??= _load(key, url).whenComplete(() {
        // A block, not an arrow: remove() returns this very future, and
        // whenComplete would wait for it forever.
        _inFlight.remove(key);
      });

  Future<File?> _load(String key, Uri url) async {
    try {
      final dir = await (_dir ??= _openDirectory());
      final target = File(p.join(dir.path, '${_safe(key)}$_extension'));
      if (await target.exists()) {
        await _touch(target);
        return target;
      }
      if (!url.isScheme('https')) return null;

      final response = await _client.get(url).timeout(timeout);
      final bytes = response.bodyBytes;
      final type = response.headers['content-type'];
      if (response.statusCode != 200 ||
          bytes.isEmpty ||
          bytes.length > maxPhotoBytes ||
          (type != null && !type.startsWith('image/'))) {
        return null;
      }
      final temp = File('${target.path}.tmp');
      await temp.writeAsBytes(bytes, flush: true);
      await temp.rename(target.path);
      await _evict(dir, keep: target.path);
      return target;
    } catch (e) {
      debugPrint('[SpeciesPhotoCache] $key not available: $e');
      _dir = null; // retry opening the folder next time if that failed
      return null;
    }
  }

  Future<Directory> _openDirectory() async {
    final dir = await _directory();
    await dir.create(recursive: true);
    return dir;
  }

  /// Marks a photo as just shown, for the eviction order.
  Future<void> _touch(File file) async {
    try {
      await file.setLastModified(DateTime.now());
    } catch (_) {
      // Read-only timestamps only make the eviction order less precise.
    }
  }

  /// Removes the least recently shown photos until under [maxBytes].
  Future<void> _evict(Directory dir, {required String keep}) async {
    final files = <File, FileStat>{};
    await for (final entity in dir.list()) {
      if (entity is File && entity.path.endsWith(_extension)) {
        files[entity] = await entity.stat();
      }
    }
    var total = files.values.fold<int>(0, (sum, stat) => sum + stat.size);
    if (total <= maxBytes) return;
    final oldestFirst =
        files.entries.toList()
          ..sort((a, b) => a.value.modified.compareTo(b.value.modified));
    for (final entry in oldestFirst) {
      if (total <= maxBytes) break;
      if (entry.key.path == keep) continue;
      try {
        await entry.key.delete();
        total -= entry.value.size;
      } catch (_) {
        // Already gone.
      }
    }
  }

  static String _safe(String key) =>
      key.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
}

/// The app's photo cache, in `<cache>/species_photos/`.
final speciesPhotoCacheProvider = Provider<SpeciesPhotoCache>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return SpeciesPhotoCache(
    client: client,
    directory:
        () async => Directory(
          p.join(
            (await getApplicationCacheDirectory()).path,
            PhotoConfig.cacheDirName,
          ),
        ),
  );
});
