import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../design/birdy_tokens.dart';
import '../home/birdygo_logo.dart';

/// Timeline of the startup screen, in milliseconds since it appeared
/// (Claude Design board « BirdyGo Splash »).
abstract final class BirdyGoSplashTimeline {
  /// When each text block starts to enter.
  static const double wordmark = 1000;
  static const double taglineFirst = 1250;
  static const double footer = 1350;
  static const double taglineSecond = 2150;

  /// Length of a text entrance.
  static const double textEnter = 320;

  /// Time constant of the loading bar catching up with the real progress.
  static const double barEase = 180;

  /// Quartic ease-out of the board, clamped to 0..1.
  static double easeOut(double v) =>
      1 - math.pow(1 - v.clamp(0.0, 1.0), 4).toDouble();
}

/// The BirdyGo mark singing: three syllables per phrase. On each one the beak
/// opens, the body swells, the wing bars pulse and a note leaves the beak.
///
/// [clock] is the time since the splash appeared, in milliseconds. With
/// [loop] off the bird sings one phrase only; [still] draws the settled mark
/// (reduced motion).
class BirdyGoSingingPainter extends CustomPainter {
  BirdyGoSingingPainter({
    required this.clock,
    this.loop = true,
    this.still = false,
  }) : super(repaint: clock);

  final ValueListenable<double> clock;
  final bool loop;
  final bool still;

  /// Source view box of the board: x -80, y 10, 570 × 450.
  static const Size viewBox = Size(570, 450);

  static const double _first = 800;
  static const double _period = 3600;
  static const double _syllable = 430;
  static const double _syllableLength = 380;
  static const double _noteLife = 1500;
  static const double _settled = 1e7;
  static const double _never = -1e9;

  static const Offset _beakHinge = Offset(118.1, 202.6);
  static const Offset _tailHinge = Offset(395, 215);
  static const Offset _feet = Offset(277.4, 423.7);
  static const Offset _eye = Offset(176.2, 172.6);

  /// Pulse of each wing bar while singing.
  static const List<double> _barPulse = [.10, .16, .12, .20];

  static const List<Color> _noteColors = [
    BirdyBrand.kingfisher,
    BirdyGoLogoPainter.lowerBeakColor,
    BirdyGoLogoPainter.plumageBottom,
  ];

  static final Path _noteFlag =
      Path()
        ..moveTo(6, -14)
        ..cubicTo(9, -8, 22, -6, 14, 5)
        ..cubicTo(17, -4, 8, -3, 6, -5)
        ..close();

  static double _smooth(double v) {
    final c = v.clamp(0.0, 1.0);
    return c * c * (3 - 2 * c);
  }

  static void _rotateAbout(Canvas canvas, Offset origin, double degrees) =>
      canvas
        ..translate(origin.dx, origin.dy)
        ..rotate(degrees * math.pi / 180)
        ..translate(-origin.dx, -origin.dy);

  static void _stretchAbout(Canvas canvas, Offset origin, double scaleY) =>
      canvas
        ..translate(origin.dx, origin.dy)
        ..scale(1, scaleY)
        ..translate(-origin.dx, -origin.dy);

