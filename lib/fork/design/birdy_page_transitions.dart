/// One page transition for the whole app (J7): the new page fades in while
/// sliding [BirdyMotion.maxOffset] px from the right; the page underneath
/// stays still (no second animation). Duration and curve come from
/// [BirdyMotion]; the exit is shorter than the enter. With reduced motion,
/// only the fade remains (fork/DESIGN.md, Animations).
///
/// Set once on the theme ([BirdyTheme]), so every `MaterialPageRoute`,
/// upstream ones included, uses it.
library;

import 'package:flutter/material.dart';

import 'birdy_motion.dart';

class BirdyPageTransitionsBuilder extends PageTransitionsBuilder {
  const BirdyPageTransitionsBuilder();

  @override
  Duration get transitionDuration => BirdyMotion.enter;

  @override
  Duration get reverseTransitionDuration => BirdyMotion.exit;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: BirdyMotion.standard,
      reverseCurve: BirdyMotion.standard,
    );
    final faded = FadeTransition(opacity: curved, child: child);
    if (BirdyMotion.reduced(context)) return faded;
    return AnimatedBuilder(
      animation: curved,
      child: faded,
      builder:
          (context, child) => Transform.translate(
            offset: Offset(BirdyMotion.maxOffset * (1 - curved.value), 0),
            child: child,
          ),
    );
  }

  /// Every platform gets the same transition.
  static const PageTransitionsTheme theme = PageTransitionsTheme(
    builders: {
      TargetPlatform.android: BirdyPageTransitionsBuilder(),
      TargetPlatform.iOS: BirdyPageTransitionsBuilder(),
      TargetPlatform.fuchsia: BirdyPageTransitionsBuilder(),
      TargetPlatform.linux: BirdyPageTransitionsBuilder(),
      TargetPlatform.macOS: BirdyPageTransitionsBuilder(),
      TargetPlatform.windows: BirdyPageTransitionsBuilder(),
    },
  );
}
