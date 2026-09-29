/// Live spectrogram panel (J6c): the upstream spectrogram with the strip of
/// species marks and names below. One tap enlarges it (about 60 % of the
/// screen), a second tap brings it back; a chevron in the corner says so
/// (J6c-bis-c).
library;

import 'package:flutter/material.dart';

import '../../shared/utils/app_icons.dart';
import '../design/birdy_motion.dart';
import '../design/birdy_theme.dart';
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
      BirdySizes.spectrumNormal + DetectionMarks.heightLabeled;

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

  // J6h: the well stays dark on the light listening screen too (its
  // marks, names and chevron use the dark tokens).
  @override
  Widget build(BuildContext context) =>
      ListeningTheme(child: Builder(builder: _well));

  Widget _well(BuildContext context) {
    final c = BirdyColors.of(context);
    final reduced = BirdyMotion.reduced(context);
    const strip = DetectionMarks.heightLabeled;
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
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ClipRect(child: RepaintBoundary(child: spectrogram)),
                      PositionedDirectional(
                        top: BirdySpace.s,
                        end: BirdySpace.s,
                        child: _Chevron(expanded: expanded, color: c.text1),
                      ),
                    ],
                  ),
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

/// Enlarge / reduce chevron in the spectrogram's corner. Decorative: the
/// whole panel is the button (and carries the label).
class _Chevron extends StatelessWidget {
  const _Chevron({required this.expanded, required this.color});

  final bool expanded;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 32,
    height: 32,
    decoration: BoxDecoration(
      color: BirdyBrand.ink.withValues(alpha: 0.55),
      shape: BoxShape.circle,
    ),
    child: Icon(
      expanded ? AppIcons.expandLess : AppIcons.expandMore,
      size: 22,
      color: color,
    ),
  );
}
