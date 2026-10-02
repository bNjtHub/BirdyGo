/// BirdyGo motion tokens (J6a), from fork/DESIGN.md (section Animations).
///
/// Restraint rules: one effect at a time, 8 px of travel at most, scale never
/// under 0.97 (0.95 only for an appearance from nothing), no rotation, bounce
/// or shake, 500 ms at most for a celebration. With reduced motion, keep the
/// fades only.
library;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

abstract final class BirdyMotion {
  /// Welcome bird step of the onboarding (J6i).
  static const Duration welcomeBird = Duration(milliseconds: 1500);

  /// Staggered entrance of the intro / onboarding cards and rows: card `i`
  /// enters 120 ms + 100 ms per index in, rows 80 ms + 100 ms per index in.
  static Duration introCardDelay(int i) => Duration(milliseconds: 120 + i * 100);
  static Duration introRowDelay(int i) => Duration(milliseconds: 80 + i * 100);

  /// Wing flap of the BirdyGo logo, and the live table's singing bars.
  static const Duration logoWing = Duration(milliseconds: 480);
  static const Duration singingBars = Duration(milliseconds: 900);

  /// The « chante » bars follow the score of the current window (J7): the
  /// tallest bar reaches this share of the height at a score of 0, all of
  /// it at a score of 1.
  static const double singingBarsMinScale = 0.5;

  /// How long the « Confirmé » pill replaces the level badge of a row that
  /// just became « Sûr » (J7).
  static const Duration confirmedShown = Duration(milliseconds: 2500);

  /// An answered card leaving the quick review.
  static const Duration cardFly = Duration(milliseconds: 260);

  /// Shortest time the splash stays up (whole intro, footer faded in).
  static const Duration splashMinimum = Duration(milliseconds: 4500);

  /// Wait for one frame before yielding to the background.
  static const Duration framePauseTimeout = Duration(milliseconds: 100);

  /// Idle bars of the quiz stage: period and start delay of bar `i`.
  static Duration quizBarPeriod(int i) => Duration(milliseconds: 700 + (i % 5) * 90);
  static Duration quizBarDelay(int i) => Duration(milliseconds: (i * 70) % 600);

  /// Loops of the quiz decor (sparks, twinkles, star burst).
  static const Duration decorSparks = Duration(milliseconds: 2200);
  static const Duration decorTwinkles = Duration(milliseconds: 2600);
  static const Duration decorBurst = Duration(milliseconds: 1200);

  /// Enter, exit and press curve. Never use `Curves.easeIn` for UI.
  static const Curve standard = Cubic(0.23, 1, 0.32, 1);

  /// On-screen moves (a live row going back to the top).
  static const Curve move = Cubic(0.77, 0, 0.175, 1);

  /// Button press, scale 0.97.
  static const Duration press = Duration(milliseconds: 120);

  /// Element entering (200 to 250 ms).
  static const Duration enter = Duration(milliseconds: 220);

  /// Element leaving: always shorter than [enter].
  static const Duration exit = Duration(milliseconds: 150);

  /// On-screen move.
  static const Duration reorder = Duration(milliseconds: 250);

  /// Counter going up: 1 → 1.08 → 1.
  static const Duration counterBump = Duration(milliseconds: 180);

  /// New species in the live table: 8 px slide, 0.97 → 1, fade, light haptic.
  static const Duration newSpecies = Duration(milliseconds: 220);

  /// Very first species: « Première rencontre » card popping in (fade,
  /// 0.97 → 1), once.
  static const Duration firstEncounter = Duration(milliseconds: 250);

