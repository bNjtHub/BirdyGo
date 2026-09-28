import 'package:birdnet_live/fork/home/singing_logo.dart';
import 'package:birdnet_live/fork/splash/birdygo_splash_painter.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Frames land a little after the exact end of a phrase.
const _margin = 100;

void main() {
  const interval = Duration(seconds: 2);
  final phrase = Duration(
    milliseconds:
        (BirdyGoSingingPainter.firstPhrase + BirdyGoSingingPainter.phraseLength)
            .round() +
        _margin,
  );
  final later = Duration(
    milliseconds: BirdyGoSingingPainter.phraseLength.round() + _margin,
  );

  Widget app({bool reduced = false, int tab = 0}) => MaterialApp(
    builder:
        (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
          child: child!,
        ),
    home: Scaffold(
      body: IndexedStack(
        index: tab,
        children: const [
          Center(child: SingingLogo(interval: interval, wordmark: Text('BG'))),
          SizedBox(),
        ],
      ),
    ),
  );

  /// Home shown, first phrase sung (the ticker starts on the next frame).
  Future<void> arrive(WidgetTester tester) async {
    await tester.pumpWidget(app());
    await tester.pump();
    await tester.pump(phrase);
    await tester.pump();
  }

  BirdyGoSingingPainter painter(WidgetTester tester) =>
      tester
              .widget<CustomPaint>(
                find.descendant(
                  of: find.byType(SingingLogo),
                  matching: find.byType(CustomPaint),
                ),
              )
              .painter!
          as BirdyGoSingingPainter;

  testWidgets('sings one phrase on arrival, then stays still', (tester) async {
    await tester.pumpWidget(app());
    await tester.pump();
    expect(tester.hasRunningAnimations, isTrue);
    await tester.pump(phrase);
    await tester.pump();
    expect(tester.hasRunningAnimations, isFalse);
    // Still after the phrase, until the interval.
    await tester.pump(interval ~/ 2);
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('sings again after the interval, one phrase only', (
    tester,
  ) async {
    await arrive(tester);
    await tester.pump(interval);
    expect(tester.hasRunningAnimations, isTrue);
    await tester.pump(later);
    await tester.pump();
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('reduced motion: the settled mark, never animated', (
    tester,
  ) async {
    await tester.pumpWidget(app(reduced: true));
    expect(tester.hasRunningAnimations, isFalse);
    expect(painter(tester).still, isTrue);
    await tester.pump(interval * 3);
    expect(tester.hasRunningAnimations, isFalse);
    await tester.tap(find.text('BG'));
    await tester.pump(kDoubleTapTimeout + const Duration(milliseconds: 50));
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('another tab: nothing runs, nothing scheduled', (tester) async {
    await tester.pumpWidget(app());
    await tester.pump(const Duration(milliseconds: 500));
    // Leaving mid-phrase stops the ticker.
    await tester.pumpWidget(app(tab: 1));
    expect(tester.hasRunningAnimations, isFalse);
    await tester.pump(interval * 3);
    expect(tester.hasRunningAnimations, isFalse);
    // Back on the home: the next phrase comes after the interval.
    await tester.pumpWidget(app());
    expect(tester.hasRunningAnimations, isFalse);
    await tester.pump(interval);
    expect(tester.hasRunningAnimations, isTrue);
  });

  testWidgets('a screen above the home: no phrase', (tester) async {
    await arrive(tester);
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.push(MaterialPageRoute<void>(builder: (_) => const Scaffold()));
    await tester.pumpAndSettle();
    await tester.pump(interval * 3);
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('a tap sings once', (tester) async {
    await arrive(tester);
    await tester.tap(find.text('BG'));
    // A double-tap recognizer is also armed (J6f flight): the tap only
    // resolves as a single tap once the double-tap timeout passes.
    await tester.pump(kDoubleTapTimeout + const Duration(milliseconds: 50));
    expect(tester.hasRunningAnimations, isTrue);
    await tester.pump(later);
    await tester.pump();
    expect(tester.hasRunningAnimations, isFalse);
  });
}
