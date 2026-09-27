import 'package:flutter/widgets.dart';

/// Keeps the painted splash visible while cold-launch routes decide where to go.
/// Unlike deferFirstFrame, this also works after the splash has reached the engine.
class BirdyGoLaunchHandoff {
  BirdyGoLaunchHandoff(this.onReleased);

  final VoidCallback onReleased;
  int _pending = 0;

  bool get isPending => _pending > 0;

  /// Returns an idempotent release for one independent launch operation.
  VoidCallback hold() {
    _pending++;
    var released = false;
    return () {
      if (released) return;
      released = true;
      _pending--;
      onReleased();
    };
  }
}

class BirdyGoLaunchScope extends InheritedWidget {
  const BirdyGoLaunchScope({
    super.key,
    required this.handoff,
    required super.child,
  });

  final BirdyGoLaunchHandoff handoff;

  /// A non-listening lookup, safe from a launch listener's initState.
  static BirdyGoLaunchHandoff? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<BirdyGoLaunchScope>()?.handoff;

  @override
  bool updateShouldNotify(BirdyGoLaunchScope oldWidget) =>
      handoff != oldWidget.handoff;
}