  /// « Première fois » sequence (J6f, AppPremiere mockup, bg-pop, bg-ring,
  /// bg-rise, bg-land): the bird pops [firstEncounterBirdDelay] after the
  /// card, its ring spreads over [firstEncounterRing], the texts rise from
  /// [firstEncounterTextDelay] in [staggerStep]s, and one confetti burst
  /// leaves the bird at [firstEncounterConfettiDelay]. The ring and the
  /// confetti outlast [celebrationMax]: an accepted exception (DESIGN.md).
  static const Duration firstEncounterBirdDelay = Duration(milliseconds: 60);
  static const Duration firstEncounterRing = Duration(milliseconds: 1200);
  static const Duration firstEncounterTextDelay = Duration(milliseconds: 120);
  static const Duration firstEncounterConfettiDelay = Duration(
    milliseconds: 250,
  );

  /// « Première rencontre » in a series (J6h, AppEcoute mockup): the card
  /// closes by itself, or moves on to the next species, after
  /// [firstEncounterShown]; the countdown bar empties linearly over it.
  static const Duration firstEncounterShown = Duration(seconds: 6);

  /// The second confetti salve leaves this much after the first.
  static const Duration firstEncounterSecondSalveDelay = Duration(
    milliseconds: 380,
  );

  /// Oriole sparkles around the bird (`BirdySparkles`): each pops for
  /// [sparklePop], [sparkleStagger] after the previous one, from
  /// [firstEncounterSparkleDelay] on. Once, never looping.
  static const Duration sparklePop = Duration(milliseconds: 700);
  static const Duration sparkleStagger = Duration(milliseconds: 160);
  static const Duration firstEncounterSparkleDelay = Duration(
    milliseconds: 500,
  );
  static const double sparklePeakAt = 0.4;
  static const double sparklePeakScale = 1.2;

  /// bg-ring: peak opacity (at [ringPeakAt] of the ring) and final scale.
  static const double ringPeakOpacity = 0.6;
  static const double ringPeakAt = 0.35;
  static const double ringScale = 1.1;

  /// bg-glow: the soft disc behind the bird peaks at this share of the
  /// ring, at [tintMaxOpacity].
  static const double glowPeakAt = 0.4;

  /// Rare bird, after « C'est bien lui »: one soft ring and the pill.
  static const Duration rareBird = Duration(milliseconds: 450);

  /// Arrival of the rare card (J6h, AppEcoute mockup, RareHalo), once: the
  /// dotted ring draws itself in [rareRing] turning from [rareRingFromTurns]
  /// to [rareRingToTurns], appearing over the first [rareRingAppearAt] of
  /// it, from [rareRingFromScale]; the halo pulses [rareGlowPulses] times
  /// for [rareGlowPulse] from [rareGlowDelay]; the diamonds pop one after
  /// the other ([rareDiamondPop] each, [rareDiamondStagger] apart, from
  /// [rareDiamondDelay]). Nothing at all with reduced motion.
  static const Duration rareRing = Duration(milliseconds: 2400);
  static const double rareRingFromTurns = -0.25;
  static const double rareRingToTurns = 1 / 3;
  static const double rareRingAppearAt = 0.35;
  static const double rareRingFromScale = 0.85;
  static const Duration rareGlowDelay = Duration(milliseconds: 350);
  static const Duration rareGlowPulse = Duration(milliseconds: 1400);
  static const int rareGlowPulses = 2;
  static const double rareGlowPeakOpacity = 0.55;
  static const double rareGlowPeakScale = 1.18;
  static const double rareGlowEndScale = 1.32;
  static const Duration rareDiamondDelay = Duration(milliseconds: 450);
  static const Duration rareDiamondStagger = Duration(milliseconds: 220);
  static const Duration rareDiamondPop = Duration(milliseconds: 1600);

  /// How long the rare card stays after each answer (J6h): the countdown
  /// bar of « C'est bien lui » and of the two quieter answers.
  static const Duration rareConfirmedShown = Duration(seconds: 6);
  static const Duration rareAnsweredShown = Duration(seconds: 3);

  /// New status: emblem fades in, text follows [newStatusTextDelay] later.
  static const Duration newStatus = Duration(milliseconds: 300);
  static const Duration newStatusTextDelay = Duration(milliseconds: 60);

