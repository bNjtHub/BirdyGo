import 'dart:ui' as ui;

import 'package:birdnet_live/fork/splash/birdygo_splash.dart';
import 'package:birdnet_live/fork/splash/birdygo_splash_painter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

typedef _Timeline = BirdyGoSplashTimeline;

void _paint(CustomPainter painter, Size size) {
  final recorder = ui.PictureRecorder();
  painter.paint(Canvas(recorder), size);
  recorder.endRecording().dispose();
}

void main() {
  test('the easings of the board are clamped and settle on 1', () {
    for (final ease in [
      _Timeline.easeOut,
      _Timeline.smooth,
      _Timeline.easeInOut,
      _Timeline.backOut,
    ]) {
      expect(ease(-1), closeTo(0, 1e-9));
      expect(ease(0), closeTo(0, 1e-9));
      expect(ease(1), 1);
      expect(ease(3), 1);
    }
    expect(_Timeline.easeInOut(.5), closeTo(.5, 1e-9));
    // The bird's arrival overshoots a little, then settles.
    expect(_Timeline.backOut(.8), greaterThan(1));
  });

  test('three acts: arrival, song, then the name', () {
    expect(_Timeline.arrival, lessThanOrEqualTo(1000));
    expect(_Timeline.firstPhrase, 1150);
    expect(_Timeline.columnRise, lessThan(_Timeline.wordmark));
    expect(_Timeline.wordmark, 2350);
    expect(_Timeline.taglineFirst, 2750);
    expect(_Timeline.taglineSecond, 3300);
    expect(_Timeline.footer, 3800);
    expect(_Timeline.settled, 4500);
    expect(
      BirdyGoSplash.minimumDisplay,
      Duration(milliseconds: _Timeline.settled.round()),
    );
    // The phrase does not come back before the intro is settled.
    expect(
      _Timeline.firstPhrase + _Timeline.phrasePeriod,
      greaterThan(_Timeline.settled),
    );
    // Rhythm shared with the home logo.
    expect(BirdyGoSingingPainter.firstPhrase, _Timeline.firstPhrase);
    expect(BirdyGoSingingPainter.phrasePeriod, _Timeline.phrasePeriod);
    expect(
      BirdyGoSingingPainter.phraseLength,
      lessThan(BirdyGoSingingPainter.phrasePeriod),
    );
  });

  test('the block rises and the texts enter, then everything is settled', () {
    expect(_Timeline.columnOffset(0), _Timeline.columnTravel);
    expect(
      _Timeline.columnOffset(_Timeline.columnRise),
      _Timeline.columnTravel,
    );
    expect(
      _Timeline.columnOffset(_Timeline.columnRise + _Timeline.columnRiseLength),
      0,
    );
    expect(_Timeline.textEntrance(_Timeline.wordmark, _Timeline.wordmark), 0);
    expect(
      _Timeline.textEntrance(
        _Timeline.wordmark + _Timeline.textEnter,
        _Timeline.wordmark,
      ),
      1,
    );
    expect(_Timeline.footerOpacity(_Timeline.footer), 0);
    for (final at in [
      _Timeline.wordmark,
      _Timeline.taglineFirst,
      _Timeline.taglineSecond,
    ]) {
      expect(_Timeline.textEntrance(_Timeline.settled, at), 1);
    }
    expect(_Timeline.footerOpacity(_Timeline.settled), 1);
    expect(_Timeline.columnOffset(_Timeline.settled), 0);
  });

  test('the singing mark paints at every moment of several phrases', () {
    final clock = ValueNotifier<double>(0);
    addTearDown(clock.dispose);
    for (final loop in [true, false]) {
      final painter = BirdyGoSingingPainter(clock: clock, loop: loop);
      for (var t = 0.0; t <= 20000; t += 37) {
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

  test('the loading bar paints any share, out-of-range ones clamped', () {
    final fraction = ValueNotifier<double>(0);
    addTearDown(fraction.dispose);
    final painter = BirdyGoLoadingPainter(fraction: fraction);
    for (final value in [-.2, 0.0, .1, .5, 1.0, 1.3]) {
      fraction.value = value;
      _paint(painter, const Size(120, 3));
    }
    expect(
      painter.shouldRepaint(BirdyGoLoadingPainter(fraction: fraction)),
      isFalse,
    );
  });
}
