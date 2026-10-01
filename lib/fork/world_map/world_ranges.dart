/// Precomputed GBIF ranges of the world map (J7), read from the bundled asset
/// `assets/fork/world/ranges.bin.gz`. Pure Dart.
///
/// Format (gzip of): magic "BGR1"; uint32 LE generation date (yyyymmdd);
/// uint16 LE species count; then per species, sorted by scientific name:
/// uint8 name byte length, UTF-8 name, uint16 LE entry count, entries uint16 LE
/// = (regionIndex << 2) | class. The region index is the 0-based position in
/// the regions asset; class 0 resident, 1 breeding, 2 wintering, 3 passage.
/// A species that is absent has no GBIF map.
library;

import 'dart:convert';
import 'dart:io' show gzip;
import 'dart:typed_data';

import 'range_class.dart';

/// Class of each code of an entry's two low bits.
const List<RangeClass> kRangeClassCodes = [
  RangeClass.resident,
  RangeClass.breeding,
  RangeClass.wintering,
  RangeClass.passage,
];

/// The bundled ranges: an index name to offset, built in one pass, then each
/// lookup reads only its own entries.
class WorldRanges {
  WorldRanges._(this.generation, this._data, this._offsets);

  /// Parses the gzip asset [gz]. Throws [FormatException] when it is not a
  /// ranges asset.
  factory WorldRanges.fromGzip(Uint8List gz) {
    final raw = gzip.decode(gz);
    return WorldRanges.parse(raw is Uint8List ? raw : Uint8List.fromList(raw));
  }

  /// Parses the decompressed [bytes].
  factory WorldRanges.parse(Uint8List bytes) {
    const magic = [0x42, 0x47, 0x52, 0x31]; // "BGR1"
    if (bytes.length < 10) throw const FormatException('ranges: too short');
    for (var i = 0; i < 4; i++) {
      if (bytes[i] != magic[i]) throw const FormatException('ranges: bad magic');
    }
    final view = ByteData.sublistView(bytes);
    final generation = view.getUint32(4, Endian.little);
    final count = view.getUint16(8, Endian.little);
    final offsets = <String, int>{};
    var pos = 10;
    for (var i = 0; i < count; i++) {
      if (pos >= bytes.length) throw const FormatException('ranges: truncated');
      final nameLen = bytes[pos++];
      if (pos + nameLen + 2 > bytes.length) {
        throw const FormatException('ranges: truncated');
      }
      final name = utf8.decode(
        Uint8List.sublistView(bytes, pos, pos + nameLen),
        allowMalformed: true,
      );
      pos += nameLen;
      final entries = view.getUint16(pos, Endian.little);
      offsets[name] = pos;
      pos += 2 + entries * 2;
      if (pos > bytes.length) throw const FormatException('ranges: truncated');
    }
    return WorldRanges._(generation, bytes, offsets);
  }

  /// Generation date of the data, yyyymmdd.
  final int generation;

  final Uint8List _data;
  final Map<String, int> _offsets;

  /// Number of species in the asset.
  int get speciesCount => _offsets.length;

  bool contains(String scientificName) => _offsets.containsKey(scientificName);

  /// Class of each region (by index in the regions asset) of the species, or
  /// null when it is not in the asset.
  Map<int, RangeClass>? entriesOf(String scientificName) {
    final offset = _offsets[scientificName];
    if (offset == null) return null;
    final view = ByteData.sublistView(_data);
    final n = view.getUint16(offset, Endian.little);
    final out = <int, RangeClass>{};
    for (var i = 0; i < n; i++) {
      final v = view.getUint16(offset + 2 + i * 2, Endian.little);
      out[v >> 2] = kRangeClassCodes[v & 3];
    }
    return out;
  }
}
