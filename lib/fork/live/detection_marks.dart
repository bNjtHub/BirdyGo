/// Colored marks under the live spectrogram (J6c): one line of the species
/// color under each detected passage.
///
/// The model tells when a bird sings, not at which frequency: marks are
/// lines under the time axis, never boxes around a sound (fork/DESIGN.md).
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../features/live/live_session.dart';
import '../design/birdy_tokens.dart';
import '../design/birdy_typography.dart';
import '../design/species_accents.dart';

/// Time span of one detected passage.
@immutable
class MarkSpan {
  const MarkSpan({
    required this.scientificName,
    required this.label,
    required this.start,
    this.end,
  });

  final String scientificName;

  /// Name drawn under the mark in the enlarged view.
  final String label;

  final DateTime start;

  /// Null while the species still sings: the mark runs up to now.
  final DateTime? end;
}

/// Spans of [records] (any order). A record covers its first analysis
/// window, [window] before [DetectionRecord.timestamp], up to its end. Only
/// the newest record of a species in [singing] is still running. Sorted by
/// start.
List<MarkSpan> markSpansFrom({
  required List<DetectionRecord> records,
  required Set<String> singing,
  required Duration window,
  String Function(DetectionRecord record)? labelOf,
}) {
  final newest = <String, DetectionRecord>{};
  for (final r in records) {
    final seen = newest[r.scientificName];
    if (seen == null || r.timestamp.isAfter(seen.timestamp)) {
      newest[r.scientificName] = r;
    }
  }
  final spans = [
    for (final r in records)
      MarkSpan(
        scientificName: r.scientificName,
        label: labelOf?.call(r) ?? r.commonName,
        start: r.timestamp.subtract(window),
        end:
            r.endTimestamp ??
            (singing.contains(r.scientificName) &&
                    identical(newest[r.scientificName], r)
                ? null
                : r.timestamp),
      ),
  ];
  spans.sort((a, b) => a.start.compareTo(b.start));
  return spans;
}

/// A mark placed in the strip: [left] and [right] are fractions of the
/// width (0 = oldest visible instant, 1 = now).
@immutable
class DetectionMark {
  const DetectionMark({
    required this.span,
    required this.left,
    required this.right,
    required this.lane,
  });

  final MarkSpan span;
  final double left;
  final double right;

  /// Row of the mark when passages overlap (0 = top).
  final int lane;
}

/// Places the [spans] (sorted by start) visible in the last
/// [displaySeconds] before [now]. Overlapping passages go to the next lane,
/// [maxLanes] at most; beyond, they share the lane that frees first.
List<DetectionMark> layoutDetectionMarks({
  required List<MarkSpan> spans,
  required DateTime now,
  required double displaySeconds,
  int maxLanes = 3,
  double minGap = 0.004,
}) {
  if (displaySeconds <= 0) return const [];
  final windowStart = now.microsecondsSinceEpoch - displaySeconds * 1e6;
  double fraction(DateTime t) =>
      ((t.microsecondsSinceEpoch - windowStart) / (displaySeconds * 1e6)).clamp(
        0.0,
        1.0,
      );

  final laneEnds = <double>[];
  final marks = <DetectionMark>[];
  for (final span in spans) {
    final end = span.end ?? now;
    if (end.microsecondsSinceEpoch < windowStart || span.start.isAfter(now)) {
      continue;
    }
    final left = fraction(span.start);
    final right = fraction(end);
    var lane = laneEnds.indexWhere((e) => e + minGap <= left);
    if (lane < 0) {
      if (laneEnds.length < maxLanes) {
        lane = laneEnds.length;
        laneEnds.add(right);
      } else {
        lane = 0;
        for (var i = 1; i < laneEnds.length; i++) {
          if (laneEnds[i] < laneEnds[lane]) lane = i;
        }
      }
    }
    if (lane < laneEnds.length) {
      laneEnds[lane] = right > laneEnds[lane] ? right : laneEnds[lane];
    }
    marks.add(DetectionMark(span: span, left: left, right: right, lane: lane));
  }
  return marks;
}

/// Strip of marks under the spectrogram. Scrolls with time while [running]
/// (the spectrogram's own clock stops with the capture, so does this one).
class DetectionMarks extends StatefulWidget {
  const DetectionMarks({
    super.key,
    required this.spans,
    required this.displaySeconds,
    required this.running,
    this.showLabels = false,
  });

  /// Strip height: bars only.
  static const double heightCompact = 14;

  /// Strip height: bars and names.
  static const double heightLabeled = 40;

  final List<MarkSpan> spans;
  final double displaySeconds;
  final bool running;

  /// Names under the marks (enlarged spectrogram).
  final bool showLabels;

  @override
  State<DetectionMarks> createState() => _DetectionMarksState();
}

