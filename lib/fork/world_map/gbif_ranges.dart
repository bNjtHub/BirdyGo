/// Reader of the offline GBIF range asset (J7 world map).
///
/// The asset is made on Benjamin's PC by tools/fork_gbif_ranges.py, which also
/// documents the format (header, species index, run-length streams). Pure Dart:
/// no Flutter binding needed, so the decoding runs in an isolate and in tests.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'season_presence.dart';
import 'world_grid.dart';
import 'world_map_config.dart';

/// Geometry of the asset's grid. Row 0 is the northern row, column 0 the
/// western one.
class GbifGrid {
  const GbifGrid({
    required this.step,
    required this.lonMin,
    required this.latMin,
    required this.cols,
    required this.rows,
  });

  /// Cell size, in degrees.
  final double step;
  final double lonMin;
  final double latMin;
  final int cols;
  final int rows;

  int get cellCount => cols * rows;

  double get latMax => latMin + rows * step;

  /// Center of [cell] (row-major, north row first).
  GridCell centerOf(int cell) {
    final row = cell ~/ cols;
    final col = cell % cols;
    return (
      latitude: latMax - (row + 0.5) * step,
      longitude: lonMin + (col + 0.5) * step,
    );
  }
}

/// What the `ranges_gbif.json` file says: where the data comes from.
class GbifMeta {
  const GbifMeta({
    required this.demo,
    required this.extractedAt,
    required this.year,
    required this.license,
    required this.licenseUrl,
    this.doi,
    this.doiUrl,
    this.citation,
  });

  factory GbifMeta.fromJson(Map<String, dynamic> json) => GbifMeta(
    demo: json['demo'] == true,
    extractedAt: json['extractedAt'] as String,
    year: (json['year'] as num).toInt(),
    license: json['license'] as String,
    licenseUrl: json['licenseUrl'] as String,
    doi: json['doi'] as String?,
    doiUrl: json['doiUrl'] as String?,
    citation: json['citation'] as String?,
  );

  factory GbifMeta.parse(String source) =>
      GbifMeta.fromJson(jsonDecode(source) as Map<String, dynamic>);

  /// True for the fictitious development asset: it is never shown in a
  /// release build.
  final bool demo;

  /// ISO date of the extraction.
  final String extractedAt;
  final int year;

  /// « CC BY 4.0 ».
  final String license;
  final String licenseUrl;

  /// DOI of the GBIF download (citation required), null for the demo asset.
  final String? doi;
  final String? doiUrl;
  final String? citation;

  /// Whether the asset may be used in this kind of build.
  bool usableIn({required bool release}) => !(demo && release);
}

/// Where the map of a species comes from.
enum WorldMapSource { gbif, geomodel }

/// The range of one species, ready to draw, and where it comes from.
class WorldMapData {
  const WorldMapData(this.presence, this.source);

  final SeasonPresence presence;
  final WorldMapSource source;
}

/// GBIF when the asset has [scientificName], the geo-model otherwise (also
/// without an asset).
WorldMapSource chooseWorldMapSource(GbifIndex? index, String scientificName) =>
    index != null && index.contains(scientificName)
        ? WorldMapSource.gbif
        : WorldMapSource.geomodel;

/// Header and species index of the asset, plus the bytes: one species is
/// decoded on demand.
class GbifIndex {
  GbifIndex._(this.grid, this._bytes, this._entries, this._dataOffset);

  /// Magic of format version 1.
  static const List<int> _magic = [0x42, 0x47, 0x52, 0x31]; // "BGR1"
  static const int _headerSize = 20;

