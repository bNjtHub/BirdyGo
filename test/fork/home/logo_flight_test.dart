import 'package:birdnet_live/fork/design/birdy_motion.dart';
import 'package:birdnet_live/fork/home/logo_flight.dart';
import 'package:birdnet_live/fork/home/singing_logo.dart';
import 'package:birdnet_live/fork/splash/birdygo_splash_painter.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget app({bool reduced = false, required VoidCallback onTap}) =>
      MaterialApp(
        builder:
            (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
              child: child!,
            ),
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SingingLogo(onTap: onTap, wordmark: const Text('BG')),
          ),
        ),
      );

  /// A double tap: two quick taps on the mark, well inside
  /// [kDoubleTapTimeout].
  Future<void> doubleTap(WidgetTester tester) async {
    await tester.tap(find.text('BG'));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.text('BG'));
    await tester.pump();
    // Flushes the gesture recognizer's own consecutive-tap timer, or a
    // "Timer still pending" assertion fires at the end of the test.
    await tester.pump(kDoubleTapTimeout);
  }

  Finder opacityOfMark() => find.ancestor(
    of: find.byWidgetPredicate(
      (w) => w is CustomPaint && w.painter is BirdyGoSingingPainter,
    ),
    matching: find.byType(Opacity),
  );

  Future<void> pumpThroughRun(WidgetTester tester, Duration total) async {
    const frames = 60;
    for (var i = 0; i < frames + 5; i++) {
      await tester.pump(total ~/ frames);
    }
    await tester.pump();
  }

  testWidgets('a double tap starts the sequence: overlay bird, logo hidden', (
    tester,
  ) async {
    var plays = 0;
    await tester.pumpWidget(app(onTap: () => plays++));
    await doubleTap(tester);

    expect(find.byType(LogoWinkBird), findsOneWidget);
    expect(tester.widget<Opacity>(opacityOfMark().first).opacity, 0);
    // The tweet waits for the bird to arrive in the middle of the screen.
    expect(plays, 0);

    await tester.pump(BirdyMotion.logoWink * BirdyMotion.logoWinkTakeoffEnd);
    await tester.pump(const Duration(milliseconds: 50));
    expect(plays, 1);

    await pumpThroughRun(tester, BirdyMotion.logoWink);
  });

  testWidgets('the bird goes to the middle of the screen, big, then home', (
    tester,
  ) async {
    await tester.pumpWidget(app(onTap: () {}));
    final markCenter = tester.getCenter(find.byType(SingingLogo));
    await doubleTap(tester);

    final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
    final timeline =
        tester.widget<LogoWinkBird>(find.byType(LogoWinkBird)).timeline;
    expect(timeline.screen, screen);
    const hover =
        (BirdyMotion.logoWinkTakeoffEnd + BirdyMotion.logoWinkHoverEnd) / 2;
    expect(
      (timeline.offsetAt(hover) - screen.center(Offset.zero)).distance,
      lessThan(BirdyMotion.logoWinkBob + 0.01),
    );
    expect(timeline.scaleAt(hover), BirdyMotion.logoWinkScale);
    // Off-screen at the turn, back exactly on the header mark at the end.
    expect(
      timeline.offsetAt(BirdyMotion.logoWinkExitEnd).dx,
      greaterThan(screen.width),
    );
    expect(timeline.offsetAt(1), timeline.origin);
    expect(timeline.scaleAt(1), 1);
    expect(timeline.facingAt(1), 1);
    expect(timeline.offsetAt(0), timeline.origin);
    expect(timeline.origin.dy, closeTo(markCenter.dy, 20));

    await pumpThroughRun(tester, BirdyMotion.logoWink);
  });

  testWidgets('the sequence ends with the logo back and the overlay gone', (
    tester,
  ) async {
    await tester.pumpWidget(app(onTap: () {}));
    await doubleTap(tester);
    expect(find.byType(LogoWinkBird), findsOneWidget);

    await pumpThroughRun(tester, BirdyMotion.logoWink);

    expect(find.byType(LogoWinkBird), findsNothing);
    expect(tester.widget<Opacity>(opacityOfMark().first).opacity, 1);
  });

  testWidgets('taps are ignored while the sequence runs', (tester) async {
    var plays = 0;
    await tester.pumpWidget(app(onTap: () => plays++));
    await doubleTap(tester);
    expect(find.byType(LogoWinkBird), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 300));
    await doubleTap(tester);
    // A single tap too.
    await tester.tap(find.text('BG'));
    await tester.pump(kDoubleTapTimeout + const Duration(milliseconds: 50));

    expect(find.byType(LogoWinkBird), findsOneWidget);
    expect(plays, lessThanOrEqualTo(1));

    await pumpThroughRun(tester, BirdyMotion.logoWink);
    // Exactly one tweet for the whole run.
    expect(plays, 1);
  });

  testWidgets('reduced motion: a quick wink in place, then back', (
    tester,
  ) async {
    var plays = 0;
    await tester.pumpWidget(app(reduced: true, onTap: () => plays++));
    await doubleTap(tester);

    expect(find.byType(LogoWinkBird), findsOneWidget);
    final timeline =
        tester.widget<LogoWinkBird>(find.byType(LogoWinkBird)).timeline;
    expect(timeline.reduced, isTrue);
    expect(timeline.offsetAt(0.5), timeline.origin);
    expect(timeline.scaleAt(0.5), 1);
    expect(timeline.eyeClosedAt(0.5), closeTo(1, 0.01));
    expect(plays, 1);

    await pumpThroughRun(tester, BirdyMotion.logoWinkReduced);
    expect(find.byType(LogoWinkBird), findsNothing);
    expect(tester.widget<Opacity>(opacityOfMark().first).opacity, 1);
  });

  test('the wink closes and reopens the eye once, while hovering', () {
    const timeline = LogoWinkTimeline(
      origin: Offset(30, 40),
      screen: Size(400, 800),
    );
    expect(timeline.eyeClosedAt(0), 0);
    expect(timeline.eyeClosedAt(BirdyMotion.logoWinkEyeStart - 0.01), 0);
    const mid = (BirdyMotion.logoWinkEyeStart + BirdyMotion.logoWinkEyeEnd) / 2;
    expect(timeline.eyeClosedAt(mid), closeTo(1, 0.01));
    expect(timeline.eyeClosedAt(BirdyMotion.logoWinkEyeEnd + 0.01), 0);
    expect(timeline.eyeClosedAt(1), 0);
    expect(
      BirdyMotion.logoWinkEyeStart,
      greaterThan(BirdyMotion.logoWinkTakeoffEnd),
    );
    expect(BirdyMotion.logoWinkEyeEnd, lessThan(BirdyMotion.logoWinkHoverEnd));
  });

  test('the bird sings at the arrival: beak and one note per syllable', () {
    const timeline = LogoWinkTimeline(
      origin: Offset(30, 40),
      screen: Size(400, 800),
    );
    const total = 4400.0;
    const syll = BirdyMotion.logoWinkSyllable;
    const start = BirdyMotion.logoWinkTakeoffEnd;
    // Before the arrival: closed beak, no note.
    expect(timeline.mouthAt(start - 0.01), 0);
    for (var i = 0; i < BirdyMotion.logoWinkSyllables; i++) {
      expect(timeline.noteAt(start - 0.01, i), isNull);
    }
    // Mid syllable: beak wide open, and each note flies in turn.
    const mid = start + BirdyMotion.logoWinkSyllableLength / 2;
    expect(timeline.mouthAt(mid), closeTo(1, 0.01));
    expect(timeline.mouthAt(mid + syll), closeTo(1, 0.01));
    for (var i = 0; i < BirdyMotion.logoWinkSyllables; i++) {
      final t =
          start +
          i * syll +
          BirdyMotion.logoWinkNoteDelay +
          BirdyMotion.logoWinkNoteLife / 2;
      expect(timeline.noteAt(t, i), closeTo(0.5, 0.01));
    }
    // Gone before the bird leaves; total run stays short.
    for (var i = 0; i < BirdyMotion.logoWinkSyllables; i++) {
      expect(timeline.noteAt(BirdyMotion.logoWinkHoverEnd, i), isNull);
    }
    expect(timeline.mouthAt(BirdyMotion.logoWinkEyeStart), 0);
    expect(BirdyMotion.logoWink.inMilliseconds, lessThanOrEqualTo(4500));
    expect(total, BirdyMotion.logoWink.inMilliseconds);
  });

  test('reduced motion: no beak, no notes', () {
    const timeline = LogoWinkTimeline(
      origin: Offset(30, 40),
      screen: Size(400, 800),
      reduced: true,
    );
    for (var k = 0; k <= 20; k++) {
      final t = k / 20;
      expect(timeline.mouthAt(t), 0);
      for (var i = 0; i < BirdyMotion.logoWinkSyllables; i++) {
        expect(timeline.noteAt(t, i), isNull);
      }
    }
  });

  testWidgets('notes are painted during the song only, one tweet', (
    tester,
  ) async {
    var plays = 0;
    await tester.pumpWidget(app(onTap: () => plays++));
    await doubleTap(tester);
    final painter =
        tester
            .widgetList<CustomPaint>(find.byType(CustomPaint))
            .map((w) => w.painter)
            .whereType<LogoNotesPainter>()
            .single;
    final timeline = painter.timeline;
    int flying() {
      final t = painter.animation.value;
      return [
        for (var i = 0; i < BirdyMotion.logoWinkSyllables; i++)
          timeline.noteAt(t, i),
      ].whereType<double>().length;
    }

    expect(flying(), 0);
    await tester.pump(
      BirdyMotion.logoWink * BirdyMotion.logoWinkTakeoffEnd +
          BirdyMotion.logoWink * BirdyMotion.logoWinkSyllable * 1.5,
    );
    expect(flying(), greaterThan(0));
    expect(plays, 1);
    await tester.pump(
      BirdyMotion.logoWink * (BirdyMotion.logoWinkHoverEnd - 0.4),
    );
    await tester.pump(BirdyMotion.logoWink * 0.1);
    expect(painter.animation.value, greaterThan(BirdyMotion.logoWinkHoverEnd));
    expect(flying(), 0);

    await pumpThroughRun(tester, BirdyMotion.logoWink);
    expect(plays, 1);
  });

  testWidgets('reduced motion paints no notes layer', (tester) async {
    await tester.pumpWidget(app(reduced: true, onTap: () {}));
    await doubleTap(tester);
    expect(
      tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .map((w) => w.painter)
          .whereType<LogoNotesPainter>(),
      isEmpty,
    );
    await pumpThroughRun(tester, BirdyMotion.logoWinkReduced);
  });

  testWidgets('a plain single tap still sings and chirps, unchanged', (
    tester,
  ) async {
    var plays = 0;
    await tester.pumpWidget(app(onTap: () => plays++));
    await tester.tap(find.text('BG'));
    // No second tap follows: the double-tap timeout resolves it as a
    // single tap.
    await tester.pump(kDoubleTapTimeout + const Duration(milliseconds: 50));

    expect(plays, 1);
    expect(find.byType(LogoWinkBird), findsNothing);
    // The phrase animation is running (sung on this single tap).
    expect(tester.hasRunningAnimations, isTrue);
    await tester.pump(const Duration(seconds: 5));
  });
}
