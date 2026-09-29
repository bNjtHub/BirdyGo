/// Place in a short sequence (J6h): onboarding pages, tip carousel, series
/// of first encounters. The current dot is a longer pill; the ones before it
/// can take a "done" color. Dots change size and color in [BirdyMotion.enter]
/// (instantly with reduced motion).
library;

import 'package:flutter/widgets.dart';

import '../birdy_motion.dart';
import '../birdy_tokens.dart';

class BirdyStepDots extends StatelessWidget {
  const BirdyStepDots({
    super.key,
    required this.count,
    required this.current,
    required this.activeColor,
    required this.inactiveColor,
    this.doneColor,
    this.height = 8,
    this.dotWidth,
    this.activeWidth = 22,
    this.gap = 6,
    this.semanticLabel,
  });

  final int count;

  /// Zero-based index of the current dot.
  final int current;
  final Color activeColor;
  final Color inactiveColor;

  /// Color of the dots before the current one; [inactiveColor] when null.
  final Color? doneColor;
  final double height;

  /// Width of a dot that is not the current one; [height] (round) when null.
  final double? dotWidth;
  final double activeWidth;

  /// Space between dots, and between lines when many dots wrap.
  final double gap;

  /// Read by screen readers; the dots are hidden from them when null.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final duration =
        BirdyMotion.reduced(context) ? Duration.zero : BirdyMotion.enter;
    final dots = Wrap(
      alignment: WrapAlignment.center,
      spacing: gap,
      runSpacing: gap,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: duration,
            curve: BirdyMotion.standard,
            width: i == current ? activeWidth : (dotWidth ?? height),
            height: height,
            decoration: BoxDecoration(
              color:
                  i == current
                      ? activeColor
                      : (i < current ? doneColor : null) ?? inactiveColor,
              borderRadius: BorderRadius.circular(BirdyRadii.pill),
            ),
          ),
      ],
    );
    if (semanticLabel == null) return ExcludeSemantics(child: dots);
    return Semantics(label: semanticLabel, excludeSemantics: true, child: dots);
  }
}
