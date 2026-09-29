/// The BirdyGo wordmark, variant 2c of the Claude Design board:
/// « Birdy » in Nunito 800 (ink), a dot of the active bird theme centred on
/// the height of the lowercase letters, « Go » in Nunito 900 in the theme's
/// accent text color. Same letters at any [size]; the brand name is never
/// translated.
library;

import 'package:flutter/material.dart';

import '../birdy_theme_choice.dart';
import '../birdy_tokens.dart';
import '../birdy_typography.dart';

class BirdyGoWordmark extends StatelessWidget {
  const BirdyGoWordmark({super.key, this.size = startupSize, this.color});

  /// Font size of « Birdy » and « Go ».
  final double size;

  /// Color of « Birdy »; the theme's main text by default. The dot and
  /// « Go » follow the bird theme.
  final Color? color;

  /// Size on the startup screen and the onboarding.
  static const double startupSize = 44;

  /// Dot diameter, as a share of [size].
  static const double dotRatio = .2;

  /// Space on each side of the dot, as a share of [size] (3 px at 24).
  static const double dotMarginRatio = .125;

  /// x-height of Nunito in em (OS/2 sxHeight 484 over 1000 units per em);
  /// the dot's centre sits at half of it above the baseline.
  static const double nunitoXHeight = .484;

  static const String _name = 'BirdyGo';

  @override
  Widget build(BuildContext context) {
    // The dot follows the text scale, like the letters.
    final fs = MediaQuery.textScalerOf(context).scale(size);
    final dot = fs * dotRatio;
    final margin = fs * dotMarginRatio;
    final ink = color ?? BirdyColors.of(context).text1;
    final brand = BirdyBrandColors.of(context);
    final letters = BirdyText.display.copyWith(
      fontSize: size,
      letterSpacing: -.01 * size,
    );
    return Semantics(
      label: _name,
      child: ExcludeSemantics(
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: 'Birdy',
                style: letters.copyWith(color: ink),
              ),
              WidgetSpan(
                alignment: PlaceholderAlignment.baseline,
                baseline: TextBaseline.alphabetic,
                child: Padding(
                  // Bottom raised so the dot's centre is at mid x-height.
                  padding: EdgeInsets.fromLTRB(
                    margin,
                    0,
                    margin,
                    fs * nunitoXHeight / 2 - dot / 2,
                  ),
                  child: SizedBox.square(
                    dimension: dot,
                    child: DecoratedBox(
                      decoration: ShapeDecoration(
                        color: brand.wordmarkDot,
                        shape: const CircleBorder(),
                      ),
                    ),
                  ),
                ),
              ),
              TextSpan(
                text: 'Go',
                style: letters.copyWith(
                  fontWeight: FontWeight.w900,
                  color: brand.accentText,
                ),
              ),
            ],
          ),
          softWrap: false,
          maxLines: 1,
        ),
      ),
    );
  }
}
