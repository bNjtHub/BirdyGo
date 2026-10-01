/// Disk cache of the GBIF counts (J7): one small gzip JSON file per species
/// with its four seasons, and one for the all-birds effort shared by every
/// species, so a species page seen once shows its map offline. The cache is
/// capped in size and drops the least recently shown files first; how long a
/// file stays fresh is the caller's business (it differs per file).
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'gbif_ranges.dart';
import 'world_map_config.dart';

class GbifCountsCache {
  GbifCountsCache({
    required Future<Directory> Function() directory,
    DateTime Function()? now,
    this.maxBytes = WorldMapConfig.gbifCacheMaxBytes,
  }) : _directory = directory,
       _now = now ?? DateTime.now;

  final Future<Directory> Function() _directory;
  final DateTime Function() _now;
  final int maxBytes;

  static const String _extension = '.gbifcounts.gz';
  static const int _version = 1;

  /// File name of a cache entry: lowercase letters, digits and underscores.
  static String fileNameOf(String name) =>
      '${name.toLowerCase().replaceAll(RegExp('[^a-z0-9]+'), '_')}$_extension';

  /// The entry [name], or null (none, damaged, or of another version). Marks
  /// it as shown.
  Future<GbifCounts?> read(String name) async {
    try {
      final file = File('${(await _directory()).path}/${fileNameOf(name)}');
      if (!await file.exists()) return null;
      final counts = _decode(await file.readAsBytes());
      if (counts == null) return null;
      try {
        await file.setLastModified(_now());
      } on Object {
        // Eviction order is then by download date.
      }
      return counts;
    } on Object {
      return null;
    }
  }

  /// Stores [counts] under [name] and evicts the oldest-shown files above the
  /// size cap. A failure is not an error: it is just not cached.
  Future<void> write(String name, GbifCounts counts) async {
    try {
      final dir = await _directory();
      await dir.create(recursive: true);
      final file = File('${dir.path}/${fileNameOf(name)}');
      final part = File('${file.path}.part');
      await part.writeAsBytes(_encode(counts), flush: true);
      await part.rename(file.path);
      await _evict(dir, keep: file);
    } on Object {
      // Nothing cached.
    }
  }

  Future<void> _evict(Directory dir, {required File keep}) async {
    final stats = <File, FileStat>{};
    await for (final entity in dir.list()) {
      if (entity is File && entity.path.endsWith(_extension)) {
        stats[entity] = await entity.stat();
      }
    }
    var total = stats.values.fold<int>(0, (sum, s) => sum + s.size);
    final oldestFirst =
        stats.keys.toList()
          ..sort((a, b) => stats[a]!.modified.compareTo(stats[b]!.modified));
    for (final file in oldestFirst) {
      if (total <= maxBytes) break;
      if (file.uri.pathSegments.last == keep.uri.pathSegments.last) continue;
      total -= stats[file]!.size;
      try {
        await file.delete();
      } on Object {
        // Left for the next eviction.
      }
    }
  }

  static Uint8List _encode(GbifCounts c) {
    final json = {
      'v': _version,
      'at': c.fetchedAt.millisecondsSinceEpoch,
      'key': c.taxonKey,
      'counts': {for (final e in c.counts.entries) e.key.name: e.value},
    };
    return Uint8List.fromList(gzip.encode(utf8.encode(jsonEncode(json))));
  }

  static GbifCounts? _decode(Uint8List bytes) {
    final json = jsonDecode(utf8.decode(gzip.decode(bytes)));
    if (json is! Map<String, dynamic> || json['v'] != _version) return null;
    final raw = json['counts'] as Map<String, dynamic>;
    final counts = <Season, Map<String, int>>{};
    for (final season in Season.values) {
      final m = raw[season.name];
      if (m is! Map<String, dynamic>) return null;
      counts[season] = {for (final e in m.entries) e.key: e.value as int};
    }
    return GbifCounts(
      fetchedAt: DateTime.fromMillisecondsSinceEpoch(json['at'] as int),
      counts: counts,
      taxonKey: json['key'] as int?,
    );
  }
}
