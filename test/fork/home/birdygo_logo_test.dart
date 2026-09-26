import 'package:birdnet_live/fork/home/birdygo_logo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pump(
    WidgetTester tester, {
    double size = 32,
    bool reduceMotion = false,
    bool animate = true,
  }) => tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(disableAnimations: reduceMotion),
      child: Center(child: BirdyGoLogo(size: size, animate: animate)),
    ),
  );

  double progress(WidgetTester tester) {
    final paint = tester.widget<CustomPaint>(
      find.descendant(
        of: find.byType(BirdyGoLogo),
        matching: find.byType(CustomPaint),
      ),
    );
    return (paint.painter! as BirdyGoLogoPainter).progress.value;
  }

  testWidgets('draws the wing once, within 500 ms', (tester) async {
    await pump(tester);
    expect(progress(tester), 0);
    await tester.pump(const Duration(milliseconds: 240));
    expect(progress(tester), inExclusiveRange(0, 1));
    await tester.pump(BirdyGoLogo.duration);
    expect(progress(tester), 1);
    expect(BirdyGoLogo.duration.inMilliseconds, lessThanOrEqualTo(500));
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('reduced motion: drawn at once', (tester) async {
    await pump(tester, reduceMotion: true);
    expect(progress(tester), 1);
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('paints at 32 and 96 without error', (tester) async {
    for (final size in [32.0, 96.0]) {
      await pump(tester, size: size, animate: false);
      expect(tester.getSize(find.byType(BirdyGoLogo)), Size.square(size));
      expect(tester.takeException(), isNull);
    }
  });
}
