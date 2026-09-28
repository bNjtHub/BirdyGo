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
          body: Center(
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
    of: find.byWidgetPredicate((w) => w is CustomPaint && w.painter is BirdyGoSingingPainter),
    matching: find.byType(Opacity),
  );

  testWidgets(
    'a double tap starts the flight: overlay bird, header logo hidden',
    (tester) async {
      var plays = 0;
      await tester.pumpWidget(app(onTap: () => plays++));
      await doubleTap(tester);

      expect(find.byType(LogoFlightBird), findsOneWidget);
      expect(tester.widget<Opacity>(opacityOfMark().first).opacity, 0);
      // The tweet plays once, at take-off.
      expect(plays, 1);
    },
  );

  testWidgets('the flight ends with the logo back', (tester) async {
    await tester.pumpWidget(app(onTap: () {}));
    await doubleTap(tester);
    expect(find.byType(LogoFlightBird), findsOneWidget);

    await tester.pump(
      BirdyMotion.logoFlight + const Duration(milliseconds: 50),
    );
    await tester.pump();

    expect(find.byType(LogoFlightBird), findsNothing);
    expect(tester.widget<Opacity>(opacityOfMark().first).opacity, 1);
  });

  testWidgets('a second double tap while flying is ignored', (tester) async {
    var plays = 0;
    await tester.pumpWidget(app(onTap: () => plays++));
    await doubleTap(tester);
    expect(find.byType(LogoFlightBird), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 300));
    await doubleTap(tester);

    // Still exactly one bird flying, and the tweet has not played again.
    expect(find.byType(LogoFlightBird), findsOneWidget);
    expect(plays, 1);
  });

  testWidgets('reduced motion: a double tap behaves like a tap, no flight', (
    tester,
  ) async {
    var plays = 0;
    await tester.pumpWidget(app(reduced: true, onTap: () => plays++));
    await doubleTap(tester);

    expect(find.byType(LogoFlightBird), findsNothing);
    expect(tester.widget<Opacity>(opacityOfMark().first).opacity, 1);
    expect(plays, 1);
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
    expect(find.byType(LogoFlightBird), findsNothing);
    // The phrase animation is running (sung on this single tap).
    expect(tester.hasRunningAnimations, isTrue);
    await tester.pump(const Duration(seconds: 5));
  });
}
