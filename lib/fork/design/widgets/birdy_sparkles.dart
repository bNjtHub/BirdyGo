/// A few sparkles that pop around a point, one after the other, once
/// (J6h, « Première rencontre »; the mockup's `data-s` stars). Each grows to
/// [BirdyMotion.sparklePeakScale] and fades away in [BirdyMotion.sparklePop];
/// they start [delay] after the first build, [BirdyMotion.sparkleStagger]
/// apart. Never looping, and nothing at all with reduced motion.
///
/// Place it with no size at the center of what it decorates, like
/// `BirdyConfetti`: the sparkles are painted around it and not clipped by it.
library;

import 'package:flutter/widgets.dart';

import '../../../shared/utils/app_icons.dart';
import '../birdy_motion.dart';
import '../birdy_tokens.dart';

class BirdySparkles extends StatefulWidget {
  const BirdySparkles({
    super.key,
    required this.offsets,
    this.color = BirdyBrand.oriole,
    this.size = BirdySizes.sparkle,
    this.delay = Duration.zero,
    this.icon = AppIcons.sparkle,
    this.stagger = BirdyMotion.sparkleStagger,
    this.pop = BirdyMotion.sparklePop,
  });

  /// Center of each sparkle, from the widget's own center.
  final List<Offset> offsets;
  final Color color;
  final double size;
  final Duration delay;

  /// The mark, the time between two sparkles and how long each one lasts
  /// (the rare card pops diamonds, slower).
  final IconData icon;
  final Duration stagger;
  final Duration pop;

  /// Around the bird of a first encounter.
  static const List<Offset> aroundBird = [
    Offset(-62, -40),
    Offset(66, -30),
    Offset(-48, 58),
    Offset(58, 54),
  ];

  /// Three diamonds around the bird of a rare card (AppEcoute mockup).
  static const List<Offset> aroundRareBird = [
    Offset(-56, -54),
    Offset(62, -30),
    Offset(52, 48),
  ];

  @override
  State<BirdySparkles> createState() => _BirdySparklesState();
}

class _BirdySparklesState extends State<BirdySparkles>
    with SingleTickerProviderStateMixin {
  late final Duration _total =
      widget.delay +
      widget.stagger * (widget.offsets.length - 1) +
      widget.pop;
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _total,
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started || BirdyMotion.reduced(context)) return;
    _started = true;
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// 0 → 1 → 0 over one sparkle's own window.
  double _pop(int index) {
    final start = widget.delay + widget.stagger * index;
    final t =
        (_controller.value * _total.inMicroseconds - start.inMicroseconds) /
        widget.pop.inMicroseconds;
    if (t <= 0 || t >= 1) return 0;
    const peak = BirdyMotion.sparklePeakAt;
    return t <= peak ? t / peak : (1 - t) / (1 - peak);
  }

  @override
  Widget build(BuildContext context) {
    if (BirdyMotion.reduced(context)) return const SizedBox.shrink();
    return SizedBox.shrink(
      child: IgnorePointer(
        child: ExcludeSemantics(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              if (_controller.isCompleted) return const SizedBox.shrink();
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  for (final (i, offset) in widget.offsets.indexed)
                    Positioned(
                      left: offset.dx - widget.size / 2,
                      top: offset.dy - widget.size / 2,
                      child: Opacity(
                        opacity: _pop(i).clamp(0.0, 1.0),
                        child: Transform.scale(
                          scale: _pop(i) * BirdyMotion.sparklePeakScale,
                          child: Icon(
                            widget.icon,
                            size: widget.size,
                            color: widget.color,
                            fill: 1,
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
