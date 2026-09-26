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

  /// Very first species: « Première rencontre » card fading in, once.
  static const Duration firstEncounter = Duration(milliseconds: 250);

  /// Rare bird, after « C'est bien lui »: one soft ring and the pill.
  static const Duration rareBird = Duration(milliseconds: 450);

  /// New status: emblem fades in, text follows [newStatusTextDelay] later.
  static const Duration newStatus = Duration(milliseconds: 300);
  static const Duration newStatusTextDelay = Duration(milliseconds: 60);

  /// Upper bound of any celebration.
  static const Duration celebrationMax = Duration(milliseconds: 500);

  /// Delay between list items entering, over [staggerMaxItems] items.
  static const Duration staggerStep = Duration(milliseconds: 40);
  static const int staggerMaxItems = 5;

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

/// Haptics of BirdyGo moments (new species, first encounter, new status).
abstract final class BirdyHaptics {
  static Future<void> light() => HapticFeedback.lightImpact();
}