  @override
  void paint(Canvas canvas, Size size) {
    final t = still ? _settled : clock.value;
    final phrase =
        still || t < _first
            ? -1
            : loop
            ? ((t - _first) / _period).floor()
            : 0;
    // Time inside the current phrase.
    final p = phrase < 0 ? _never : t - (_first + phrase * _period);
    // How open the beak is, 0..1.
    var song = 0.0;
    for (var i = 0; i < 3; i++) {
      final u = (p - i * _syllable) / _syllableLength;
      if (u > 0 && u < 1) song = math.max(song, math.sin(math.pi * u));
    }

    canvas.save();
    canvas.scale(size.width / viewBox.width, size.height / viewBox.height);
    canvas.translate(80, -10);

    final lift = BirdyGoSplashTimeline.easeOut(t / 700);
    final grow = .95 + .05 * lift;
    final opacity = (t / 300).clamp(0.0, 1.0);
    if (opacity < 1) {
      canvas.saveLayer(null, Paint()..color = Color.fromRGBO(0, 0, 0, opacity));
    } else {
      canvas.save();
    }
    canvas
      ..translate(0, 14 * (1 - lift))
      ..translate(_feet.dx, _feet.dy)
      ..rotate(-2.5 * song * math.pi / 180)
      ..scale(grow * (1 - .014 * song), grow * (1 + .045 * song))
      ..translate(-_feet.dx, -_feet.dy);

    final plumage =
        Paint()
          ..shader = ui.Gradient.linear(
            const Offset(165, 97.7),
            const Offset(361.7, 434.9),
            const [
              BirdyGoLogoPainter.plumageTop,
              BirdyGoLogoPainter.plumageBottom,
            ],
          );

    canvas.save();
    _rotateAbout(canvas, _tailHinge, -7 * song);
    canvas
      ..drawPath(BirdyGoLogoPainter.tail, plumage)
      ..restore();

    for (final (path, color, degrees) in [
      (
        BirdyGoLogoPainter.lowerBeak,
        BirdyGoLogoPainter.lowerBeakColor,
        -11 * song,
      ),
      (BirdyGoLogoPainter.upperBeak, BirdyBrand.oriole, 13 * song),
    ]) {
      canvas.save();
      _rotateAbout(canvas, _beakHinge, degrees);
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

    canvas.drawPath(BirdyGoLogoPainter.body, plumage);

    for (final (i, (from, to, color)) in BirdyGoLogoPainter.bars.indexed) {
      final drawn = BirdyGoSplashTimeline.easeOut((t - 350 - i * 70) / 520);
      if (drawn == 0) continue;
      final pulse =
          song == 0
              ? 1.0
              : 1 + song * _barPulse[i] * math.sin(p / 60 + i * 1.7);
      canvas.save();
      _stretchAbout(canvas, Offset.lerp(from, to, .5)!, pulse);
      canvas
        ..drawLine(
          from,
          Offset.lerp(from, to, drawn)!,
          Paint()
            ..color = color
            ..strokeWidth = 30
            ..strokeCap = StrokeCap.round,
        )
        ..restore();
    }

    final b = (p - 2000) / 160;
    final blink = b > 0 && b < 1 ? math.sin(math.pi * b) : 0.0;
    canvas.save();
    _stretchAbout(canvas, _eye, 1 - .9 * blink);
    canvas
      ..drawCircle(_eye, 18.7, Paint()..color = BirdyBrand.ink)
      ..drawCircle(
        const Offset(171, 166.6),
        5.4,
        Paint()..color = const Color(0xFFFFFFFF),
      )
      ..restore();
    canvas.restore(); // Bird.

    // One note per syllable; the notes of the previous phrase may still fly.
    for (var i = 0; i < 3; i++) {
      double? age;
      for (final k in [phrase, phrase - 1]) {
        if (k < 0) continue;
        final a = t - (_first + k * _period + i * _syllable + 90);
        if (a >= 0 && a < _noteLife) {
          age = a;
          break;
        }
      }
      if (age == null) continue;
      final u = age / _noteLife;
      final rise = 1 - math.pow(1 - u, 2).toDouble();
      final paint =
          Paint()
            ..color = _noteColors[i].withValues(
              alpha:
                  BirdyGoSplashTimeline.easeOut(u / .15) *
                  (1 - _smooth((u - .55) / .45)),
            );
      canvas
        ..save()
        ..translate(
          40 - (40 + i * 22) * rise + math.sin(u * math.pi * 2 + i) * 8,
          190 - (125 + i * 18) * rise,
        )
        ..rotate((-14 + math.sin(u * math.pi) * 18) * math.pi / 180)
        ..scale(
          (.6 + .5 * BirdyGoSplashTimeline.easeOut(u / .3)) * 2 * (1 - i * .08),
        )
        ..save();
      _rotateAbout(canvas, const Offset(-.5, 15), -20);
      canvas
        ..drawOval(
          Rect.fromCenter(center: const Offset(-.5, 15), width: 15, height: 10),
          paint,
        )
        ..restore()
        ..drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(3, -14, 4, 30),
            const Radius.circular(2),
          ),
          paint,
        )
        ..drawPath(_noteFlag, paint)
        ..restore();
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(BirdyGoSingingPainter oldDelegate) =>
      oldDelegate.clock != clock ||
      oldDelegate.loop != loop ||
      oldDelegate.still != still;
}

/// The loading bar: filled to the real share of the startup work done
/// ([fraction], 0..1), never a made-up percentage.
class BirdyGoLoadingPainter extends CustomPainter {
  BirdyGoLoadingPainter({
    required this.fraction,
    this.track = const Color(0x1A13233A),
  }) : super(repaint: fraction);

  final ValueListenable<double> fraction;

  /// Empty part of the bar: Encre at 10 % on Brume, Brume at 12 % on Encre.
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(2),
    );
    canvas.drawRRect(bounds, Paint()..color = track);
    final filled = fraction.value.clamp(0.0, 1.0);
    if (filled == 0) return;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width * filled, size.height),
        const Radius.circular(2),
      ),
      Paint()..color = BirdyBrand.kingfisher,
    );
  }

  @override
  bool shouldRepaint(BirdyGoLoadingPainter oldDelegate) =>
      oldDelegate.fraction != fraction;
}
