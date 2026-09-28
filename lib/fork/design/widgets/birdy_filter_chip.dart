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
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  /// Colors when [selected]; tonal by default.
  final BirdyChipColors? selectedColors;
  final Widget? leading;

  /// Over a map: white chips carry the float shadow.
  final bool floating;

  @override
  Widget build(BuildContext context) {
    final c = BirdyColors.of(context);
    final on = selectedColors ?? BirdyChipColors.tonal(c);
    final background = selected ? on.background : c.surface1;
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
                    children: [
                      if (leading != null) ...[
                        IconTheme.merge(
                          data: IconThemeData(color: foreground, size: 18),
                          child: leading!,
                        ),
                        const SizedBox(width: BirdySpace.s),
                      ],
                      Text(
                        label,
                        style: BirdyText.labelCompact.copyWith(
                          color: foreground,
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
