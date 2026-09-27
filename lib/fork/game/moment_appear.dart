/// Entrance of a moment's parts (J6e, fork/DESIGN.md « Animations »): fade,
/// scale 0.97 → 1, once. Reduced motion keeps the fade only.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../design/birdy_motion.dart';

class MomentAppear extends StatefulWidget {
  const MomentAppear({
    super.key,
    required this.child,
    this.duration = BirdyMotion.newStatus,
    this.delay = Duration.zero,
  });

  final Widget child;
  final Duration duration;
  final Duration delay;

  @override
  State<MomentAppear> createState() => _MomentAppearState();
}

class _MomentAppearState extends State<MomentAppear>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );
  late final Animation<double> _curve = CurvedAnimation(
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
    final reduced = BirdyMotion.reduced(context);
    return FadeTransition(
      opacity: _curve,
      child:
          reduced
              ? widget.child
              : ScaleTransition(
                scale: Tween(
                  begin: BirdyMotion.enterScale,
                  end: 1.0,
                ).animate(_curve),
                child: widget.child,
              ),
    );
  }
}
