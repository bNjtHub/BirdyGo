import 'package:birdnet_live/fork/design/birdy_motion.dart';
import 'package:birdnet_live/fork/design/birdy_tokens.dart';
import 'package:birdnet_live/fork/design/widgets/birdy_shimmer.dart';
import 'package:birdnet_live/fork/design/widgets/birdy_skeleton.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget child, {bool reduced = false, bool dark = false}) =>
    MaterialApp(
      key: ValueKey(dark),
      theme: ThemeData(
        extensions: [dark ? BirdyColors.dark : BirdyColors.light],
      ),
      home: MediaQuery(
        data: MediaQueryData(
          size: const Size(400, 800),
          disableAnimations: reduced,
        ),
        child: Scaffold(body: child),
      ),
    );

final _clock = BirdyShimmerClock.instance;

Widget _skeletons() => Column(
  children: [
    BirdySkeleton.box(width: 200, height: 40),
    BirdySkeleton.text(const TextStyle(fontSize: 15)),
  ],
);

void main() {
  test('sweep progress: eased, rests during the pause', () {
    expect(BirdyShimmerClock.progressAt(Duration.zero), 0);
    final mid = BirdyShimmerClock.progressAt(BirdyMotion.shimmerSweep ~/ 2)!;
    expect(mid, closeTo(0.5, 1e-6));
    final quarter =
        BirdyShimmerClock.progressAt(BirdyMotion.shimmerSweep ~/ 4)!;
    expect(quarter, lessThan(0.25)); // ease-in-out starts slowly
    expect(
      BirdyShimmerClock.progressAt(
        BirdyMotion.shimmerSweep + BirdyMotion.shimmerPause ~/ 2,
      ),
      isNull,
    );
    // Cycle repeats.
    expect(BirdyShimmerClock.progressAt(BirdyShimmerClock.period * 3), 0);
    expect(
      BirdyShimmerClock.period.inMilliseconds,
      inInclusiveRange(1300, 1600),
    );
  });

  test('band travels from off the left edge to off the right edge', () {
    expect(BirdyShimmer.bandStart(0, 400), -200);
    expect(BirdyShimmer.bandStart(1, 400), 400);
  });

  testWidgets('shimmer animates: the shared progress changes over time', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_skeletons()));
    expect(_clock.isRunning, isTrue);
    await tester.pump(const Duration(milliseconds: 200));
    final a = _clock.progress.value;
    await tester.pump(const Duration(milliseconds: 300));
    final b = _clock.progress.value;
    expect(a, isNotNull);
    expect(b, isNotNull);
    expect(b, greaterThan(a!));
    expect(find.byType(ShaderMask), findsNWidgets(2));
    // During the pause nothing is painted over the shapes.
    await tester.pump(const Duration(milliseconds: 700));
    expect(_clock.progress.value, isNull);
    expect(find.byType(ShaderMask), findsNothing);
  });

  testWidgets('all shapes share one ticker', (tester) async {
    await tester.pumpWidget(
      _app(
        SingleChildScrollView(
          child: Column(children: [for (var i = 0; i < 10; i++) _skeletons()]),
        ),
      ),
    );
    expect(_clock.users, 20);
    expect(tester.binding.transientCallbackCount, 1);
  });

  testWidgets('reduced motion: static, no ticker', (tester) async {
    await tester.pumpWidget(_app(_skeletons(), reduced: true));
    await tester.pump(const Duration(milliseconds: 300));
    expect(_clock.isRunning, isFalse);
    expect(tester.binding.transientCallbackCount, 0);
    expect(find.byType(ShaderMask), findsNothing);
    final box = tester.widget<Container>(find.byType(Container).first);
    expect(
      (box.decoration! as BoxDecoration).color,
      BirdyColors.light.skeleton,
    );
  });

  testWidgets('ticker stops when the skeleton is removed', (tester) async {
    await tester.pumpWidget(_app(_skeletons()));
    expect(_clock.isRunning, isTrue);
    await tester.pumpWidget(_app(const SizedBox()));
    expect(_clock.isRunning, isFalse);
    expect(_clock.users, 0);
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('ticker stops when hidden by TickerMode', (tester) async {
    Widget tree(bool on) => _app(TickerMode(enabled: on, child: _skeletons()));
    await tester.pumpWidget(tree(true));
    expect(_clock.isRunning, isTrue);
    await tester.pumpWidget(tree(false));
    expect(_clock.isRunning, isFalse);
    await tester.pumpWidget(tree(true));
    expect(_clock.isRunning, isTrue);
    await tester.pumpWidget(_app(const SizedBox()));
    expect(_clock.isRunning, isFalse);
  });

  test('sheen and base colors come from the tokens, per theme', () {
    const l = BirdyColors.light;
    const d = BirdyColors.dark;
    expect(l.skeletonSheen.a, greaterThan(d.skeletonSheen.a));
    expect(d.skeletonSheen.a, lessThan(0.2)); // subtle in dark
    expect(l.skeletonSheen.a, lessThan(0.7));
    expect(l.skeleton, isNot(d.skeleton));
  });

  testWidgets('shapes keep their size and skeleton fill in both themes', (
    tester,
  ) async {
    for (final dark in [false, true]) {
      await tester.pumpWidget(_app(_skeletons(), dark: dark));
      await tester.pump(const Duration(seconds: 1)); // theme animation
      expect(tester.getSize(find.byType(Container).first), const Size(200, 40));
      final box = tester.widget<Container>(find.byType(Container).first);
      expect(
        (box.decoration! as BoxDecoration).color,
        (dark ? BirdyColors.dark : BirdyColors.light).skeleton,
      );
      await tester.pumpWidget(_app(const SizedBox()));
    }
  });
}
