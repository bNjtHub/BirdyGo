/// Observations ready to report on Faune-France (fork/PLAN.md J5b).
///
/// Only confirmed detections (« C'est bien lui ») can become an
/// observation: [lpoEligible] is the single gate, used by every screen.
library;

import 'dart:math' as math;

import '../../features/announcements/domain/announcement_signals.dart';
import '../../features/announcements/geo_commonness_provider.dart';
import '../../features/inference/geo_model.dart';
import '../../features/live/live_session.dart';
import '../map/sensitive_species.dart';
import '../reliability/reliability_config.dart';
import 'lpo_config.dart';

/// True when [record] may be prepared for the LPO: the observer confirmed
/// it. Unreviewed, rejected or merely "Sûr" detections never can.
bool lpoEligible(DetectionRecord record) =>
    record.reviewStatus == ReviewStatus.confirmed;

/// One observation to report: a species at one place during a session.
class LpoObservation {
  const LpoObservation({
    required this.scientificName,
    required this.commonName,
    required this.time,
    required this.records,
    this.latitude,
    this.longitude,
    this.accuracyMeters,
    this.clipPath,
  });

  final String scientificName;

  /// Common name stored with the detection (the screen shows the French
  /// name from the taxonomy when it has one).
  final String commonName;

  /// Time of the first confirmed contact.
  final DateTime time;

  /// Confirmed detections merged into this observation, oldest first.
  final List<DetectionRecord> records;

  final double? latitude;
  final double? longitude;

  /// Horizontal GPS accuracy near [time], when the session track has it.
  final double? accuracyMeters;

  /// Clip of the best-scored record that has one.
  final String? clipPath;

  /// True when every merged record comes from the AI (not added by hand).
  bool get aiAssisted => records.every((r) => r.source == DetectionSource.auto);

  bool get hasPosition => latitude != null && longitude != null;
}

/// Groups the confirmed detections of [detections] (defaults to the
/// session's) into observations: one per species and place, oldest first.
List<LpoObservation> lpoObservations(
  LiveSession session, {
  List<DetectionRecord>? detections,
}) {
  final confirmed =
      (detections ?? session.detections).where(lpoEligible).toList()
        ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  final groups = <List<DetectionRecord>>[];
  for (final record in confirmed) {
    final group = groups.where((g) {
      final first = g.first;
      if (first.scientificName != record.scientificName) return false;
      final a = _position(session, first);
      final b = _position(session, record);
      if (a == null || b == null) return true;
      return distanceMeters(a.$1, a.$2, b.$1, b.$2) <=
          LpoConfig.samePlaceMeters;
    });
    if (group.isEmpty) {
      groups.add([record]);
    } else {
      group.first.add(record);
    }
  }
  return [for (final group in groups) _observation(session, group)];
}

LpoObservation _observation(LiveSession session, List<DetectionRecord> group) {
  final first = group.first;
  final position = group
      .map((r) => _position(session, r))
      .firstWhere((p) => p != null, orElse: () => null);
  final withClip =
      group.where((r) => r.audioClipPath?.isNotEmpty ?? false).toList()
        ..sort((a, b) => b.confidence.compareTo(a.confidence));
  return LpoObservation(
    scientificName: first.scientificName,
    commonName: first.commonName,
    time: first.timestamp,
    records: List.unmodifiable(group),
    latitude: position?.$1,
    longitude: position?.$2,
    accuracyMeters: accuracyNear(session, first.timestamp),
    clipPath: withClip.isEmpty ? null : withClip.first.audioClipPath,
  );
}

/// Position of [record], else the session's.
(double, double)? _position(LiveSession session, DetectionRecord record) {
  if (record.latitude != null && record.longitude != null) {
    return (record.latitude!, record.longitude!);
  }
  if (session.latitude != null && session.longitude != null) {
    return (session.latitude!, session.longitude!);
  }
  return null;
}

/// Accuracy of the measured GPS fix closest to [time], within
/// [LpoConfig.gpsAccuracyWindow].
double? accuracyNear(LiveSession session, DateTime time) {
  double? best;
  var bestGap = LpoConfig.gpsAccuracyWindow.inMilliseconds + 1;
  for (final point in session.gpsTrack) {
    if (!point.measured || point.accuracy == null) continue;
    final gap = point.timestamp.difference(time).inMilliseconds.abs();
    if (gap < bestGap) {
      bestGap = gap;
      best = point.accuracy;
    }
  }
  return best;
}

/// Great-circle distance in meters.
double distanceMeters(double lat1, double lon1, double lat2, double lon2) {
  const earthRadius = 6371000.0;
  double rad(double deg) => deg * math.pi / 180;
  final dLat = rad(lat2 - lat1);
  final dLon = rad(lon2 - lon1);
  final h =
      math.pow(math.sin(dLat / 2), 2) +
      math.cos(rad(lat1)) *
          math.cos(rad(lat2)) *
          math.pow(math.sin(dLon / 2), 2);
  return 2 * earthRadius * math.asin(math.min(1, math.sqrt(h)));
}

/// Warnings shown before a card can be reported.
enum LpoAlert {
  /// Sensitive species: propose to hide the data on Faune-France.
  sensitive,

  /// Rare or absent here at this season (geo-model).
  rare,

  /// Well outside its usual season here (geo-model).
  outOfSeason,
}

/// What the geo-model says about an observation.
class LpoGeoStatus {
  const LpoGeoStatus({required this.rare, required this.outOfSeason});

  final bool rare;
  final bool outOfSeason;
}

/// Status from `geoCommonnessProvider` (current place and week): rare
/// bin, or missing from a non-empty map (not expected here at all), and
/// its out-of-season flag. Null while the map is unavailable.
LpoGeoStatus? geoStatusFromCommonness(
  Map<String, GeoCommonnessEntry>? commonness,
  String scientificName,
) {
  if (commonness == null || commonness.isEmpty) return null;
  final entry = commonness[scientificName];
  if (entry == null) return const LpoGeoStatus(rare: true, outOfSeason: false);
  return LpoGeoStatus(
    rare: entry.commonness == CommonnessBin.rare,
    outOfSeason: entry.isOutOfSeason,
  );
}

/// Status from the geo presence at the observation's own place and week
/// (J3), used when the observation is not "here and now". It knows rarity,
/// not seasonality.
LpoGeoStatus? geoStatusFromPresence(GeoPresence? presence) =>
    presence == null
        ? null
        : LpoGeoStatus(rare: presence.unexpected, outOfSeason: false);

/// True when `geoCommonnessProvider` (computed at [hereLatitude],
/// [hereLongitude] for the week of [now]) applies to [observation].
bool isHereAndNow(
  LpoObservation observation, {
  required double? hereLatitude,
  required double? hereLongitude,
  required DateTime now,
}) {
  if (!observation.hasPosition ||
      hereLatitude == null ||
      hereLongitude == null) {
    return false;
  }
  if (GeoModel.dateTimeToWeek(observation.time.toLocal()) !=
      GeoModel.dateTimeToWeek(now.toLocal())) {
    return false;
  }
  final distance = distanceMeters(
    observation.latitude!,
    observation.longitude!,
    hereLatitude,
    hereLongitude,
  );
  return distance <= LpoConfig.hereRadiusKm * 1000;
}

/// Alerts of [scientificName], given its geo-model status.
Set<LpoAlert> lpoAlerts(String scientificName, LpoGeoStatus? geo) => {
  if (isSensitiveSpecies(scientificName)) LpoAlert.sensitive,
  if (geo?.rare ?? false) LpoAlert.rare,
  if (geo?.outOfSeason ?? false) LpoAlert.outOfSeason,
};