  /// Animated icon (tips): waits for the card fade, then plays once.
  static const Duration iconDelay = Duration(milliseconds: 150);
  static const Duration iconPlay = Duration(milliseconds: 450);

  /// Travel of a sliding icon, under [maxOffset].
  static const double iconOffset = 6;

  /// Upper bound of any celebration.
  static const Duration celebrationMax = Duration(milliseconds: 500);

  /// The home logo's double-tap easter egg (J6h, logo_flight.dart): the bird
  /// flies to the middle of the screen, winks, and flies off and back.
  /// Explicit, user-triggered exception to [celebrationMax], see DESIGN.md's
  /// Logo section. One controller, the legs are shares of [logoWink]
  /// (written in milliseconds of its 4.4 s): take-off until
  /// [logoWinkTakeoffEnd], hover until [logoWinkHoverEnd] (the tweet and the
  /// song from the arrival, the wink between [logoWinkEyeStart] and
  /// [logoWinkEyeEnd], head tilt), off-screen until [logoWinkExitEnd], then
  /// back to its place.
  static const Duration logoWink = Duration(milliseconds: 4400);
  static const double logoWinkTakeoffEnd = 800 / 4400;
  static const double logoWinkHoverEnd = 3100 / 4400;
  static const double logoWinkExitEnd = 3700 / 4400;
  static const double logoWinkEyeStart = 2400 / 4400;
  static const double logoWinkEyeEnd = 2950 / 4400;

  /// The song at the middle of the screen, from [logoWinkTakeoffEnd] with
  /// the tweet: [logoWinkSyllables] syllables [logoWinkSyllable] apart, the
  /// beak open for [logoWinkSyllableLength] of each, one note per syllable
  /// leaving the beak [logoWinkNoteDelay] later and flying (rising, fading)
  /// for [logoWinkNoteLife], [logoWinkNoteReach] times the header's flight.
  /// All shares of [logoWink]; the last note is gone before [logoWinkHoverEnd].
  static const int logoWinkSyllables = 4;
  static const double logoWinkSyllable = 400 / 4400;
  static const double logoWinkSyllableLength = 360 / 4400;
  static const double logoWinkNoteDelay = 80 / 4400;
  static const double logoWinkNoteLife = 1000 / 4400;
  static const double logoWinkNoteReach = 1.6;

  /// Size of the bird at the middle of the screen, as a multiple of the
  /// header mark, and the size it has while off-screen (it shrinks back to
  /// 1 on its way home).
  static const double logoWinkScale = 3.5;
  static const double logoWinkFarScale = 2;

  /// Head tilt while hovering, in degrees, and the hover's gentle bob, in
  /// logical pixels (under [maxOffset]) over [logoWinkBobCycles] cycles.
  static const double logoWinkTiltDegrees = 7;
  static const double logoWinkBob = 6;
  static const double logoWinkBobCycles = 2;

  /// The bird throws its head back to sing (J7), like a real songbird: ONE
  /// gesture per phrase, around the first notes leaving the beak, and no
  /// deformation (no stretch, no squash) and no translation. The whole bird
  /// leans backward rigidly by [logoLeanDegrees] about its feet, in
  /// [logoLeanIn] (easeOutCubic, snappy), holds [logoLeanHold] while the
  /// notes leave, and settles in [logoLeanOut] (easeInOutCubic). Painted from
  /// the singing clock, so it stays in sync with the sound; reduced motion
  /// draws none of it.
  static const double logoLeanIn = 160;
  static const double logoLeanHold = 200;
  static const double logoLeanOut = 420;
  static const double logoLeanDegrees = 10;

  /// Wing beats while flying, and the share of a bar the beat never takes.
  static const int logoWinkFlapCycles = 6;
  static const double logoWinkFlapFloor = 0.35;

  /// Reduced motion: a quick wink in place, nothing else.
  static const Duration logoWinkReduced = Duration(milliseconds: 450);

