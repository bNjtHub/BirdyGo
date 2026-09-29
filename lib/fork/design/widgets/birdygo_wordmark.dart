/// The BirdyGo wordmark, variant « Point Loriot » of the Claude Design board:
/// « Birdy » in Fraunces, an Oriole dot sitting on the baseline,
/// « Go » in Atkinson extra-bold. The same letters as the startup
/// screen, at any [size]; the brand name is never translated.
library;

import 'package:flutter/material.dart';

import '../birdy_tokens.dart';
import '../birdy_typography.dart';

class BirdyGoWordmark extends StatelessWidget {
  const BirdyGoWordmark({super.key, this.size = startupSize, this.color});

  /// Font size of « Birdy »; the rest scales with it.
  final double size;

  /// Letters' color; the theme's main text by default. The dot stays Oriole.
  final Color? color;

  /// Size on the startup screen (board: Fraunces 44, Atkinson 42, dot 9).
  static const double startupSize = 44;

  /// Gap between the « o » and the dot, and between the dot and « Go »
  /// (board units at [startupSize]).
  static const double dotGapBefore = 2;
  static const double dotGapAfter = 5;

  static const String _name = 'BirdyGo';

  @override
  Widget build(BuildContext context) {
    final scale = size / startupSize;
    final scaler = MediaQuery.textScalerOf(context);
    final ink = color ?? BirdyColors.of(context).text1;
    return Semantics(
      label: _name,
      child: ExcludeSemantics(
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: 'Birdy',
                style: BirdyText.display.copyWith(
                  fontSize: size,
                  letterSpacing: -.8 * scale,
                  fontVariations: [
                    const FontVariation('SOFT', 100),
                    FontVariation('opsz', size.clamp(9, 144).toDouble()),
                  ],
                ),
              ),
              WidgetSpan(
                alignment: PlaceholderAlignment.baseline,
                baseline: TextBaseline.alphabetic,
                child: Padding(
                  // Bottom on the baseline (no raise), 2 px after the « o ».
                  padding: EdgeInsets.fromLTRB(
                    dotGapBefore * scale,
                    0,
                    dotGapAfter * scale,
                    0,
                  ),
                  child: SizedBox.square(
                    dimension: scaler.scale(9 * scale),
                    child: const DecoratedBox(
                      decoration: ShapeDecoration(
                        color: BirdyBrand.oriole,
                        shape: CircleBorder(),
                      ),
                    ),
                  ),
                ),
              ),
              TextSpan(
                text: 'Go',
                style: BirdyText.label.copyWith(
                  fontSize: 42 * scale,
                  height: 1.1,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1 * scale,
                ),
              ),
            ],
          ),
          style: TextStyle(color: ink),
          softWrap: false,
          maxLines: 1,
        ),
      ),
    );
  }
}
