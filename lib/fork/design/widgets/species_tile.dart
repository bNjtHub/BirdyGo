/// Species row (J6a, SPEC.md 5.5): the base of the live table, the ranking
/// and the sound library lists.
library;

import 'package:flutter/material.dart';

import '../birdy_tokens.dart';
import '../birdy_typography.dart';

class SpeciesTile extends StatelessWidget {
  const SpeciesTile({
    super.key,
    required this.name,
    required this.avatar,
    this.scientificName,
    this.meta,
    this.count,
    this.action,
    this.onTap,
    this.compact = false,
    this.background,
  });

  /// Common name. Wraps to a second line, never truncated.
  final String name;

  /// [SpeciesAvatar], 42 px (34 to 40 when [compact]).
  final Widget avatar;

  /// Latin name, in italic below the name.
  final String? scientificName;

  /// Line below the name: badges, total (« 142 au total »).
  final Widget? meta;

  /// Session counter on the right ([AnimatedCount]).
  final Widget? count;

  /// Trailing action, for example a [ClipPlayButton].
  final Widget? action;

  /// Opens the species sheet.
  final VoidCallback? onTap;

  /// 60 px rows (top 3 under the expanded spectrum, dimmed backgrounds).
  final bool compact;

  /// Row surface; the theme's surface 1 by default.
  final Color? background;

  @override
  Widget build(BuildContext context) {
    final c = BirdyColors.of(context);
    final radius = BorderRadius.circular(BirdyRadii.card);
    final body = Row(
      children: [
        avatar,
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                name,
                style: (compact ? BirdyText.speciesCompact : BirdyText.species)
                    .copyWith(color: c.text1),
              ),
              if (scientificName != null)
                Text(
                  scientificName!,
                  style: BirdyText.latinCompact.copyWith(
                    color: c.text2,
                    fontSize: 13,
                  ),
                ),
              if (meta != null) ...[
                const SizedBox(height: BirdySpace.xs),
                DefaultTextStyle.merge(
                  style: BirdyText.caption.copyWith(color: c.text2),
                  child: meta!,
                ),
              ],
            ],
          ),
        ),
      ],
    );
    return Material(
      color: background ?? c.surface1,
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: compact ? BirdySizes.rowCompact : BirdySizes.row,
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: BirdySpace.s,
            vertical: compact ? 6 : BirdySpace.s,
          ),
          child: Row(
            children: [
              Expanded(
                child: InkWell(onTap: onTap, borderRadius: radius, child: body),
              ),
              if (count != null) ...[
                const SizedBox(width: BirdySpace.s),
                DefaultTextStyle.merge(
                  style: BirdyText.numberM.copyWith(color: c.text1),
                  child: count!,
                ),
              ],
              if (action != null) ...[
                const SizedBox(width: BirdySpace.s),
                action!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
