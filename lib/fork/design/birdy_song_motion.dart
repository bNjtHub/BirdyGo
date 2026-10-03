import 'dart:math' as math;

import 'package:flutter/animation.dart';

import 'birdy_motion.dart';

/// What the singing bird does at one instant of its clock.
class BirdySongPose {
  const BirdySongPose({
    required this.phrase,
    required this.phraseTime,
    required this.song,
    required this.lift,
    required this.leanDegrees,
    required this.tiltDegrees,
  });

  /// The bird at rest (reduced motion, before the first phrase).
  static const BirdySongPose rest = BirdySongPose(
    phrase: -1,
    phraseTime: BirdySongMotion.never,
    song: 0,
    lift: 0,
    leanDegrees: 0,
    tiltDegrees: 0,
  );

  /// Index of the current phrase, or -1 before the first one.
  final int phrase;

  /// Milliseconds since the current phrase started.
  final double phraseTime;

  /// How open the beak is, 0..1 (the swell of the current syllable).
  final double song;

  /// How far the bird leans back, 0..1.
  final double lift;

  /// Backward lean of the whole bird about its feet, in degrees (positive:
  /// back, away from where the beak points); rigid, never a stretch.
  final double leanDegrees;

  /// The song's own tilt of the bird about its feet, in degrees (negative:
  /// back); not part of the lean.
  final double tiltDegrees;
}

/// The one source of truth for how the BirdyGo logo sings: the syllable
/// timeline, the single backward lean, the song tilt and their easing. The splash,
/// the home logo, the theme logo and the flight overlay all paint through
/// `BirdyGoSingingPainter`, which reads this and nothing else; a screen only
/// supplies its clock. Tweak the song here (and in `BirdyMotion.logoLean*`),
/// nowhere else.
abstract final class BirdySongMotion {
  /// Start of the first phrase and time between two phrases of the loop, in
  /// ms on the singing clock.
  static const double firstPhrase = 1150;
  static const double phrasePeriod = 6500;

  /// Time between two syllables and length of a syllable.
  static const double syllable = 400;
  static const double syllableLength = 360;

  /// A note leaves the beak [noteDelay] after its syllable starts and flies
  /// for [noteLife].
  static const double noteDelay = 80;
  static const double noteLife = 1300;

  /// Length of one phrase, until its last note has faded.
  static const double phraseLength = 2 * syllable + noteDelay + noteLife;

  /// Back tilt, in degrees, at the full swell of a syllable (the original
  /// song motion).
  static const double songTiltDegrees = 2.5;

  /// Time of the settled mark, and the "no phrase" marker.
  static const double settled = 1e7;
  static const double never = -1e9;

  /// The lift envelope, 0..1, [p] ms into a phrase: one gesture, leaning fast
  /// from the phrase start, holding while the first notes leave, settling
  /// softly. Zero before the phrase and once it is done.
  static double liftAt(double p) {
    const songEnd = BirdyMotion.logoLeanIn + BirdyMotion.logoLeanHold;
    if (p <= 0) return 0;
    if (p < BirdyMotion.logoLeanIn) {
      return Curves.easeOutCubic.transform(p / BirdyMotion.logoLeanIn);
    }
    if (p <= songEnd) return 1;
    final u = (p - songEnd) / BirdyMotion.logoLeanOut;
    if (u >= 1) return 0;
    return Curves.easeInOutCubic.transform(1 - u);
  }

  /// Beak opening, 0..1, [p] ms into a phrase.
  static double songAt(double p) {
    var song = 0.0;
    for (var i = 0; i < 3; i++) {
      final u = (p - i * syllable) / syllableLength;
      if (u > 0 && u < 1) song = math.max(song, math.sin(math.pi * u));
    }
    return song;
  }

  /// Index of the phrase playing at clock [t], -1 before the first. With
  /// [loop] off only the first phrase exists.
  static int phraseAt(double t, {bool loop = true}) =>
      t < firstPhrase
          ? -1
          : loop
          ? ((t - firstPhrase) / phrasePeriod).floor()
          : 0;

  /// Age in ms of note [i] of phrase [phrase] at clock [t]; null when it is
  /// not flying.
  static double? noteAge(double t, int phrase, int i) {
    if (phrase < 0) return null;
    final a =
        t - (firstPhrase + phrase * phrasePeriod + i * syllable + noteDelay);
    return a >= 0 && a < noteLife ? a : null;
  }

  /// The pose at clock [t]; [reduced] is the rest pose.
  static BirdySongPose at(double t, {bool loop = true, bool reduced = false}) {
    if (reduced) return BirdySongPose.rest;
    final phrase = phraseAt(t, loop: loop);
    if (phrase < 0) return BirdySongPose.rest;
    final p = t - (firstPhrase + phrase * phrasePeriod);
    final song = songAt(p);
    final lift = liftAt(p);
    return BirdySongPose(
      phrase: phrase,
      phraseTime: p,
      song: song,
      lift: lift,
      leanDegrees: lift * BirdyMotion.logoLeanDegrees,
      tiltDegrees: -songTiltDegrees * song,
    );
  }
}
