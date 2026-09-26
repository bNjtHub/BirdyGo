/// Geo presence of species at the place and week of a detection
/// (fork/PLAN.md J3). One small geo-model run per rounded place and week,
/// cached for the app's lifetime.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/announcements/domain/announcement_signals.dart';
import '../../features/announcements/geo_commonness_provider.dart';
import '../../features/explore/explore_providers.dart';
import '../../features/inference/geo_abundance.dart';
import '../../features/inference/geo_model.dart';
import 'reliability_config.dart';

/// Computes and caches [GeoPresence] maps.
class GeoPresenceService {
  GeoPresenceService(this._ref);

  final Ref _ref;
  final Map<String, Future<Map<String, GeoPresence>>> _cache = {};

  /// Presence of [scientificName] at ([latitude], [longitude]) during the
  /// geo-model week of [time], or null without a position or a model.
  Future<GeoPresence?> presenceAt(
    String scientificName, {
    required double? latitude,
    required double? longitude,
    required DateTime time,
  }) async {
    if (latitude == null || longitude == null) return null;
    try {
      final map = await _mapFor(latitude, longitude, time);
      if (map.isEmpty) return null;
      return map[scientificName] ?? kAbsentHere;
    } catch (_) {
      // No geo-model (e.g. assets missing): plausibility stays unknown.
      return null;
    }
  }

  Future<Map<String, GeoPresence>> _mapFor(
    double latitude,
    double longitude,
    DateTime time,
  ) {
    final week = GeoModel.dateTimeToWeek(time.toLocal());
    // ~11 km cells: the geo-model is far coarser than that.
    final key =
        '${latitude.toStringAsFixed(1)},${longitude.toStringAsFixed(1)},$week';
    return _cache[key] ??= () async {
      final model = await _ref.read(geoModelProvider.future);
      final labels = await _ref.read(audioLabelsSetProvider.future);
      final scores = await model.predict(
        latitude: latitude,
        longitude: longitude,
        week: week,
      );
      return presenceFromWeekScores(scores, audioLabels: labels);
    }();
  }
}

/// App-wide geo presence service.
final geoPresenceServiceProvider = Provider<GeoPresenceService>(
  GeoPresenceService.new,
);

/// Presence for the Live screen, from the current-location commonness map
/// that the announcements already compute. Null while the map is
/// unavailable.
///
/// Same rule as [GeoPresenceService.presenceAt] (J3b): rare tier, below the
/// abundance inclusion threshold, or missing from the map. "Out of season"
/// alone no longer makes a species unexpected, so Live and the listening
/// summary agree; it stays in the spoken hints and the LPO status.
GeoPresence? livePresence(
  Map<String, GeoCommonnessEntry>? commonness,
  String scientificName,
) {
  if (commonness == null || commonness.isEmpty) {
    if (!kReleaseMode) _logNoMap(commonness);
    return null;
  }
  final cause = liveUnexpectedCause(commonness[scientificName]);
  if (!kReleaseMode) _logLiveCause(scientificName, commonness[scientificName]);
  return GeoPresence(unexpected: cause != null);
}

/// Why the Live screen finds a species unexpected here, or null when it is
/// expected. [entry] null means missing from the commonness map.
LiveUnexpectedCause? liveUnexpectedCause(GeoCommonnessEntry? entry) {
  if (entry == null) return LiveUnexpectedCause.absent;
  if (entry.commonness == CommonnessBin.rare) return LiveUnexpectedCause.rare;
  if (entry.currentScore < kAbundanceInclusionThreshold) {
    return LiveUnexpectedCause.belowInclusion;
  }
  return null;
}

/// Criteria behind "unexpected here" in Live.
enum LiveUnexpectedCause { absent, rare, belowInclusion }

final Set<String> _loggedLiveCauses = {};
bool _loggedNoMap = false;

/// Outside release builds, once per species: which criterion fired, and
/// whether the former "out of season" rule would have fired too (J3b).
void _logLiveCause(String scientificName, GeoCommonnessEntry? entry) {
  if (!_loggedLiveCauses.add(scientificName)) return;
  final cause = liveUnexpectedCause(entry);
  debugPrint(
    '[GeoPresence] $scientificName: '
    'unexpected=${cause != null} cause=${cause?.name ?? '-'} '
    'outOfSeason=${entry?.isOutOfSeason ?? false} '
    'commonness=${entry?.commonness.name ?? '-'} '
    'week=${entry?.currentScore.toStringAsFixed(3) ?? '-'} '
    'annualMax=${entry?.annualMax.toStringAsFixed(3) ?? '-'}',
  );
}

/// Outside release builds, once: Live has no geo information, so no
/// species can be unexpected (no position, or geo-model not loaded).
void _logNoMap(Map<String, GeoCommonnessEntry>? commonness) {
  if (_loggedNoMap) return;
  _loggedNoMap = true;
  debugPrint(
    '[GeoPresence] no commonness map '
    '(${commonness == null ? 'no position or geo-model yet' : 'empty'})',
  );
}
