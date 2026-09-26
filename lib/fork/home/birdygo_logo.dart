/// The BirdyGo mark (fork/brand/birdygo-logo-static.svg) drawn in Flutter,
/// so the home screen can animate it without an SVG package (J6c).
///
/// On arrival the four wing bars, a spectrogram, draw upward one after the
/// other; the bird itself does not move (fork/DESIGN.md: one effect at a
/// time, 500 ms at most). With reduced motion the mark is drawn at once.
library;

import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../design/birdy_motion.dart';
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
      painter: BirdyGoLogoPainter(progress: _controller),
    ),
  );
}

/// Paints the mark in a square. [progress] (0 → 1) draws the wing bars.
class BirdyGoLogoPainter extends CustomPainter {
  BirdyGoLogoPainter({required this.progress}) : super(repaint: progress);

  final Animation<double> progress;

  /// Source view box of the SVG.
  static const double _box = 512;

  static const Color _plumageTop = Color(0xFF1CAEBA);
  static const Color _plumageBottom = Color(0xFF0E7C86);
  static const Color _lowerBeak = Color(0xFFE3A22B);
  static const Color _paleKingfisher = Color(0xFF8CD3D9);

  /// Wing bars, bottom point first (the SVG draws them upward).
  static const List<(Offset, Offset, Color)> _bars = [
    (Offset(217.4, 333.7), Offset(217.4, 240.1), BirdyBrand.mist),
    (Offset(260.6, 365.5), Offset(268, 223.3), BirdyBrand.oriole),
    (Offset(306.2, 349.4), Offset(316, 256.2), BirdyBrand.mist),
    (Offset(352.9, 331.7), Offset(359.3, 290.9), _paleKingfisher),
  ];

  /// Each bar draws over this share of [progress], starting in turn.
  static const double _barShare = 0.75;

  static final Path _tail =
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

  static final Path _body =
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

  static final Path _upperBeak =
      Path()
        ..moveTo(145.9, 149)
        ..lineTo(50.6, 160.9)
        ..lineTo(118.1, 196.6)
        ..close();

  static final Path _lowerBeakPath =
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
            const [_plumageTop, _plumageBottom],
          );
    canvas.drawPath(_tail, plumage);

    for (final (path, color) in [
      (_lowerBeakPath, _lowerBeak),
      (_upperBeak, BirdyBrand.oriole),
    ]) {
      canvas
        ..drawPath(path, Paint()..color = color)
        ..drawPath(
          path,
          Paint()
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeWidth = 12
            ..strokeJoin = StrokeJoin.round,
        );
    }

    canvas.drawPath(_body, plumage);

    final t = progress.value;
    final step = (1 - _barShare) / (_bars.length - 1);
    for (final (i, (from, to, color)) in _bars.indexed) {
      final local = ((t - i * step) / _barShare).clamp(0.0, 1.0);
      if (local == 0) continue;
      final eased = BirdyMotion.standard.transform(local);
      canvas.drawLine(
        from,
        Offset.lerp(from, to, eased)!,
        Paint()
          ..color = color
          ..strokeWidth = 30
          ..strokeCap = StrokeCap.round,
      );
    }

    canvas
      ..drawCircle(
        const Offset(176.2, 172.6),
        18.7,
        Paint()..color = BirdyBrand.ink,
      )
      ..drawCircle(
        const Offset(171, 166.6),
        5.4,
        Paint()..color = const Color(0xFFFFFFFF),
      )
      ..restore();
  }

  @override
  bool shouldRepaint(BirdyGoLogoPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
