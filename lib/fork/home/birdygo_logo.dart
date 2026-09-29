/// The BirdyGo mark (fork/brand/birdygo-logo-static.svg) drawn in Flutter,
/// so the home screen can animate it without an SVG package (J6c).
///
/// On arrival the four wing bars, a spectrogram, draw upward one after the
/// other; the bird itself does not move (fork/DESIGN.md: one effect at a
/// time, 500 ms at most). With reduced motion the mark is drawn at once.
///
/// The live header (`lib/fork/live/live_header.dart`) reuses the same
/// painter for its logo, past the arrival: while listening the bars idle in
/// a level-meter loop (`BirdyGoLogoPainter.level`), the fork's one exception
/// to "no loops" (fork/DESIGN.md, Animations).
library;

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../design/birdy_motion.dart';
import '../design/birdy_theme_choice.dart';
import '../design/birdy_tokens.dart';

class BirdyGoLogo extends StatefulWidget {
  const BirdyGoLogo({super.key, this.size = 32, this.animate = true});

  final double size;

  /// Draws the wing on arrival (once).
  final bool animate;

  /// Length of the whole wing animation.
  static const Duration duration = Duration(milliseconds: 480);

  @override
  State<BirdyGoLogo> createState() => _BirdyGoLogoState();
}

class _BirdyGoLogoState extends State<BirdyGoLogo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: BirdyGoLogo.duration,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller.isAnimating || _controller.isCompleted) return;
    if (widget.animate && !BirdyMotion.reduced(context)) {
      _controller.forward();
    } else {
      _controller.value = 1;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: CustomPaint(
      size: Size.square(widget.size),
      painter: BirdyGoLogoPainter(
        progress: _controller,
        brand: BirdyBrandColors.of(context),
      ),
    ),
  );
}

/// Paints the mark in a square. [progress] (0 → 1) draws the wing bars once
/// on arrival. Once it reaches 1, [level] (0 → 1, repeating) makes each bar
/// oscillate like a level meter, staggered, while the bird stays still (J6f,
/// live header). [frozenLevel] holds the bars at a fixed length instead
/// (paused). Neither is read while [progress] is still drawing the bars in.
class BirdyGoLogoPainter extends CustomPainter {
  BirdyGoLogoPainter({
    required this.progress,
    this.level,
    this.frozenLevel,
    this.eyeClosed,
    this.mouth,
    this.brand = const BirdyBrandColors(BirdyBird.loriot),
  }) : super(
         repaint: Listenable.merge([
           progress,
           if (level != null) level,
           if (eyeClosed != null) eyeClosed,
           if (mouth != null) mouth,
         ]),
       );

  final Animation<double> progress;
  final Animation<double>? level;
  final double? frozenLevel;

  /// 0 (open) → 1 (winking: the eye is a curved line): the home easter
  /// egg's wink (logo_flight.dart).
  final Animation<double>? eyeClosed;

  /// 0 (closed) → 1 (open): the beak's opening while the easter egg's bird
  /// sings, with the header singing mark's own angles.
  final Animation<double>? mouth;

  /// The bird theme's colors: plumage, beaks, wing bars 2 and 4 (J6i).
  /// Loriot (the original look) by default.
  final BirdyBrandColors brand;

  static const double lowerBeakOpenDegrees = -11;
  static const double upperBeakOpenDegrees = 13;

  /// Length a bar holds while paused (the oscillation's own shortest length
  /// is [BirdyMotion.listeningBarMin]): never fully gone.
  static const double pausedBarLevel = 0.55;

  /// Source view box of the SVG.
  static const double _box = 512;

  /// Wing bars in the Loriot colors, bottom point first (the SVG draws them
  /// upward). Bars 1 and 3 are Brume for every bird; use [barsFor] for the
  /// bird theme's bars 2 and 4.
  static const List<(Offset, Offset, Color)> bars = [
    (Offset(217.4, 333.7), Offset(217.4, 240.1), BirdyBrand.mist),
    (Offset(260.6, 365.5), Offset(268, 223.3), BirdyBrand.oriole),
    (Offset(306.2, 349.4), Offset(316, 256.2), BirdyBrand.mist),
    (Offset(352.9, 331.7), Offset(359.3, 290.9), BirdyBrand.wingSky),
  ];

  /// [bars] in [brand]'s colors: bar 2 = highlight, bar 4 = accentLight.
  static List<(Offset, Offset, Color)> barsFor(BirdyBrandColors brand) => [
    for (final (i, (from, to, color)) in bars.indexed)
      (
        from,
        to,
        switch (i) {
          1 => brand.highlight,
          3 => brand.accentLight,
          _ => color,
        },
      ),
  ];

  /// Each bar draws over this share of [progress], starting in turn.
  static const double _barShare = 0.75;

  static final Path tail =
      Path()
        ..moveTo(364.4, 181.4)
        ..arcToPoint(
          const Offset(397.4, 179.5),
          radius: const Radius.circular(24.4),
          clockwise: false,
        )
        ..lineTo(424, 152)
        ..arcToPoint(
          const Offset(458.5, 177.1),
          radius: const Radius.circular(21.5),
        )
        ..lineTo(425, 240.5)
        ..arcToPoint(
          const Offset(414.2, 285.3),
          radius: const Radius.circular(93.7),
          clockwise: false,
        )
        ..close();

