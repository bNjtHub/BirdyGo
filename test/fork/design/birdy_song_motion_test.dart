import 'dart:io';

import 'package:birdnet_live/fork/design/birdy_motion.dart';
import 'package:birdnet_live/fork/design/birdy_song_motion.dart';
import 'package:birdnet_live/fork/splash/birdygo_splash_painter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const first = BirdySongMotion.firstPhrase;

  test('the pose lifts rigidly at the first notes, rests otherwise', () {
    // Peak while the first note leaves the beak (it is out at noteDelay and
    // the lift holds through its first moments).
    final peak = BirdySongMotion.at(first + BirdyMotion.logoLiftIn + 50);
    expect(peak.lift, 1);
    expect(peak.rise, BirdyMotion.logoLiftRise);
    expect(peak.beakLiftDegrees, BirdyMotion.logoLiftBeakDegrees);
    expect(
      BirdySongMotion.at(first + BirdySongMotion.noteDelay + 40).lift,
      greaterThan(.85),
    );
    // The tilt is the song's own, not the lift's.
    final mid = BirdySongMotion.at(first + 200);
    expect(mid.tiltDegrees, -BirdySongMotion.songTiltDegrees * mid.song);
    for (final t in [0.0, first - 1, first + BirdySongMotion.phraseLength]) {
      final rest = BirdySongMotion.at(t);
      expect(rest.rise, 0);
      expect(rest.beakLiftDegrees, 0);
      expect(rest.tiltDegrees, 0);
      expect(rest.song, 0);
    }
  });

  test('one gesture per phrase: no second lift on the later syllables', () {
    const end = BirdyMotion.logoLiftIn + BirdyMotion.logoLiftHold;
    var rises = 0;
    var previous = 0.0;
    var wasRising = false;
    for (var p = 0.0; p < BirdySongMotion.phraseLength; p += 5) {
      final v = BirdySongMotion.at(first + p).rise;
      final rising = v > previous;
      if (rising && !wasRising) rises++;
      wasRising = rising || (v == previous && wasRising);
      previous = v;
    }
    expect(rises, 1);
    expect(
      BirdySongMotion.at(first + end + BirdyMotion.logoLiftOut).rise,
      0,
    );
    expect(BirdySongMotion.at(first + BirdySongMotion.syllable * 2).rise, 0);
  });

  test('the painter never scales the bird with the song or the lift', () {
    final src = File(
      'lib/fork/splash/birdygo_splash_painter.dart',
    ).readAsStringSync();
    expect(src.contains('neckStretch'), isFalse);
    expect(src.contains('..scale(grow)'), isTrue);
    expect(RegExp(r'\.\.scale\(grow\s*\*').hasMatch(src), isFalse);
  });

  test('reduced motion is the rest pose whatever the clock says', () {
    final p = BirdySongMotion.at(first + 600, reduced: true);
    expect(p.rise, 0);
    expect(p.beakLiftDegrees, 0);
    expect(p.tiltDegrees, 0);
    expect(p.lift, 0);
    expect(p.phrase, -1);
  });

  test('the same clock gives the same pose; the loop repeats it', () {
    final a = BirdySongMotion.at(first + 700);
    final b = BirdySongMotion.at(first + 700 + BirdySongMotion.phrasePeriod);
    expect(b.rise, a.rise);
    expect(b.tiltDegrees, a.tiltDegrees);
    expect(b.phrase, 1);
    // Without the loop only the first phrase sings.
    expect(
      BirdySongMotion.at(first + BirdySongMotion.phrasePeriod + 700, loop: false)
          .phrase,
      0,
    );
  });

  test('the splash painter and the logos share the one timeline', () {
    expect(BirdyGoSingingPainter.firstPhrase, BirdySongMotion.firstPhrase);
    expect(BirdyGoSingingPainter.phrasePeriod, BirdySongMotion.phrasePeriod);
    expect(BirdyGoSingingPainter.phraseLength, BirdySongMotion.phraseLength);
    expect(BirdyGoSplashTimeline.syllable, BirdySongMotion.syllable);
    expect(BirdyGoSplashTimeline.noteLife, BirdySongMotion.noteLife);
  });

  test('no screen carries its own copy of the song motion', () {
    final offenders = <String>[];
    for (final f in Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))) {
      final path = f.path.replaceAll(r'\', '/');
      if (path.endsWith('fork/design/birdy_song_motion.dart') ||
          path.endsWith('fork/design/birdy_motion.dart')) {
        continue;
      }
      final src = f.readAsStringSync();
      if (src.contains('logoLift') || src.contains('liftAt(')) {
        offenders.add(path);
      }
    }
    expect(offenders, isEmpty);
  });
}
