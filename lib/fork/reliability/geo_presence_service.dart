/// Geo presence of species at the place and week of a detection
/// (fork/PLAN.md J3). One small geo-model run per rounded place and week,
/// cached for the app's lifetime.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/announcements/domain/announcement_signals.dart';
import '../../features/announcements/geo_commonness_provider.dart';
import '../../features/explore/explore_providers.dart';
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
/// that the announcements already compute (it also knows "out of season").
/// Null while the map is unavailable.
GeoPresence? livePresence(
  Map<String, GeoCommonnessEntry>? commonness,
  String scientificName,
) {
  if (commonness == null || commonness.isEmpty) return null;
  final entry = commonness[scientificName];
  if (entry == null) return kAbsentHere;
  return GeoPresence(
    unexpected: entry.commonness == CommonnessBin.rare || entry.isOutOfSeason,
  );
}
