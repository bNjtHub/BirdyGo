/// Empty states of BirdyGo (J6c, DESIGN.md « Écrans vides »).
///
/// One component for every screen that has nothing to show. The icon says
/// what will fill the screen, the title says what is missing, the body says
/// what to do (and when), and the button does it when the screen has no
/// other way to. Three kinds pick the disc colors:
///
/// - [BirdyEmptyKind.firstUse]: nothing here yet (Martin-pêcheur tint).
/// - [BirdyEmptyKind.filtered]: data exists, not for these filters (grey).
/// - [BirdyEmptyKind.done]: empty because the work is finished (Lichen).
library;

import 'package:flutter/material.dart';

import '../birdy_icons.dart';
import '../birdy_tokens.dart';
import '../birdy_typography.dart';
import 'birdy_buttons.dart';
import 'entrance.dart';
import 'pressable.dart';

enum BirdyEmptyKind { firstUse, filtered, done }

class BirdyEmptyState extends StatelessWidget {
  /// Full-page empty state, centered, for a screen with nothing else to show.
  const BirdyEmptyState({
    super.key,
    this.icon,
    this.leading,
    required this.title,
    this.body,
    this.kind = BirdyEmptyKind.firstUse,
    this.action,
    this.onAction,
    this.iconActive = false,
  }) : assert(icon != null || leading != null),
       inline = false;

  /// Compact card in a flow (home, LPO, over the map): disc on the left,
  /// texts on the right, optional action under the texts.
  const BirdyEmptyState.inline({
    super.key,
    this.icon,
    this.leading,
    required this.title,
    this.body,
    this.kind = BirdyEmptyKind.firstUse,
    this.action,
    this.onAction,
    this.iconActive = false,
  }) : assert(icon != null || leading != null),
       inline = true;

  final IconData? icon;

  /// Draws [icon] filled (a reached state, see BirdyIcons fill rule).
  final bool iconActive;

  /// Feature emblem (quiz logo, wing...) drawn instead of the icon disc, at
  /// the disc size ([fullDisc] / [inlineDisc]). Null keeps the icon disc.
  final Widget? leading;

  /// What is missing, one line, no final period.
  final String title;

  /// What to do to fill the screen, and when if it helps.
  final String? body;

  final BirdyEmptyKind kind;

  /// Label of the action button; shown only with [onAction].
  final String? action;
  final VoidCallback? onAction;

  final bool inline;

  static const double fullDisc = 72;
  static const double fullIcon = 36;
  static const double inlineDisc = 48;
  static const double inlineIcon = 24;
  static const double maxWidth = 360;

  /// Disc and icon colors of [kind] in the current theme.
  static (Color background, Color foreground) colors(
    BirdyColors c,
    BirdyEmptyKind kind,
  ) => switch (kind) {
    BirdyEmptyKind.firstUse => (c.tonal, c.accentText),
    BirdyEmptyKind.filtered => (c.borderOpaque, c.text2),
    BirdyEmptyKind.done => (c.sure.background, c.sure.foreground),
  };

  @override
  Widget build(BuildContext context) {
    final c = BirdyColors.of(context);
    final (discColor, iconColor) = colors(c, kind);
    final hasAction = action != null && onAction != null;

    final disc =
        leading ??
        Container(
          width: inline ? inlineDisc : fullDisc,
          height: inline ? inlineDisc : fullDisc,
          decoration: BoxDecoration(color: discColor, shape: BoxShape.circle),
          child: BirdyIcon(
            icon!,
            active: iconActive,
            size: inline ? inlineIcon : fullIcon,
            color: iconColor,
          ),
        );

    if (inline) {
      return BirdyEntrance(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: c.surface1,
            borderRadius: BorderRadius.circular(BirdyRadii.card),
            border: Border.all(color: c.border),
          ),
          child: Padding(
            padding: const EdgeInsets.all(BirdySpace.l),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ExcludeSemantics(child: disc),
                const SizedBox(width: BirdySpace.m),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: BirdyText.label.copyWith(color: c.text1),
                      ),
                      if (body != null) ...[
                        const SizedBox(height: BirdySpace.xs),
                        Text(
                          body!,
                          style: BirdyText.bodyCompact.copyWith(color: c.text2),
                        ),
                      ],
                      if (hasAction) ...[
                        const SizedBox(height: BirdySpace.m),
                        Pressable(
                          child: FilledButton(
                            style: BirdyButtonStyles.tonal(context),
                            onPressed: onAction,
                            child: Text(action!),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Center(
      child: BirdyEntrance(
        child: Padding(
          padding: const EdgeInsets.all(BirdySpace.xxxl),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: maxWidth),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ExcludeSemantics(child: disc),
                const SizedBox(height: BirdySpace.l),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: BirdyText.heading.copyWith(color: c.text1),
                ),
                if (body != null) ...[
                  const SizedBox(height: BirdySpace.s),
                  Text(
                    body!,
                    textAlign: TextAlign.center,
                    style: BirdyText.body.copyWith(color: c.text2),
                  ),
                ],
                if (hasAction) ...[
                  const SizedBox(height: BirdySpace.xxl),
                  Pressable(
                    child: FilledButton(
                      style:
                          kind == BirdyEmptyKind.filtered
                              ? BirdyButtonStyles.tonal(context)
                              : BirdyButtonStyles.primary(context),
                      onPressed: onAction,
                      child: Text(action!),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
