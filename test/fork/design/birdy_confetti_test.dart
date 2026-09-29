import 'package:birdnet_live/fork/design/birdy_motion.dart';
import 'package:birdnet_live/fork/design/birdy_tokens.dart';
import 'package:birdnet_live/fork/design/widgets/birdy_confetti.dart';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(
  WidgetTester tester,
  Widget confetti, {
  bool reduced = false,
}) => tester.pumpWidget(
  MediaQuery(
    data: MediaQueryData(
      size: const Size(400, 800),
      disableAnimations: reduced,
    ),
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: Center(child: confetti),
    ),
  ),
);

ConfettiWidget _particles(WidgetTester tester) =>
    tester.widget<ConfettiWidget>(find.byType(ConfettiWidget));

void main() {
  testWidgets('burst: one emission after its delay, then gone', (tester) async {
    const delay = Duration(milliseconds: 250);
    await _pump(tester, const BirdyConfetti.burst(delay: delay));
    final particles = _particles(tester);
    expect(particles.numberOfParticles, BirdyConfettiMotion.burstParticles);
    expect(particles.shouldLoop, isFalse);
    expect(particles.colors, BirdyConfettiColors.burst);
    expect(particles.confettiController.state, ConfettiControllerState.stopped);
    await tester.pump(delay);
    expect(
      _particles(tester).confettiController.state,
      ConfettiControllerState.playing,
    );
    // Faded out after its life: nothing left in the tree.
    await tester.pump(BirdyConfettiMotion.burstLife);
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(ConfettiWidget), findsNothing);
  });

  testWidgets('burst without delay plays after the first frame', (
    tester,
  ) async {
    await _pump(tester, const BirdyConfetti.burst());
    await tester.pump();
    expect(
      _particles(tester).confettiController.state,
      ConfettiControllerState.playing,
    );
    await tester.pump(BirdyConfettiMotion.burstLife);
  });

  testWidgets('rain: a third of the particles, slower, rain colors', (
    tester,
  ) async {
    final controller = ConfettiController(
      duration: BirdyConfettiMotion.emission,
    );
    addTearDown(controller.dispose);
    await _pump(tester, BirdyConfetti.rain(controller: controller));
    final particles = _particles(tester);
    expect(
      particles.numberOfParticles,
      BirdyConfettiMotion.rainParticles ~/ BirdyConfettiMotion.rainSpots.length,
    );
    expect(particles.gravity, BirdyConfettiMotion.rainGravity);
    expect(particles.colors, BirdyConfettiColors.rain);
    // The caller's controller: played by the caller only.
    expect(controller.state, ConfettiControllerState.stopped);
    controller.play();
    await tester.pump();
    expect(controller.state, ConfettiControllerState.playing);
    await tester.pump(BirdyConfettiMotion.rainLife);
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(ConfettiWidget), findsNothing);
  });

  testWidgets('reduced motion: no confetti at all', (tester) async {
    await _pump(tester, const BirdyConfetti.burst(), reduced: true);
    expect(find.byType(ConfettiWidget), findsNothing);
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(ConfettiWidget), findsNothing);
    await _pump(tester, const BirdyConfetti.rain(), reduced: true);
    expect(find.byType(ConfettiWidget), findsNothing);
  });

  testWidgets('never takes taps', (tester) async {
    await _pump(tester, const BirdyConfetti.burst());
    expect(
      find.ancestor(
        of: find.byType(ConfettiWidget),
        matching: find.byType(IgnorePointer),
      ),
      findsWidgets,
    );
    await tester.pump(BirdyConfettiMotion.burstLife);
  });
  testWidgets(
    'burst settings: count, force, gravity and life come from the caller',
    (tester) async {
      const salve = BirdyConfettiBurst.firstEncounterSecond;
      await _pump(tester, const BirdyConfetti.burst(settings: salve));
      final particles = _particles(tester);
      expect(particles.numberOfParticles, salve.particles);
      expect(particles.minBlastForce, salve.minForce);
      expect(particles.maxBlastForce, salve.maxForce);
      expect(particles.gravity, salve.gravity);
      // Faded out after ITS life, which is shorter than the default one.
      expect(salve.life, lessThan(BirdyConfettiMotion.burstLife));
      await tester.pump();
      await tester.pump(salve.life);
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(ConfettiWidget), findsNothing);
    },
  );

  test('the default burst is the one of the quiz and the statuses', () {
    const standard = BirdyConfettiBurst.standard;
    expect(standard.particles, BirdyConfettiMotion.burstParticles);
    expect(standard.minForce, BirdyConfettiMotion.burstMinForce);
    expect(standard.maxForce, BirdyConfettiMotion.burstMaxForce);
    expect(standard.gravity, BirdyConfettiMotion.burstGravity);
    expect(standard.life, BirdyConfettiMotion.burstLife);
  });
}