  /// Parses [bytes]. Throws [FormatException] when they are not the asset.
  factory GbifIndex.parse(Uint8List bytes) {
    if (bytes.length < _headerSize) {
      throw const FormatException('GBIF asset too short');
    }
    for (var i = 0; i < _magic.length; i++) {
      if (bytes[i] != _magic[i]) {
        throw const FormatException('GBIF asset: bad magic');
      }
    }
    final data = ByteData.sublistView(bytes);
    final grid = GbifGrid(
      step: data.getUint16(4, Endian.little) / 100,
      lonMin: data.getInt16(6, Endian.little) / 100,
      latMin: data.getInt16(8, Endian.little) / 100,
      cols: data.getUint16(10, Endian.little),
      rows: data.getUint16(12, Endian.little),
    );
    final count = data.getUint16(14, Endian.little);
    final dataOffset = data.getUint32(16, Endian.little);
    final entries = <String, ({int offset, int length})>{};
    var pos = _headerSize;
    for (var i = 0; i < count; i++) {
      final nameLength = bytes[pos];
      final name = utf8.decode(bytes.sublist(pos + 1, pos + 1 + nameLength));
      final offset = data.getUint32(pos + 1 + nameLength, Endian.little);
      final length = data.getUint32(pos + 5 + nameLength, Endian.little);
      if (dataOffset + offset + length > bytes.length) {
        throw const FormatException('GBIF asset: block out of range');
      }
      entries[name] = (offset: offset, length: length);
      pos += 9 + nameLength;
    }
    return GbifIndex._(grid, bytes, entries, dataOffset);
  }

  final GbifGrid grid;
  final Uint8List _bytes;
  final Map<String, ({int offset, int length})> _entries;
  final int _dataOffset;

  int get speciesCount => _entries.length;

  Iterable<String> get names => _entries.keys;

  bool contains(String scientificName) => _entries.containsKey(scientificName);

  /// A copy of the bytes of one species (small: sent to an isolate as is),
  /// or null when the asset does not have it.
  Uint8List? blockOf(String scientificName) {
    final e = _entries[scientificName];
    if (e == null) return null;
    final start = _dataOffset + e.offset;
    return Uint8List.fromList(_bytes.sublist(start, start + e.length));
  }
}

/// Request of [decodeGbifSpecies]: plain data, so it crosses into an isolate.
class GbifDecodeRequest {
  const GbifDecodeRequest(this.block, this.grid);

  final Uint8List block;
  final GbifGrid grid;
}

/// Levels (0 absent, 1 to [WorldMapConfig.gbifLevels] from faint to strong) of
/// every cell, one list per season in the order of `Season.values`.
List<Uint8List> decodeGbifBlock(Uint8List block, int cellCount) {
  final data = ByteData.sublistView(block);
  final seasons = <Uint8List>[];
  var pos = 0;
  for (var s = 0; s < Season.values.length; s++) {
    final length = data.getUint16(pos, Endian.little);
    pos += 2;
    seasons.add(_decodeRuns(block, pos, pos + length, cellCount));
    pos += length;
  }
  return seasons;
}

Uint8List _decodeRuns(Uint8List bytes, int start, int end, int cellCount) {
  final levels = Uint8List(cellCount);
  var cell = 0;
  var pos = start;
  while (pos < end) {
    var value = 0;
    var shift = 0;
    while (true) {
      final b = bytes[pos++];
      value |= (b & 0x7F) << shift;
      shift += 7;
      if (b & 0x80 == 0) break;
    }
    final run = value >> 2;
    final level = value & 3;
    if (cell + run > cellCount) {
      throw const FormatException('GBIF asset: run past the grid');
    }
    if (level != 0) levels.fillRange(cell, cell + run, level);
    cell += run;
  }
  if (cell != cellCount) {
    throw const FormatException('GBIF asset: runs do not cover the grid');
  }
  return levels;
}

/// Decodes one species into the drawing model. A top-level function of one
/// argument: it is what `compute` runs off the UI thread.
SeasonPresence decodeGbifSpecies(GbifDecodeRequest request) {
  final grid = request.grid;
  final levels = decodeGbifBlock(request.block, grid.cellCount);
  final cells = <GridCell>[];
  final flags = {for (final s in Season.values) s: <bool>[]};
  final perSeason = {for (final s in Season.values) s: <int>[]};
  for (var cell = 0; cell < grid.cellCount; cell++) {
    var any = false;
    for (var s = 0; s < levels.length; s++) {
      if (levels[s][cell] != 0) any = true;
    }
    if (!any) continue;
    cells.add(grid.centerOf(cell));
    for (var s = 0; s < levels.length; s++) {
      final season = Season.values[s];
      flags[season]!.add(levels[s][cell] != 0);
      perSeason[season]!.add(levels[s][cell]);
    }
  }
  return SeasonPresence(cells, flags, step: grid.step, levels: perSeason);
}
