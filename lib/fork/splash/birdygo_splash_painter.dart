import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../design/birdy_motion.dart';
import '../design/birdy_theme_choice.dart';
import '../design/birdy_tokens.dart';
import '../home/birdygo_logo.dart';

/// Timeline of the startup screen, in milliseconds since it appeared
/// (Claude Design board « BirdyGo Splash »), in three acts: the bird arrives
/// (0 to 1 s), sings (from [firstPhrase]), then the name comes
/// ([wordmark], [taglineFirst], [taglineSecond], [footer]).
abstract final class BirdyGoSplashTimeline {
  // Act 1: arrival.

  /// Fade-in of the bird.
  static const double birdFade = 380;

  /// Rise and back-eased growth of the bird.
  static const double arrival = 850;

  /// Travel of the rise, in view-box units.
  static const double arrivalTravel = 12;

  /// Wing bars: the first starts to draw at [barsStart], each next one
  /// [barsStagger] later, each in [barsDraw].
  static const double barsStart = 450;
  static const double barsStagger = 60;
  static const double barsDraw = 500;

  // Act 2: song.

  /// First phrase, time between two phrases, between two syllables, and the
  /// length of a syllable.
  static const double firstPhrase = 1150;
  static const double phrasePeriod = 6500;
  static const double syllable = 400;
  static const double syllableLength = 360;

  /// A note leaves the beak [noteDelay] after its syllable starts and flies
  /// for [noteLife].
  static const double noteDelay = 80;
  static const double noteLife = 1300;

  /// Breathing of the resting bird: starts at [breatheStart], fades in over
  /// [breatheRamp], period 2π × [breathePeriod], amplitude [breatheAmount].
  static const double breatheStart = 2400;
  static const double breatheRamp = 900;
  static const double breathePeriod = 540;
  static const double breatheAmount = .007;

  /// Blinks: the first at [blinkStart], then every [blinkEvery], each
  /// lasting [blinkLength].
  static const double blinkStart = 4300;
  static const double blinkEvery = 4200;
  static const double blinkLength = 150;

  // Act 3: the name.

  /// The centred block (mark, wordmark, tagline) starts [columnTravel] dp
  /// lower and rises from [columnRise] for [columnRiseLength].
  static const double columnRise = 2150;
  static const double columnRiseLength = 800;
  static const double columnTravel = 56;

  /// When each text block starts to enter.
  static const double wordmark = 2350;
  static const double taglineFirst = 2750;
  static const double taglineSecond = 3300;

  /// Length of a text entrance, its travel and its starting blur, in dp.
  static const double textEnter = 650;
  static const double textTravel = 10;
  static const double textBlur = 4;

  /// Fade-in of the footer (loading bar, attribution).
  static const double footer = 3800;
  static const double footerFade = 700;

  /// Everything has entered: the intro is settled.
  static const double settled = footer + footerFade;

  /// Time constant of the loading bar catching up with the real progress.
  static const double barEase = 180;

  /// Quartic ease-out of the board, clamped to 0..1.
  static double easeOut(double v) =>
      1 - math.pow(1 - v.clamp(0.0, 1.0), 4).toDouble();

  /// Smoothstep, clamped to 0..1.
  static double smooth(double v) {
    final c = v.clamp(0.0, 1.0);
    return c * c * (3 - 2 * c);
  }

  /// Cubic ease-in-out, clamped to 0..1.
  static double easeInOut(double v) {
    final c = v.clamp(0.0, 1.0);
    return c < .5 ? 4 * c * c * c : 1 - math.pow(-2 * c + 2, 3).toDouble() / 2;
  }

  /// Back ease-out: overshoots a little past 1, then settles.
  static double backOut(double v) {
    final c = v.clamp(0.0, 1.0) - 1;
    return 1 + 2.2 * c * c * c + 1.2 * c * c;
  }

  /// Progress of a text entrance starting at [at], 0..1.
  static double textEntrance(double t, double at) =>
      easeOut((t - at) / textEnter);

  /// Downward offset of the centred block, in dp.
  static double columnOffset(double t) =>
      columnTravel * (1 - easeInOut((t - columnRise) / columnRiseLength));

  /// Opacity of the footer.
  static double footerOpacity(double t) => smooth((t - footer) / footerFade);
}

typedef _Timeline = BirdyGoSplashTimeline;

/// The BirdyGo mark singing: three syllables per phrase. On each one the beak
/// opens, the body swells, the tail and the wing bars move and a note leaves
/// the beak. Between phrases the bird breathes and blinks.
///
/// [clock] is the time since the splash appeared, in milliseconds. With
/// [loop] off the bird sings one phrase only; [still] draws the settled mark
/// (reduced motion).
class BirdyGoSingingPainter extends CustomPainter {
  BirdyGoSingingPainter({
    required this.clock,
    this.loop = true,
    this.still = false,
    this.brand = const BirdyBrandColors(BirdyBird.loriot),
  }) : super(repaint: clock);

