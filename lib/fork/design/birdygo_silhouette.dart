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

/// Where a point of the logo's 512 box lands in [birdyGoSilhouette]'s unit
/// space, and the scale between the two: the wing bars ride the same
/// transform as the outline, so they sit exactly as in the full logo.
final Rect _eyeLessBounds = _outline(withEye: false).getBounds();
Offset _toUnit(Offset p) =>
    (p - _eyeLessBounds.center) / _eyeLessBounds.longestSide;
final double _unitScale = 1 / _eyeLessBounds.longestSide;

/// The silhouette with the eye at [closed] (0 → 1): the eye's hole squashed
/// into a curved line. Only the last value is kept: an animation asks for a
/// new one each frame, a still icon never gets here.
final Path _filledOutline = _outline(withEye: true);
double? _cachedClosed;
Path? _cachedClosedPath;
Path _silhouetteWithEye(double closed) {
  if (closed <= 0) return birdyGoSilhouette;
  if (_cachedClosed != closed) {
    _cachedClosed = closed;
    _cachedClosedPath = _unit(
      Path.combine(
        PathOperation.difference,
        _filledOutline,
        BirdyGoLogoPainter.eyePath(closed),
      ),
    );
  }
  return _cachedClosedPath!;
}

/// [birdyGoSilhouette] filled with one flat [color], drawn at [size] (its
/// longest side): the mystery card's placeholder, in place of a generic
/// species icon, so it reads as the BirdyGo bird rather than any bird.
///
/// The wing (the logo's four bars, same place, stroke and round caps) is
/// drawn by default, in the logo's own colors. A [muted] bird (a species
/// still to find, a translucent or grey mark) gets bars in a lighter tone
/// of [color] instead, so it stays discreet. [wing] false draws the plain
/// shape. [eyeClosed] (0 → 1) squashes the eye's hole into a curved line.
class BirdyGoSilhouetteIcon extends StatelessWidget {
  const BirdyGoSilhouetteIcon({
    super.key,
    required this.size,
    required this.color,
    this.muted = false,
    this.wing = true,
    this.eyeClosed = 0,
  });

  final double size;
  final Color color;
  final bool muted;
  final bool wing;
  final double eyeClosed;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size.square(size),
    painter: BirdyGoSilhouettePainter(
      color,
      muted: muted,
      wing: wing,
      eyeClosed: eyeClosed,
    ),
  );
}

class BirdyGoSilhouettePainter extends CustomPainter {
  BirdyGoSilhouettePainter(
    this.color, {
    this.muted = false,
    this.wing = true,
    this.eyeClosed = 0,
  });

  final Color color;
  final bool muted;
  final bool wing;
  final double eyeClosed;

  /// A muted bird's bars: the body color this far towards white.
  static const double mutedWingLighten = 0.55;

  /// Stroke of a bar in the logo's 512 box (as in [BirdyGoLogoPainter]).
  static const double _barStroke = 30;

  /// The bar colors this painter draws, in order.
  List<Color> get barColors => [
    for (final (_, _, original) in BirdyGoLogoPainter.bars)
      muted
          ? Color.lerp(color, const Color(0xFFFFFFFF), mutedWingLighten)!
          : original,
  ];

  @override
  void paint(Canvas canvas, Size size) {
    canvas
      ..save()
      ..translate(size.width / 2, size.height / 2)
      ..scale(size.shortestSide)
      ..drawPath(_silhouetteWithEye(eyeClosed), Paint()..color = color);
    if (wing) {
      final colors = barColors;
      for (final (i, (from, to, _)) in BirdyGoLogoPainter.bars.indexed) {
        canvas.drawLine(
          _toUnit(from),
          _toUnit(to),
          Paint()
            ..color = colors[i]
            ..strokeWidth = _barStroke * _unitScale
            ..strokeCap = StrokeCap.round,
        );
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(BirdyGoSilhouettePainter old) =>
      old.color != color ||
      old.muted != muted ||
      old.wing != wing ||
      old.eyeClosed != eyeClosed;
}
