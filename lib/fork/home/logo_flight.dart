/// The home logo's double-tap easter egg (J6h): the BirdyGo bird takes off
/// from [SingingLogo], flies to the middle of the screen, grows, tilts its
/// head and winks (with the BirdyGo tweet), then flies off one side and
/// comes back to its place in the header. For children: nobody sees it
/// without asking for it twice, and it never repeats on its own. An explicit,
/// user-triggered exception to DESIGN.md's 500 ms celebration cap and
/// single-effect rule (see DESIGN.md, section Logo).
///
/// One controller drives everything: [LogoWinkTimeline] turns its 0 → 1
/// into position, size, facing, tilt, eye and wing, leg by leg (the legs and
/// every duration are [BirdyMotion] tokens).
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../design/birdy_motion.dart';
import '../splash/birdygo_splash_painter.dart';
import 'birdygo_logo.dart';

/// Everything the winking bird does at [t] (0 → 1), for the header mark
/// centered on [origin] and a [screen] of that size (overlay coordinates).
/// [farMargin] is how far past the screen's edge the bird's center goes to
/// be fully out of sight. With [reduced], the bird stays in place and only
/// winks, over the whole run.
@immutable
class LogoWinkTimeline {
  const LogoWinkTimeline({
    required this.origin,
    required this.screen,
    this.farMargin = 0,
    this.reduced = false,
  });

  final Offset origin;
  final Size screen;
  final double farMargin;
  final bool reduced;

  /// Share of a leg the bird spends turning around.
  static const double _turnShare = 0.35;

  static const double _takeoff = BirdyMotion.logoWinkTakeoffEnd;
  static const double _hover = BirdyMotion.logoWinkHoverEnd;
  static const double _exit = BirdyMotion.logoWinkExitEnd;

  /// Length of the wing's blend between beating and resting.
  static const double _wingRamp = 0.04;

  Offset get _center => screen.center(Offset.zero);

  Offset get _farStart =>
      Offset(screen.width + farMargin, origin.dy + screen.height * 0.08);

  Offset get _farEnd =>
      Offset(screen.width + farMargin, _center.dy - screen.height * 0.22);

  static double _leg(double t, double from, double to, Curve curve) =>
      Interval(from, to, curve: curve).transform(t);

  static Offset _bezier(Offset p0, Offset p1, Offset p2, Offset p3, double s) {
    final mt = 1 - s;
    return p0 * (mt * mt * mt) +
        p1 * (3 * mt * mt * s) +
        p2 * (3 * mt * s * s) +
        p3 * (s * s * s);
  }

  static double _lerp(double a, double b, double t) => a + (b - a) * t;

  static double _smooth(double x) {
    final v = x.clamp(0.0, 1.0);
    return v * v * (3 - 2 * v);
  }

  /// Center of the bird on screen.
  Offset offsetAt(double t) {
    if (reduced) return origin;
    final w = screen.width;
    final h = screen.height;
    if (t <= _takeoff) {
      final s = _leg(t, 0, _takeoff, BirdyMotion.move);
      return _bezier(
        origin,
        origin + Offset(w * 0.05, h * 0.22),
        _center + Offset(-w * 0.25, -h * 0.12),
        _center,
        s,
      );
    }
    if (t <= _hover) {
      final phase = (t - _takeoff) / (_hover - _takeoff);
      return _center +
          Offset(
            0,
            math.sin(phase * BirdyMotion.logoWinkBobCycles * 2 * math.pi) *
                BirdyMotion.logoWinkBob,
          );
    }
    if (t <= _exit) {
      final s = _leg(t, _hover, _exit, BirdyMotion.move);
      return _bezier(
        _center,
        _center + Offset(w * 0.1, -h * 0.12),
        _farEnd + Offset(-w * 0.3, 0),
        _farEnd,
        s,
      );
    }
    final s = _leg(t, _exit, 1, BirdyMotion.standard);
    return _bezier(
      _farStart,
      _farStart + Offset(-w * 0.3, h * 0.1),
      origin + Offset(w * 0.25, h * 0.12),
      origin,
      s,
    );
  }

