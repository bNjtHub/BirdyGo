/// Small bar charts of activity by hour or by month (J4), drawn with a
/// CustomPainter: no chart dependency. Also supports a per-bar sequential
/// color scale and a tap/long-press selection (J6f-b fix).
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
    this.color,
    this.colorForValue,
    this.trackColor,
    this.onSelect,
  });

  final List<int> values;

  /// Label per bar index (sparse: only some indices are labeled).
  final Map<int, String> labels;
  final String semanticLabel;
  final double height;

  /// Flat bar color; the theme's primary by default. Ignored when
  /// [colorForValue] is set.
  final Color? color;

  /// Per-bar color from its value and the busiest value, for a sequential
  /// scale (J6f-b fix); overrides [color] when set. Never called with a
  /// zero value: those always use [trackColor].
  final Color Function(int value, int maxValue)? colorForValue;

  /// Bar color for a zero value; the theme's surfaceContainerHighest by
  /// default.
  final Color? trackColor;

  /// Called with a bar's index and value on tap or long press (J6f-b fix).
  final void Function(int index, int value)? onSelect;

  void _select(Offset local, double width) {
    final onSelect = this.onSelect;
    if (onSelect == null || values.isEmpty || width <= 0) return;
    final slot = width / values.length;
    final index = (local.dx / slot).floor().clamp(0, values.length - 1);
    onSelect(index, values[index]);
  }

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
            child: LayoutBuilder(
              builder: (context, constraints) {
                final chart = CustomPaint(
                  painter: _BarsPainter(
                    values: values,
                    color: color ?? theme.colorScheme.primary,
                    emptyColor:
                        trackColor ?? theme.colorScheme.surfaceContainerHighest,
                    colorForValue: colorForValue,
                  ),
                );
                if (onSelect == null) return chart;
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  excludeFromSemantics: true,
                  onTapDown:
                      (d) => _select(d.localPosition, constraints.maxWidth),
                  onLongPressStart:
                      (d) => _select(d.localPosition, constraints.maxWidth),
                  child: chart,
                );
              },
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
    this.colorForValue,
  });

  final List<int> values;
  final Color color;
  final Color emptyColor;
  final Color Function(int value, int maxValue)? colorForValue;

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
      final barColor =
          values[i] == 0
              ? emptyColor
              : (colorForValue?.call(values[i], maxValue) ?? color);
      canvas.drawRRect(
        RRect.fromRectAndCorners(rect, topLeft: radius, topRight: radius),
        Paint()..color = barColor,
      );
    }
  }

  @override
  bool shouldRepaint(_BarsPainter old) =>
      old.color != color ||
      old.emptyColor != emptyColor ||
      old.colorForValue != colorForValue ||
      !_sameValues(old.values, values);

  static bool _sameValues(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
