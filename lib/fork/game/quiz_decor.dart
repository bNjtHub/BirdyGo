/// Decorative particle fields of the « Qui chante ? » v2 mockup that sit
/// outside quiz_fx.dart's per-widget animations: the hero's 16 radiating
/// sparks, the soft twinkling stars (hero, stage, result), and the
/// result's one-shot party star burst. Each field is a single
/// [CustomPainter] driven by one [AnimationController], so a whole cluster
/// costs one ticker and one repaint rather than N widgets; callers wrap
/// the field in a `RepaintBoundary`.
///
/// The ticker is created with [SingleTickerProviderStateMixin], so it
/// already pauses on its own when the route is hidden ([TickerMode]).
/// With reduced motion ([BirdyMotion.reduced]) the ticker never starts:
/// sparks and the burst don't draw at all, twinkles draw once at their
/// resting (mid) frame.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../design/birdy_motion.dart';
import '../design/birdy_tokens.dart';

/// Span of the shared endless controller: long enough that many independent
/// periods (spark 2.6 s, twinkle 2.2 s, ...) can each take `elapsed % their
/// own period` without the controller itself ever visibly looping.
const Duration _fieldSpan = Duration(hours: 2);

/// A field animation driven by one endless [AnimationController], so many
/// independent periods can share a single ticker.
abstract class _QuizField extends StatefulWidget {
  const _QuizField({super.key});
}

abstract class _QuizFieldState<T extends _QuizField> extends State<T>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller = AnimationController(
    vsync: this,
    duration: _fieldSpan,
  );
  bool reduced = false;
  bool _started = false;

  /// Whether the field keeps looping once started (sparks, twinkles) or
  /// plays once (the party burst).
  bool get loops => true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final now = BirdyMotion.reduced(context);
    if (now != reduced || (!now && !_started)) {
      reduced = now;
      _sync();
    }
  }

  void _sync() {
    if (reduced) {
      controller.stop();
      return;
    }
    _started = true;
    if (loops) {
      controller.repeat();
    } else if (!controller.isAnimating && controller.value == 0) {
      controller.forward();
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
}

/// Soft 4-point twinkling stars (qz-twinkle: scale .5↔1, opacity .3↔1,
/// 2.2 s), at stable pseudo-random positions in the box. Positions and
/// colors are re-derived from [seed] every frame (cheap for a handful of
/// points), so no field or list needs to be kept in state.
class QuizTwinkleField extends _QuizField {
  const QuizTwinkleField({super.key, required this.count, this.seed = 0});

  final int count;
  final int seed;

  static const Duration period = Duration(milliseconds: 2200);

  @override
  State<QuizTwinkleField> createState() => _QuizTwinkleFieldState();
}

class _QuizTwinkleFieldState extends _QuizFieldState<QuizTwinkleField> {
  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: IgnorePointer(
      child: CustomPaint(
        size: Size.infinite,
        painter: _TwinklePainter(
          controller: controller,
          count: widget.count,
          seed: widget.seed,
          reduced: reduced,
        ),
      ),
    ),
  );
}

class _TwinklePainter extends CustomPainter {
  _TwinklePainter({
    required this.controller,
    required this.count,
    required this.seed,
    required this.reduced,
  }) : super(repaint: controller);