  /// Delay between list items entering, over [staggerMaxItems] items.
  static const Duration staggerStep = Duration(milliseconds: 40);
  static const int staggerMaxItems = 5;

  /// Palmarès podium (J6f-f, `AppPalmares` mockup): fade and scale
  /// [appearScale] → 1, no bounce (the mockup's 0.7 → 1.05 → 1 keyframes
  /// are not used, DESIGN.md bans bounce and a scale under 0.97 except this
  /// from-nothing case). Steps enter in visual order (2nd, 1st, 3rd).
  static const Duration podiumPopIn = Duration(milliseconds: 380);
  static const List<Duration> podiumPopInDelay = [
    Duration(milliseconds: 80),
    Duration.zero,
    Duration(milliseconds: 160),
  ];

  /// Palmarès row bar filling in (J6f-f): capped by [staggerMaxItems] like
  /// any other list, not the mockup's uncapped 30 ms/row.
  static const Duration rankingBarGrow = Duration(milliseconds: 500);

  /// Loading skeleton shimmer (the only allowed loop, DESIGN.md): a diagonal
  /// light band sweeps left to right in [shimmerSweep], then rests for
  /// [shimmerPause]. Only while loading; static with reduced motion.
  static const Duration shimmerSweep = Duration(milliseconds: 1100);
  static const Duration shimmerPause = Duration(milliseconds: 300);
  static const Curve shimmerCurve = Curves.easeInOut;

  /// Band width as a share of the screen width, and its tilt in degrees.
  static const double shimmerBandWidth = 0.5;
  static const double shimmerTiltDegrees = 20;

  /// Soft falloff of the band: opacity share at each stop, edge to edge.
  static const List<double> shimmerBandAlphas = [
    0,
    0.12,
    0.45,
    1,
    0.45,
    0.12,
    0,
  ];
  static const List<double> shimmerBandStops = [
    0,
    0.15,
    0.32,
    0.5,
    0.68,
    0.85,
    1,
  ];

  static const double pressScale = 0.97;

  /// « Écouter » disc of the bar (J6j): the one press deeper than
  /// [pressScale], an explicit exception (DESIGN.md).
  static const double listenDiscPressScale = 0.95;

  /// Starting scale of an element entering.
  static const double enterScale = 0.97;

  /// Starting scale of an element appearing from nothing (with opacity 0).
  static const double appearScale = 0.95;

  static const double counterBumpScale = 1.08;

  /// Maximum travel of an element, in logical pixels.
  static const double maxOffset = 8;

  /// Maximum opacity of a bird-colored tint behind a celebration.
  static const double tintMaxOpacity = 0.15;

  /// Bottom sheet spring.
  static final SpringDescription sheetSpring =
      SpringDescription.withDampingRatio(mass: 1, stiffness: 500, ratio: 0.85);

  /// Period of the listening logo's wing-bar level meter (J6f, J6h,
  /// `BirdyListeningLogo`, `BirdyGoLogoPainter`): the one loop allowed in the
  /// fork, replacing the live dot's pulse. Calm, no bounce (curve
  /// [standard] on each half); reduced motion stops it (fork/DESIGN.md,
  /// Animations). Each bar swells between [listeningBarMin] and its full
  /// length, [listeningBarStagger] (share of the period) after the previous
  /// one (AppEcoute mockup: 0.45 → 1, 1 s, 0.18 s).
  static const Duration listeningLevelPeriod = Duration(milliseconds: 1000);
  static const double listeningBarMin = 0.45;
  static const double listeningBarStagger = 0.18;

  /// Wing icon wave on « Écouter » (J6h): every [wingWaveInterval], exactly
  /// (J6j, no jitter), the four bars swell one after the other in
  /// [wingWave], then return exactly to rest. A gentle level-meter hint, not
  /// a loop: at rest nothing ticks.
  /// Each bar starts [wingWaveStagger] (share of the wave) after the
  /// previous one and grows by [wingWaveAmplitude] of its length at most.
  static const Duration wingWave = Duration(milliseconds: 900);
  static const Duration wingWaveInterval = Duration(seconds: 7);
  static const Curve wingWaveCurve = Curves.easeInOut;
  static const double wingWaveStagger = 0.12;
  static const double wingWaveAmplitude = 0.22;

