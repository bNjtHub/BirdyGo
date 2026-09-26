/// Species card (J6a, SPEC.md 5.6): a card tinted with the species color,
/// for the notebook grid, and a larger hero version (home, ranking).
library;

import 'package:flutter/material.dart';

import '../birdy_tokens.dart';
import '../birdy_typography.dart';
import '../species_tint.dart';
import 'dashed_border.dart';

enum _CardVariant { tinted, mystery, toConfirm }

class SpeciesCard extends StatelessWidget {
  const SpeciesCard({
    super.key,
    required this.name,
    required this.visual,
    this.tint,
    this.caption,
    this.corner,
    this.hero = false,
    this.onTap,
  }) : _variant = _CardVariant.tinted;

  /// Card of a species expected here but not found yet: dashed outline, no
  /// fill, the hint instead of the name.
  const SpeciesCard.mystery({
    super.key,
    required this.name,
    required this.visual,
    this.caption,
  }) : tint = null,
       corner = null,
       hero = false,
       onTap = null,
       _variant = _CardVariant.mystery;

  /// Card of a species heard but waiting for confirmation: white card,
  /// dashed outline in the « À vérifier » color.
  const SpeciesCard.toConfirm({
    super.key,
    required this.name,
    required this.visual,
    this.caption,
    this.corner,
    this.onTap,
  }) : tint = null,
       hero = false,
       _variant = _CardVariant.toConfirm;

  final String name;

  /// [SpeciesAvatar] or species icon, 72 px in the grid.
  final Widget visual;

  /// Species colors: tintLight background on light, tintDark on dark.
  final SpeciesTint? tint;

  /// Line below the name (« 23 fois », hint of a mystery card).
  final Widget? caption;

  /// Top-right mark: rarity icon, « Nouveau » pill.
  final Widget? corner;

  /// Hero card: radius 28, heading-size name.
  final bool hero;

  final VoidCallback? onTap;

  final _CardVariant _variant;

  @override
  Widget build(BuildContext context) {
    final c = BirdyColors.of(context);
    final radius = hero ? BirdyRadii.hero : BirdyRadii.card;
    final isMystery = _variant == _CardVariant.mystery;
    final isToConfirm = _variant == _CardVariant.toConfirm;

    final Color? background;
    if (isMystery) {
      background = null;
    } else if (isToConfirm) {
      background = c.surface1;
    } else {
      background = (tint ?? SpeciesTint.neutral).cardBackground(c.brightness);
    }
    final nameStyle = (hero ? BirdyText.heading : BirdyText.speciesCompact)
        .copyWith(color: isMystery ? c.text2 : c.text1);

    Widget content = Padding(
      padding: EdgeInsets.all(hero ? BirdySpace.l : 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          visual,
          const SizedBox(height: 6),
          Text(
            name,
            style:
                isMystery
                    ? BirdyText.badge.copyWith(color: c.text2, height: 1.2)
                    : nameStyle,
          ),
          if (caption != null) ...[
            const SizedBox(height: 6),
            DefaultTextStyle.merge(
              style: BirdyText.caption.copyWith(
                color: isMystery || !c.isDark ? c.text2 : c.text1,
              ),
              child: caption!,
            ),
          ],
        ],
      ),
    );
    if (corner != null) {
      content = Stack(
        children: [
          content,
          PositionedDirectional(top: 10, end: 10, child: corner!),
        ],
      );
    }

    Widget card = Material(
      color: background ?? Colors.transparent,
      borderRadius: BorderRadius.circular(radius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: hero ? 0 : BirdySizes.collectionCard,
          ),
          child: content,
        ),
      ),
    );
    if (isMystery || isToConfirm) {
      card = CustomPaint(
        foregroundPainter: DashedBorderPainter(
          color: isMystery ? c.dashed : c.toCheck.foreground,
          radius: radius,
        ),
        child: card,
      );
    }
    return card;
  }
}
