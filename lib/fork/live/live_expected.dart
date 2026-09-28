/// Empty state of the live table (J6f, « Attendus ici ce matin »): the
/// species the geo-model expects here this week, as muted silhouettes that
/// the table replaces as soon as the first species sings.
///
/// Reasons stay honest: they only say what the geo-model knows (this week's
/// score, its commonness tier, the species' annual peak here). Nothing about
/// the time of day, which no model here knows. Rule, in order:
///
/// 1. commonness tier in [ReliabilityConfig.liveExpectedFrequentBins]:
///    « Parmi les plus fréquents ici en `<mois>` »;
/// 2. this week at [ReliabilityConfig.liveExpectedPeakShare] of the annual
///    peak here or more: « En pleine saison ici »;
/// 3. otherwise « Peut chanter ici en `<mois>` ».
library;

import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../features/announcements/geo_commonness_provider.dart';
import '../../features/explore/explore_providers.dart';
import '../../shared/providers/settings_providers.dart';
import '../../shared/utils/app_icons.dart';
import '../daily_goal/daily_goal_providers.dart';
import '../design/birdy_tokens.dart';
import '../design/birdy_typography.dart';
import '../design/widgets/birdy_pill.dart';
import '../design/widgets/dashed_border.dart';
import '../design/widgets/entrance.dart';
import '../design/widgets/species_avatar.dart';
import '../notebook/notebook_loader.dart';
import '../reliability/geo_presence_service.dart';
import '../reliability/reliability_config.dart';
import '../summary/listening_summary.dart';

/// Why a species is listed as expected here.
enum LiveExpectedReason { frequent, peak, possible }

class LiveExpectedSpecies {
  const LiveExpectedSpecies({
    required this.scientificName,
    required this.commonName,
    required this.reason,
    this.goal = false,
  });

  final String scientificName;
  final String commonName;
  final LiveExpectedReason reason;

  /// Part of today's goal, not found yet: the « Objectif » pill.
  final bool goal;
}

/// Reason shown under an expected species (see the library doc).
LiveExpectedReason liveExpectedReason(GeoCommonnessEntry entry) {
  if (ReliabilityConfig.liveExpectedFrequentBins.contains(entry.commonness)) {
    return LiveExpectedReason.frequent;
  }
  if (entry.annualMax > 0 &&
      entry.currentScore / entry.annualMax >=
          ReliabilityConfig.liveExpectedPeakShare) {
    return LiveExpectedReason.peak;
  }
  return LiveExpectedReason.possible;
}

/// The [count] birds most likely here this week, from the Live commonness
/// map. Species the Live screen would call unexpected here are left out.
List<LiveExpectedSpecies> liveExpectedSpecies({
  required Map<String, GeoCommonnessEntry> commonness,
  required bool Function(String scientificName) isBird,
  required String Function(String scientificName) commonName,
  Set<String> goal = const {},
  int count = ReliabilityConfig.liveExpectedCount,
}) {
  final candidates = [
    for (final entry in commonness.entries)
      if (isBird(entry.key) && liveUnexpectedCause(entry.value) == null) entry,
  ];
  candidates.sort((a, b) {
    final byScore = b.value.currentScore.compareTo(a.value.currentScore);
    return byScore != 0 ? byScore : a.key.compareTo(b.key);
  });
  return [
    for (final entry in candidates.take(count))
      LiveExpectedSpecies(
        scientificName: entry.key,
        commonName: commonName(entry.key),
        reason: liveExpectedReason(entry.value),
        goal: goal.contains(entry.key),
      ),
  ];
}

/// Today's goal species not found yet (saved goal only: never asks for a
/// position).
final liveGoalSpeciesProvider = Provider.autoDispose<Set<String>>((ref) {
  final goal = ref.watch(dailyGoalProvider).goal;
  if (goal == null || !goal.isForDay(DateTime.now())) return const {};
  final done = ref.watch(dailyGoalProgressProvider).value ?? const <String>{};
  return {
    for (final bird in goal.species)
      if (!done.contains(bird.scientificName)) bird.scientificName,
  };
});

/// The empty state wired to the app: taxonomy names, daily goal. Without a
/// commonness map (no position, no geo-model, a recording) it shows the
/// title and the tip only.
class LiveExpectedEmpty extends ConsumerWidget {
  const LiveExpectedEmpty({
    super.key,
    required this.commonness,
    this.imageFor,
    this.now,
  });

  final Map<String, GeoCommonnessEntry>? commonness;
  final ImageProvider? Function(String scientificName)? imageFor;

  /// Clock for tests.
  final DateTime Function()? now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final map = commonness;
    var species = const <LiveExpectedSpecies>[];
    if (map != null && map.isNotEmpty) {
      final taxonomy = ref.watch(taxonomyServiceProvider).value;
      final locale = ref.watch(effectiveSpeciesLocaleProvider);
      species = liveExpectedSpecies(
        commonness: map,
        isBird: (name) => isBird(taxonomy, name),
        commonName:
            (name) =>
                taxonomy?.lookup(name)?.commonNameForLocale(locale) ?? name,
        goal: ref.watch(liveGoalSpeciesProvider),
      );
    }
    return LiveExpectedView(
      now: (now ?? DateTime.now)(),
      species: species,
      imageFor: imageFor,
    );
  }
}

