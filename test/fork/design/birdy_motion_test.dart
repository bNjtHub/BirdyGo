import 'dart:math' as math;

import 'package:birdnet_live/fork/design/birdy_motion.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('durations follow fork/DESIGN.md', () {
    expect(BirdyMotion.press, const Duration(milliseconds: 120));
    expect(BirdyMotion.enter.inMilliseconds, inInclusiveRange(200, 250));
    expect(BirdyMotion.exit < BirdyMotion.enter, isTrue);
    expect(BirdyMotion.reorder, const Duration(milliseconds: 250));
    expect(BirdyMotion.counterBump, const Duration(milliseconds: 180));
    for (final celebration in [
      BirdyMotion.newSpecies,
      BirdyMotion.firstEncounter,
      BirdyMotion.rareBird,
      BirdyMotion.newStatus + BirdyMotion.newStatusTextDelay,
    ]) {
      expect(celebration <= BirdyMotion.celebrationMax, isTrue);
    }
    expect(BirdyMotion.celebrationMax, const Duration(milliseconds: 500));
  });

  test('restraint rules', () {
    expect(BirdyMotion.pressScale, greaterThanOrEqualTo(0.97));
    expect(BirdyMotion.enterScale, greaterThanOrEqualTo(0.97));
    expect(BirdyMotion.appearScale, 0.95);
    expect(BirdyMotion.counterBumpScale, lessThanOrEqualTo(1.08));
    expect(BirdyMotion.maxOffset, lessThanOrEqualTo(8));
    expect(BirdyMotion.tintMaxOpacity, lessThanOrEqualTo(0.15));
  });

  test('curves are the spec cubics, never ease-in', () {
    expect(BirdyMotion.standard, const Cubic(0.23, 1, 0.32, 1));
    expect(BirdyMotion.move, const Cubic(0.77, 0, 0.175, 1));
    // An ease-out curve is ahead of linear time early on.
    expect(BirdyMotion.standard.transform(0.25), greaterThan(0.5));
    expect(BirdyMotion.standard, isNot(Curves.easeIn));
  });

  test('stagger: 40 ms steps over 5 items', () {
    expect(BirdyMotion.staggerDelay(0), Duration.zero);
    expect(BirdyMotion.staggerDelay(1), const Duration(milliseconds: 40));
    expect(BirdyMotion.staggerDelay(4), const Duration(milliseconds: 160));
    expect(BirdyMotion.staggerDelay(12), const Duration(milliseconds: 160));
  });

  test('sheet spring', () {
    final spring = BirdyMotion.sheetSpring;
    expect(spring.mass, 1);
    expect(spring.stiffness, 500);
    expect(spring.damping, closeTo(0.85 * 2 * math.sqrt(500), 1e-9));
  });

  testWidgets('reduced motion follows MediaQuery', (tester) async {
    late bool reduced;
    Widget probe(bool disable) => MediaQuery(
      data: MediaQueryData(disableAnimations: disable),
      child: Builder(
        builder: (context) {
          reduced = BirdyMotion.reduced(context);
          return const SizedBox();
        },
      ),
    );
    await tester.pumpWidget(probe(true));
    expect(reduced, isTrue);
    await tester.pumpWidget(probe(false));
    expect(reduced, isFalse);
  });
}