class _DetectionMarksState extends State<DetectionMarks>
    with SingleTickerProviderStateMixin {
  late final ValueNotifier<DateTime> _now = ValueNotifier(DateTime.now());
  late final Ticker _ticker = createTicker((_) => _now.value = DateTime.now());

  /// Laid-out species names, kept across frames and rebuilds.
  final Map<String, TextPainter> _labels = {};
  TextStyle? _labelStyle;
  TextScaler? _labelScaler;

  @override
  void initState() {
    super.initState();
    _syncTicker();
  }

  @override
  void didUpdateWidget(DetectionMarks old) {
    super.didUpdateWidget(old);
    _syncTicker();
  }

  /// Ticks only while capturing and something is on screen.
  void _syncTicker() {
    final shouldRun = widget.running && widget.spans.isNotEmpty;
    if (shouldRun && !_ticker.isActive) {
      _now.value = DateTime.now();
      _ticker.start();
    } else if (!shouldRun && _ticker.isActive) {
      _ticker.stop();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _now.dispose();
    _clearLabels();
    super.dispose();
  }

  void _clearLabels() {
    for (final painter in _labels.values) {
      painter.dispose();
    }
    _labels.clear();
  }

  @override
  Widget build(BuildContext context) {
    final c = BirdyColors.of(context);
    final labelStyle = BirdyText.labelCompact.copyWith(
      fontSize: 13,
      color: c.text1,
    );
    final textScaler = MediaQuery.textScalerOf(context);
    if (labelStyle != _labelStyle || textScaler != _labelScaler) {
      _clearLabels();
      _labelStyle = labelStyle;
      _labelScaler = textScaler;
    }
    return RepaintBoundary(
      child: CustomPaint(
        size: Size.fromHeight(
          widget.showLabels
              ? DetectionMarks.heightLabeled
              : DetectionMarks.heightCompact,
        ),
        painter: DetectionMarksPainter(
          now: _now,
          spans: widget.spans,
          displaySeconds: widget.displaySeconds,
          showLabels: widget.showLabels,
          labelStyle: labelStyle,
          textScaler: textScaler,
          textDirection: Directionality.of(context),
          labels: _labels,
        ),
      ),
    );
  }
}

class DetectionMarksPainter extends CustomPainter {
  DetectionMarksPainter({
    required this.now,
    required this.spans,
    required this.displaySeconds,
    required this.showLabels,
    required this.labelStyle,
    required this.textScaler,
    required this.textDirection,
    Map<String, TextPainter>? labels,
  }) : _labels = labels ?? {},
       super(repaint: now);

  final ValueListenable<DateTime> now;
  final List<MarkSpan> spans;
  final double displaySeconds;
  final bool showLabels;
  final TextStyle labelStyle;
  final TextScaler textScaler;
  final TextDirection textDirection;

  /// Cache of laid-out names, owned by the caller.
  final Map<String, TextPainter> _labels;

  @override
  void paint(Canvas canvas, Size size) {
    final marks = layoutDetectionMarks(
      spans: spans,
      now: now.value,
      displaySeconds: displaySeconds,
    );
    if (marks.isEmpty) return;
    final bar = showLabels ? 5.0 : 3.0;
    final step = bar + (showLabels ? 2.0 : 1.5);
    const top = 2.0;
    final paint = Paint();
    var lanes = 0;
    for (final m in marks) {
      paint.color = SpeciesAccents.accentOf(m.span.scientificName);
      final left = m.left * size.width;
      final width = (m.right * size.width - left).clamp(bar, size.width);
      final y = top + m.lane * step;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(left, y, width, bar),
          Radius.circular(bar / 2),
        ),
        paint,
      );
      if (m.lane + 1 > lanes) lanes = m.lane + 1;
    }
    if (!showLabels) return;
    final labelTop = top + lanes * step + 2;
    var freeFrom = double.negativeInfinity;
    for (final m in marks) {
      final left = m.left * size.width;
      if (left < freeFrom) continue;
      final text = _labels.putIfAbsent(
        m.span.label,
        () => TextPainter(
          text: TextSpan(text: m.span.label, style: labelStyle),
          textDirection: textDirection,
          textScaler: textScaler,
          maxLines: 1,
        )..layout(),
      );
      if (labelTop + text.height > size.height) break;
      final x = left.clamp(0.0, size.width - text.width).toDouble();
      if (x < freeFrom) continue;
      text.paint(canvas, Offset(x, labelTop));
      freeFrom = x + text.width + 8;
    }
  }

  @override
  bool shouldRepaint(DetectionMarksPainter old) =>
      old.spans != spans ||
      old.displaySeconds != displaySeconds ||
      old.showLabels != showLabels ||
      old.labelStyle != labelStyle ||
      old.textScaler != textScaler ||
      old.now != now;
}