/// « Attendus ici ce matin », the expected species and the tip.
class LiveExpectedView extends StatelessWidget {
  const LiveExpectedView({
    super.key,
    required this.now,
    required this.species,
    this.imageFor,
  });

  final DateTime now;
  final List<LiveExpectedSpecies> species;
  final ImageProvider? Function(String scientificName)? imageFor;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
    final title = switch (dayPartOf(now)) {
      DayPart.morning => l10n.forkLiveExpectedTitleMorning,
      DayPart.afternoon => l10n.forkLiveExpectedTitleAfternoon,
      DayPart.evening => l10n.forkLiveExpectedTitleEvening,
      DayPart.night => l10n.forkLiveExpectedTitleNight,
    };
    final month = DateFormat.MMMM(l10n.localeName).format(now.toLocal());
    final goals = species.where((s) => s.goal).length;
    final intro = [
      l10n.forkLiveExpectedIntro,
      if (goals > 0) l10n.forkLiveExpectedGoalCount(goals),
    ].join(' ');
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BirdyEntrance.staggered(
            index: 0,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: BirdySpace.s,
                vertical: BirdySpace.xs,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      title,
                      style: BirdyText.heading.copyWith(color: c.text1),
                    ),
                  ),
                  if (species.isNotEmpty) ...[
                    const SizedBox(height: BirdySpace.xs),
                    Text(
                      intro,
                      style: BirdyText.bodyCompact.copyWith(color: c.text2),
                    ),
                  ],
                ],
              ),
            ),
          ),
          for (final (i, bird) in species.indexed)
            Padding(
              padding: const EdgeInsets.only(top: BirdySpace.s),
              child: BirdyEntrance.staggered(
                index: i + 1,
                child: LiveExpectedRow(
                  species: bird,
                  reason: switch (bird.reason) {
                    LiveExpectedReason.frequent => l10n
                        .forkLiveExpectedReasonFrequent(month),
                    LiveExpectedReason.peak => l10n.forkLiveExpectedReasonPeak,
                    LiveExpectedReason.possible => l10n
                        .forkLiveExpectedReasonPossible(month),
                  },
                  image: imageFor?.call(bird.scientificName),
                ),
              ),
            ),
          const SizedBox(height: BirdySpace.m),
          const LiveExpectedTip(),
        ],
      ),
    );
  }
}

/// One expected species: muted silhouette in a dashed circle, name, reason
/// and the « Objectif » pill.
class LiveExpectedRow extends StatelessWidget {
  const LiveExpectedRow({
    super.key,
    required this.species,
    required this.reason,
    this.image,
  });

  final LiveExpectedSpecies species;
  final String reason;
  final ImageProvider? image;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
    return MergeSemantics(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: c.surface1.withValues(alpha: BirdyAlpha.expectedRow),
          borderRadius: BorderRadius.circular(BirdyRadii.card),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: BirdySizes.rowCompact),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: BirdySpace.s,
              vertical: BirdySpace.xs,
            ),
            child: Row(
              children: [
                ExcludeSemantics(
                  child: CustomPaint(
                    foregroundPainter: DashedBorderPainter(
                      color: c.dashed,
                      radius: BirdyRadii.pill,
                    ),
                    child: SizedBox.square(
                      dimension: BirdySizes.expectedSlot,
                      child: Padding(
                        padding: const EdgeInsets.all(BirdySpace.s),
                        child: SpeciesAvatar(
                          image: image,
                          size: BirdySizes.expectedSlot - 2 * BirdySpace.s,
                          muted: true,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: BirdySpace.m),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        species.commonName,
                        style: BirdyText.speciesCompact.copyWith(
                          color: c.text1,
                        ),
                      ),
                      Text(
                        reason,
                        style: BirdyText.caption.copyWith(color: c.text2),
                      ),
                    ],
                  ),
                ),
                if (species.goal) ...[
                  const SizedBox(width: BirdySpace.s),
                  BirdyPill(
                    label: l10n.forkLiveExpectedGoal,
                    foreground: c.onOriole,
                    background: c.oriole,
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

/// « Micro vers le haut, ne bouge plus pendant une minute. »
class LiveExpectedTip extends StatelessWidget {
  const LiveExpectedTip({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: c.orioleContainer,
        // Not a stadium: the tip wraps on two lines at 130 %.
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(BirdyRadii.card),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: BirdySpace.l,
          vertical: BirdySpace.m,
        ),
        child: Row(
          children: [
            Icon(
              AppIcons.lightbulbOutline,
              size: BirdySizes.tipIcon,
              color: c.orioleText,
            ),
            const SizedBox(width: BirdySpace.s),
            Expanded(
              child: Text(
                l10n.forkLiveExpectedTip,
                style: BirdyText.caption.copyWith(color: c.text1),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
