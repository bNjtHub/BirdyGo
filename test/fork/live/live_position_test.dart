import 'package:birdnet_live/features/inference/detection_accumulator.dart';
import 'package:birdnet_live/features/inference/models/detection.dart';
import 'package:birdnet_live/features/inference/models/species.dart';
import 'package:birdnet_live/features/live/live_session.dart';
import 'package:birdnet_live/fork/live/live_position.dart';
import 'package:birdnet_live/shared/models/gps_point.dart';
import 'package:flutter_test/flutter_test.dart';

const _bird = Species(
  index: 0,
  id: 0,
  scientificName: 'Turdus merula',
  commonName: 'Eurasian Blackbird',
  className: 'Aves',
  order: 'Passeriformes',
);
final _start = DateTime.utc(2026, 9, 27, 7);

class _FakeSource implements LivePositionSource {
  void Function(GpsPoint point)? _onPoint;
  int starts = 0;
  int stops = 0;
  bool running = false;

  @override
  GpsPoint? lastPoint;

  @override
  double distanceMeters = 0;

  @override
  set onPoint(void Function(GpsPoint point)? callback) => _onPoint = callback;

  @override
  Future<void> start() async {
    starts++;
    running = true;
  }

  @override
  Future<void> stop() async {
    stops++;
    running = false;
  }

  void emit(double lat, double lon, {double distance = 0}) {
    final point = GpsPoint(
      latitude: lat,
      longitude: lon,
      accuracy: 5,
      timestamp: _start,
    );
    lastPoint = point;
    distanceMeters = distance;
    _onPoint?.call(point);
  }
}

LiveSession _session({double? lat = 48.0, double? lon = 2.0}) => LiveSession(
  id: 's',
  startTime: _start,
  latitude: lat,
  longitude: lon,
  settings: const SessionSettings(
    windowDuration: 3,
    confidenceThreshold: 25,
    inferenceRate: 1,
    speciesFilterMode: 'off',
  ),
);

const _detection = Detection(species: _bird, confidence: 0.8);

({LivePositionTracker tracker, _FakeSource source}) _tracker({
  bool allowed = true,
}) {
  final source = _FakeSource();
  final tracker = LivePositionTracker(createSource: () => source)
    ..canTrack = () async => allowed;
  return (tracker: tracker, source: source);
}

void main() {
  test('new detections carry the last measured point', () async {
    final t = _tracker();
    final session = _session();
    t.tracker.begin(session, startPositionUncertain: false);
    await pumpEventQueue();

    t.source.emit(48.1, 2.1, distance: 12);
    final record = t.tracker.createRecord(_detection, _start);

    expect(record.latitude, 48.1);
    expect(record.longitude, 2.1);
    expect(session.gpsTrack, hasLength(1));
    expect(session.distanceMeters, 12);
    // A trusted start position stays where the listening began.
    expect(session.latitude, 48.0);
  });

  test('before the first fix, a trusted session position is used', () async {
    final t = _tracker();
    t.tracker.begin(_session(), startPositionUncertain: false);
    await pumpEventQueue();

    final record = t.tracker.createRecord(_detection, _start);

    expect(record.latitude, 48.0);
    expect(record.longitude, 2.0);
  });

  test('an uncertain start position is replaced by the first fix', () async {
    final t = _tracker();
    final session = _session(lat: null, lon: null);
    t.tracker.begin(session, startPositionUncertain: true);
    await pumpEventQueue();

    final early = t.tracker.createRecord(_detection, _start);
    expect(early.latitude, isNull, reason: 'readers use the session position');

    t.source.emit(48.2, 2.2);
    t.source.emit(48.3, 2.3);
    expect(session.latitude, 48.2);
    expect(session.longitude, 2.2);
  });

  test('no tracking when location is not allowed', () async {
    final t = _tracker(allowed: false);
    t.tracker.begin(_session(), startPositionUncertain: false);
    await pumpEventQueue();

    expect(t.source.starts, 0);
    final record = t.tracker.createRecord(_detection, _start);
    expect(record.latitude, isNull);
    expect(record.longitude, isNull);
  });

  test('no gate means no tracking', () async {
    final source = _FakeSource();
    final tracker = LivePositionTracker(createSource: () => source);
    tracker.begin(_session(), startPositionUncertain: false);
    await pumpEventQueue();

    expect(source.starts, 0);
  });

  test('pause stops the stream, resume restarts it, end stops it', () async {
    final t = _tracker();
    t.tracker.begin(_session(), startPositionUncertain: false);
    await pumpEventQueue();
    expect(t.source.running, isTrue);

    t.tracker.pause();
    await pumpEventQueue();
    expect(t.source.running, isFalse);
    expect(t.tracker.isRunning, isFalse);

    t.tracker.resume();
    await pumpEventQueue();
    expect(t.source.running, isTrue);
    expect(t.source.starts, 2);

    t.tracker.end();
    await pumpEventQueue();
    expect(t.source.running, isFalse);
    expect(t.tracker.session, isNull);
  });

  test('a pause during the permission check never starts the stream', () async {
    final t = _tracker();
    t.tracker.begin(_session(), startPositionUncertain: false);
    t.tracker.pause();
    await pumpEventQueue();

    expect(t.source.starts, 0);
  });

  test('fixes after the end are ignored', () async {
    final t = _tracker();
    final session = _session();
    t.tracker.begin(session, startPositionUncertain: true);
    await pumpEventQueue();
    t.tracker.end();

    t.source.emit(48.5, 2.5);
    expect(session.gpsTrack, isEmpty);
    expect(session.latitude, 48.0);
  });

  test('without a session the record matches the accumulator default', () {
    final tracker = LivePositionTracker(createSource: _FakeSource.new);
    final withFactory = DetectionAccumulator(
      sessionStart: _start,
      records: [],
    ).processCycle(
      detections: const [_detection],
      windowEnd: _start,
      createRecord: tracker.createRecord,
    );
    final byDefault = DetectionAccumulator(
      sessionStart: _start,
      records: [],
    ).processCycle(detections: const [_detection], windowEnd: _start);

    expect(
      withFactory.changes.single.record.toJson(),
      byDefault.changes.single.record.toJson(),
    );
  });

  test('the accumulator keeps the position when the peak rises', () async {
    final t = _tracker();
    t.tracker.begin(_session(), startPositionUncertain: false);
    await pumpEventQueue();
    t.source.emit(48.1, 2.1);

    final accumulator = DetectionAccumulator(sessionStart: _start, records: []);
    accumulator.processCycle(
      detections: const [_detection],
      windowEnd: _start,
      createRecord: t.tracker.createRecord,
    );
    t.source.emit(49.0, 3.0);
    final cycle = accumulator.processCycle(
      detections: const [Detection(species: _bird, confidence: 0.95)],
      windowEnd: _start.add(const Duration(seconds: 1)),
      createRecord: t.tracker.createRecord,
    );

    final record = cycle.changes.single.record;
    expect(record.confidence, 0.95);
    expect(record.latitude, 48.1, reason: 'position of the song start');
  });
}
