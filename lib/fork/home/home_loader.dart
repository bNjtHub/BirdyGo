/// Loads the home screen's numbers from the observation index (J6c), and the
/// name of the place where the phone is.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/reverse_geocoding_service.dart';
import '../../features/explore/explore_providers.dart';
import '../../shared/providers/settings_providers.dart';
import '../data/observation_index.dart';
import '../data/observation_index_service.dart';
import '../reliability/geo_presence_service.dart';
import '../reliability/reliability_config.dart';
import 'home_model.dart';

/// Position of the phone, or null when it cannot be had without asking.
typedef HomePosition = ({double latitude, double longitude});

class HomeLoader {
  HomeLoader({
    required Future<ObservationIndex> Function() index,
    required GeoPresenceService presence,
    required Future<HomePosition?> Function() position,
    required String Function() localeName,
    DateTime Function()? now,
  }) : _index = index,
       _presence = presence,
       _position = position,
       _localeName = localeName,
       _now = now ?? DateTime.now;

  final Future<ObservationIndex> Function() _index;
  final GeoPresenceService _presence;
  final Future<HomePosition?> Function() _position;
  final String Function() _localeName;
  final DateTime Function() _now;

  /// Today's tiles, the last bird and the review count. An index that
  /// cannot open gives an empty home, never an error.
  Future<HomeSnapshot> load() async {
    final ObservationIndex index;
    try {
      index = await _index();
    } catch (_) {
      return const HomeSnapshot();
    }

    final now = _now();
    final dayStart = DateTime(now.year, now.month, now.day);
    final today = await index.detectionsSince(dayStart);
    final names = {for (final d in today) d.scientificName};
    final heardBefore = await index.speciesHeardBefore(dayStart, among: names);

    // Presence of each species where it was first heard today.
    final presence = <String, GeoPresence>{};
    for (final d in today) {
      if (presence.containsKey(d.scientificName)) continue;
      final geo = await _presenceOf(d);
      if (geo != null) presence[d.scientificName] = geo;
    }

    LastBird? last;
    final newest = await index.lastDetection();
    if (newest != null) {
      final geo = await _presenceOf(newest);
      final totals = await index.totalContactsBySpecies();
      last = LastBird(
        detection: newest,
        level: reliabilityFor(
          score: newest.confidence,
          review: newest.reviewStatus,
          presence: geo,
        ),
        unexpected: geo?.unexpected ?? false,
        total: totals[newest.scientificName] ?? 1,
      );
    }

    return HomeSnapshot(
      today: buildDaySummary(
        detections: today,
        presence: presence,
        heardBefore: heardBefore,
      ),
      last: last,
      toVerify: await index.reviewQueueLength(),
    );
  }

  Future<GeoPresence?> _presenceOf(IndexedDetection d) => _presence.presenceAt(
    d.scientificName,
    latitude: d.latitude,
    longitude: d.longitude,
    time: d.start,
  );

  /// Name of the place where the phone is: geocoding cache, or network with
  /// the user's consent. Null without position or offline.
  Future<String?> placeName() async {
    try {
      final position = await _position();
      if (position == null) return null;
      return await reverseGeocode(
        latitude: position.latitude,
        longitude: position.longitude,
        localeName: _localeName(),
      );
    } catch (_) {
      return null;
    }
  }
}

final homeLoaderProvider = Provider<HomeLoader>(
  (ref) => HomeLoader(
    index: () => ref.read(observationIndexServiceProvider).ensureReady(),
    presence: ref.read(geoPresenceServiceProvider),
    // Same care as the upstream warm-up: never trigger the location prompt
    // from the home screen.
    position: () async {
      if (ref.read(useGpsProvider) &&
          !await ref.read(locationServiceProvider).hasPermission()) {
        return null;
      }
      final location = await ref.read(currentLocationProvider.future);
      return location == null
          ? null
          : (latitude: location.latitude, longitude: location.longitude);
    },
    localeName: () => ref.read(effectiveAppLocaleProvider),
  ),
);
