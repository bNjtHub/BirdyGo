/// Section title of a species page block (J6h fix): a small disc in the
/// species' own tint with the section icon, then the 20 heading. Brings the
/// species identity back into the white blocks.
library;

import 'package:flutter/material.dart';

import '../design/birdy_tokens.dart';
import '../design/birdy_typography.dart';
import '../design/species_tint.dart';

/// The tint of the species on show, for the blocks below it.
class SpeciesTintScope extends InheritedWidget {
  const SpeciesTintScope({super.key, required this.tint, required super.child});

  final SpeciesTint tint;

  static SpeciesTint of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SpeciesTintScope>()?.tint ??
      SpeciesTint.neutral;

  @override
  bool updateShouldNotify(SpeciesTintScope old) => tint != old.tint;
}

/// Tint disc + icon, on the species tint of the surrounding
/// [SpeciesTintScope]. Ink on the light tint, the theme text on the dark one
/// (both keep AA, see SpeciesTint).
class SectionIconDisc extends StatelessWidget {
  const SectionIconDisc({super.key, required this.icon, this.glyphBuilder});

  final IconData icon;

  /// Draws a non-[IconData] glyph (a brand shape) in place of [icon].
  final Widget Function(double size, Color color)? glyphBuilder;

  @override
  Widget build(BuildContext context) {
    final c = BirdyColors.of(context);
    final tint = SpeciesTintScope.of(context);
    return Container(
      width: BirdySizes.sectionDisc,
      height: BirdySizes.sectionDisc,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: c.isDark ? tint.tintDark : tint.tintLight,
      ),
      child:
          glyphBuilder?.call(
            BirdySizes.sectionIcon,
            c.isDark ? c.text1 : BirdyBrand.ink,
          ) ??
          Icon(
            icon,
            size: BirdySizes.sectionIcon,
            color: c.isDark ? c.text1 : BirdyBrand.ink,
          ),
    );
  }
}

/// Icon disc and 20 heading of a block.
class SectionTitle extends StatelessWidget {
  const SectionTitle({
    super.key,
    required this.icon,
    required this.text,
    this.glyphBuilder,
  });

  final IconData icon;
  final Widget Function(double size, Color color)? glyphBuilder;
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = BirdyColors.of(context);
    return Row(
      children: [
        SectionIconDisc(icon: icon, glyphBuilder: glyphBuilder),
        const SizedBox(width: BirdySpace.m),
        Expanded(
          child: Text(text, style: BirdyText.heading.copyWith(color: c.text1)),
        ),
      ],
    );
  }
}
