/// Small bar charts of activity by hour or by month (J4), drawn with a
/// CustomPainter: no chart dependency. Also supports a per-bar sequential
/// color scale, a tap/long-press selection and one highlighted bar (J6f-b
/// fix).
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../design/birdy_motion.dart';
import '../design/birdy_tokens.dart';

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
    this.highlightIndex,
    this.highlightColor,
    this.labelStyle,
    this.selectedIndex,
    this.dimUnselected = false,
  });

  /// Opacity of the unselected bars when [dimUnselected] is on and a bar is
  /// selected.
  static const double dimmedOpacity = 0.4;

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

  /// Bar marked as the current one (e.g. today's month), independent of its
  /// color: a dot under the bar, on the background rather than on the bar
  /// (a light dot on a light bar was hard to see), and its label in bold
  /// [highlightColor] (J6f-b fix).
  final int? highlightIndex;

  /// Color of the [highlightIndex] dot and label; the theme's primary by
  /// default.
  final Color? highlightColor;

  /// Axis label style (J6h: [BirdyText.axisLabel], 12); the theme's
  /// labelSmall by default.
  final TextStyle? labelStyle;

  /// The selected bar (kept by the caller, usually from [onSelect]); only
  /// used by [dimUnselected].
  final int? selectedIndex;

  /// Opt-in: with a [selectedIndex], the other bars fade to [dimmedOpacity]
  /// (animated, [BirdyMotion.enter]). Off by default: bars are unchanged.
  final bool dimUnselected;

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
    final style = (labelStyle ?? theme.textTheme.labelSmall)?.copyWith(
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
                Widget paint(double othersOpacity) => CustomPaint(
                  painter: _BarsPainter(
                    values: values,
                    color: color ?? theme.colorScheme.primary,
                    emptyColor:
                        trackColor ?? theme.colorScheme.surfaceContainerHighest,
                    colorForValue: colorForValue,
                    highlightIndex: highlightIndex,
                    highlightColor: highlightColor ?? theme.colorScheme.primary,
                    selectedIndex: selectedIndex,
                    othersOpacity: othersOpacity,
                  ),
                );
                final chart =
                    dimUnselected
                        ? TweenAnimationBuilder<double>(
                          tween: Tween(
                            end: selectedIndex == null ? 1 : dimmedOpacity,
                          ),
                          duration: BirdyMotion.enter,
                          curve: BirdyMotion.standard,
                          builder: (context, v, _) => paint(v),
                        )
                        : paint(1);
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
          const SizedBox(height: BirdySpace.xs),
          LayoutBuilder(
            builder: (context, constraints) {
              final slot = constraints.maxWidth / values.length;
              final keys = labels.keys.toList()..sort();
              return SizedBox(
                height: BirdySpace.l,
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
                          style:
                              keys[i] == highlightIndex
                                  ? style?.copyWith(
                                    color:
                                        highlightColor ??
                                        theme.colorScheme.primary,
                                    fontWeight: FontWeight.w800,
                                  )
                                  : style,
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
    this.highlightIndex,
    required this.highlightColor,
    this.selectedIndex,
    this.othersOpacity = 1,
  });

  final List<int> values;
  final Color color;
  final Color emptyColor;
  final Color Function(int value, int maxValue)? colorForValue;
  final int? highlightIndex;
  final Color highlightColor;
  final int? selectedIndex;

  /// Opacity of every bar but [selectedIndex] (1 = none dimmed).
  final double othersOpacity;

  /// Dot of the highlighted bar, and the strip it sits in under the bars.
  static const double _dotRadius = 3;
  static const double _dotStrip = 2 * _dotRadius + 3;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final maxValue = values.reduce(math.max);
    final slot = size.width / values.length;
    final barWidth = math.max(slot * 0.7, 1.0);
    final radius = Radius.circular(math.min(barWidth / 2, 3));
    // With a highlighted bar, the bars leave a strip at the bottom for its
    // dot, so the dot sits on the background, never on a bar.
    final bars =
        highlightIndex == null ? size.height : size.height - _dotStrip;
    for (var i = 0; i < values.length; i++) {
      final ratio = maxValue == 0 ? 0.0 : values[i] / maxValue;
      final h = math.max(ratio * bars, 2.0);
      final rect = Rect.fromLTWH(
        i * slot + (slot - barWidth) / 2,
        bars - h,
        barWidth,
        h,
      );
      var barColor =
          values[i] == 0
              ? emptyColor
              : (colorForValue?.call(values[i], maxValue) ?? color);
      if (othersOpacity < 1 && selectedIndex != null && i != selectedIndex) {
        barColor = barColor.withValues(alpha: barColor.a * othersOpacity);
      }
      canvas.drawRRect(
        RRect.fromRectAndCorners(rect, topLeft: radius, topRight: radius),
        Paint()..color = barColor,
      );
      if (i == highlightIndex) {
        canvas.drawCircle(
          Offset(i * slot + slot / 2, size.height - _dotRadius),
          _dotRadius,
          Paint()..color = highlightColor,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_BarsPainter old) =>
      old.color != color ||
      old.emptyColor != emptyColor ||
      old.colorForValue != colorForValue ||
      old.highlightIndex != highlightIndex ||
      old.highlightColor != highlightColor ||
      old.selectedIndex != selectedIndex ||
      old.othersOpacity != othersOpacity ||
      !_sameValues(old.values, values);

  static bool _sameValues(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
