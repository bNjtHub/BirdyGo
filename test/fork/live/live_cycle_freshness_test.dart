import 'package:birdnet_live/features/inference/models/detection.dart';
import 'package:birdnet_live/features/inference/models/species.dart';
import 'package:birdnet_live/features/inference/species_filter.dart';
import 'package:birdnet_live/features/live/live_session.dart';
import 'package:birdnet_live/fork/live/live_candidates.dart';
import 'package:flutter_test/flutter_test.dart';

const _bird = Species(
  index: 0,
  id: 0,
  scientificName: 'Turdus merula',
  commonName: 'Eurasian Blackbird',
  className: 'Aves',
  order: 'Passeriformes',
);
const _candidate = Species(
  index: 1,
  id: 1,
  scientificName: 'Parus major',
  commonName: 'Great Tit',
  className: 'Aves',
  order: 'Passeriformes',
);
const _window = Duration(seconds: 3);
const _hop = Duration(seconds: 1);
final _start = DateTime.utc(2026, 9, 26, 6, 30);
final _end = _start.add(_window);
final _record = DetectionRecord(
  scientificName: _bird.scientificName,
  commonName: _bird.commonName,
  confidence: 0.9,
  timestamp: _start,
);

LiveCycleSignal _update(
  LiveCycleTracker tracker, {
  DateTime? windowEnd,
  DateTime? processedAt,
  Duration hop = _hop,
  List<double>? scores = const [0.9, 0.4],
}) => tracker.update(
  windowScores: scores,
  labels: const [_bird, _candidate],
  poolingMode: 'adaptive_lme_peak',
  supportThreshold: 0.25,
  confirmed: [Detection(species: _bird, confidence: 0.9, timestamp: _start)],
  records: [_record],
  filterMode: SpeciesFilterMode.off,
  windowEnd: windowEnd ?? _end,
  window: _window,
  expectedHop: hop,
  processedAt: processedAt ?? windowEnd ?? _end,
);

void main() {
  test('unsupported pooled contact stays dark even on its first cycle', () {
    final tracker = LiveCycleTracker();
    final signal = _update(tracker, scores: const [0.01, 0]);
    expect(signal.singingVisual, isEmpty);
    expect(signal.candidates, isEmpty);
    expect(signal.analysing, isFalse);
    expect(tracker.remainingLifetime(_end), isNull);
  });

  test('a stalled result expires singing and candidates, preserving marks', () {
    final tracker = LiveCycleTracker();
    final signal = _update(
      tracker,
      processedAt: _end.add(const Duration(milliseconds: 500)),
    );
    expect(signal.singingVisual, {_bird.scientificName});
    expect(signal.candidates, {_candidate.scientificName});
    expect(
      tracker.remainingLifetime(_end.add(const Duration(milliseconds: 500))),
      const Duration(milliseconds: 3500),
      reason: 'freshness starts at the audio end, not inference completion',
    );
    expect(
      tracker.expire(_end.add(const Duration(milliseconds: 3999))),
      isNull,
    );
    final expired = tracker.expire(_end.add(_window + _hop))!;
    expect(expired.singingVisual, isEmpty);
    expect(expired.candidates, isEmpty);
    expect(expired.analysing, isFalse);
    expect(expired.heardUntil, signal.heardUntil);
    expect(tracker.remainingLifetime(_end), isNull);
  });

  test('a backlogged result cannot relight an expired signal', () {
    final tracker = LiveCycleTracker();
    final first = _update(tracker);
    final stale = _update(tracker, processedAt: _end.add(_window + _hop));
    expect(stale.singingVisual, isEmpty);
    expect(stale.candidates, isEmpty);
    expect(stale.analysing, isFalse);
    expect(stale.heardUntil, first.heardUntil);

    final newEnd = _end.add(const Duration(seconds: 10));
    final resumed = _update(tracker, windowEnd: newEnd);
    expect(resumed.singingVisual, {_bird.scientificName});
    expect(resumed.candidates, {_candidate.scientificName});
    expect(resumed.heardUntil[(_bird.scientificName, _start)], newEnd);
  });

  test('slow configured cadence remains lit until its next result is due', () {
    final tracker = LiveCycleTracker();
    const slowHop = Duration(seconds: 10);
    _update(tracker, hop: slowHop);
    expect(tracker.expire(_end.add(const Duration(seconds: 2))), isNull);
    expect(tracker.expire(_end.add(slowHop)), isNull);
    expect(
      tracker.remainingLifetime(_end.add(slowHop)),
      _window,
      reason: 'the 0.1 Hz cadence still has time for the next inference',
    );
    expect(tracker.expire(_end.add(slowHop + _window)), isNotNull);
  });

  test('an old expiry callback cannot clear a newer fresh cycle', () {
    final tracker = LiveCycleTracker();
    _update(tracker);
    final newEnd = _end.add(const Duration(seconds: 2));
    _update(tracker, windowEnd: newEnd);
    expect(tracker.expire(_end.add(_hop + _window)), isNull);
    expect(tracker.expire(newEnd.add(_hop + _window)), isNotNull);
  });

  test('missing scores clear active signals and cancel their deadline', () {
    final tracker = LiveCycleTracker();
    final first = _update(tracker);
    final missing = _update(tracker, scores: null);
    expect(missing.singingVisual, isEmpty);
    expect(missing.candidates, isEmpty);
    expect(missing.heardUntil, first.heardUntil);
    expect(tracker.remainingLifetime(_end), isNull);
  });

  test('pause keeps historical ends; reset removes them and the deadline', () {
    final tracker = LiveCycleTracker();
    final first = _update(tracker);
    expect(tracker.pause().heardUntil, first.heardUntil);
    expect(tracker.remainingLifetime(_end), isNull);
    _update(tracker);
    tracker.reset();
    expect(tracker.pause().heardUntil, isEmpty);
    expect(tracker.remainingLifetime(_end), isNull);
  });
}
