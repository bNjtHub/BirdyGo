/// Pure decoding of a gzip JSON species bundle file (J7). Kept free of
/// Flutter so it can run in a background isolate (`compute`) instead of the
/// UI thread: the descriptions files are large and the fiche espèce waits
/// on them.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show compute;

/// Decompresses and parses [gzipBytes] into a `scientific name → text` map.
Map<String, String> decodeSpeciesBundle(Uint8List gzipBytes) {
  final json =
      jsonDecode(utf8.decode(gzip.decode(gzipBytes))) as Map<String, dynamic>;
  return json.map((k, v) => MapEntry(k, v as String));
}

/// [decodeSpeciesBundle] off the UI thread.
Future<Map<String, String>> decodeSpeciesBundleInBackground(
  Uint8List gzipBytes,
) => compute(decodeSpeciesBundle, gzipBytes);
