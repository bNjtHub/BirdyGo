import 'package:birdnet_live/features/live/live_session.dart';
import 'package:birdnet_live/fork/live/detection_marks.dart';
import 'package:flutter_test/flutter_test.dart';

final _t0 = DateTime(2026, 9, 26, 7, 0);
DateTime _at(num seconds) =>
    _t0.add(Duration(milliseconds: (seconds * 1000).round()));

MarkSpan _span(String name, num start, [num? end]) => MarkSpan(
  scientificName: name,
  label: name,
  start: _at(start),
  end: end == null ? null : _at(end),
);

void main() {
  group('markSpansFrom', () {
    DetectionRecord rec(String name, int second, {int? end}) => DetectionRecord(
      scientificName: name,
      commonName: 'common $name',
      confidence: 0.9,
      timestamp: _at(second),
      endTimestamp: end == null ? null : _at(end),
    );

    test('a passage starts one analysis window before its timestamp', () {
      final spans = markSpansFrom(
        records: [rec('A', 10, end: 14)],
        singing: const {},
        window: const Duration(seconds: 3),
      );
      expect(spans.single.start, _at(7));
      expect(spans.single.end, _at(14));
      expect(spans.single.label, 'common A');
    });

    test('only the newest record of a singing species runs to now', () {
      final spans = markSpansFrom(
        records: [rec('A', 20), rec('A', 5), rec('B', 8)],
        singing: const {'A'},
        window: const Duration(seconds: 3),
      );
      expect([for (final s in spans) s.start], [_at(2), _at(5), _at(17)]);
      expect(spans[2].end, isNull);
      // Old record without end: one window long.
      expect(spans[0].end, _at(5));
      // Not singing: closes at its timestamp.
      expect(spans[1].end, _at(8));
    });
  });

  group('layoutDetectionMarks', () {
    test('maps time to the width, now on the right', () {
      final marks = layoutDetectionMarks(
        spans: [_span('A', 5, 7.5)],
        now: _at(10),
        displaySeconds: 10,
      );
      expect(marks.single.left, closeTo(0.5, 1e-9));
      expect(marks.single.right, closeTo(0.75, 1e-9));
      expect(marks.single.lane, 0);
    });

    test('a running passage reaches now', () {
      final marks = layoutDetectionMarks(
        spans: [_span('A', 8)],
        now: _at(10),
        displaySeconds: 10,
      );
      expect(marks.single.right, 1);
    });

    test('clips passages at the edges and drops hidden ones', () {
      final marks = layoutDetectionMarks(
        spans: [
          _span('old', -20, -15),
          _span('edge', -2, 3),
          _span('B', 9, 12),
        ],
        now: _at(10),
        displaySeconds: 10,
      );
      expect([for (final m in marks) m.span.scientificName], ['edge', 'B']);
      expect(marks.first.left, 0);
      expect(marks.first.right, closeTo(0.3, 1e-9));
      expect(marks.last.right, 1);
    });

    test('overlapping passages take the next lane, three at most', () {
      final marks = layoutDetectionMarks(
        spans: [
          _span('A', 0, 6),
          _span('B', 1, 3),
          _span('C', 2, 4),
          _span('D', 2.5, 5),
          _span('E', 7, 8),
        ],
        now: _at(10),
        displaySeconds: 10,
      );
      final lanes = {for (final m in marks) m.span.scientificName: m.lane};
      expect(lanes['A'], 0);
      expect(lanes['B'], 1);
      expect(lanes['C'], 2);
      // No lane is free: shares the one that frees first (B, at 3 s).
      expect(lanes['D'], 1);
      // After A: back to the first lane.
      expect(lanes['E'], 0);
    });

    test('frozen clock: nothing moves', () {
      final spans = [_span('A', 5, 7)];
      final a = layoutDetectionMarks(
        spans: spans,
        now: _at(10),
        displaySeconds: 10,
      );
      final b = layoutDetectionMarks(
        spans: spans,
        now: _at(10),
        displaySeconds: 10,
      );
      expect(a.single.left, b.single.left);
    });

    test('a pause does not move the marks (the spectrogram stops too)', () {
      final spans = [_span('A', 5, 7)];
      final before =
          layoutDetectionMarks(
            spans: spans,
            now: _at(10),
            displaySeconds: 10,
          ).single;
      final pauses =
          MarkPauses()
            ..pause(_at(10))
            ..resume(_at(70));
      final after =
          layoutDetectionMarks(
            spans: spans,
            now: _at(70),
            displaySeconds: 10,
            pauses: pauses,
          ).single;
      expect(after.left, closeTo(before.left, 1e-9));
      expect(after.right, closeTo(before.right, 1e-9));

      // Still paused: frozen, however long the pause.
      final paused = MarkPauses()..pause(_at(10));
      final during =
          layoutDetectionMarks(
            spans: spans,
            now: _at(300),
            displaySeconds: 10,
            pauses: paused,
          ).single;
      expect(during.left, closeTo(before.left, 1e-9));
    });

    test('after a pause, marks scroll again with listening time', () {
      final pauses =
          MarkPauses()
            ..pause(_at(10))
            ..resume(_at(70));
      final marks = layoutDetectionMarks(
        spans: [_span('A', 5, 7)],
        now: _at(72),
        displaySeconds: 10,
        pauses: pauses,
      );
      // 2 s of listening since the resume: same as now = 12 s without pause.
      expect(marks.single.left, closeTo(0.3, 1e-9));
      expect(marks.single.right, closeTo(0.5, 1e-9));
    });

    test('a passage older than the window, counting pauses, is dropped', () {
      final pauses =
          MarkPauses()
            ..pause(_at(10))
            ..resume(_at(70));
      final marks = layoutDetectionMarks(
        spans: [_span('A', 5, 7)],
        now: _at(90),
        displaySeconds: 10,
        pauses: pauses,
      );
      expect(marks, isEmpty);
    });
  });
}