  static final Path body =
      Path()
        ..moveTo(133.1, 251.5)
        ..arcToPoint(
          const Offset(280.7, 131.8),
          radius: const Radius.circular(95.6),
          largeArc: true,
        )
        ..arcToPoint(
          const Offset(312.3, 154.7),
          radius: const Radius.circular(54.3),
          clockwise: false,
        )
        ..arcToPoint(
          const Offset(141.2, 274.1),
          radius: const Radius.circular(136.8),
          largeArc: true,
        )
        ..arcToPoint(
          const Offset(133.1, 251.5),
          radius: const Radius.circular(28.1),
          clockwise: false,
        )
        ..close();

  /// The eye (ink disc), also cut out of the map's place silhouette.
  static const Offset eyeCenter = Offset(176.2, 172.6);
  static const double eyeRadius = 18.7;

  /// How far the closed eye's line sags below the eye's center, and its
  /// thickness at the middle, as shares of [eyeRadius].
  static const double _closedSag = 0.3;
  static const double _closedThickness = 0.5;

  /// The eye at [closed] (0 → 1) in the 512 box: the round eye, squashing
  /// into a thin curved line (a smiling closed eye) with the same width.
  /// Shared by the silhouette, which cuts it out.
  static Path eyePath(double closed) {
    final c = closed.clamp(0.0, 1.0);
    const r = eyeRadius;
    final top = _lerp(-r, r * _closedSag, c);
    final bottom = _lerp(r, r * (_closedSag + _closedThickness), c);
    // A cubic with both controls at 4/3 of the peak peaks at that height.
    const k = 4 / 3;
    final left = eyeCenter.dx - r;
    final right = eyeCenter.dx + r;
    final y = eyeCenter.dy;
    return Path()
      ..moveTo(left, y)
      ..cubicTo(left, y + k * top, right, y + k * top, right, y)
      ..cubicTo(right, y + k * bottom, left, y + k * bottom, left, y)
      ..close();
  }

  static double _lerp(double a, double b, double t) => a + (b - a) * t;

  /// The beak's hinge, where both halves turn to open.
  static const Offset beakHinge = Offset(118.1, 202.6);

  static final Path upperBeak =
      Path()
        ..moveTo(145.9, 149)
        ..lineTo(50.6, 160.9)
        ..lineTo(118.1, 196.6)
        ..close();

  static final Path lowerBeak =
      Path()
        ..moveTo(118.1, 206.6)
        ..lineTo(64.5, 222.5)
        ..lineTo(140, 240.3)
        ..close();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    final scale = size.shortestSide / _box;
    canvas.scale(scale);

    final plumage =
        Paint()
          ..shader = ui.Gradient.linear(
            const Offset(165, 97.7),
            const Offset(361.7, 434.9),
            [brand.accentHi, brand.accentDeep],
          );
    canvas.drawPath(tail, plumage);

    final open = mouth?.value ?? 0;
    for (final (path, color, degrees) in [
      (lowerBeak, brand.highlightDeep, lowerBeakOpenDegrees * open),
      (upperBeak, brand.highlight, upperBeakOpenDegrees * open),
    ]) {
      canvas.save();
      if (degrees != 0) {
        canvas
          ..translate(beakHinge.dx, beakHinge.dy)
          ..rotate(degrees * math.pi / 180)
          ..translate(-beakHinge.dx, -beakHinge.dy);
      }
      canvas
        ..drawPath(path, Paint()..color = color)
        ..drawPath(
          path,
          Paint()
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeWidth = 12
            ..strokeJoin = StrokeJoin.round,
        )
        ..restore();
    }

    canvas.drawPath(body, plumage);

    final t = progress.value;
    final step = (1 - _barShare) / (bars.length - 1);
    for (final (i, (from, to, color)) in barsFor(brand).indexed) {
      final local = ((t - i * step) / _barShare).clamp(0.0, 1.0);
      if (local == 0) continue;
      final double fraction;
      if (local < 1) {
        // Drawing in on arrival: unaffected by the live level meter.
        fraction = BirdyMotion.standard.transform(local);
      } else if (frozenLevel != null) {
        fraction = frozenLevel!;
      } else if (level != null) {
        // Staggered level meter: each bar a little behind the last.
        final phase =
            (level!.value - i * BirdyMotion.listeningBarStagger) % 1.0;
        final triangle = phase < 0.5 ? phase * 2 : (1 - phase) * 2;
        final eased = BirdyMotion.standard.transform(triangle);
        fraction =
            BirdyMotion.listeningBarMin +
            (1 - BirdyMotion.listeningBarMin) * eased;
      } else {
        fraction = 1;
      }
      canvas.drawLine(
        from,
        Offset.lerp(from, to, fraction)!,
        Paint()
          ..color = color
          ..strokeWidth = 30
          ..strokeCap = StrokeCap.round,
      );
    }

    final closed = eyeClosed?.value ?? 0;
    if (closed <= 0) {
      canvas.drawCircle(eyeCenter, eyeRadius, Paint()..color = BirdyBrand.ink);
    } else {
      canvas.drawPath(eyePath(closed), Paint()..color = BirdyBrand.ink);
    }
    // The glint fades out before the lid gets to it.
    final glint = (1 - closed * 2).clamp(0.0, 1.0);
    if (glint > 0) {
      canvas.drawCircle(
        const Offset(171, 166.6),
        5.4,
        Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: glint),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(BirdyGoLogoPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.level != level ||
      oldDelegate.frozenLevel != frozenLevel ||
      oldDelegate.eyeClosed != eyeClosed ||
      oldDelegate.mouth != mouth ||
      oldDelegate.brand != brand;
}
