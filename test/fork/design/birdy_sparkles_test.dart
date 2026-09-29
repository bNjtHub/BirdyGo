import 'package:birdnet_live/fork/design/birdy_motion.dart';
import 'package:birdnet_live/fork/design/widgets/birdy_sparkles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(WidgetTester tester, {bool reduced = false}) =>
    tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: reduced),
          child: const Center(
            child: BirdySparkles(
              offsets: BirdySparkles.aroundBird,
              delay: BirdyMotion.firstEncounterSparkleDelay,
            ),
          ),
        ),
      ),
    );

Finder get _icons => find.descendant(
  of: find.byType(BirdySparkles),
  matching: find.byType(Icon),
);

double _opacityOf(WidgetTester tester, int index) =>
    tester
        .widgetList<Opacity>(
          find.descendant(
            of: find.byType(BirdySparkles),
            matching: find.byType(Opacity),
          ),
        )
        .elementAt(index)
        .opacity;

void main() {
  testWidgets('sparkles pop one after the other, once, then leave', (
    tester,
  ) async {
    await _pump(tester);
    await tester.pump();
    expect(_icons, findsNWidgets(4));
    // Nothing before the delay.
    expect(_opacityOf(tester, 0), 0);
    // First one at its peak, the last one not started yet.
    await tester.pump(
      BirdyMotion.firstEncounterSparkleDelay +
          BirdyMotion.sparklePop * BirdyMotion.sparklePeakAt,
    );
    expect(_opacityOf(tester, 0), closeTo(1, 0.05));
    expect(_opacityOf(tester, 3), 0);
    // All done, and gone from the tree.
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(seconds: 1));
    expect(_icons, findsNothing);
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('reduced motion: no sparkle at all', (tester) async {
    await _pump(tester, reduced: true);
    await tester.pump(const Duration(seconds: 3));
    expect(_icons, findsNothing);
    expect(tester.hasRunningAnimations, isFalse);
  });
}