  final ValueListenable<double> clock;
  final bool loop;
  final bool still;

  /// The bird theme's colors (J6i); Loriot by default.
  final BirdyBrandColors brand;

  /// Source view box of the board: x -80, y 10, 570 × 450.
  static const Size viewBox = Size(570, 450);

  /// Start of the first phrase and time between two phrases of the loop.
  /// The home logo (`SingingLogo`) plays one phrase at a time with them.
  static const double firstPhrase = BirdyGoSplashTimeline.firstPhrase;
  static const double phrasePeriod = BirdyGoSplashTimeline.phrasePeriod;

  /// Length of one phrase, until its last note has faded; the mark is
  /// settled again after it.
  static const double phraseLength = 2 * _syllable + _noteDelay + _noteLife;

  static const double _syllable = BirdyGoSplashTimeline.syllable;
  static const double _syllableLength = BirdyGoSplashTimeline.syllableLength;
  static const double _noteDelay = BirdyGoSplashTimeline.noteDelay;
  static const double _noteLife = BirdyGoSplashTimeline.noteLife;
  static const double _settled = 1e7;
  static const double _never = -1e9;

  static const Offset _beakHinge = Offset(118.1, 202.6);

  /// The tail swings about its root (Claude Design « BirdyGo Splash »).
  static const Offset _tailHinge = Offset(414.2, 285.3);

  /// The logo's tail, extended into the body: when it swings, no gap opens
  /// between tail and body (the extension is hidden under the body).
  static final Path _singingTail = Path.from(BirdyGoLogoPainter.tail)
    ..addPolygon(const [
      Offset(414.2, 285.3),
      Offset(412, 300),
      Offset(360, 295),
      Offset(335, 205),
      Offset(364.4, 181.4),
    ], true);
  static const Offset _feet = Offset(277.4, 423.7);
  static const Offset _eye = Offset(176.2, 172.6);

  /// Pulse of each wing bar while singing.
  static const List<double> _barPulse = [.08, .13, .10, .16];

  static final Path _noteFlag =
      Path()
        ..moveTo(6, -14)
        ..cubicTo(9, -8, 22, -6, 14, 5)
        ..cubicTo(17, -4, 8, -3, 6, -5)
        ..close();

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

