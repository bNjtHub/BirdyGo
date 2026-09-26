/// Dashed rounded outline (J6a): « À vérifier » badges and mystery cards.
library;

import 'dart:ui' show PathMetric;

import 'package:flutter/widgets.dart';

class DashedBorderPainter extends CustomPainter {
  const DashedBorderPainter({
    required this.color,
    required this.radius,
    this.strokeWidth = 1.5,
    this.dash = 4,
    this.gap = 3,
  });

  final Color color;
  final double radius;
  final double strokeWidth;
  final double dash;
  final double gap;

  @override
  void paint(Canvas canvas, Size size) {
    final inset = strokeWidth / 2;
    final rect = Rect.fromLTWH(
      inset,
      inset,
      size.width - strokeWidth,
      size.height - strokeWidth,
    );
    final r = radius.clamp(0, rect.shortestSide / 2).toDouble();
    final path =
        Path()..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(r)));
    final paint =
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round;
    for (final PathMetric metric in path.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += dash + gap) {
        canvas.drawPath(metric.extractPath(d, d + dash), paint);
      }
    }
  }

  @override
  bool shouldRepaint(DashedBorderPainter old) =>
      old.color != color ||
      old.radius != radius ||
      old.strokeWidth != strokeWidth ||
      old.dash != dash ||
      old.gap != gap;
}
