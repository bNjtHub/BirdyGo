/// The home logo's double-tap easter egg (J6f): the BirdyGo bird takes off
/// from [SingingLogo], loops over the screen, and lands back in its place.
/// An explicit, user-triggered exception to DESIGN.md's 500 ms celebration
/// cap and single-effect rule (see DESIGN.md, section Logo) — nobody sees
/// it without asking for it twice, and it never repeats on its own.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../design/birdy_motion.dart';
import 'birdygo_logo.dart';

/// Position and facing of the flying bird at [t] (0 → 1), relative to
/// [origin] (its resting place) and the [screen] size the excursion scales
/// to. Three legs meet exactly at [_peak], so the path has no seam: up and
/// across the screen, a full loop, then back down to [origin]. A gentle
/// bob (within [BirdyMotion.maxOffset]) rides on top throughout.
@immutable
class LogoFlightPath {
  const LogoFlightPath({required this.origin, required this.screen});

  final Offset origin;
  final Size screen;

  /// End of the outbound leg / start of the loop.
  static const double outEnd = 0.4;

  /// End of the loop / start of the inbound leg.
  static const double loopEnd = 0.75;

  static const double _bobCycles = 9;

  /// The far point the bird loops around: up and across from [origin].
  Offset get _peak =>
      origin + Offset(screen.width * 0.5, -screen.height * 0.32);

  double get _loopRadius => math.min(screen.width, screen.height) * 0.1;

  static Offset _bezier(Offset p0, Offset p1, Offset p2, Offset p3, double s) {
    final mt = 1 - s;
    return p0 * (mt * mt * mt) +
        p1 * (3 * mt * mt * s) +
        p2 * (3 * mt * s * s) +
        p3 * (s * s * s);
  }

  /// Raw path position (no bob): used both for [offsetAt] and, by finite
  /// difference, for [facingRightAt].
  Offset _rawAt(double t) {
    final peak = _peak;
    if (t <= outEnd) {
      final s = t / outEnd;
      return _bezier(
        origin,
        origin + Offset(screen.width * 0.08, -screen.height * 0.3),
        peak + Offset(-screen.width * 0.18, screen.height * 0.08),
        peak,
        s,
      );
    }
    if (t <= loopEnd) {
      final s = (t - outEnd) / (loopEnd - outEnd);
      final radius = _loopRadius;
      final center = peak + Offset(0, -radius);
      final angle0 = math.atan2(peak.dy - center.dy, peak.dx - center.dx);
      final angle = angle0 - s * 2 * math.pi;
      return center + Offset(math.cos(angle), math.sin(angle)) * radius;
    }
    final s = (t - loopEnd) / (1 - loopEnd);
    return _bezier(
      peak,
      peak + Offset(screen.width * 0.05, screen.height * 0.06),
      origin + Offset(-screen.width * 0.1, -screen.height * 0.22),
      origin,
      s,
    );
  }

  /// The bird's on-screen position at [t] (0 → 1), bob included.
  Offset offsetAt(double t) =>
      _rawAt(t) +
      Offset(0, math.sin(t * _bobCycles * 2 * math.pi) * BirdyMotion.maxOffset);

  /// Whether the bird faces right (not mirrored) at [t], from the path's
  /// horizontal direction of travel there.
  bool facingRightAt(double t) {
    const dt = 0.01;
    final a = _rawAt(math.max(0, t - dt));
    final b = _rawAt(math.min(1, t + dt));
    return b.dx >= a.dx;
  }
}

/// Draws [BirdyGoLogoPainter] flying along [path] as [animation] runs from
/// 0 to 1: one controller drives both the position (through [path]) and the
/// wing bars' flap (through [_WingFlap], so they animate their length
/// instead of just drawing once). Meant to be an [OverlayEntry]'s builder
/// result directly, hence the [Positioned] as the outer widget (an
/// [Overlay] places each entry straight into its own [Stack]); the flying
/// bird ignores touches, but that has to sit *inside* the [Positioned].
class LogoFlightBird extends StatelessWidget {
  const LogoFlightBird({
    super.key,
    required this.animation,
    required this.path,
    required this.size,
  });

  final Animation<double> animation;
  final LogoFlightPath path;
  final double size;

  /// Wing beats over the whole flight.
  static const int wingFlapCycles = 6;

  /// The bars never fully retract between beats.
  static const double _wingFlapFloor = 0.35;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final t = animation.value;
        final pos = path.offsetAt(t);
        final facingRight = path.facingRightAt(t);
        return Positioned(
          left: pos.dx - size / 2,
          top: pos.dy - size / 2,
          width: size,
          height: size,
          child: IgnorePointer(
            child: Transform(
              alignment: Alignment.center,
              transform:
                  Matrix4.identity()
                    ..scaleByDouble(facingRight ? 1.0 : -1.0, 1.0, 1.0, 1.0),
              child: RepaintBoundary(
                child: CustomPaint(
                  size: Size.square(size),
                  painter: BirdyGoLogoPainter(
                    progress: animation.drive(const _WingFlap()),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Remaps the flight's 0 → 1 into a repeating triangle wave between
/// [LogoFlightBird._wingFlapFloor] and 1, so the wing bars flap instead of
/// only drawing once.
class _WingFlap extends Animatable<double> {
  const _WingFlap();

  @override
  double transform(double t) {
    final phase = (t * LogoFlightBird.wingFlapCycles) % 1.0;
    final triangle = 1 - (2 * phase - 1).abs();
    const floor = LogoFlightBird._wingFlapFloor;
    return floor + (1 - floor) * triangle;
  }
}
