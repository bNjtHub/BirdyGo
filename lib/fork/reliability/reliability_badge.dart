/// Compact badges for reliability levels and "Inattendu ici" (J3), and
/// « Rare ici · à confirmer » when the place alone makes it « À vérifier »
/// (J3b).
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
import 'rare_here_sheet.dart';
import 'reliability_config.dart';

/// Localized label of a level.
String reliabilityLabel(AppLocalizations l10n, ReliabilityLevel level) =>
    switch (level) {
      ReliabilityLevel.sure => l10n.forkLevelSure,
      ReliabilityLevel.probable => l10n.forkLevelProbable,
      ReliabilityLevel.toCheck => l10n.forkLevelToCheck,
    };

/// True when [ReliabilityBadge] merges the level and « Inattendu ici » into
/// the single « Rare ici · à confirmer » pill (J3b).
bool showsRareHereToConfirm({
  required ReliabilityLevel level,
  required bool unexpected,
  double? score,
}) =>
    level == ReliabilityLevel.toCheck &&
    score != null &&
    placeOnlyToCheck(
      score: score,
      presence: GeoPresence(unexpected: unexpected),
    );

/// Level badge: three rising bars plus short label (J6a look).
class ReliabilityBadge extends StatelessWidget {
  const ReliabilityBadge({
    super.key,
    required this.level,
    this.unexpected = false,
    this.score,
    this.compact = false,
    this.showUnexpectedMark = true,
  });

  final ReliabilityLevel level;

  /// False when another tag already says why the species is unexpected
  /// (the rarity tag of the live rows, J6h); the semantics keep the text.
  final bool showUnexpectedMark;

  /// Adds the "Inattendu ici" mark.
  final bool unexpected;

  /// Detection score (best one for a species). With [unexpected] and a
  /// score that passes on its own, the level and the "Inattendu ici" mark
  /// merge into « Rare ici · à confirmer » (J3b). Null keeps both marks.
  final double? score;

  /// Glyph only (label kept for screen readers and the tooltip).
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
    final colors = c.level(level);
    final label = reliabilityLabel(l10n, level);
    final rareHere = showsRareHereToConfirm(
      level: level,
      unexpected: unexpected,
      score: score,
    );
    if (rareHere) return _RareHereBadge(compact: compact);
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
            if (unexpected && showUnexpectedMark)
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

/// Single Loriot pill replacing « À vérifier » + « Inattendu ici » (J3b).
/// Full size opens the explanation; compact (inside tappable rows) does
/// not, and keeps the label for the tooltip and screen readers.
class _RareHereBadge extends StatelessWidget {
  const _RareHereBadge({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
    final label = l10n.forkRareHereToConfirm;
    if (compact) {
      return Tooltip(
        message: label,
        child: Semantics(
          label: label,
          excludeSemantics: true,
          child: CustomPaint(
            foregroundPainter: DashedBorderPainter(
              color: c.orioleText,
              radius: BirdyRadii.pill,
              dash: 3,
              gap: 2.5,
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: c.orioleContainer,
                shape: BoxShape.circle,
              ),
              child: SizedBox.square(
                dimension: BirdySizes.pill,
                child: Icon(
                  AppIcons.diamond,
                  size: 14,
                  fill: 1,
                  color: c.orioleText,
                ),
              ),
            ),
          ),
        ),
      );
    }
    return Semantics(
      button: true,
      label: label,
      hint: l10n.forkRareHereExplanation,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => showRareHereSheet(context),
        child: const NoveltyPill(kind: NoveltyKind.rareHereToConfirm),
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
