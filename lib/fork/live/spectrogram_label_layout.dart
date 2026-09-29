/// Placement of the species names under the live spectrogram (J6h): never
/// overlapping, and never cut by the left edge.
library;

import 'package:flutter/foundation.dart';

/// Gap kept between two names on the same line.
const double kMarkLabelGap = 8;

/// A name waiting for a place: [left] is where its mark starts (pixels from
/// the strip's left edge), [width] its laid-out width.
@immutable
class MarkLabelSlot {
  const MarkLabelSlot({
    required this.left,
    required this.width,
    this.startsBeforeWindow = false,
  });

  final double left;
  final double width;

  /// The passage began before the visible window: the name would sit on the
  /// left edge, cut off, so it is not written.
  final bool startsBeforeWindow;
}

/// X position of each of [slots] (in the order given, oldest first), or null
/// when the name is not drawn.
///
/// A name is anchored at its mark's left, pushed left at most to fit before
/// [maxWidth] (the right edge). It is skipped when it would run off the left
/// edge, or touch the previous drawn name ([gap] pixels apart at least).
List<double?> placeMarkLabels(
  List<MarkLabelSlot> slots, {
  required double maxWidth,
  double gap = kMarkLabelGap,
}) {
  var freeFrom = double.negativeInfinity;
  final placed = <double?>[];
  for (final slot in slots) {
    if (slot.startsBeforeWindow) {
      placed.add(null);
      continue;
    }
    final fitting = maxWidth - slot.width;
    final x = slot.left > fitting ? fitting : slot.left;
    if (x < 0 || x < freeFrom) {
      placed.add(null);
      continue;
    }
    placed.add(x);
    freeFrom = x + slot.width + gap;
  }
  return placed;
}