  /// Size of the bird as a multiple of the header mark.
  double scaleAt(double t) {
    if (reduced) return 1;
    if (t <= _takeoff) {
      return _lerp(
        1,
        BirdyMotion.logoWinkScale,
        _leg(t, 0, _takeoff, BirdyMotion.move),
      );
    }
    if (t <= _hover) return BirdyMotion.logoWinkScale;
    if (t <= _exit) {
      return _lerp(
        BirdyMotion.logoWinkScale,
        BirdyMotion.logoWinkFarScale,
        _leg(t, _hover, _exit, BirdyMotion.move),
      );
    }
    return _lerp(
      BirdyMotion.logoWinkFarScale,
      1,
      _leg(t, _exit, 1, BirdyMotion.standard),
    );
  }

  /// Horizontal scale of the drawing: 1 faces left (the mark's own way), -1
  /// faces right; in between the bird is turning.
  double facingAt(double t) {
    if (reduced) return 1;
    if (t <= _takeoff) {
      // Flying right, then turning to face the child as it arrives.
      final s = (t / _takeoff - (1 - _turnShare * 2)) / (_turnShare * 2);
      return _lerp(-1, 1, _smooth(s));
    }
    if (t <= _hover) return 1;
    if (t <= _exit) {
      // Turning right to leave, flying right.
      final s = ((t - _hover) / (_exit - _hover)) / _turnShare;
      return _lerp(1, -1, _smooth(s));
    }
    // Coming back from the right edge: flying left, facing left.
    return 1;
  }

  /// Head tilt in radians, only while hovering.
  double tiltAt(double t) {
    if (reduced || t <= _takeoff || t >= _hover) return 0;
    final phase = (t - _takeoff) / (_hover - _takeoff);
    return math.sin(phase * math.pi) *
        BirdyMotion.logoWinkTiltDegrees *
        math.pi /
        180;
  }

  /// 0 (open) → 1 (closed) → 0: one wink.
  double eyeClosedAt(double t) {
    final from = reduced ? 0.0 : BirdyMotion.logoWinkEyeStart;
    final to = reduced ? 1.0 : BirdyMotion.logoWinkEyeEnd;
    if (t <= from || t >= to) return 0;
    final p = (t - from) / (to - from);
    return BirdyMotion.standard.transform(1 - (2 * p - 1).abs());
  }

  /// Beak opening (0 → 1) while singing: one open-and-close per syllable,
  /// like the header mark's. Reduced motion: never.
  double mouthAt(double t) {
    if (reduced) return 0;
    var open = 0.0;
    for (var i = 0; i < BirdyMotion.logoWinkSyllables; i++) {
      final u =
          (t - _takeoff - i * BirdyMotion.logoWinkSyllable) /
          BirdyMotion.logoWinkSyllableLength;
      if (u > 0 && u < 1) open = math.max(open, math.sin(math.pi * u));
    }
    return open;
  }

  /// Age (0 → 1) of syllable [i]'s note at [t], or null while it is not in
  /// flight. Reduced motion: never.
  double? noteAt(double t, int i) {
    if (reduced) return null;
    final age =
        t -
        _takeoff -
        i * BirdyMotion.logoWinkSyllable -
        BirdyMotion.logoWinkNoteDelay;
    if (age < 0 || age >= BirdyMotion.logoWinkNoteLife) return null;
    return age / BirdyMotion.logoWinkNoteLife;
  }

