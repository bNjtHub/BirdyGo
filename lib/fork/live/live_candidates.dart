/// « Analyse… » in the live header (fork/PLAN.md J6c-bis-b).
///
/// A candidate is a bird the last window heard at or above the per-window
/// support threshold of the temporal gate, allowed by the active species
/// filter, but not confirmed yet. The header says « Analyse… » while there is
/// one; no name, no row, no vibration.
library;

import 'package:flutter/foundation.dart';

import '../../features/inference/inference_service.dart';
import '../../features/inference/models/detection.dart';
import '../../features/inference/models/species.dart';
import '../../features/inference/species_filter.dart';
import '../../features/live/live_session.dart';
import '../reliability/reliability_config.dart';
import 'live_heard.dart';

/// Taxonomic class of the candidates: insects and frogs never light it.
const String candidateClass = 'Aves';

/// Pooling modes with the temporal support gate. With `off`, `avg` or `max`
/// nothing is held back, so there is never a candidate.
bool supportGateActive(String poolingMode) =>
    poolingMode == 'lme' || poolingMode == 'adaptive_lme_peak';

/// What the live screen shows for the last cycle, besides the results.
@immutable
class LiveCycleSignal {
  const LiveCycleSignal({
    this.candidates = const {},
    this.analysing = false,
    this.singingVisual = const {},
    this.heardUntil = const {},
  });

  static const empty = LiveCycleSignal();

  /// Birds heard by the last window and not confirmed yet.
  final Set<String> candidates;

  /// The header says « Analyse… ».
  final bool analysing;

  /// Species whose « chante » symbol is on (see [LiveHeard]).
  final Set<String> singingVisual;

  /// Displayed end of each contact's mark (see [LiveHeard.heardUntil]).
  final Map<ContactKey, DateTime> heardUntil;
}

/// Same filter as the live results (`LiveController._runInference`): the
/// active species filter, then the intersection with the geo-model's species.
List<Detection> liveSpeciesFilter(
  List<Detection> detections, {
  required SpeciesFilterMode mode,
  required double threshold,
  Map<String, double>? geoScores,
  double geoThreshold = 0.03,
  Set<String>? geoNames,
}) {
  final filtered = SpeciesFilter.apply(
    detections: detections,
    mode: mode,
    geoScores: geoScores,
    geoThreshold: geoThreshold,
    confidenceThreshold: threshold,
  );
  return geoNames == null
      ? filtered
      : filtered
          .where((d) => geoNames.contains(d.species.scientificName))
          .toList();
}

/// Candidates of one window: [candidateClass], window score at or above
/// [supportThreshold] (no upper bound), kept by [filter], not in [confirmed].
/// [windowScores] are indexed like [labels].
Set<String> liveCandidates({
  required List<double>? windowScores,
  required List<Species> labels,
  required String poolingMode,
  required double supportThreshold,
  required Set<String> confirmed,
  required List<Detection> Function(List<Detection> detections) filter,
}) {
  final scores = windowScores;
  if (scores == null || !supportGateActive(poolingMode)) return const {};
  final heard = <Detection>[];
  final n = scores.length < labels.length ? scores.length : labels.length;
  for (var i = 0; i < n; i++) {
    final score = scores[i];
    if (score < supportThreshold) continue;
    final species = labels[i];
    if (species.className != candidateClass ||
        confirmed.contains(species.scientificName)) {
      continue;
    }
    heard.add(Detection(species: species, confidence: score));
  }
  if (heard.isEmpty) return const {};
  return {for (final d in filter(heard)) d.species.scientificName};
}

/// Keeps « Analyse… » on [holdWindows] more cycles when a candidate of the
/// previous cycle is confirmed, so the header does not fade while its row
/// comes in.
class AnalysingHold {
  AnalysingHold({this.holdWindows = ReliabilityConfig.analysingHoldWindows});

  final int holdWindows;
  Set<String> _previous = const {};
  int _left = 0;

  /// Whether the header says « Analyse… » this cycle.
  bool update({
    required Set<String> candidates,
    required Set<String> confirmed,
  }) {
    if (_previous.any(confirmed.contains)) {
      _left = holdWindows;
    } else if (_left > 0) {
      _left--;
    }
    _previous = candidates;
    return candidates.isNotEmpty || _left > 0;
  }

  void reset() {
    _previous = const {};
    _left = 0;
  }
}

/// Turns each inference cycle into a [LiveCycleSignal]. Owned by the live
/// controller, fed once per cycle.
class LiveCycleTracker {
  final AnalysingHold _hold = AnalysingHold();
  final LiveHeard _heard = LiveHeard();
  DateTime? _expiresAt;

  /// Time left until the current signal becomes stale, measured from the
  /// audio window's end, not the moment its inference happened to finish.
  /// Null means there is no active signal to expire.
  Duration? remainingLifetime(DateTime now) {
    final expiresAt = _expiresAt;
    if (expiresAt == null) return null;
    final remaining = expiresAt.difference(now);
    return remaining.isNegative ? Duration.zero : remaining;
  }

