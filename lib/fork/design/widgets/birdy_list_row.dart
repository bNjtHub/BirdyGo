/// The single list row of BirdyGo (J6h): a leading tinted disc with an icon
/// (or a species avatar), a title, an optional subtitle and a trailing
/// widget (a chevron by default). At least [BirdySizes.row] high, the whole
/// row is one tap target.
library;

import 'package:flutter/material.dart';

import '../../../shared/utils/app_icons.dart';
import '../birdy_tokens.dart';
import '../birdy_typography.dart';
import 'pressable.dart';

class BirdyListRow extends StatelessWidget {
  const BirdyListRow({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.discColor,
    this.iconColor,
    this.avatar,
    this.trailing,
    this.showChevron = true,
    this.titleStyle,
    this.onTap,
    this.semanticLabel,
  }) : assert(
         icon == null || avatar == null,
         'Give an icon or an avatar, not both.',
       );

  final String title;
  final String? subtitle;

  /// Icon of the leading disc ([BirdySizes.rowDisc]).
  final IconData? icon;

  /// Fill of the disc; [BirdyColors.tonal] when null.
  final Color? discColor;

  /// Icon color; [BirdyColors.accentText] when null.
  final Color? iconColor;

  /// Leading widget instead of the disc (a 48 dp `SpeciesAvatar`).
  final Widget? avatar;

  /// Replaces the chevron.
  final Widget? trailing;

  /// Chevron when [trailing] is null and the row is tappable.
  final bool showChevron;

  /// Title style; [BirdyText.label] (17 bold) when null, or
  /// [BirdyText.species] for a species name.
  final TextStyle? titleStyle;

  final VoidCallback? onTap;

  /// Replaces the children's semantics with one label.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final c = BirdyColors.of(context);
    Widget? leading = avatar;
    if (icon != null) {
      leading = Container(
        width: BirdySizes.rowDisc,
        height: BirdySizes.rowDisc,
        decoration: BoxDecoration(
          color: discColor ?? c.tonal,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 22, color: iconColor ?? c.accentText, fill: 1),
      );
    }
    final end =
        trailing ??
        (showChevron && onTap != null
            ? Icon(AppIcons.chevronRight, size: 24, color: c.text2)
            : null);
    Widget row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: BirdySizes.row),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: BirdySpace.l,
          vertical: BirdySpace.s,
        ),
        child: Row(
          children: [
            if (leading != null) ...[
              leading,
              const SizedBox(width: BirdySpace.m),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: (titleStyle ?? BirdyText.label).copyWith(
                      color: c.text1,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: BirdyText.caption.copyWith(color: c.text2),
                    ),
                ],
              ),
            ),
            if (end != null) ...[const SizedBox(width: BirdySpace.s), end],
          ],
        ),
      ),
    );
    if (onTap == null) return row;
    row = Semantics(
      button: true,
      label: semanticLabel,
      excludeSemantics: semanticLabel != null,
      child: InkWell(onTap: onTap, child: row),
    );
    return Pressable(child: row);
  }
}
