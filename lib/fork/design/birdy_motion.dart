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

  /// bg-ring: peak opacity (at [ringPeakAt] of the ring) and final scale.
  static const double ringPeakOpacity = 0.6;
  static const double ringPeakAt = 0.35;
  static const double ringScale = 1.1;

  /// bg-glow: the soft disc behind the bird peaks at this share of the
  /// ring, at [tintMaxOpacity].
  static const double glowPeakAt = 0.4;

  /// Rare bird, after « C'est bien lui »: one soft ring and the pill.
  static const Duration rareBird = Duration(milliseconds: 450);

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

  /// The home logo's double-tap flight (J6f): explicit, user-triggered
  /// exception to [celebrationMax], see DESIGN.md's Logo section.
  static const Duration logoFlight = Duration(milliseconds: 2300);

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

  static const double pressScale = 0.97;

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
