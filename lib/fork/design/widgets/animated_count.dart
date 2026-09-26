/// Counters of BirdyGo (J6a, SPEC.md 5.4).
library;

import 'package:flutter/material.dart';

import '../birdy_motion.dart';
import '../birdy_tokens.dart';
import '../birdy_typography.dart';

/// Number in tabular figures. When it goes up, the number alone grows a
/// little (1 → 1.08 → 1, 180 ms): the line around it does not move. No bump
/// with reduced motion.
class AnimatedCount extends StatefulWidget {
  const AnimatedCount({
    super.key,
    required this.value,
    this.format,
    this.style = BirdyText.numberM,
    this.semanticsLabel,
  });

  final int value;

  /// Text of the value (for example « ×4 »). Defaults to the plain number.
  final String Function(int value)? format;

  final TextStyle style;

  /// What a screen reader says instead of the raw text.
  final String? semanticsLabel;

  @override
  State<AnimatedCount> createState() => _AnimatedCountState();
}

class _AnimatedCountState extends State<AnimatedCount>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: BirdyMotion.counterBump,
  );
  late final Animation<double> _scale = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween(begin: 1, end: BirdyMotion.counterBumpScale),
      weight: 35,
    ),
    TweenSequenceItem(
      tween: Tween(begin: BirdyMotion.counterBumpScale, end: 1),
      weight: 65,
    ),
  ]).animate(CurvedAnimation(parent: _controller, curve: BirdyMotion.standard));

  @override
  void didUpdateWidget(AnimatedCount old) {
    super.didUpdateWidget(old);
    if (widget.value > old.value && !BirdyMotion.reduced(context)) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = widget.format?.call(widget.value) ?? '${widget.value}';
    return ScaleTransition(
      scale: _scale,
      child: Text(
        text,
        style: widget.style,
        semanticsLabel: widget.semanticsLabel,
      ),
    );
  }
}

/// Stat tile of a header: big number and a caption below.
class StatTile extends StatelessWidget {
  const StatTile({super.key, required this.value, required this.label});

  /// Tile with an [AnimatedCount].
  StatTile.count({super.key, required int count, required this.label})
    : value = AnimatedCount(value: count, style: BirdyText.numberL);

  /// The number: an [AnimatedCount] or a [Text] in [BirdyText.numberL].
  final Widget value;

  final String label;

  @override
  Widget build(BuildContext context) {
    final c = BirdyColors.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.surface1,
        borderRadius: BorderRadius.circular(BirdyRadii.card),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            DefaultTextStyle.merge(
              style: BirdyText.numberL.copyWith(color: c.text1),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: value,
              ),
            ),
            const SizedBox(height: BirdySpace.xs),
            Text(label, style: BirdyText.caption.copyWith(color: c.text2)),
          ],
        ),
      ),
    );
  }
}
