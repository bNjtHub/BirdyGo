/// Entrance of an element (J6a): fade, short slide and scale 0.97 → 1.
/// With reduced motion, only the fade remains.
library;

import 'dart:async';

import 'package:flutter/widgets.dart';

import '../birdy_motion.dart';

class BirdyEntrance extends StatefulWidget {
  const BirdyEntrance({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = BirdyMotion.enter,
    this.offset = const Offset(0, BirdyMotion.maxOffset),
    this.fromScale = BirdyMotion.enterScale,
  });

  /// Entrance of the list item at [index] (40 ms steps, first 5 items).
  BirdyEntrance.staggered({
    super.key,
    required int index,
    required this.child,
    this.duration = BirdyMotion.enter,
    this.offset = const Offset(0, BirdyMotion.maxOffset),
    this.fromScale = BirdyMotion.enterScale,
  }) : delay = BirdyMotion.staggerDelay(index);

  final Widget child;
  final Duration delay;
  final Duration duration;

  /// Starting offset in logical pixels (8 px at most). A new live row
  /// comes from above: `Offset(0, -8)`.
  final Offset offset;

  final double fromScale;

  @override
  State<BirdyEntrance> createState() => _BirdyEntranceState();
}

class _BirdyEntranceState extends State<BirdyEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );
  late final Animation<double> _progress = CurvedAnimation(
    parent: _controller,
    curve: BirdyMotion.standard,
  );
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (widget.delay == Duration.zero) {
      _controller.forward();
    } else {
      _timer = Timer(widget.delay, _controller.forward);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fadeOnly = BirdyMotion.reduced(context);
    return FadeTransition(
      opacity: _progress,
      child:
          fadeOnly
              ? widget.child
              : AnimatedBuilder(
                animation: _progress,
                child: widget.child,
                builder: (context, child) {
                  final remaining = 1 - _progress.value;
                  return Transform.translate(
                    offset: widget.offset * remaining,
                    child: Transform.scale(
                      scale: 1 - (1 - widget.fromScale) * remaining,
                      child: child,
                    ),
                  );
                },
              ),
    );
  }
}
