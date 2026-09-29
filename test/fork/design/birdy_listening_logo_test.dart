import 'package:birdnet_live/fork/design/birdy_motion.dart';
import 'package:birdnet_live/fork/design/widgets/birdy_listening_logo.dart';
import 'package:birdnet_live/fork/home/birdygo_logo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(
  WidgetTester tester, {
  bool running = false,
  bool frozen = false,
  bool reduced = false,
  double size = 24,
}) => tester.pumpWidget(
  MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reduced),
      child: Center(
        child: BirdyListeningLogo(size: size, running: running, frozen: frozen),
      ),
    ),
  ),
);

BirdyGoLogoPainter _painter(WidgetTester tester) =>
    tester
        .widgetList<CustomPaint>(
          find.descendant(
            of: find.byType(BirdyListeningLogo),
            matching: find.byType(CustomPaint),
          ),
        )
        .map((p) => p.painter)
        .whereType<BirdyGoLogoPainter>()
        .first;

void main() {
  testWidgets('running: the bars loop; the size is the caller\'s', (
    tester,
  ) async {
    await _pump(tester, running: true, size: 18);
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.hasRunningAnimations, isTrue);
    expect(_painter(tester).level, isNotNull);
    expect(_painter(tester).frozenLevel, isNull);
    expect(tester.getSize(find.byType(BirdyListeningLogo)), const Size(18, 18));
  });

  testWidgets('frozen (paused): bars held, nothing runs', (tester) async {
    await _pump(tester, frozen: true);
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.hasRunningAnimations, isFalse);
    expect(_painter(tester).level, isNull);
    expect(_painter(tester).frozenLevel, BirdyGoLogoPainter.pausedBarLevel);
  });

  testWidgets('idle: the full static logo', (tester) async {
    await _pump(tester);
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.hasRunningAnimations, isFalse);
    expect(_painter(tester).level, isNull);
    expect(_painter(tester).frozenLevel, isNull);
  });

  testWidgets('reduced motion: never animates, even running', (tester) async {
    await _pump(tester, running: true, reduced: true);
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.hasRunningAnimations, isFalse);
    expect(_painter(tester).level, isNull);
    expect(_painter(tester).frozenLevel, isNull);
  });

  testWidgets('running then frozen stops the loop', (tester) async {
    await _pump(tester, running: true);
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.hasRunningAnimations, isTrue);
    await _pump(tester, frozen: true);
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.hasRunningAnimations, isFalse);
  });

  test('the loop keeps the mockup rhythm', () {
    expect(BirdyMotion.listeningLevelPeriod, const Duration(seconds: 1));
    expect(BirdyMotion.listeningBarMin, 0.45);
    expect(BirdyMotion.listeningBarStagger, 0.18);
  });
}
