/// Disk cache of the GBIF species maps (J7): one small file per species with
/// its four seasons, so a species page seen once shows its map offline.
/// A map is fresh for `WorldMapConfig.gbifCacheMaxAge`; the cache is capped
/// in size and drops the least recently shown maps first.
library;

import 'dart:io';
import 'dart:typed_data';

import 'gbif_map.dart';
import 'season_presence.dart';
import 'world_map_config.dart';

/// A cached map and whether it is still within its validity.
typedef GbifCached = ({GbifSpeciesMap map, bool fresh});

class GbifMapCache {
  GbifMapCache({
    required Future<Directory> Function() directory,
    DateTime Function()? now,
    this.maxAge = WorldMapConfig.gbifCacheMaxAge,
    this.maxBytes = WorldMapConfig.gbifCacheMaxBytes,
  }) : _directory = directory,
       _now = now ?? DateTime.now;

  final Future<Directory> Function() _directory;
  final DateTime Function() _now;
  final Duration maxAge;
  final int maxBytes;

  static const String _extension = '.gbifmap';
  static const List<int> _magic = [0x42, 0x47, 0x4D, 0x31]; // "BGM1"
  static const int _headerSize = 4 + 4 + 8 + 2 + 2;

  /// File name of a species: lowercase letters, digits and underscores.
  static String fileNameOf(String scientificName) =>
      '${scientificName.toLowerCase().replaceAll(RegExp('[^a-z0-9]+'), '_')}$_extension';

  /// The cached map of [scientificName] for a grid of [cols] x [rows] cells,
  /// or null (none, damaged, or made for another grid). Marks it as shown.
  Future<GbifCached?> read(
    String scientificName, {
    required int cols,
    required int rows,
  }) async {
    try {
      final file = File('${(await _directory()).path}/${fileNameOf(scientificName)}');
      if (!await file.exists()) return null;
      final map = _decode(await file.readAsBytes(), cols, rows);
      if (map == null) return null;
      try {
        await file.setLastModified(_now());
      } on Object {
        // Eviction order is then by download date.
      }
      return (map: map, fresh: _now().difference(map.fetchedAt) < maxAge);
    } on Object {
      return null;
    }
  }

  /// Stores [map] and evicts the oldest-shown maps above the size cap. A
  /// failure is not an error: the map is just not cached.
  Future<void> write(String scientificName, GbifSpeciesMap map) async {
    try {
      final dir = await _directory();
      await dir.create(recursive: true);
      final file = File('${dir.path}/${fileNameOf(scientificName)}');
      final part = File('${file.path}.part');
      await part.writeAsBytes(_encode(map), flush: true);
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
      if (file.path == keep.path) continue;
      total -= stats[file]!.size;
      try {
        await file.delete();
      } on Object {
        // Left for the next eviction.
      }
    }
  }

  static Uint8List _encode(GbifSpeciesMap map) {
    final blocks = [for (final l in map.levels) gzip.encode(l)];
    final out = BytesBuilder();
    final header = ByteData(_headerSize);
    for (var i = 0; i < _magic.length; i++) {
      header.setUint8(i, _magic[i]);
    }
    header.setUint32(4, map.taxonKey, Endian.little);
    header.setInt64(8, map.fetchedAt.millisecondsSinceEpoch, Endian.little);
    header.setUint16(16, map.cols, Endian.little);
    header.setUint16(18, map.rows, Endian.little);
    out.add(header.buffer.asUint8List());
    for (final b in blocks) {
      final length = ByteData(4)..setUint32(0, b.length, Endian.little);
      out
        ..add(length.buffer.asUint8List())
        ..add(b);
    }
    return out.toBytes();
  }

  static GbifSpeciesMap? _decode(Uint8List bytes, int cols, int rows) {
    if (bytes.length < _headerSize) return null;
    for (var i = 0; i < _magic.length; i++) {
      if (bytes[i] != _magic[i]) return null;
    }
    final data = ByteData.sublistView(bytes);
    if (data.getUint16(16, Endian.little) != cols ||
        data.getUint16(18, Endian.little) != rows) {
      return null;
    }
    final levels = <Uint8List>[];
    var pos = _headerSize;
    for (var s = 0; s < Season.values.length; s++) {
      if (pos + 4 > bytes.length) return null;
      final length = data.getUint32(pos, Endian.little);
      pos += 4;
      if (pos + length > bytes.length) return null;
      final plain = Uint8List.fromList(
        gzip.decode(bytes.sublist(pos, pos + length)),
      );
      if (plain.length != cols * rows) return null;
      levels.add(plain);
      pos += length;
    }
    return GbifSpeciesMap(
      taxonKey: data.getUint32(4, Endian.little),
      fetchedAt: DateTime.fromMillisecondsSinceEpoch(
        data.getInt64(8, Endian.little),
      ),
      cols: cols,
      rows: rows,
      levels: levels,
    );
  }
}
