/// Rarity tag of the live rows (J6h), next to the reliability badge:
/// « Peu commun ici » or « Rare ici », from the geo presence.
///
/// Mapping of [LiveUnexpectedCause] (the reasons the listening screen finds
/// a species unexpected here):
/// - `rare` and `absent` (rare tier, or missing from the place's map): « Rare ici »;
/// - `belowInclusion` (present, but below the abundance threshold this
///   week): « Peu commun ici »;
/// - null (expected here, or no geo information): no tag.
///
/// When « Rare ici · à confirmer » already shows (unexpected and the score
/// alone would pass), no second tag is added. The tag replaces the lone
/// diamond that used to sit next to the badge.
library;

import 'package:flutter/material.dart';

import '../../features/announcements/geo_commonness_provider.dart';
import '../design/widgets/birdy_pill.dart';
import '../reliability/geo_presence_service.dart';
import '../reliability/reliability_badge.dart';
import '../reliability/reliability_config.dart';

/// Why [scientificName] is unexpected in [commonness] (the current place
/// and week map), or null when it is expected or the map is unavailable.
LiveUnexpectedCause? liveRarityCause(
  Map<String, GeoCommonnessEntry>? commonness,
  String scientificName,
) {
  if (commonness == null || commonness.isEmpty) return null;
  return liveUnexpectedCause(commonness[scientificName]);
}

/// Tag to show for [cause], or null for none: no cause, or the merged
/// « Rare ici · à confirmer » pill already says it.
NoveltyKind? liveRarityKind({
  required LiveUnexpectedCause? cause,
  required ReliabilityLevel level,
  double? score,
}) {
  if (cause == null) return null;
  if (showsRareHereToConfirm(level: level, unexpected: true, score: score)) {
    return null;
  }
  return switch (cause) {
    LiveUnexpectedCause.absent ||
    LiveUnexpectedCause.rare => NoveltyKind.rareHere,
    LiveUnexpectedCause.belowInclusion => NoveltyKind.uncommonHere,
  };
}

/// [ReliabilityBadge] of a live row plus its rarity tag.
class LiveReliabilityBadge extends StatelessWidget {
  const LiveReliabilityBadge({
    super.key,
    required this.level,
    required this.cause,
    required this.score,
    required this.compact,
  });

  final ReliabilityLevel level;

  /// See [liveRarityCause].
  final LiveUnexpectedCause? cause;

  /// Detection score, as for [ReliabilityBadge.score].
  final double score;

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final kind = liveRarityKind(cause: cause, level: level, score: score);
    final badge = ReliabilityBadge(
      level: level,
      unexpected: cause != null,
      score: score,
      compact: compact,
      showUnexpectedMark: kind == null,
    );
    if (kind == null) return badge;
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [badge, NoveltyPill(kind: kind)],
    );
  }
}
