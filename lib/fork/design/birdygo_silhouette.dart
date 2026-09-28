/// The BirdyGo bird as one filled shape (fork/DESIGN.md): tail, body and
/// beak joined, the eye cut out. Centered on the origin, its longest side
/// is 1. Recorded once from [BirdyGoLogoPainter]'s paths, so the map's
/// place markers (J6f) and a mystery species card's placeholder (J6f-b)
/// draw the exact same outline, just in different colors.
library;

import 'package:flutter/widgets.dart';

import '../home/birdygo_logo.dart';

/// The BirdyGo bird as one filled shape: tail, body and beak joined, the
/// eye cut out. Centered on the origin, its longest side is 1.
final Path birdyGoSilhouette = _unit(_outline(withEye: false));

/// Bounds of the whole bird (beak to tail, eye included) in the logo's
/// 512 box, before [_unit] centers and scales it: the map's place markers
/// use this to center [BirdyGoLogoPainter]'s own picture the same way.
final Rect birdyGoLogoBounds = _outline(withEye: true).getBounds();

/// Center of the logo's wing (the middle of its bars) in
/// [birdyGoSilhouette]'s unit space: the visual middle of the body, where a
/// mark drawn on the bird (the quiz's question mark) sits.
final Offset birdyGoWingCenter = () {
  final bounds = _outline(withEye: false).getBounds();
  var sum = Offset.zero;
  for (final (bottom, top, _) in BirdyGoLogoPainter.bars) {
    sum += (bottom + top) / 2;
  }
  final wing = sum / BirdyGoLogoPainter.bars.length.toDouble();
  return (wing - bounds.center) / bounds.longestSide;
}();

Path _outline({required bool withEye}) {
  var shape = Path.combine(
    PathOperation.union,
    BirdyGoLogoPainter.body,
    BirdyGoLogoPainter.tail,
  );
  shape = Path.combine(
    PathOperation.union,
    shape,
    BirdyGoLogoPainter.upperBeak,
  );
  shape = Path.combine(
    PathOperation.union,
    shape,
    BirdyGoLogoPainter.lowerBeak,
  );
  if (withEye) return shape;
  return Path.combine(
    PathOperation.difference,
    shape,
    Path()..addOval(
      Rect.fromCircle(
        center: BirdyGoLogoPainter.eyeCenter,
        radius: BirdyGoLogoPainter.eyeRadius,
      ),
    ),
  );
}

Path _unit(Path shape) {
  final bounds = shape.getBounds();
  final scale = 1 / bounds.longestSide;
  return shape.transform(
    (Matrix4.identity()
          ..scaleByDouble(scale, scale, 1, 1)
          ..translateByDouble(-bounds.center.dx, -bounds.center.dy, 0, 1))
        .storage,
  );
}

/// [birdyGoSilhouette] filled with one flat [color], drawn at [size] (its
/// longest side): the mystery card's placeholder, in place of a generic
/// species icon, so it reads as the BirdyGo bird rather than any bird.
class BirdyGoSilhouetteIcon extends StatelessWidget {
  const BirdyGoSilhouetteIcon({
    super.key,
    required this.size,
    required this.color,
  });

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size.square(size),
    painter: _BirdyGoSilhouettePainter(color),
  );
}

class _BirdyGoSilhouettePainter extends CustomPainter {
  _BirdyGoSilhouettePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas
      ..save()
      ..translate(size.width / 2, size.height / 2)
      ..scale(size.shortestSide)
      ..drawPath(birdyGoSilhouette, Paint()..color = color)
      ..restore();
  }

  @override
  bool shouldRepaint(_BirdyGoSilhouettePainter old) => old.color != color;
}