  /// One note of age [u] (0 → 1) in the logo's 512 box, leaving the beak and
  /// rising to the left; [i] picks its color and lane. [reach] stretches the
  /// flight and the size (the home easter egg's big bird, logo_flight.dart).
  static void paintNote(
    Canvas canvas,
    int i,
    double u, {
    double reach = 1,
    BirdyBrandColors brand = const BirdyBrandColors(BirdyBird.loriot),
  }) {
    // Notes: accent, lower beak color, deep accent.
    final noteColors = [brand.accent, brand.highlightDeep, brand.accentDeep];
    final rise = 1 - math.pow(1 - u, 2).toDouble();
    final paint =
        Paint()
          ..color = noteColors[i % noteColors.length].withValues(
            alpha:
                _Timeline.easeOut(u / .15) *
                (1 - _Timeline.smooth((u - .5) / .5)),
          );
    canvas
      ..save()
      ..translate(
        40 - (34 + i * 18) * rise * reach + math.sin(u * math.pi * 2 + i) * 5,
        190 - (110 + i * 16) * rise * reach,
      )
      ..rotate((-12 + math.sin(u * math.pi) * 14) * math.pi / 180)
      ..scale((.6 + .4 * _Timeline.easeOut(u / .3)) * 1.7 * (1 - i * .08))
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

  /// How far the bird has lifted its head, 0..1, [p] ms into a phrase: eases
  /// in from the first syllable, holds through the song, eases back out after
  /// the last syllable. Zero before the phrase and once it is done.
  // FORK: J7, the bird lifts its head while it sings.
  static double liftAt(double p) {
    const songEnd = 2 * _syllable + _syllableLength;
    if (p <= 0) return 0;
    if (p < BirdyMotion.logoLiftIn) {
      return Curves.easeOutCubic.transform(p / BirdyMotion.logoLiftIn);
    }
    if (p <= songEnd) return 1;
    final u = (p - songEnd) / BirdyMotion.logoLiftOut;
    if (u >= 1) return 0;
    return Curves.easeInOutCubic.transform(1 - u);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final t = still ? _settled : clock.value;
    final phrase =
        still || t < firstPhrase
            ? -1
            : loop
            ? ((t - firstPhrase) / phrasePeriod).floor()
            : 0;
    // Time inside the current phrase.
    final p = phrase < 0 ? _never : t - (firstPhrase + phrase * phrasePeriod);
    // How open the beak is, 0..1.
    var song = 0.0;
    for (var i = 0; i < 3; i++) {
      final u = (p - i * _syllable) / _syllableLength;
      if (u > 0 && u < 1) song = math.max(song, math.sin(math.pi * u));
    }

    canvas.save();
    canvas.scale(size.width / viewBox.width, size.height / viewBox.height);
    canvas.translate(80, -10);

    final lift = _Timeline.easeOut(t / _Timeline.arrival);
    final breathe =
        still
            ? 1.0
            : 1 +
                _Timeline.breatheAmount *
                    math.sin(
                      (t - _Timeline.breatheStart) / _Timeline.breathePeriod,
                    ) *
                    _Timeline.smooth(
                      (t - _Timeline.breatheStart) / _Timeline.breatheRamp,
                    );
    final grow = (.9 + .1 * _Timeline.backOut(t / _Timeline.arrival)) * breathe;
    final opacity = (t / _Timeline.birdFade).clamp(0.0, 1.0);
    if (opacity < 1) {
      canvas.saveLayer(null, Paint()..color = Color.fromRGBO(0, 0, 0, opacity));
    } else {
      canvas.save();
    }
    // FORK: J7, the lift of the head: a rise and a back tilt about the feet,
    // a small bob with each syllable. Only the bird; the notes stay put.
    final headLift = still ? 0.0 : liftAt(p);
    canvas
      ..translate(
        0,
        -headLift * BirdyMotion.logoLiftUnits -
            headLift * song * BirdyMotion.logoLiftBobUnits,
      )
      ..translate(0, _Timeline.arrivalTravel * (1 - lift))
      ..translate(_feet.dx, _feet.dy)
      ..rotate(
        (-2.5 * song - BirdyMotion.logoLiftTiltDegrees * headLift) *
            math.pi /
            180,
      )
      ..scale(grow * (1 - .014 * song), grow * (1 + .045 * song))
      ..translate(-_feet.dx, -_feet.dy);

    final plumage =
        Paint()
          ..shader = ui.Gradient.linear(
            const Offset(165, 97.7),
            const Offset(361.7, 434.9),
            [brand.accentHi, brand.accentDeep],
          );

    canvas.save();
    _rotateAbout(canvas, _tailHinge, -5 * song);
    canvas
      ..drawPath(_singingTail, plumage)
      ..restore();

    for (final (path, color, degrees) in [
      (
        BirdyGoLogoPainter.lowerBeak,
        brand.highlightDeep,
        -11 * song,
      ),
      (BirdyGoLogoPainter.upperBeak, brand.highlight, 13 * song),
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

    for (final (i, (from, to, color)) in BirdyGoLogoPainter.barsFor(brand).indexed) {
      final drawn = _Timeline.easeOut(
        (t - _Timeline.barsStart - i * _Timeline.barsStagger) /
            _Timeline.barsDraw,
      );
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

    final b =
        still || t < _Timeline.blinkStart
            ? -1.0
            : ((t - _Timeline.blinkStart) % _Timeline.blinkEvery) /
                _Timeline.blinkLength;
    final blink = b > 0 && b < 1 ? math.sin(math.pi * b) : 0.0;
    canvas.save();
    _stretchAbout(canvas, _eye, 1 - .9 * blink);
    canvas
      ..drawCircle(_eye, 18.7, Paint()..color = BirdyBrand.ink)
      ..drawCircle(
        const Offset(171, 166.6),
        5.4,
        Paint()..color = BirdyBrand.white,
      )
      ..restore();
    canvas.restore(); // Bird.

    // One note per syllable; the notes of the previous phrase may still fly.
    for (var i = 0; i < 3; i++) {
      double? age;
      for (final k in [phrase, phrase - 1]) {
        if (k < 0) continue;
        final a =
            t - (firstPhrase + k * phrasePeriod + i * _syllable + _noteDelay);
        if (a >= 0 && a < _noteLife) {
          age = a;
          break;
        }
      }
      if (age == null) continue;
      paintNote(canvas, i, age / _noteLife, brand: brand);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(BirdyGoSingingPainter oldDelegate) =>
      oldDelegate.clock != clock ||
      oldDelegate.loop != loop ||
      oldDelegate.still != still ||
      oldDelegate.brand != brand;
}

/// The loading bar: filled to the real share of the startup work done
/// ([fraction], 0..1), never a made-up percentage.
class BirdyGoLoadingPainter extends CustomPainter {
  BirdyGoLoadingPainter({
    required this.fraction,
    this.track = lightTrack,
    this.fill = BirdyBrand.kingfisher,
  }) : super(repaint: fraction);

  /// Empty part of the bar on Brume: Encre at 8 %.
  static const Color lightTrack = BirdyBrand.splashTrackLight;

  final ValueListenable<double> fraction;

  /// Empty part of the bar: Encre at 8 % on Brume, Brume at 12 % on Encre.
  final Color track;

  /// The filled part: the bird theme's accent (J6i), Loriot's by default.
  final Color fill;

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
      Paint()..color = fill,
    );
  }

  @override
  bool shouldRepaint(BirdyGoLoadingPainter oldDelegate) =>
      oldDelegate.fraction != fraction ||
      oldDelegate.track != track ||
      oldDelegate.fill != fill;
}
