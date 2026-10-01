/// Asks GBIF for the observation map of one species (J7 world map): resolves
/// its taxon key, then downloads the tiles of the four seasons (a few at a
/// time, short time limits), and keeps the result in the disk cache.
///
/// Only the species' scientific name leaves the phone, never a position.
library;

import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:http/http.dart' as http;

import '../../core/constants/app_constants.dart';
import 'gbif_cache.dart';
import 'gbif_map.dart';
import 'world_map_config.dart';

/// GBIF has no usable map for the species, or it did not answer.
class GbifUnavailable implements Exception {
  GbifUnavailable(this.reason);

  final String reason;

  @override
  String toString() => 'GbifUnavailable: $reason';
}

/// The default PNG decoder, on the engine's codec.
Future<GbifRaster> decodePngRaster(Uint8List png) async {
  final codec = await ui.instantiateImageCodec(png);
  try {
    final frame = await codec.getNextFrame();
    final image = frame.image;
    try {
      final data = await image.toByteData(
        format: ui.ImageByteFormat.rawStraightRgba,
      );
      return GbifRaster(
        image.width,
        image.height,
        data!.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      );
    } finally {
      image.dispose();
    }
  } finally {
    codec.dispose();
  }
}

class GbifMapService {
  GbifMapService({
    required http.Client client,
    required GbifMapCache cache,
    GbifRasterDecoder decode = decodePngRaster,
    DateTime Function()? now,
  }) : _client = client,
       _cache = cache,
       _decode = decode,
       _now = now ?? DateTime.now;

  final http.Client _client;
  final GbifMapCache _cache;
  final GbifRasterDecoder _decode;
  final DateTime Function() _now;

  static const _headers = {
    'User-Agent': AppConstants.networkUserAgent,
    'Accept': 'application/json, image/png',
  };

  final GbifGrid grid = GbifGrid.forZone();

  /// The four-season map of [scientificName]: the cache when fresh, else
  /// GBIF; an old cached map when GBIF cannot be reached. Throws
  /// [GbifUnavailable] (or a network error) when there is nothing to show.
  Future<GbifSpeciesMap> load(String scientificName) async {
    final cached = await _cache.read(
      scientificName,
      cols: grid.cols,
      rows: grid.rows,
    );
    if (cached != null && cached.fresh) return cached.map;
    try {
      final map = await _fetch(scientificName, cached?.map.taxonKey);
      await _cache.write(scientificName, map);
      return map;
    } on Object {
      if (cached != null) return cached.map;
      rethrow;
    }
  }

  Future<GbifSpeciesMap> _fetch(String scientificName, int? knownKey) async {
    final taxonKey = knownKey ?? await _resolveTaxonKey(scientificName);
    final lastYear = _now().year;
    final levels = {
      for (final s in Season.values) s: Uint8List(grid.cellCount),
    };
    var failed = false;
    final jobs = <Future<void> Function()>[
      for (final season in Season.values)
        for (final tile in grid.tiles)
          () async {
            if (failed) return;
            try {
              final raster = await _tile(
                gbifTileUri(
                  taxonKey: taxonKey,
                  season: season,
                  tile: tile,
                  lastYear: lastYear,
                ),
              );
              if (raster != null) grid.readTile(tile, raster, levels[season]!);
            } on Object {
              failed = true;
              rethrow;
            }
          },
    ];
    var next = 0;
    Future<void> worker() async {
      while (next < jobs.length) {
        await jobs[next++]();
      }
    }

    await Future.wait([
      for (var i = 0; i < WorldMapConfig.gbifMaxParallel; i++) worker(),
    ]);
    return GbifSpeciesMap(
      taxonKey: taxonKey,
      fetchedAt: _now(),
      cols: grid.cols,
      rows: grid.rows,
      levels: [for (final s in Season.values) levels[s]!],
    );
  }

  Future<int> _resolveTaxonKey(String scientificName) async {
    final response = await _client
        .get(gbifMatchUri(scientificName), headers: _headers)
        .timeout(WorldMapConfig.gbifMatchTimeout);
    if (response.statusCode != 200) {
      throw GbifUnavailable('match HTTP ${response.statusCode}');
    }
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final key = json['usageKey'];
    if (key is! int ||
        !WorldMapConfig.gbifMatchTypes.contains(json['matchType'])) {
      throw GbifUnavailable('no taxon for $scientificName');
    }
    return key;
  }

  /// A decoded tile, or null for an empty one (no observation there).
  Future<GbifRaster?> _tile(Uri uri) async {
    final response = await _client
        .get(uri, headers: _headers)
        .timeout(WorldMapConfig.gbifTileTimeout);
    if (response.statusCode == 204) return null;
    if (response.statusCode != 200) {
      throw GbifUnavailable('tile HTTP ${response.statusCode}');
    }
    if (response.bodyBytes.isEmpty) return null;
    return _decode(response.bodyBytes);
  }
}
