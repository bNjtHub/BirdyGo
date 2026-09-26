import 'package:birdnet_live/features/live/live_session.dart';
import 'package:birdnet_live/fork/live/detection_marks.dart';
import 'package:birdnet_live/fork/live/live_heard.dart';
import 'package:birdnet_live/fork/reliability/reliability_config.dart';
import 'package:flutter_test/flutter_test.dart';

const _name = 'Turdus merula';
final _t0 = DateTime(2026, 9, 26, 6, 30);
const _window = Duration(seconds: 3);

/// Feeds [heard] one window per second from [_t0]: true = at or above the
/// support threshold. The contact stays open all along.
List<Set<String>> _feed(LiveHeard live, List<bool> heard) => [
  for (var i = 0; i < heard.length; i++)
    (live..update(
          contacts: {_name: _t0},
          supported: heard[i] ? {_name} : {},
          windowEnd: _t0.add(_window + Duration(seconds: i)),
          window: _window,
        ))
        .singingVisual,
];

void main() {
  test('the symbol lights up when the contact opens', () {
    final visual = _feed(LiveHeard(), [false]);
    expect(visual.single, {_name});
  });

  test('phrase, one missed window, phrase: the symbol stays', () {
    final visual = _feed(LiveHeard(), [true, false, true, true]);
    expect(visual.every((v) => v.contains(_name)), isTrue);
  });

  test('two windows under the support threshold put it out', () {
    expect(ReliabilityConfig.liveSingingHoldWindows, 2);
    final visual = _feed(LiveHeard(), [true, false, false, true]);
    expect(visual.map((v) => v.contains(_name)), [true, true, false, true]);
  });

  test('out of the results: out at once', () {
    final live = LiveHeard();
    _feed(live, [true]);
    live.update(
      contacts: const {},
      supported: const {},
      windowEnd: _t0.add(const Duration(seconds: 4)),
      window: _window,
    );
    expect(live.singingVisual, isEmpty);
  });

  test('heardUntil is the end of the last supporting window, never back', () {
    final live = LiveHeard();
    final ends = <DateTime>[];
    for (final (i, heard) in [true, true, false, false, false].indexed) {
      live.update(
        contacts: {_name: _t0},
        supported: heard ? {_name} : {},
        windowEnd: _t0.add(_window + Duration(seconds: i)),
        window: _window,
      );
      ends.add(live.heardUntil[(_name, _t0)]!);
    }
    for (var i = 1; i < ends.length; i++) {
      expect(ends[i].isBefore(ends[i - 1]), isFalse);
    }
    expect(ends.last, _t0.add(_window + const Duration(seconds: 1)));

    // A pause keeps the ends.
    live.pause();
    expect(live.singingVisual, isEmpty);
    expect(live.heardUntil[(_name, _t0)], ends.last);
  });

  test('the displayed mark end never goes back', () {
    final live = LiveHeard();
    final record = DetectionRecord(
      scientificName: _name,
      commonName: _name,
      confidence: 0.9,
      timestamp: _t0,
    );
    final hold = MarkEndHold();
    var shown = <MarkSpan>[];
    DateTime? lastEnd;
    final heard = [true, true, false, false, false, false];
    for (var i = 0; i < heard.length; i++) {
      live.update(
        contacts: {_name: _t0},
        supported: heard[i] ? {_name} : {},
        windowEnd: _t0.add(_window + Duration(seconds: i)),
        window: _window,
      );
      final now = _t0.add(_window + Duration(seconds: i, milliseconds: 300));
      shown = hold.apply(
        previous: shown,
        next: markSpansFrom(
          records: [record],
          singing: live.singingVisual,
          heardUntil: live.heardUntil,
          window: _window,
        ),
        now: now,
      );
      final end = shown.single.end ?? now;
      if (lastEnd != null) expect(end.isBefore(lastEnd), isFalse);
      lastEnd = end;
    }
    expect(shown.single.end, isNotNull, reason: 'the mark stopped running');

    // Redrawn from scratch (rotation): the end is heardUntil.
    final redrawn = markSpansFrom(
      records: [record],
      singing: live.singingVisual,
      heardUntil: live.heardUntil,
      window: _window,
    );
    expect(redrawn.single.end, live.heardUntil[(_name, _t0)]);
  });
}
