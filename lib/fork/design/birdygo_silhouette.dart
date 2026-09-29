/// The BirdyGo bird as one filled shape (fork/DESIGN.md): tail, body and
/// beak joined, the eye cut out. Centered on the origin, its longest side
/// is 1. Recorded once from [BirdyGoLogoPainter]'s paths, so the map's
/// place markers (J6f) and a mystery species card's placeholder (J6f-b)
/// draw the exact same outline, just in different colors.
library;

import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../home/birdygo_logo.dart';
import 'birdy_tokens.dart';
import 'birdy_typography.dart';

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

/// What a silhouette means (fork/DESIGN.md, "Oiseau générique"): one
/// meaning, one look, everywhere.
enum SilhouetteRole {
  /// An unknown bird to discover: grey body, no wing, a « ? » on the wing
  /// (the « ? » only from [BirdySizes.silhouetteMarkMin]).
  mystery,

  /// A known species with no photo: its deep tint, with the logo's wing
  /// (the wing only from [BirdySizes.silhouetteWingMin]).
  species,

  /// An icon: the plain shape in the surrounding icon color.
  glyph,
}

/// [birdyGoSilhouette] filled with one flat [color], drawn at [size] (its
/// longest side). Pick the look with the named constructors: [species],
/// [mystery] or [glyph] ([SilhouetteRole]). [eyeClosed] (0 → 1) squashes
/// the eye's hole into a curved line.
class BirdyGoSilhouetteIcon extends StatelessWidget {
  const BirdyGoSilhouetteIcon({
    super.key,
    required this.size,
    required this.color,
    required this.role,
    this.eyeClosed = 0,
  });

  /// A known species without photo: [color] is its deep tint.
  const BirdyGoSilhouetteIcon.species({
    Key? key,
    required double size,
    required Color color,
    double eyeClosed = 0,
  }) : this(
         key: key,
         size: size,
         color: color,
         role: SilhouetteRole.species,
         eyeClosed: eyeClosed,
       );

  /// An unknown bird to discover: [color] is a grey.
  const BirdyGoSilhouetteIcon.mystery({
    Key? key,
    required double size,
    required Color color,
    double eyeClosed = 0,
  }) : this(
         key: key,
         size: size,
         color: color,
         role: SilhouetteRole.mystery,
         eyeClosed: eyeClosed,
       );

  /// A plain icon: [color] is the text or icon color around it.
  const BirdyGoSilhouetteIcon.glyph({
    Key? key,
    required double size,
    required Color color,
    double eyeClosed = 0,
  }) : this(
         key: key,
         size: size,
         color: color,
         role: SilhouetteRole.glyph,
         eyeClosed: eyeClosed,
       );

  final double size;
  final Color color;
  final SilhouetteRole role;
  final double eyeClosed;

  /// Whether the logo's wing is drawn at this size and role.
  bool get showsWing =>
      role == SilhouetteRole.species && size >= BirdySizes.silhouetteWingMin;

  /// Whether the « ? » is drawn at this size and role.
  bool get showsMark =>
      role == SilhouetteRole.mystery && size >= BirdySizes.silhouetteMarkMin;

  @override
  Widget build(BuildContext context) {
    final shape = CustomPaint(
      size: Size.square(size),
      painter: BirdyGoSilhouettePainter(
        color,
        wing: showsWing,
        eyeClosed: eyeClosed,
      ),
    );
    if (!showsMark) return shape;
    return SizedBox.square(
      dimension: size,
      child: Stack(
        alignment: Alignment.center,
        children: [shape, BirdyMysteryMark(silhouette: size)],
      ),
    );
  }
}

/// The « ? » of a mystery bird: Fraunces bold, oriole, tilted, centered on
/// the wing of a [silhouette]-sized BirdyGo bird (so it reads as sitting on
/// the body). Scales with the silhouette. Put it in a stack over the
/// silhouette; [BirdyGoSilhouetteIcon.mystery] and the quiz do.
class BirdyMysteryMark extends StatelessWidget {
  const BirdyMysteryMark({super.key, required this.silhouette});

  /// Size of the silhouette this mark sits on.
  final double silhouette;

  /// The « ? » is [BirdySizes.quizMark] tall on a [_markRef] silhouette (the
  /// quiz intro's disc at full size); tilted like the mockup (degrees).
  static const double _markRef = 104;
  static const double _markTilt = -8;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Transform.translate(
      offset: birdyGoWingCenter * silhouette,
      child: Transform.rotate(
        angle: _markTilt * math.pi / 180,
        child: Text(
          '?',
          // J6i: the titles moved to Nunito, the « ? » stays in Fraunces.
          style: BirdyText.species.copyWith(
            fontSize: BirdySizes.quizMark * silhouette / _markRef,
            fontWeight: FontWeight.w700,
            fontVariations: const [
              FontVariation('SOFT', 100),
              FontVariation('opsz', 34),
            ],
            height: 1,
            color: BirdyBrand.oriole,
          ),
        ),
      ),
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
