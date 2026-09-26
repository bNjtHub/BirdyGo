/// Live spectrogram panel (J6c): the upstream spectrogram with the strip of
/// species marks below. One tap enlarges it (about 60 % of the screen, kHz
/// scale, names under the marks), a second tap brings it back.
library;

import 'package:flutter/material.dart';

import '../design/birdy_motion.dart';
import '../design/birdy_tokens.dart';
import 'detection_marks.dart';

class LiveSpectrogramPanel extends StatelessWidget {
  const LiveSpectrogramPanel({
    super.key,
    required this.expanded,
    required this.expandedHeight,
    required this.onToggle,
    required this.spectrogram,
    required this.marks,
    required this.semanticLabel,
    required this.toggleLabel,
  });

  /// Height of the normal band, marks included.
  static const double normalHeight =
      BirdySizes.spectrumNormal + DetectionMarks.heightCompact;

  final bool expanded;

  /// Full height when enlarged, marks included.
  final double expandedHeight;

  final VoidCallback onToggle;

  /// The spectrogram itself (repaints alone, see [RepaintBoundary]).
  final Widget spectrogram;

  /// The [DetectionMarks] strip.
  final Widget marks;

  /// What the panel shows, for screen readers.
  final String semanticLabel;

  /// What a tap does (« Agrandir le spectre »).
  final String toggleLabel;

  @override
  Widget build(BuildContext context) {
    final c = BirdyColors.of(context);
    final reduced = BirdyMotion.reduced(context);
    final strip =
        expanded ? DetectionMarks.heightLabeled : DetectionMarks.heightCompact;
    return Semantics(
      container: true,
      button: true,
      label: semanticLabel,
      onTapHint: toggleLabel,
      onTap: onToggle,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onToggle,
        child: AnimatedContainer(
          duration: reduced ? Duration.zero : BirdyMotion.reorder,
          curve: BirdyMotion.move,
          height: expanded ? expandedHeight : normalHeight,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [BirdyBrand.wellTop, BirdyBrand.wellBottom],
            ),
          ),
          child: ExcludeSemantics(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: ClipRect(child: RepaintBoundary(child: spectrogram)),
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: BirdyBrand.wellTop,
                    border: Border(top: BorderSide(color: c.border)),
                  ),
                  child: SizedBox(height: strip, child: marks),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
