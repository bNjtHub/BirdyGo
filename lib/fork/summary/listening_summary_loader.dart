/// Gathers what [ListeningSummary] needs from the index and the geo-model.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/live/live_session.dart';
import '../data/observation_index.dart';
import '../data/observation_index_service.dart';
import '../reliability/geo_presence_service.dart';
import '../reliability/reliability_config.dart';
import 'listening_summary.dart';

/// Builds the summary of a saved [session].
///
/// Indexes the session first: saving indexes it in the background, and the
/// quick review launched from the summary reads the index.
Future<ListeningSummary> loadListeningSummary({
  required LiveSession session,
  required ObservationIndex index,
  required Future<GeoPresence?> Function(String scientificName) presenceOf,
}) async {
  await index.upsertSession(session);
  final verified = await index.verifiedSpecies(
    minScore: ReliabilityConfig.sureMinScore,
    excludeSessionId: session.id,
  );
  final names = {
    for (final d in session.detections)
      if (!d.isRejected && !d.isUnknown) d.scientificName,
  };
  final presence = <String, GeoPresence?>{};
  for (final name in names) {
    presence[name] = await presenceOf(name);
  }
  return ListeningSummary.of(
    session,
    verifiedBefore: verified,
    presence: (name) => presence[name],
  );
}

/// Loads the summary of a saved session with the app's index and geo-model.
final listeningSummaryLoaderProvider =
    Provider<Future<ListeningSummary> Function(LiveSession session)>((ref) {
      return (session) async {
        final index =
            await ref.read(observationIndexServiceProvider).ensureReady();
        final geo = ref.read(geoPresenceServiceProvider);
        return loadListeningSummary(
          session: session,
          index: index,
          presenceOf:
              (name) => geo.presenceAt(
                name,
                latitude: session.latitude,
                longitude: session.longitude,
                time: session.startTime,
              ),
        );
      };
    });
