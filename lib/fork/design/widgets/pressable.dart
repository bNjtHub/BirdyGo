/// Press feedback of BirdyGo buttons (J6a): the child shrinks to 0.97 while
/// a finger is on it, 120 ms. Nothing moves when animations are reduced.
library;

import 'package:flutter/widgets.dart';

import '../birdy_motion.dart';

class Pressable extends StatefulWidget {
  const Pressable({super.key, required this.child, this.enabled = true});

  final Widget child;

  /// Disabled buttons do not react.
  final bool enabled;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _pressed = false;

  void _set(bool pressed) {
    if (_pressed != pressed) setState(() => _pressed = pressed);
  }

  @override
  Widget build(BuildContext context) {
    final active = widget.enabled && !BirdyMotion.reduced(context);
    return Listener(
      onPointerDown: active ? (_) => _set(true) : null,
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: AnimatedScale(
        scale: active && _pressed ? BirdyMotion.pressScale : 1,
        duration: BirdyMotion.press,
        curve: BirdyMotion.standard,
        child: widget.child,
      ),
    );
  }
}
