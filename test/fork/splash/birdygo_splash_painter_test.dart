import 'dart:ui' as ui;

import 'package:birdnet_live/fork/splash/birdygo_splash_painter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void _paint(CustomPainter painter, Size size) {
  final recorder = ui.PictureRecorder();
  painter.paint(Canvas(recorder), size);
  recorder.endRecording().dispose();
}

void main() {
  test('the text timeline fits in the first sung phrase', () {
    expect(BirdyGoSplashTimeline.easeOut(-1), 0);
    expect(BirdyGoSplashTimeline.easeOut(0), 0);
    expect(BirdyGoSplashTimeline.easeOut(1), 1);
    expect(BirdyGoSplashTimeline.easeOut(3), 1);
    expect(
      BirdyGoSplashTimeline.wordmark,
      lessThan(BirdyGoSplashTimeline.taglineFirst),
    );
    expect(
      BirdyGoSplashTimeline.taglineFirst,
      lessThan(BirdyGoSplashTimeline.taglineSecond),
    );
  });

  test('the singing mark paints at every moment of several phrases', () {
    final clock = ValueNotifier<double>(0);
    addTearDown(clock.dispose);
    for (final loop in [true, false]) {
      final painter = BirdyGoSingingPainter(clock: clock, loop: loop);
      for (var t = 0.0; t <= 12000; t += 37) {
        clock.value = t;
        _paint(painter, const Size(310, 245));
      }
    }
    _paint(
      BirdyGoSingingPainter(clock: clock, still: true),
      const Size(168, 133),
    );
  });

  test('the singing mark repaints with its clock only', () {
    final clock = ValueNotifier<double>(0);
    addTearDown(clock.dispose);
    final painter = BirdyGoSingingPainter(clock: clock);
    expect(painter.shouldRepaint(BirdyGoSingingPainter(clock: clock)), isFalse);
    expect(
      painter.shouldRepaint(BirdyGoSingingPainter(clock: clock, loop: false)),
      isTrue,
    );
    expect(
      painter.shouldRepaint(BirdyGoSingingPainter(clock: clock, still: true)),
      isTrue,
    );
  });

  test('the loading sweep loops and rests when inactive', () {
    final clock = ValueNotifier<double>(0);
    addTearDown(clock.dispose);
    for (final active in [true, false]) {
      final painter = BirdyGoLoadingPainter(clock: clock, active: active);
      for (var t = 0.0; t <= 5000; t += 111) {
        clock.value = t;
        _paint(painter, const Size(180, 4));
      }
    }
  });
}
