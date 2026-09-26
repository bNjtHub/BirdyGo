/// Compact badges for reliability levels and "Inattendu ici" (J3).
///
/// Levels differ by the number of filled bars, by lightness and by outline
/// (dashed for "À vérifier"), not by hue alone.
library;

import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

import '../../shared/utils/app_icons.dart';
import '../design/birdy_tokens.dart';
import '../design/widgets/birdy_pill.dart';
import '../design/widgets/dashed_border.dart';
import 'reliability_config.dart';

/// Localized label of a level.
String reliabilityLabel(AppLocalizations l10n, ReliabilityLevel level) =>
    switch (level) {
      ReliabilityLevel.sure => l10n.forkLevelSure,
      ReliabilityLevel.probable => l10n.forkLevelProbable,
      ReliabilityLevel.toCheck => l10n.forkLevelToCheck,
    };

/// Level badge: three rising bars plus short label (J6a look).
class ReliabilityBadge extends StatelessWidget {
  const ReliabilityBadge({
    super.key,
    required this.level,
    this.unexpected = false,
    this.compact = false,
  });

  final ReliabilityLevel level;

  /// Adds the "Inattendu ici" mark.
  final bool unexpected;

  /// Glyph only (label kept for screen readers and the tooltip).
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
    final colors = c.level(level);
    final label = reliabilityLabel(l10n, level);
    final semantics = unexpected ? '$label, ${l10n.forkUnexpectedHere}' : label;
    final glyph = ReliabilityGlyph(level: level, color: colors.foreground);
    final Widget badge =
        compact
            ? _CompactBadge(colors: colors, glyph: glyph)
            : BirdyPill(
              label: label,
              foreground: colors.foreground,
              background: colors.background,
              dashed: colors.dashed,
              leading: glyph,
            );
    return Tooltip(
      message: semantics,
      child: Semantics(
        label: semantics,
        excludeSemantics: true,
        child: Wrap(
          spacing: 6,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            badge,
            if (unexpected)
              compact
                  ? Icon(
                    AppIcons.diamond,
                    size: 14,
                    fill: 1,
                    color: c.orioleText,
                  )
                  : const NoveltyPill(kind: NoveltyKind.unexpectedHere),
          ],
        ),
      ),
    );
  }
}

class _CompactBadge extends StatelessWidget {
  const _CompactBadge({required this.colors, required this.glyph});

  final LevelColors colors;
  final Widget glyph;

  @override
  Widget build(BuildContext context) {
    final circle = DecoratedBox(
      decoration: BoxDecoration(
        color: colors.background,
        shape: BoxShape.circle,
      ),
      child: SizedBox.square(
        dimension: BirdySizes.pill,
        child: Center(child: glyph),
      ),
    );
    if (!colors.dashed) return circle;
    return CustomPaint(
      foregroundPainter: DashedBorderPainter(
        color: colors.foreground,
        radius: BirdyRadii.pill,
        dash: 3,
        gap: 2.5,
      ),
      child: circle,
    );
  }
}
