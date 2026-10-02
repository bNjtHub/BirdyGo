import 'dart:io';

import 'package:birdnet_live/fork/design/birdy_motion.dart';
import 'package:birdnet_live/fork/design/birdy_song_motion.dart';
import 'package:birdnet_live/fork/splash/birdygo_splash_painter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const first = BirdySongMotion.firstPhrase;

  test('the pose lifts and tilts back mid-song, rests otherwise', () {
    final mid = BirdySongMotion.at(first + 600);
    expect(mid.lift, 1);
    expect(mid.dy, lessThan(-BirdyMotion.logoLiftUnits + 1));
    expect(mid.tiltDegrees, lessThan(-BirdyMotion.logoLiftTiltDegrees + .01));
    for (final t in [0.0, first - 1, first + BirdySongMotion.phraseLength]) {
      final rest = BirdySongMotion.at(t);
      expect(rest.dy, 0);
      expect(rest.tiltDegrees, 0);
      expect(rest.song, 0);
    }
  });

  test('reduced motion is the rest pose whatever the clock says', () {
    final p = BirdySongMotion.at(first + 600, reduced: true);
    expect(p.dy, 0);
    expect(p.tiltDegrees, 0);
    expect(p.lift, 0);
    expect(p.phrase, -1);
  });

  test('the same clock gives the same pose; the loop repeats it', () {
    final a = BirdySongMotion.at(first + 700);
    final b = BirdySongMotion.at(first + 700 + BirdySongMotion.phrasePeriod);
    expect(b.dy, a.dy);
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
