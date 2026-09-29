/// The BirdyGo mark that shows the app is listening (J6f live header, J6h
/// first-encounter card, fork/DESIGN.md « Animations »). Only its four wing
/// bars move, like a small level meter, and only while [running]; the bird
/// itself never moves. [frozen] (paused) holds the bars at a mid length.
/// Neither, or reduced motion: the full static logo.
///
/// One [AnimationController], repainted through [BirdyGoLogoPainter]'s own
/// `repaint` listenable, so whatever holds the logo never rebuilds per frame.
library;

import 'package:flutter/widgets.dart';

import '../../home/birdygo_logo.dart';
import '../birdy_motion.dart';
import '../birdy_theme_choice.dart';

class BirdyListeningLogo extends StatefulWidget {
  const BirdyListeningLogo({
    super.key,
    required this.size,
    this.running = false,
    this.frozen = false,
  });

  final double size;

  /// Listening: the bars swell one after the other, looping.
  final bool running;

  /// Paused: the bars stay at [BirdyGoLogoPainter.pausedBarLevel].
  final bool frozen;

  @override
  State<BirdyListeningLogo> createState() => _BirdyListeningLogoState();
}

class _BirdyListeningLogoState extends State<BirdyListeningLogo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: BirdyMotion.listeningLevelPeriod,
    // The loop keeps its rhythm whatever the platform's animation scale;
    // reduced motion is handled by hand below.
    animationBehavior: AnimationBehavior.preserve,
  );

  bool _shouldRun(BuildContext context) =>
      widget.running && !BirdyMotion.reduced(context);

  void _sync() {
    if (_shouldRun(context)) {
      if (!_controller.isAnimating) _controller.repeat();
    } else if (_controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(BirdyListeningLogo old) {
    super.didUpdateWidget(old);
    _sync();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduced = BirdyMotion.reduced(context);
    final active = widget.running && !reduced;
    final paused = widget.frozen && !widget.running && !reduced;
    return ExcludeSemantics(
      child: RepaintBoundary(
        child: CustomPaint(
          size: Size.square(widget.size),
          painter: BirdyGoLogoPainter(
            progress: kAlwaysCompleteAnimation,
            level: active ? _controller : null,
            frozenLevel: paused ? BirdyGoLogoPainter.pausedBarLevel : null,
            brand: BirdyBrandColors.of(context),
          ),
        ),
      ),
    );
  }
}
