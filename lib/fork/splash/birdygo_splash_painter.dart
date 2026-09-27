import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../design/birdy_tokens.dart';
import '../home/birdygo_logo.dart';

/// Keeps the exact brand paths and colors, framed like the supplied SVG.
class BirdyGoSplashPainter extends CustomPainter {
  BirdyGoSplashPainter({required this.progress, this.reducedMotion = false})
    : super(repaint: progress);

  final Animation<double> progress;
  final bool reducedMotion;

  static final _bird = BirdyGoLogoPainter(
    progress: const AlwaysStoppedAnimation(1),
  );

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 530, size.height / 368);
    canvas.translate(52, -72);
    _bird.paint(canvas, const Size.square(512));

    // Three notes leave the beak in sequence. Each follows its own small arc;
    // their staggered fades end before the introduction completes.
    for (var i = 0; i < 3; i++) {
      final t = ((progress.value - .1583 - i * .125) / .5).clamp(0.0, 1.0);
      if (reducedMotion || t <= 0 || t >= 1) continue;
      final fadeIn = Curves.easeOut.transform((t / .18).clamp(0.0, 1.0));
      final fadeOut =
          1 - Curves.easeInOut.transform(((t - .48) / .52).clamp(0.0, 1.0));
      final paint =
          Paint()
            ..color = BirdyBrand.kingfisher.withValues(
              alpha: fadeIn * fadeOut * .9,
            );
      final eased = Curves.easeOut.transform(t);
      canvas.save();
      canvas.translate(
        22 - i * 23 - 15 * eased + math.sin(t * math.pi * 2) * 3,
        176 + i * 21 - (46 + i * 10) * eased,
      );
      canvas.rotate(-.12 + math.sin(t * math.pi) * .16);
      canvas.scale(1 - i * .08);
      canvas.drawOval(const Rect.fromLTWH(-8, 10, 15, 10), paint);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(3, -14, 4, 30),
          const Radius.circular(2),
        ),
        paint,
      );
      canvas.drawPath(
        Path()
          ..moveTo(6, -14)
          ..cubicTo(9, -8, 22, -6, 14, 5)
          ..cubicTo(17, -4, 8, -3, 6, -5)
          ..close(),
        paint,
      );
      canvas.restore();
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(BirdyGoSplashPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.reducedMotion != reducedMotion;
}

/// An activity sweep, never a made-up percentage of bootstrap completion.
/// It settles to a quiet track if initialization outlasts the introduction.
class BirdyGoLoadingPainter extends CustomPainter {
  BirdyGoLoadingPainter({required this.progress}) : super(repaint: progress);

  final Animation<double> progress;

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(2),
    );
    canvas.drawRRect(
      bounds,
      Paint()..color = BirdyBrand.ink.withValues(alpha: .1),
    );
    final t = progress.value;
    if (t <= 0 || t >= 1) return;
    final x = (t * 1.4 - .4) * size.width;
    canvas.save();
    canvas.clipRRect(bounds);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x, 0, size.width * .4, size.height),
        const Radius.circular(2),
      ),
      Paint()..color = BirdyBrand.kingfisher,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(BirdyGoLoadingPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
