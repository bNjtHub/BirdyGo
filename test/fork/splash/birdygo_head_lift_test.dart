import 'dart:ui' as ui;

import 'package:birdnet_live/fork/design/birdy_motion.dart';
import 'package:birdnet_live/fork/design/birdy_song_motion.dart';
import 'package:birdnet_live/fork/splash/birdygo_splash_painter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

Future<List<int>> _pixels(double clock, {bool still = false}) async {
  final recorder = ui.PictureRecorder();
  BirdyGoSingingPainter(clock: ValueNotifier(clock), still: still)
      .paint(Canvas(recorder), const Size(114, 90));
  final image = await recorder.endRecording().toImage(114, 90);
  final data = await image.toByteData();
  return data!.buffer.asUint8List().toList();
}

void main() {
  const lift = BirdySongMotion.liftAt;
  const first = BirdyGoSingingPainter.firstPhrase;

  test('the lift is zero at rest, before and after the phrase', () {
    expect(lift(-500), 0);
    expect(lift(0), 0);
    expect(lift(BirdyGoSingingPainter.phrasePeriod - 1), 0);
    expect(lift(BirdyGoSingingPainter.phraseLength), 0);
  });

  test('the lift is up mid-song and holds through the syllables', () {
    expect(lift(BirdyMotion.logoLeanIn), 1);
    expect(lift(BirdyMotion.logoLeanIn + BirdyMotion.logoLeanHold), 1);
    expect(lift(BirdyMotion.logoLeanIn + 100), 1);
    expect(lift(50), inInclusiveRange(0.1, 0.9));
  });

  test('the lift is back to zero after the song and never jumps', () {
    expect(
      lift(
        BirdyMotion.logoLeanIn +
            BirdyMotion.logoLeanHold +
            BirdyMotion.logoLeanOut,
      ),
      0,
    );
    var previous = lift(0);
    for (var p = 1.0; p < 1500; p++) {
      final v = lift(p);
      expect(v, inInclusiveRange(0, 1));
      // Eases in 160 ms: at most ~1/50 per ms is smooth.
      expect((v - previous).abs(), lessThan(0.04));
      previous = v;
    }
  });

  testWidgets('the bird is painted lifted mid-song, identical at rest', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final still = await _pixels(first + 600, still: true);
      final singing = await _pixels(first + 250);
      // Reduced motion: the settled mark, whatever the clock says.
      expect(listEquals(still, await _pixels(0, still: true)), isTrue);
      expect(listEquals(singing, still), isFalse);
      // Between phrases the bird is exactly where it rests (the lift and the
      // song are both over, nothing else moves the bird by then).
      final later = await _pixels(first + 5000);
      final later2 = await _pixels(first + 5000);
      expect(listEquals(later, later2), isTrue);
    });
  });

  test('a repeated phrase starts and ends at rest (no restart jump)', () {
    const again = first + BirdyGoSingingPainter.phrasePeriod;
    final p = again - (first + 0);
    expect(lift(p - BirdyGoSingingPainter.phrasePeriod), 0);
  });
}
