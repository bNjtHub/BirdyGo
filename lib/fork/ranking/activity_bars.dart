/// Small bar charts of activity by hour or by month (J4), drawn with a
/// CustomPainter: no chart dependency.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Bars for [values], with a few axis [labels] under them.
class ActivityBars extends StatelessWidget {
  const ActivityBars({
    super.key,
    required this.values,
    required this.labels,
    required this.semanticLabel,
    this.height = 64,
  });

  final List<int> values;

  /// Label per bar index (sparse: only some indices are labeled).
  final Map<int, String> labels;
  final String semanticLabel;
  final double height;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Semantics(
      label: semanticLabel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: height,
            child: CustomPaint(
              painter: _BarsPainter(
                values: values,
                color: theme.colorScheme.primary,
                emptyColor: theme.colorScheme.surfaceContainerHighest,
              ),
            ),
          ),
          const SizedBox(height: 4),
          LayoutBuilder(
            builder: (context, constraints) {
              final slot = constraints.maxWidth / values.length;
              final keys = labels.keys.toList()..sort();
              return SizedBox(
                height: 16,
                child: Stack(
                  children: [
                    for (var i = 0; i < keys.length; i++)
                      Positioned(
                        left: keys[i] * slot,
                        // Each label spans up to the next labeled bar.
                        width:
                            ((i + 1 < keys.length
                                    ? keys[i + 1]
                                    : values.length) -
                                keys[i]) *
                            slot,
                        child: Text(
                          labels[keys[i]]!,
                          style: style,
                          maxLines: 1,
                          textAlign:
                              keys.length == values.length
                                  ? TextAlign.center
                                  : TextAlign.start,
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _BarsPainter extends CustomPainter {
  _BarsPainter({
    required this.values,
    required this.color,
    required this.emptyColor,
  });

  final List<int> values;
  final Color color;
  final Color emptyColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final maxValue = values.reduce(math.max);
    final slot = size.width / values.length;
    final barWidth = math.max(slot * 0.7, 1.0);
    final radius = Radius.circular(math.min(barWidth / 2, 3));
    for (var i = 0; i < values.length; i++) {
      final ratio = maxValue == 0 ? 0.0 : values[i] / maxValue;
      final h = math.max(ratio * size.height, 2.0);
      final rect = Rect.fromLTWH(
        i * slot + (slot - barWidth) / 2,
        size.height - h,
        barWidth,
        h,
      );
      canvas.drawRRect(
        RRect.fromRectAndCorners(rect, topLeft: radius, topRight: radius),
        Paint()..color = values[i] == 0 ? emptyColor : color,
      );
    }
  }

  @override
  bool shouldRepaint(_BarsPainter old) =>
      old.color != color || !_sameValues(old.values, values);

  static bool _sameValues(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
