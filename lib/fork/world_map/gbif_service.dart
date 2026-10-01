/// Asks GBIF for the observation counts of one species per administrative
/// region (J7 world map): resolves its taxon key, then counts its human
/// observations per GADM level-1 region for each of the four seasons, and the
/// same for every bird (the observation effort, kept much longer). Two
/// requests at a time at most, short time limits, a few retries on 429 and
/// 5xx, and the disk cache in front of it all.
///
/// Only the species' scientific name leaves the phone, never a position.
library;

import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/constants/app_constants.dart';
import 'gbif_cache.dart';
import 'gbif_ranges.dart';
import 'range_class.dart';
import 'world_map_config.dart';

/// GBIF has no usable answer for the species, or it did not answer.
class GbifUnavailable implements Exception {
  GbifUnavailable(this.reason);

  final String reason;

  @override
  String toString() => 'GbifUnavailable: $reason';
}

class GbifRangeService {
  GbifRangeService({
    required http.Client client,
    required GbifCountsCache cache,
    DateTime Function()? now,
    Future<void> Function(Duration)? delay,
  }) : _client = client,
       _cache = cache,
       _now = now ?? DateTime.now,
       _delay = delay ?? Future<void>.delayed;

  final http.Client _client;
  final GbifCountsCache _cache;
  final DateTime Function() _now;
  final Future<void> Function(Duration) _delay;

  static const _headers = {
    'User-Agent': AppConstants.networkUserAgent,
    'Accept': 'application/json',
  };

  /// The counts of [scientificName] and of every bird: the cache when fresh,
  /// else GBIF; an old cached entry when GBIF cannot be reached. Throws
  /// [GbifUnavailable] (or a network error) when there is nothing to show.
  Future<GbifRange> load(String scientificName) async {
    final species = await _cache.read(scientificName);
    final effort = await _cache.read(WorldMapConfig.gbifEffortCacheName);
    final speciesCounts = await _fresh(
      species,
      WorldMapConfig.gbifCacheMaxAge,
      (known) async {
        final key = known?.taxonKey ?? await _resolveTaxonKey(scientificName);
        final counts = await _seasons(key);
        final fetched = GbifCounts(
          fetchedAt: _now(),
          counts: counts,
          taxonKey: key,
        );
        await _cache.write(scientificName, fetched);
        return fetched;
      },
    );
    final effortCounts = await _fresh(
      effort,
      WorldMapConfig.gbifEffortMaxAge,
      (_) async {
        final fetched = GbifCounts(
          fetchedAt: _now(),
          counts: await _seasons(null),
        );
        await _cache.write(WorldMapConfig.gbifEffortCacheName, fetched);
        return fetched;
      },
    );
    return GbifRange(
      species: speciesCounts.counts,
      effort: effortCounts.counts,
    );
  }

  /// [cached] when younger than [maxAge], else what [fetch] brings; the old
  /// [cached] one when [fetch] fails.
  Future<GbifCounts> _fresh(
    GbifCounts? cached,
    Duration maxAge,
    Future<GbifCounts> Function(GbifCounts? cached) fetch,
  ) async {
    if (cached != null && _now().difference(cached.fetchedAt) < maxAge) {
      return cached;
    }
    try {
      return await fetch(cached);
    } on Object {
      if (cached != null) return cached;
      rethrow;
    }
  }

  /// The four seasons of [taxonKey] (every bird when null), two requests at a
  /// time.
  Future<SeasonCounts> _seasons(int? taxonKey) async {
    final lastYear = _now().year;
    final out = <Season, Map<String, int>>{};
    final seasons = [...Season.values];
    Future<void> worker() async {
      while (seasons.isNotEmpty) {
        final season = seasons.removeAt(0);
        out[season] = await _facet(
          gbifFacetUri(taxonKey: taxonKey, season: season, lastYear: lastYear),
        );
      }
    }

    await Future.wait([
      for (var i = 0; i < WorldMapConfig.gbifMaxParallel; i++) worker(),
    ]);
    return {for (final s in Season.values) s: out[s]!};
  }

  Future<int> _resolveTaxonKey(String scientificName) async {
    final response = await _get(
      gbifMatchUri(scientificName),
      WorldMapConfig.gbifMatchTimeout,
    );
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final key = json['usageKey'];
    if (key is! int ||
        !WorldMapConfig.gbifMatchTypes.contains(json['matchType'])) {
      throw GbifUnavailable('no taxon for $scientificName');
    }
    return key;
  }

  Future<Map<String, int>> _facet(Uri uri) async {
    final response = await _get(uri, WorldMapConfig.gbifFacetTimeout);
    return parseFacetCounts(jsonDecode(response.body) as Map<String, dynamic>);
  }

  /// A GET answered 200. A 429 or 5xx (or a timeout) is asked again after the
  /// configured pauses; any other status fails at once.
  Future<http.Response> _get(Uri uri, Duration timeout) async {
    final pauses = WorldMapConfig.gbifRetryDelays;
    for (var attempt = 0; ; attempt++) {
      try {
        final response = await _client
            .get(uri, headers: _headers)
            .timeout(timeout);
        if (response.statusCode == 200) return response;
        final retryable =
            response.statusCode == 429 || response.statusCode >= 500;
        if (!retryable || attempt >= pauses.length) {
          throw GbifUnavailable('HTTP ${response.statusCode}');
        }
      } on GbifUnavailable {
        rethrow;
      } on Object {
        if (attempt >= pauses.length) rethrow;
      }
      await _delay(pauses[attempt]);
    }
  }
}
