/// Filter chip of the J6f layout: white without border; the chosen one
/// takes its own color (Carnet: Toutes in ink, Découvertes in Sûr,
/// À découvrir in tonal, Rares in Loriot; Carte and Palmarès: tonal).
library;

import 'package:flutter/material.dart';

import '../birdy_tokens.dart';
import '../birdy_typography.dart';
import 'pressable.dart';

/// Colors of a chosen [BirdyFilterChip].
@immutable
class BirdyChipColors {
  const BirdyChipColors({required this.background, required this.foreground});

  final Color background;
  final Color foreground;

  /// Tonal Martin-pêcheur (default).
  factory BirdyChipColors.tonal(BirdyColors c) =>
      BirdyChipColors(background: c.tonal, foreground: c.text1);

  /// Ink (Encre), the « Toutes » chip.
  factory BirdyChipColors.ink(BirdyColors c) =>
      BirdyChipColors(background: c.text1, foreground: c.background);

  /// Sûr level.
  factory BirdyChipColors.sure(BirdyColors c) =>
      BirdyChipColors(background: c.sure.background, foreground: c.text1);

  /// Loriot container.
  factory BirdyChipColors.oriole(BirdyColors c) =>
      BirdyChipColors(background: c.orioleContainer, foreground: c.text1);
}

class BirdyFilterChip extends StatelessWidget {
  const BirdyFilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
    this.selectedColors,
    this.leading,
    this.floating = false,
    this.unselectedColor,
    this.centered = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  /// Colors when [selected]; tonal by default.
  final BirdyChipColors? selectedColors;
  final Widget? leading;

  /// Over a map: white chips carry the float shadow.
  final bool floating;

  /// Fill when not selected; white by default (Brume on a white block).
  final Color? unselectedColor;
  /// Centers the label (a chip stretched by a grid cell).
  final bool centered;

  @override
  Widget build(BuildContext context) {
    final c = BirdyColors.of(context);
    final on = selectedColors ?? BirdyChipColors.tonal(c);
    // Over a map, a translucent fill (tonal is 16 % on the dark theme)
    // would let the tiles through: floating chips lay it on white/surface1.
    final background =
        selected
            ? (floating
                ? Color.alphaBlend(on.background, c.surface1)
                : on.background)
            : (unselectedColor ?? c.surface1);
    final foreground = selected ? on.foreground : c.text1;
    return Semantics(
      button: true,
      selected: selected,
      child: Pressable(
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(BirdyRadii.pill),
            boxShadow: floating ? c.floatShadow : null,
          ),
          child: Material(
            color: background,
            shape: const StadiumBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onSelected,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: BirdySizes.target),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: BirdySpace.l),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment:
                        centered
                            ? MainAxisAlignment.center
                            : MainAxisAlignment.start,
                    children: [
                      if (leading != null) ...[
                        IconTheme.merge(
                          data: IconThemeData(color: foreground, size: BirdyGlyph.l),
                          child: leading!,
                        ),
                        const SizedBox(width: BirdySpace.s),
                      ],
                      // Ellipsized only when its row is narrower than the
                      // label (large text in a tight row); natural otherwise.
                      Flexible(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: BirdyText.labelCompact.copyWith(
                            color: foreground,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