  final AnimationController controller;
  final int count;
  final int seed;
  final bool reduced;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final elapsedMs = controller.value * _fieldSpan.inMilliseconds;
    final rnd = math.Random(seed);
    final periodMs = QuizTwinkleField.period.inMilliseconds;
    for (var i = 0; i < count; i++) {
      final dx = rnd.nextDouble();
      final dy = rnd.nextDouble();
      final baseSize = 9.0 + rnd.nextDouble() * 5;
      final delayMs = rnd.nextInt(periodMs);
      final color =
          BirdyQuizColors.sparkColors[i % BirdyQuizColors.sparkColors.length];
      double k;
      if (reduced) {
        k = 0.65; // at rest: visible, not blinking.
      } else {
        final phase = ((elapsedMs - delayMs) % periodMs) / periodMs;
        // Triangular wave, 0 at the edges and 1 at the middle (qz-twinkle).
        k = 1 - (2 * phase - 1).abs();
      }
      final starSize = baseSize * (0.5 + 0.5 * k);
      final opacity = (0.3 + 0.7 * k).clamp(0.0, 1.0);
      _sparkle(
        canvas,
        Offset(dx * size.width, dy * size.height),
        starSize,
        color.withValues(alpha: opacity),
      );
    }
  }

  /// A 4-point sparkle, the mockup's own twinkle SVG.
  void _sparkle(Canvas canvas, Offset center, double size, Color color) {
    final r = size / 2;
    final path = Path()
      ..moveTo(center.dx, center.dy - r)
      ..quadraticBezierTo(
        center.dx + r * 0.18,
        center.dy - r * 0.18,
        center.dx + r,
        center.dy,
      )
      ..quadraticBezierTo(
        center.dx + r * 0.18,
        center.dy + r * 0.18,
        center.dx,
        center.dy + r,
      )
      ..quadraticBezierTo(
        center.dx - r * 0.18,
        center.dy + r * 0.18,
        center.dx - r,
        center.dy,
      )
      ..quadraticBezierTo(
        center.dx - r * 0.18,
        center.dy - r * 0.18,
        center.dx,
        center.dy - r,
      )
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _TwinklePainter oldDelegate) =>
      oldDelegate.reduced != reduced ||
      oldDelegate.count != count ||
      oldDelegate.seed != seed;
}

/// 16 sparks radiating outward from the box's center, forever (qz-spark-a
/// / qz-spark-b, 2.6 s): the intro hero's glow. Hidden entirely with
/// reduced motion (a spark frozen mid-flight reads as a rendering glitch,
/// not as decoration).
class QuizSparkField extends _QuizField {
  const QuizSparkField({
    super.key,
    this.count = 16,
    this.seed = 1,
    this.maxRadius = 120,
  });

  final int count;
  final int seed;
  final double maxRadius;

  static const Duration period = Duration(milliseconds: 2600);

  @override
  State<QuizSparkField> createState() => _QuizSparkFieldState();
}

class _QuizSparkFieldState extends _QuizFieldState<QuizSparkField> {
  @override
  Widget build(BuildContext context) {
    if (reduced) return const SizedBox.shrink();
    return RepaintBoundary(
      child: IgnorePointer(
        child: CustomPaint(
          size: Size.infinite,
          painter: _SparkPainter(
            controller: controller,
            count: widget.count,
            seed: widget.seed,
            maxRadius: widget.maxRadius,
          ),
        ),
      ),
    );
  }
}

class _SparkPainter extends CustomPainter {
  _SparkPainter({
    required this.controller,
    required this.count,
    required this.seed,
    required this.maxRadius,
  }) : super(repaint: controller);

  final AnimationController controller;
  final int count;
  final int seed;
  final double maxRadius;

