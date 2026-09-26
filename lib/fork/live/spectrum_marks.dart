/// Species marks under the live spectrogram (J6c).
///
/// The model says when a bird sings, not at which frequency: each detected
/// passage gets a short bar of the species color along the bottom edge,
/// never a box around a sound (fork/DESIGN.md, Live).
library;

import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

import '../../features/live/live_session.dart';

/// Audio time shown by the spectrogram, which stands still while the
/// session is paused (the spectrogram only scrolls while capturing).
class SpectrumClock {
  SpectrumClock(this.origin);

  /// When the spectrogram started scrolling: nothing older is on screen.
  final DateTime origin;

  final List<(DateTime, DateTime?)> _pauses = [];

  bool get isPaused => _pauses.isNotEmpty && _pauses.last.$2 == null;

  void pause(DateTime at) {
    if (!isPaused) _pauses.add((at, null));
  }

  void resume(DateTime at) {
    if (isPaused) _pauses.last = (_pauses.last.$1, at);
  }

  /// Seconds of audio the spectrogram scrolled between [t] and [now].
  double audioSecondsBetween(DateTime t, DateTime now) {
    if (!now.isAfter(t)) return 0;
    var micros = now.difference(t).inMicroseconds;
    for (final (start, end) in _pauses) {
      final from = start.isAfter(t) ? start : t;
      final pauseEnd = end ?? now;
      final to = pauseEnd.isBefore(now) ? pauseEnd : now;
      if (to.isAfter(from)) micros -= to.difference(from).inMicroseconds;
    }
    return math.max(0, micros) / Duration.microsecondsPerSecond;
  }
}

/// One detected passage: [end] is null while the species is still singing.
@immutable
class SpectrumMark {
  const SpectrumMark({required this.start, this.end, required this.color});

  final DateTime start;
  final DateTime? end;
  final Color color;

  @override
  bool operator ==(Object other) =>
      other is SpectrumMark &&
      other.start == start &&
      other.end == end &&
      other.color == color;

  @override
  int get hashCode => Object.hash(start, end, color);
}

/// Marks of the session records. An episode still open is drawn up to "now"
/// while its species is in [currentSpecies], else over one analysis window.
List<SpectrumMark> buildSpectrumMarks({
  required List<DetectionRecord> records,
  required Set<String> currentSpecies,
  required Duration window,
  required Color Function(String scientificName) colorOf,
}) => [
  for (final record in records)
    SpectrumMark(
      start: record.timestamp,
      end:
          record.endTimestamp ??
          (currentSpecies.contains(record.scientificName)
              ? null
              : record.timestamp.add(window)),
      color: colorOf(record.scientificName),
    ),
];

/// Height of a mark and its gap to the bottom edge, in logical pixels.
const double kSpectrumMarkHeight = 4;
const double kSpectrumMarkInset = 3;

/// Narrowest mark, so a short call stays visible.
const double kSpectrumMarkMinWidth = 6;

/// Rectangle of a mark whose start and end are [startAge] and [endAge]
/// seconds old, on a plot of [size] whose right edge is "now" and whose
/// width spans [displaySeconds]. Null when off screen.
Rect? spectrumMarkRect({
  required Size size,
  required double displaySeconds,
  required double startAge,
  required double endAge,
}) {
  if (displaySeconds <= 0 || size.width <= 0) return null;
  double xOf(double age) => size.width * (1 - age / displaySeconds);
  var left = xOf(startAge);
  var right = xOf(endAge);
  if (right <= 0 || left >= size.width) return null;
  if (right - left < kSpectrumMarkMinWidth) {
    left = right - kSpectrumMarkMinWidth;
  }
  left = math.max(0, left);
  right = math.min(size.width, right);
  final bottom = size.height - kSpectrumMarkInset;
  return Rect.fromLTRB(left, bottom - kSpectrumMarkHeight, right, bottom);
}

/// Paints the marks; repaints on [repaint] (one tick per frame).
class SpectrumMarksPainter extends CustomPainter {
  SpectrumMarksPainter({
    required this.marks,
    required this.clock,
    required this.displaySeconds,
    required this.now,
    super.repaint,
  });

  final List<SpectrumMark> marks;
  final SpectrumClock clock;
  final double displaySeconds;
  final DateTime Function() now;

  @override
  void paint(Canvas canvas, Size size) {
    final t = now();
    final paint = Paint();
    for (final mark in marks) {
      final end = mark.end ?? t;
      if (end.isBefore(clock.origin)) continue;
      final start =
          mark.start.isBefore(clock.origin) ? clock.origin : mark.start;
      final rect = spectrumMarkRect(
        size: size,
        displaySeconds: displaySeconds,
        startAge: clock.audioSecondsBetween(start, t),
        endAge: clock.audioSecondsBetween(end, t),
      );
      if (rect == null) continue;
      paint.color = mark.color;
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(2)),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(SpectrumMarksPainter old) =>
      old.marks != marks ||
      old.displaySeconds != displaySeconds ||
      old.clock != clock;
}
