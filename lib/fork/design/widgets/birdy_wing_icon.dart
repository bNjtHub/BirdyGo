/// The logo's wing as an icon (J6h): the four bars of
/// [BirdyGoLogoPainter.bars] in their own colors, round caps, a soft shadow,
/// no outline. Used on « Écouter », « Commencer à écouter » and the quiz's
/// question mark.
library;

import 'package:flutter/widgets.dart';

import '../../home/birdygo_logo.dart';
import '../birdy_tokens.dart';

class BirdyWingIcon extends StatelessWidget {
  const BirdyWingIcon({super.key, this.size = 28});

  /// Side of the square box the wing fills.
  final double size;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: CustomPaint(size: Size.square(size), painter: const _WingPainter()),
  );
}

class _WingPainter extends CustomPainter {
  const _WingPainter();

  /// Stroke of a bar, in the logo's 512 box (same as the logo painter).
  static const double _stroke = 30;

  /// Blur sigma of the wing's soft shadow (CSS blur 2 px is sigma 1), and
  /// its vertical offset, both in logical pixels.
  static const double _shadowSigma = 1;
  static const double _shadowDy = 0.1;

  /// Bounds of the bars including their round caps, in the logo's box.
  static final Rect _bounds = () {
    Rect? rect;
    for (final (from, to, _) in BirdyGoLogoPainter.bars) {
      final bar = Rect.fromPoints(from, to);
      rect = rect == null ? bar : rect.expandToInclude(bar);
    }
    return rect!.inflate(_stroke / 2);
  }();

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.shortestSide / _bounds.longestSide;
    canvas
      ..save()
      ..translate(size.width / 2, size.height / 2)
      ..scale(scale)
      ..translate(-_bounds.center.dx, -_bounds.center.dy);
    final shadow =
        Paint()
          ..color = BirdyBrand.wingShadow
          ..strokeWidth = _stroke
          ..strokeCap = StrokeCap.round
          ..maskFilter = MaskFilter.blur(
            BlurStyle.normal,
            _shadowSigma / scale,
          );
    final dy = _shadowDy / scale;
    for (final (from, to, _) in BirdyGoLogoPainter.bars) {
      canvas.drawLine(from.translate(0, dy), to.translate(0, dy), shadow);
    }
    for (final (from, to, color) in BirdyGoLogoPainter.bars) {
      canvas.drawLine(
        from,
        to,
        Paint()
          ..color = color
          ..strokeWidth = _stroke
          ..strokeCap = StrokeCap.round,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_WingPainter old) => false;
}
