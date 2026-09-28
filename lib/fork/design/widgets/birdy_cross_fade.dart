/// Fades a skeleton into its loaded content in place (J6f skeletons): no
/// move, no scale, and the child keeps the full width it is given.
library;

import 'package:flutter/widgets.dart';

import '../birdy_motion.dart';

/// Cross-fades [child] when its key changes (skeleton → content).
///
/// [AnimatedSwitcher]'s default layout centers loose children, so a block
/// would shrink to its content's width; this one passes the parent's
/// constraints through and aligns to the start.
class BirdyCrossFade extends StatelessWidget {
  const BirdyCrossFade({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: BirdyMotion.enter,
    switchInCurve: BirdyMotion.standard,
    switchOutCurve: BirdyMotion.standard,
    transitionBuilder:
        (child, animation) => FadeTransition(opacity: animation, child: child),
    layoutBuilder:
        (current, previous) => Stack(
          alignment: AlignmentDirectional.topStart,
          fit: StackFit.passthrough,
          children: [...previous, if (current != null) current],
        ),
    child: child,
  );
}
