import 'package:birdnet_live/features/live/live_session.dart';
import 'package:birdnet_live/fork/live/live_table_model.dart';
import 'package:flutter_test/flutter_test.dart';

final _t0 = DateTime(2026, 9, 26, 7, 0);

DetectionRecord _rec(
  String name,
  int second, {
  double confidence = 0.9,
  int? endSecond,
}) => DetectionRecord(
  scientificName: name,
  commonName: 'common $name',
  confidence: confidence,
  timestamp: _t0.add(Duration(seconds: second)),
  endTimestamp:
      endSecond == null ? null : _t0.add(Duration(seconds: endSecond)),
);

/// Session records, newest first like [LiveController.sessionDetections].
List<DetectionRecord> _session(List<DetectionRecord> records) =>
    records.reversed.toList();

List<String> _names(List<LiveTableEntry> entries) => [
  for (final e in entries) e.scientificName,
];

void main() {
  test('new species come in on top', () {
    final table = buildLiveTable(
      sessionDetections: _session([_rec('A', 0), _rec('B', 10), _rec('C', 20)]),
      currentDetections: const [],
    );
    expect(_names(table), ['C', 'B', 'A']);
  });

  test('a species heard again goes back to the top', () {
    final table = buildLiveTable(
      sessionDetections: _session([
        _rec('A', 0, endSecond: 5),
        _rec('B', 10, endSecond: 12),
        _rec('A', 30),
      ]),
      currentDetections: const [],
    );
    expect(_names(table), ['A', 'B']);
    expect(table.first.sessionCount, 2);
  });

  test('a contact that goes on does not move its row', () {
    final running = _rec('A', 0);
    final before = buildLiveTable(
      sessionDetections: _session([running, _rec('B', 10)]),
      currentDetections: [running],
    );
    final later = buildLiveTable(
      sessionDetections: _session([running, _rec('B', 10)]),
      currentDetections: [_rec('A', 0, confidence: 0.95)],
    );
    expect(_names(before), ['B', 'A']);
    expect(_names(later), ['B', 'A']);
    expect(later.last.singing, isTrue);
    expect(later.last.record.confidence, 0.95);
  });

  test('species stay when they stop singing', () {
    final table = buildLiveTable(
      sessionDetections: _session([_rec('A', 0, endSecond: 3)]),
      currentDetections: const [],
    );
    expect(_names(table), ['A']);
    expect(table.single.singing, isFalse);
  });

  test('totals, fallbacks and header stats', () {
    final table = buildLiveTable(
      sessionDetections: _session([_rec('A', 0), _rec('A', 20), _rec('B', 30)]),
      currentDetections: const [],
      totals: const {'A': 142},
      localizedName: (r) => r.scientificName.toLowerCase(),
    );
    final a = table.firstWhere((e) => e.scientificName == 'A');
    final b = table.firstWhere((e) => e.scientificName == 'B');
    expect(a.total, 142);
    expect(b.total, 1);
    expect(a.commonName, 'a');
    final stats = LiveStats.of(table);
    expect(stats.species, 2);
    expect(stats.contacts, 3);
  });

  test('a current result missing from the session still shows', () {
    final table = buildLiveTable(
      sessionDetections: const [],
      currentDetections: [_rec('A', 0)],
    );
    expect(_names(table), ['A']);
    expect(table.single.sessionCount, 1);
  });

  test('current results stamped each cycle do not reorder the rows', () {
    final session = _session([_rec('A', 0), _rec('B', 10)]);
    // Each cycle stamps A's current result with its new window start.
    for (final cycle in [12, 13, 14]) {
      final table = buildLiveTable(
        sessionDetections: session,
        currentDetections: [_rec('A', cycle)],
      );
      expect(_names(table), ['B', 'A']);
      expect(table.last.lastHeard, _t0);
      expect(table.last.singing, isTrue);
    }
  });

  test('a species only in the current results comes in on top', () {
    final table = buildLiveTable(
      sessionDetections: _session([_rec('A', 0)]),
      currentDetections: [_rec('B', 5)],
    );
    expect(_names(table), ['B', 'A']);
    expect(table.first.lastHeard, _t0.add(const Duration(seconds: 5)));
  });

  test('nothing sings while paused or replaying', () {
    final current = [_rec('A', 0)];
    expect(
      singingDetections(current, paused: false, replaying: false),
      current,
    );
    expect(singingDetections(current, paused: true, replaying: false), isEmpty);
    expect(singingDetections(current, paused: false, replaying: true), isEmpty);
    final table = buildLiveTable(
      sessionDetections: _session([_rec('A', 0)]),
      currentDetections: singingDetections(
        current,
        paused: true,
        replaying: false,
      ),
    );
    expect(_names(table), ['A']);
    expect(table.single.singing, isFalse);
  });

  test('equal times keep a stable order', () {
    final table = buildLiveTable(
      sessionDetections: [_rec('B', 0), _rec('A', 0)],
      currentDetections: const [],
    );
    expect(_names(table), ['A', 'B']);
  });
}