  /// Whether the platform asks for reduced motion.
  static bool reduced(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  /// Entrance delay of the list item at [index]: 40 ms steps, the items
  /// after the fifth enter with the fifth.
  static Duration staggerDelay(int index) =>
      staggerStep * (index.clamp(0, staggerMaxItems - 1));
}

/// Shared confetti (`BirdyConfetti`, quiz-fx.js of the Quiz v2 mockup):
/// one emission window, then particles fading out. Physics are the
/// confetti package's units.
abstract final class BirdyConfettiMotion {
  /// Emission window: a single burst.
  static const Duration emission = Duration(milliseconds: 300);

  /// Particles of a burst, and of a whole rain (split between [rainSpots]).
  static const int burstParticles = 110;
  static const int rainParticles = 132;

  /// Life of the layer: particles fade out over the last [fade]
  /// (quiz-fx.js: 1.9 → 2.3 s, rain 4.2 → 4.6 s).
  static const Duration burstLife = Duration(milliseconds: 2300);
  static const Duration rainLife = Duration(milliseconds: 4600);
  static const Duration fade = Duration(milliseconds: 400);

  /// The rain falls from three points across the top.
  static const List<double> rainSpots = [1 / 6, 1 / 2, 5 / 6];

  static const double burstMinForce = 12;
  static const double burstMaxForce = 34;
  static const double burstGravity = 0.3;
  static const double rainMinForce = 4;
  static const double rainMaxForce = 14;
  static const double rainGravity = 0.08;
  static const double drag = 0.05;

  /// Particle sizes, and the share of dots among the rectangles.
  static const Size minSize = Size(6, 4);
  static const Size maxSize = Size(11, 7);
  static const double dotShare = 0.3;
}

/// Haptics of BirdyGo moments (new species, first encounter, new status).
abstract final class BirdyHaptics {
  static Future<void> light() => HapticFeedback.lightImpact();
}

/// Physics of one confetti burst (`BirdyConfetti.burst(burst: ...)`): how
/// many pieces, how hard they leave, how fast they fall, and the life of
/// the layer (they fade out over the last [BirdyConfettiMotion.fade]).
class BirdyConfettiBurst {
  const BirdyConfettiBurst({
    required this.particles,
    required this.minForce,
    required this.maxForce,
    required this.gravity,
    required this.life,
  });

  final int particles;
  final double minForce;
  final double maxForce;
  final double gravity;
  final Duration life;

  /// The burst of the quiz, statuses and the first encounter until J6h.
  static const BirdyConfettiBurst standard = BirdyConfettiBurst(
    particles: BirdyConfettiMotion.burstParticles,
    minForce: BirdyConfettiMotion.burstMinForce,
    maxForce: BirdyConfettiMotion.burstMaxForce,
    gravity: BirdyConfettiMotion.burstGravity,
    life: BirdyConfettiMotion.burstLife,
  );

  /// « Première rencontre » fireworks (AppEcoute mockup, Burst): a first
  /// salve of 22 pieces reaching far, then 14 shorter ones, each falling a
  /// little before fading (1.5 to 1.9 s).
  static const BirdyConfettiBurst firstEncounterMain = BirdyConfettiBurst(
    particles: 22,
    minForce: 22,
    maxForce: 40,
    gravity: 0.3,
    life: Duration(milliseconds: 1900),
  );
  static const BirdyConfettiBurst firstEncounterSecond = BirdyConfettiBurst(
    particles: 14,
    minForce: 16,
    maxForce: 30,
    gravity: 0.3,
    life: Duration(milliseconds: 1900),
  );
}
