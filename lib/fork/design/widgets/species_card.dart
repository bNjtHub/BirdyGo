/// Species card (J6a, SPEC.md 5.6): a card tinted with the species color,
/// for the notebook grid, and a larger hero version (home, ranking).
library;

import 'package:flutter/material.dart';

import '../birdy_tokens.dart';
import '../birdy_typography.dart';
import '../species_tint.dart';
import 'dashed_border.dart';
import 'pressable.dart';

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
    this.footer,
    this.uniform = false,
    this.largeName = false,
    this.onTap,
  }) : _variant = _CardVariant.tinted;

  /// Card of a species expected here but not found yet: dashed outline, no
  /// fill, the hint instead of the name.
  const SpeciesCard.mystery({
    super.key,
    required this.name,
    required this.visual,
    this.caption,
    this.uniform = false,
    this.largeName = false,
  }) : tint = null,
       corner = null,
       footer = null,
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
    this.footer,
    this.uniform = false,
    this.largeName = false,
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

  /// Row below [caption] (rarity / « Nouveau » pills). Only laid out in a
  /// [uniform] card, where it owns a reserved slot of one pill height.
  final Widget? footer;

  /// Grid card: the visual is centered, and the caption and footer sit in a
  /// slot of fixed height ([gridCaptionHeight]), so every card of the grid
  /// has the same size and the caption (« N fois ») the same position,
  /// whatever the name, the count or the pills. Ignored by hero cards.
  final bool uniform;

  /// Top-right mark: rarity icon, « Nouveau » pill.
  final Widget? corner;

  /// Hero card: radius 28, heading-size name.
  final bool hero;

  /// Name in [BirdyText.species] (17) instead of the compact 15 (notebook
  /// grid, two columns); the mystery card's name follows.
  final bool largeName;

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
    final nameStyle = (hero
            ? BirdyText.heading
            : (largeName ? BirdyText.species : BirdyText.speciesCompact))
        .copyWith(color: isMystery ? c.text2 : c.text1);
    final effectiveNameStyle =
        isMystery && !largeName
            ? BirdyText.badge.copyWith(color: c.text2, height: 1.2)
            : nameStyle;
    // Two lines, always: a 1-line name and a 2-line name must leave the
    // caption / « Nouveau » badge below at the exact same spot in every
    // grid card, not one row shorter than the next.
    final nameHeight = twoLineTextHeight(context, effectiveNameStyle);

    final fixed = uniform && !hero;
    Widget content = Padding(
      padding: EdgeInsets.all(hero ? BirdySpace.l : BirdySpace.cozy),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        // Hero cards size to their own content (no bounded height to fill);
        // grid cards fill the row's intrinsic height so the spacer below
        // can push the caption down to the card's bottom edge.
        mainAxisSize: hero ? MainAxisSize.min : MainAxisSize.max,
        children: [
          if (fixed) Center(child: visual) else visual,
          const SizedBox(height: BirdySpace.snug),
          SizedBox(
            height: nameHeight,
            child: Align(
              alignment: AlignmentDirectional.topStart,
              child: Text(
                name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: effectiveNameStyle,
              ),
            ),
          ),
          if (fixed)
            SizedBox(
              height: gridCaptionHeight(context),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (caption != null)
                    DefaultTextStyle.merge(
                      style: BirdyText.caption.copyWith(
                        color: isMystery || !c.isDark ? c.text2 : c.text1,
                      ),
                      child: caption!,
                    ),
                  if (footer != null) ...[
                    const Spacer(),
                    SizedBox(
                      height: BirdySizes.pill,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: AlignmentDirectional.centerStart,
                        child: footer,
                      ),
                    ),
                  ],
                ],
              ),
            )
          else if (caption != null) ...[
            if (hero)
              const SizedBox(height: BirdySpace.snug)
            else
              const Spacer(),
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
          PositionedDirectional(
            top: BirdySpace.cozy,
            end: BirdySpace.cozy,
            child: corner!,
          ),
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
    // Tactile: the tile shrinks a little under the finger (J6g-b).
    return onTap == null ? card : Pressable(child: card);
  }
}

/// Height of the caption slot of a [SpeciesCard.uniform] card: the caption
/// line, a gap and one pill row. One definition for the card and for the
/// notebook's loading skeleton.
double gridCaptionHeight(BuildContext context) {
  final line = TextPainter(
    text: TextSpan(text: 'A', style: BirdyText.caption),
    textScaler: MediaQuery.textScalerOf(context),
    textDirection: Directionality.of(context),
  )..layout();
  final height = line.height + BirdySpace.snug + BirdySizes.pill;
  line.dispose();
  return height;
}

/// Height of two lines of [style] at the current text scale: a name box
/// reserving it never resizes depending on whether the name wraps to one
/// line or two (same trick as `heroNameHeight` on the home screen). Public
/// so the notebook grid's loading skeleton ([NotebookScreen]) can reserve
/// the exact same space for its placeholder name.
double twoLineTextHeight(BuildContext context, TextStyle style) {
  final painter = TextPainter(
    text: TextSpan(text: 'A\nA', style: style),
    textScaler: MediaQuery.textScalerOf(context),
    textDirection: Directionality.of(context),
  )..layout();
  final height = painter.height;
  painter.dispose();
  return height;
}