  /// Wing bars length (0 → 1): they beat while flying and rest, spread,
  /// while hovering.
  double wingAt(double t) {
    if (reduced) return 1;
    final phase = (t * BirdyMotion.logoWinkFlapCycles) % 1.0;
    final wave =
        BirdyMotion.logoWinkFlapFloor +
        (1 - BirdyMotion.logoWinkFlapFloor) * (1 - (2 * phase - 1).abs());
    final resting =
        _smooth((t - _takeoff) / _wingRamp) *
        (1 - _smooth((t - _hover) / _wingRamp));
    return _lerp(wave, 1, resting);
  }
}

/// Draws [BirdyGoLogoPainter] along [timeline] as [animation] runs from 0 to
/// 1. [size] is the side of the painter's 512 box (the header mark's scale
/// times 512); [pivot] is the mark's center in that box, the point that sits
/// on the timeline's position. Meant to be an [OverlayEntry]'s builder
/// result directly; the bird ignores touches. Only the transform and the
/// painter follow the animation: the picture itself is built once, in its
/// own [RepaintBoundary].
class LogoWinkBird extends StatelessWidget {
  const LogoWinkBird({
    super.key,
    required this.animation,
    required this.timeline,
    required this.size,
    required this.pivot,
  });

  final Animation<double> animation;
  final LogoWinkTimeline timeline;
  final double size;
  final Offset pivot;

  @override
  Widget build(BuildContext context) {
    final picture = RepaintBoundary(
      child: CustomPaint(
        size: Size.square(size),
        painter: BirdyGoLogoPainter(
          progress: animation.drive(_Curve(timeline.wingAt)),
          eyeClosed: animation.drive(_Curve(timeline.eyeClosedAt)),
          mouth: animation.drive(_Curve(timeline.mouthAt)),
        ),
      ),
    );
    return Positioned.fill(
      child: IgnorePointer(
        child: Align(
          alignment: Alignment.topLeft,
          child: AnimatedBuilder(
            animation: animation,
            child: SizedBox.square(
              dimension: size,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  picture,
                  if (!timeline.reduced)
                    RepaintBoundary(
                      child: CustomPaint(
                        size: Size.square(size),
                        painter: LogoNotesPainter(
                          animation: animation,
                          timeline: timeline,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            builder: (context, child) {
              final t = animation.value;
              final pos = timeline.offsetAt(t);
              final scale = timeline.scaleAt(t);
              return Transform(
                transform:
                    Matrix4.identity()
                      ..translateByDouble(pos.dx, pos.dy, 0, 1)
                      ..rotateZ(timeline.tiltAt(t))
                      ..scaleByDouble(timeline.facingAt(t) * scale, scale, 1, 1)
                      ..translateByDouble(-pivot.dx, -pivot.dy, 0, 1),
                child: child,
              );
            },
          ),
        ),
      ),
    );
  }
}

/// The notes of the song, the header mark's own glyphs and colors
/// ([BirdyGoSingingPainter.paintNote]) in the bird's 512 box, so they follow
/// its position and size. Paints nothing outside the song.
class LogoNotesPainter extends CustomPainter {
  LogoNotesPainter({required this.animation, required this.timeline})
    : super(repaint: animation);

  final Animation<double> animation;
  final LogoWinkTimeline timeline;

  @override
  void paint(Canvas canvas, Size size) {
    final t = animation.value;
    if (t < BirdyMotion.logoWinkTakeoffEnd ||
        t > BirdyMotion.logoWinkHoverEnd) {
      return;
    }
    canvas
      ..save()
      ..scale(size.shortestSide / 512);
    for (var i = 0; i < BirdyMotion.logoWinkSyllables; i++) {
      final u = timeline.noteAt(t, i);
      if (u == null) continue;
      BirdyGoSingingPainter.paintNote(
        canvas,
        i,
        u,
        reach: BirdyMotion.logoWinkNoteReach,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(LogoNotesPainter oldDelegate) =>
      oldDelegate.animation != animation || oldDelegate.timeline != timeline;
}

class _Curve extends Animatable<double> {
  const _Curve(this.fn);

  final double Function(double) fn;

  @override
  double transform(double t) => fn(t);
}