  /// Clears an expired signal even if no new inference completes. Historical
  /// mark ends remain available. Returns null while the signal is fresh.
  LiveCycleSignal? expire(DateTime now) {
    final remaining = remainingLifetime(now);
    if (remaining == null || remaining > Duration.zero) return null;
    return pause();
  }

  /// Cycle read from [service] (null when it is not running).
  LiveCycleSignal updateFrom(
    InferenceService? service, {
    required double confidenceThreshold,
    required List<Detection> confirmed,
    required List<DetectionRecord> records,
    required SpeciesFilterMode filterMode,
    required Map<String, double>? geoScores,
    required double geoThreshold,
    required Set<String>? geoNames,
    required DateTime windowEnd,
    required Duration window,
    required Duration expectedHop,
    required DateTime processedAt,
    required bool replayHeard,
  }) => update(
    windowScores: service?.lastWindowScores,
    labels: service?.labels ?? const [],
    poolingMode: service?.poolingMode ?? 'off',
    supportThreshold: service?.supportThresholdFor(confidenceThreshold) ?? 1,
    confirmed: confirmed,
    records: records,
    filterMode: filterMode,
    geoScores: geoScores,
    geoThreshold: geoThreshold,
    geoNames: geoNames,
    windowEnd: windowEnd,
    window: window,
    expectedHop: expectedHop,
    processedAt: processedAt,
    replayHeard: replayHeard,
  );

  /// One cycle. [confirmed]: the filtered results of this cycle.
  /// [records]: the session records, oldest first. [replayHeard]: the window
  /// overlaps a replay, so nothing it heard counts.
  LiveCycleSignal update({
    required List<double>? windowScores,
    required List<Species> labels,
    required String poolingMode,
    required double supportThreshold,
    required List<Detection> confirmed,
    required List<DetectionRecord> records,
    required SpeciesFilterMode filterMode,
    Map<String, double>? geoScores,
    double geoThreshold = 0.03,
    Set<String>? geoNames,
    required DateTime windowEnd,
    required Duration window,
    required Duration expectedHop,
    required DateTime processedAt,
    bool replayHeard = false,
  }) {
    final scores = windowScores;
    if (scores == null || replayHeard) return pause();

    // Allow the next scheduled hop plus one model window of processing
    // slack. This also works at slow inference rates without blinking
    // between normal cycles. Backlogged results never relight the signal.
    final expiresAt = windowEnd.add(expectedHop + window);
    if (!processedAt.isBefore(expiresAt)) return pause();

    final confirmedNames = {
      for (final d in confirmed) d.species.scientificName,
    };
    final candidates = liveCandidates(
      windowScores: scores,
      labels: labels,
      poolingMode: poolingMode,
      supportThreshold: supportThreshold,
      confirmed: confirmedNames,
      filter:
          (heard) => liveSpeciesFilter(
            heard,
            mode: filterMode,
            threshold: supportThreshold,
            geoScores: geoScores,
            geoThreshold: geoThreshold,
            geoNames: geoNames,
          ),
    );
    final analysing = _hold.update(
      candidates: candidates,
      confirmed: confirmedNames,
    );

    _heard.update(
      contacts: _contactStarts(confirmed, records),
      supported: {
        for (final d in confirmed)
          if (d.species.index >= 0 &&
              d.species.index < scores.length &&
              scores[d.species.index] >= supportThreshold)
            d.species.scientificName,
      },
      windowEnd: windowEnd,
      window: window,
    );

    final singing = _heard.singingVisual;
    _expiresAt = analysing || singing.isNotEmpty ? expiresAt : null;
    return LiveCycleSignal(
      candidates: candidates,
      analysing: analysing,
      singingVisual: singing,
      heardUntil: _heard.heardUntil,
    );
  }

  /// Start of each confirmed species' contact: its newest record (records
  /// are appended when a contact opens), else the detection's own time.
  Map<String, DateTime> _contactStarts(
    List<Detection> confirmed,
    List<DetectionRecord> records,
  ) {
    final starts = <String, DateTime>{};
    if (confirmed.isEmpty) return starts;
    final wanted = {for (final d in confirmed) d.species.scientificName};
    for (var i = records.length - 1; i >= 0 && wanted.isNotEmpty; i--) {
      final r = records[i];
      if (wanted.remove(r.scientificName)) {
        starts[r.scientificName] = r.timestamp;
      }
    }
    for (final d in confirmed) {
      final t = d.timestamp;
      if (t != null) starts.putIfAbsent(d.species.scientificName, () => t);
    }
    return starts;
  }

  /// Pause or replay: no candidate, no symbol; the marks keep their ends.
  LiveCycleSignal pause() {
    _expiresAt = null;
    _hold.reset();
    _heard.pause();
    return LiveCycleSignal(heardUntil: _heard.heardUntil);
  }

  /// New session.
  void reset() {
    _expiresAt = null;
    _hold.reset();
    _heard.reset();
  }
}
