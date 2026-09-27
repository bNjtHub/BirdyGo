/// Animated icons of BirdyGo (DESIGN.md « Astuces »).
///
/// Our own Material Symbols, played once when they become [active]: the icon
/// fills in, slides a few pixels or pulses. Within the motion rules: no
/// rotation, bounce or loop, 8 px of travel at most, one effect at a time.
/// With reduced motion the icon shows its final state straight away.
library;

import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../birdy_motion.dart';

enum BirdyIconMotion {
  /// Outline, then filled: the icon « lights up ».
  fill,

  /// Slides in from the start side (wind, sound going away).
  drift,

  /// Comes down into place (download, volume down).
  drop,

  /// One soft pulse, 1 → 1.08 → 1 (sound, score).
  pulse,
}

class BirdyAnimatedIcon extends StatefulWidget {
  const BirdyAnimatedIcon({
    super.key,
    required this.icon,
    required this.motion,
    this.active = true,
    this.size,
    this.color,
  });

  final IconData icon;
  final BirdyIconMotion motion;

  /// Plays each time this turns true (and on first build when true).
  final bool active;

  final double? size;
  final Color? color;

  @override
  State<BirdyAnimatedIcon> createState() => _BirdyAnimatedIconState();
}

class _BirdyAnimatedIconState extends State<BirdyAnimatedIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: BirdyMotion.iconDelay + BirdyMotion.iconPlay,
  );

  // Starts once the card has faded in, so only one effect runs at a time.
  late final Animation<double> _t = CurvedAnimation(
    parent: _controller,
    curve: Interval(
      BirdyMotion.iconDelay.inMilliseconds /
          (BirdyMotion.iconDelay + BirdyMotion.iconPlay).inMilliseconds,
      1,
      curve: BirdyMotion.standard,
    ),
  );

  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      _play();
    }
  }

  @override
  void didUpdateWidget(BirdyAnimatedIcon old) {
    super.didUpdateWidget(old);
    if (widget.active && !old.active) _play();
  }

  void _play() {
    if (!widget.active) return;
    if (BirdyMotion.reduced(context)) {
      _controller.value = 1;
    } else {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _t,
    builder: (context, _) {
      final t = _t.value;
      final travel = (1 - t) * BirdyMotion.iconOffset;
      final icon = Icon(
        widget.icon,
        size: widget.size,
        color: widget.color,
        fill: widget.motion == BirdyIconMotion.fill ? t : 0,
      );
      return switch (widget.motion) {
        BirdyIconMotion.fill => icon,
        BirdyIconMotion.drift => Transform.translate(
          offset: Offset(
            Directionality.of(context) == TextDirection.rtl ? travel : -travel,
            0,
          ),
          child: icon,
        ),
        BirdyIconMotion.drop => Transform.translate(
          offset: Offset(0, -travel),
          child: icon,
        ),
        BirdyIconMotion.pulse => Transform.scale(
          scale: 1 + math.sin(math.pi * t) * (BirdyMotion.counterBumpScale - 1),
          child: icon,
        ),
      };
    },
  );
}
