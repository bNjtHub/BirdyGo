/// Reads what the Bilan needs besides the session itself (J6c): geo presence
/// at the session's place, species heard before, « Je ne sais pas » answers
/// and the place name.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/reverse_geocoding_service.dart';
import '../../features/history/session_repository.dart';
import '../../features/live/live_providers.dart';
import '../../features/live/live_session.dart';
import '../../shared/providers/settings_providers.dart';
import '../data/observation_index.dart';
import '../data/observation_index_service.dart';
import '../reliability/geo_presence_service.dart';
import '../reliability/reliability_config.dart';

/// Inputs of [buildBilan] other than the session.
class BilanInputs {
  const BilanInputs({
    required this.session,
    this.presence = const {},
    this.heardBefore,
    this.skippedKeys = const {},
  });

  /// The saved session, reviews included.
  final LiveSession session;
  final Map<String, GeoPresence> presence;

  /// Null when the index is unavailable: nothing is shown as new.
  final Set<String>? heardBefore;
  final Set<String> skippedKeys;
}

/// Loads [BilanInputs]. Every source is optional: a missing geo-model, index
/// or network only hides what depends on it.
class BilanLoader {
  BilanLoader({
    required SessionRepository repository,
    required Future<ObservationIndex> Function() index,
    required GeoPresenceService presence,
    required String Function() localeName,
  }) : _repository = repository,
       _index = index,
       _presence = presence,
       _localeName = localeName;

  final SessionRepository _repository;
  final Future<ObservationIndex> Function() _index;
  final GeoPresenceService _presence;
  final String Function() _localeName;

  Future<BilanInputs> load(LiveSession session) async {
    final saved = await _fresh(session);
    final names = {for (final d in saved.detections) d.scientificName};

    Set<String>? heardBefore;
    var skipped = const <String>{};
    try {
      final index = await _index();
      // The save hook indexes the session too, without waiting: make sure the
      // quick review opened from here finds its detections.
      await index.upsertSession(saved);
      heardBefore = await index.speciesHeardBefore(
        saved.startTime,
        among: names,
      );
      skipped = await index.skippedKeys();
    } catch (_) {
      // No index: no novelties, every unreviewed doubt stays to check.
    }

    final presence = <String, GeoPresence>{};
    for (final name in names) {
      final geo = await _presence.presenceAt(
        name,
        latitude: saved.latitude,
        longitude: saved.longitude,
        time: saved.startTime,
      );
      if (geo != null) presence[name] = geo;
    }

    return BilanInputs(
      session: saved,
      presence: presence,
      heardBefore: heardBefore,
      skippedKeys: skipped,
    );
  }

  /// The saved version of [session], or [session] when it cannot be read.
  Future<LiveSession> _fresh(LiveSession session) async {
    try {
      return await _repository.load(session.id) ?? session;
    } catch (_) {
      return session;
    }
  }

  /// Place name of [session]: the stored one, else reverse geocoding (cache,
  /// or network with the user's consent), stored in the session as the
  /// review screen does. Null offline or without a position.
  Future<String?> placeName(LiveSession session) async {
    final stored = session.locationName;
    if (stored != null) return stored;
    final lat = session.latitude;
    final lon = session.longitude;
    if (lat == null || lon == null) return null;
    try {
      final name = await reverseGeocode(
        latitude: lat,
        longitude: lon,
        localeName: _localeName(),
      );
      if (name != null) {
        // Re-read first: a review may have been saved while the name was
        // being resolved, and must not be overwritten.
        final saved = await _fresh(session);
        if (saved.locationName == null) {
          saved.locationName = name;
          await _repository.save(saved);
        }
      }
      return name;
    } catch (_) {
      return null;
    }
  }
}

final bilanLoaderProvider = Provider<BilanLoader>(
  (ref) => BilanLoader(
    repository: ref.read(sessionRepositoryProvider),
    index: () => ref.read(observationIndexServiceProvider).ensureReady(),
    presence: ref.read(geoPresenceServiceProvider),
    localeName: () => ref.read(effectiveAppLocaleProvider),
  ),
);
