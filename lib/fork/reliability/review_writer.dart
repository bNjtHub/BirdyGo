/// Writes quick-review answers into the session JSON (the source of truth);
/// the session hooks then update the observation index (J3).
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/history/session_repository.dart';
import '../../features/live/live_providers.dart';
import '../../features/live/live_session.dart';
import '../data/observation_index.dart';
import '../data/observation_index_service.dart';

/// Applies "C'est bien lui", "Ce n'est pas lui" and "Je ne sais pas".
class ReviewWriter {
  ReviewWriter({
    required SessionRepository repository,
    required Future<ObservationIndex> Function() index,
    DateTime Function()? now,
    VoidCallback? onQueueChanged,
  }) : _repository = repository,
       _index = index,
       _onQueueChanged = onQueueChanged,
       _now = now ?? DateTime.now;

  final SessionRepository _repository;
  final Future<ObservationIndex> Function() _index;
  final DateTime Function() _now;

  /// Called once a skip is stored: it changes the queue without any session
  /// save, so the index hooks stay silent and the counters would stay stale.
  final VoidCallback? _onQueueChanged;

  /// Sets the review status of [detection] in its session and saves it.
  /// Returns false when the session or the detection no longer exists.
  Future<bool> setStatus(
    IndexedDetection detection,
    ReviewStatus status,
  ) async {
    final session = await _repository.load(detection.sessionId);
    if (session == null) return false;
    final record = _find(session, detection);
    if (record == null) return false;
    record.reviewStatus = status;
    record.reviewedAt = _now();
    await _repository.save(session);
    return true;
  }

  /// "Je ne sais pas": the detection stays unreviewed but leaves the queue.
  Future<void> skip(IndexedDetection detection) async {
    await (await _index()).markSkipped(detection.key);
    _onQueueChanged?.call();
  }

  static DetectionRecord? _find(LiveSession session, IndexedDetection d) {
    final list = session.detections;
    bool matches(DetectionRecord r) => detectionKey(session.id, r) == d.key;
    if (d.position < list.length && matches(list[d.position])) {
      return list[d.position];
    }
    for (final record in list) {
      if (matches(record)) return record;
    }
    return null;
  }
}

/// App-wide review writer.
final reviewWriterProvider = Provider<ReviewWriter>((ref) {
  return ReviewWriter(
    repository: ref.read(sessionRepositoryProvider),
    index: () => ref.read(observationIndexServiceProvider).ensureReady(),
    onQueueChanged:
        () => ref.read(observationIndexServiceProvider).notifyQueueChanged(),
  );
});
