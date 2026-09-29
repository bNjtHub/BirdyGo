import 'package:birdnet_live/fork/design/birdy_motion.dart';
import 'package:birdnet_live/fork/design/widgets/birdy_wing_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  _wingAnimationTests();
  testWidgets('paints at 28 by default and at the given size', (tester) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Column(children: [BirdyWingIcon(), BirdyWingIcon(size: 40)]),
      ),
    );
    final sizes =
        tester
            .widgetList<BirdyWingIcon>(find.byType(BirdyWingIcon))
            .map((w) => tester.getSize(find.byWidget(w)))
            .toList();
    expect(sizes, [const Size.square(28), const Size.square(40)]);
    expect(tester.takeException(), isNull);
  });
}

void _wingAnimationTests() {
  Widget host({bool reduced = false}) => MediaQuery(
    data: MediaQueryData(disableAnimations: reduced),
    child: const Directionality(
      textDirection: TextDirection.ltr,
      child: BirdyWingIcon(animated: true),
    ),
  );

  test('the wave is at rest before and after, swells in between', () {
    for (var i = 0; i < 4; i++) {
      expect(BirdyWingIcon.barScale(i, 0), 1.0);
      expect(BirdyWingIcon.barScale(i, 1), 1.0);
    }
    final mid = [for (var i = 0; i < 4; i++) BirdyWingIcon.barScale(i, .5)];
    expect(mid.every((k) => k >= 1 && k <= 1 + BirdyMotion.wingWaveAmplitude),
        isTrue);
    expect(mid.any((k) => k > 1.05), isTrue);
    // Staggered: the first bar peaks before the last one.
    expect(BirdyWingIcon.barScale(0, .3), greaterThan(BirdyWingIcon.barScale(3, .3)));
  });

  testWidgets('waves after the interval, returns to rest, cleans up', (
    tester,
  ) async {
    await tester.pumpWidget(host());
    // Nothing ticks while resting.
    expect(tester.binding.hasScheduledFrame, isFalse);
    await tester.pump(
      BirdyMotion.wingWaveInterval + BirdyMotion.wingWaveJitter,
    );
    await tester.pump(BirdyMotion.wingWave ~/ 2);
    expect(tester.binding.hasScheduledFrame, isTrue);
    await tester.pump(BirdyMotion.wingWave);
    await tester.pump();
    expect(tester.binding.hasScheduledFrame, isFalse);
    // Dispose with the next wave pending: no timer left over.
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('no wave with reduced motion', (tester) async {
    await tester.pumpWidget(host(reduced: true));
    await tester.pump(
      BirdyMotion.wingWaveInterval + BirdyMotion.wingWaveJitter * 2,
    );
    expect(tester.binding.hasScheduledFrame, isFalse);
    await tester.pumpWidget(const SizedBox());
  });
}