  static const _innerRadius = 0.24; // share of maxRadius at full opacity.

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final elapsedMs = controller.value * _fieldSpan.inMilliseconds;
    final center = size.center(Offset.zero);
    final rnd = math.Random(seed);
    final periodMs = QuizSparkField.period.inMilliseconds;
    for (var i = 0; i < count; i++) {
      final jitter = (rnd.nextDouble() - 0.5) * 0.35;
      final angle = i * (2 * math.pi / count) + jitter;
      final delayMs = rnd.nextInt(periodMs);
      final rect = i.isOdd;
      final color =
          BirdyQuizColors.sparkColors[i % BirdyQuizColors.sparkColors.length];
      final phase = ((elapsedMs - delayMs) % periodMs) / periodMs;
      // qz-spark-a/b: fades and grows in fast, holds, fades out far out.
      const stops = [0.0, 0.12, 0.7, 1.0];
      double at(List<double> v) {
        for (var s = 1; s < stops.length; s++) {
          if (phase <= stops[s]) {
            final local = (phase - stops[s - 1]) / (stops[s] - stops[s - 1]);
            return v[s - 1] + (v[s] - v[s - 1]) * local.clamp(0.0, 1.0);
          }
        }
        return v.last;
      }

      final dist = at([0, maxRadius * _innerRadius, maxRadius * 0.9, maxRadius]);
      final opacity = at([0, 1, 1, 0]).clamp(0.0, 1.0);
      final scale = at([0, 1, 1, 0.3]).clamp(0.0, 1.0);
      if (opacity <= 0) continue;
      final pos = center + Offset(math.cos(angle), math.sin(angle)) * dist;
      final paint = Paint()..color = color.withValues(alpha: opacity);
      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      canvas.rotate(angle);
      final w = (rect ? 10.0 : 7.0) * scale;
      final h = (rect ? 4.0 : 7.0) * scale;
      final r = rect ? 2.0 : h / 2;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: w, height: h),
          Radius.circular(r),
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _SparkPainter oldDelegate) => true;
}

/// The result's party star burst: [count] particles radiating from the
/// stars once, when the field first builds. Never loops, so it's built
/// only while `party` holds on the result screen.
class QuizStarBurstField extends _QuizField {
  const QuizStarBurstField({super.key, this.count = 14, this.seed = 2});

  final int count;
  final int seed;

  static const Duration duration = Duration(milliseconds: 1200);

  @override
  State<QuizStarBurstField> createState() => _QuizStarBurstFieldState();
}

class _QuizStarBurstFieldState extends _QuizFieldState<QuizStarBurstField> {
  @override
  bool get loops => false;

  @override
  Widget build(BuildContext context) {
    if (reduced) return const SizedBox.shrink();
    return RepaintBoundary(
      child: IgnorePointer(
        child: CustomPaint(
          size: Size.infinite,
          painter: _BurstPainter(
            controller: controller,
            count: widget.count,
            seed: widget.seed,
          ),
        ),
      ),
    );
  }
}

class _BurstPainter extends CustomPainter {
  _BurstPainter({
    required this.controller,
    required this.count,
    required this.seed,
  }) : super(repaint: controller);

  final AnimationController controller;
  final int count;
  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final elapsedMs = controller.value * _fieldSpan.inMilliseconds;
    final center = size.center(Offset.zero);
    final rnd = math.Random(seed);
    for (var i = 0; i < count; i++) {
      final jitter = (rnd.nextDouble() - 0.5) * 0.3;
      final angle = i * (2 * math.pi / count) + jitter;
      final delayMs = (i % 3) * 40;
      final rect = i % 3 == 1;
      final color =
          BirdyQuizColors.sparkColors[i % BirdyQuizColors.sparkColors.length];
      final t = ((elapsedMs - delayMs) / QuizStarBurstField.duration.inMilliseconds)
          .clamp(0.0, 1.0);
      const stops = [0.0, 0.2, 1.0];
      double at(List<double> v) {
        for (var s = 1; s < stops.length; s++) {
          if (t <= stops[s]) {
            final local = (t - stops[s - 1]) / (stops[s] - stops[s - 1]);
            return v[s - 1] + (v[s] - v[s - 1]) * local.clamp(0.0, 1.0);
          }
        }
        return v.last;
      }

      final dist = at([0, 70, 110]);
      final opacity = at([0, 1, 0]).clamp(0.0, 1.0);
      if (opacity <= 0) continue;
      final pos = center + Offset(math.cos(angle), math.sin(angle)) * dist;
      final paint = Paint()..color = color.withValues(alpha: opacity);
      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      canvas.rotate(angle);
      final w = rect ? 10.0 : 7.0;
      final h = rect ? 4.0 : 7.0;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: w, height: h),
          Radius.circular(rect ? 2 : h / 2),
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _BurstPainter oldDelegate) => true;
}
