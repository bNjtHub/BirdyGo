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
import '../daily_goal/daily_goal_providers.dart';
import '../design/birdy_tokens.dart';
import '../design/birdy_typography.dart';
import '../design/widgets/birdy_pill.dart';
import '../design/widgets/birdy_skeleton.dart';
import '../design/widgets/dashed_border.dart';
import '../design/widgets/entrance.dart';
import '../design/widgets/species_avatar.dart';
import '../design/widgets/birdy_cross_fade.dart';
import '../notebook/notebook_loader.dart';
import '../reliability/geo_presence_service.dart';
import '../reliability/reliability_config.dart';
import '../summary/listening_summary.dart';
import '../design/birdy_icons.dart';

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
    this.loading = false,
    this.imageFor,
    this.now,
  });

  final Map<String, GeoCommonnessEntry>? commonness;

  /// The geo-model/position have not resolved yet: [commonness] is not the
  /// final word, so the view reserves skeleton rows instead of reading it
  /// as "nothing expected here" (J6f skeletons).
  final bool loading;
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
      loading: loading,
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
    this.loading = false,
    this.imageFor,
  });

  final DateTime now;
  final List<LiveExpectedSpecies> species;

  /// See [LiveExpectedEmpty.loading].
  final bool loading;
  final ImageProvider? Function(String scientificName)? imageFor;

  /// Fades [child] in in place: a skeleton row or caption replaced by its
  /// loaded content, no move, no scale (DESIGN.md, J6f skeletons).
  static Widget _crossFade(Widget child) => BirdyCrossFade(child: child);

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
    // The common case (SPEC.md's geo-model/position present) fills all
    // `liveExpectedCount` rows; the skeleton reserves exactly that many so
    // the tip below never moves once the real rows land. Only the rare
    // case — no geo-model, no position, or truly nothing expected — ends
    // up with fewer (or zero) rows, and the tip may then shift up.
    final rowCount =
        loading ? ReliabilityConfig.liveExpectedCount : species.length;
    // The caption reserves its line whenever rows do, real or skeleton, so
    // it never appears or disappears once the geo-model resolves.
    final showCaption = loading || species.isNotEmpty;
    // The intro alone, without a goal count: most expected species are
    // not part of today's goal, so this is the common-case shape. A goal
    // count added to it only grows this line once real, which is the
    // one part of this caption allowed to shift.
    final placeholderIntro = l10n.forkLiveExpectedIntro;
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
                  if (showCaption) ...[
                    const SizedBox(height: BirdySpace.xs),
                    _crossFade(
                      loading
                          ? BirdySkeleton.text(
                            BirdyText.bodyCompact,
                            key: const ValueKey('expected-intro-skeleton'),
                            placeholder: placeholderIntro,
                            maxLines: null,
                          )
                          : Text(
                            intro,
                            key: const ValueKey('expected-intro-real'),
                            style: BirdyText.bodyCompact.copyWith(
                              color: c.text2,
                            ),
                          ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          for (var i = 0; i < rowCount; i++)
            Padding(
              key: ValueKey('expected-row-$i'),
              padding: const EdgeInsets.only(top: BirdySpace.s),
              child: BirdyEntrance.staggered(
                index: i + 1,
                child: _crossFade(
                  loading
                      ? const LiveExpectedRowSkeleton(
                        key: ValueKey('expected-row-skeleton'),
                      )
                      : LiveExpectedRow(
                        key: ValueKey(
                          'expected-row-real-${species[i].scientificName}',
                        ),
                        species: species[i],
                        reason: switch (species[i].reason) {
                          LiveExpectedReason.frequent => l10n
                              .forkLiveExpectedReasonFrequent(month),
                          LiveExpectedReason.peak =>
                            l10n.forkLiveExpectedReasonPeak,
                          LiveExpectedReason.possible => l10n
                              .forkLiveExpectedReasonPossible(month),
                        },
                        image: imageFor?.call(species[i].scientificName),
                      ),
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

/// Loading placeholder of [LiveExpectedRow], same [BirdySizes.rowCompact]
/// minimum height and [BirdySizes.expectedSlot] silhouette slot.
///
/// Uses one line for the name and one for the reason: most expected
/// species have a short common name and a short reason, and no
/// « Objectif » pill, so this is the shape that keeps the common case
/// from moving. A long two-word name, a reason that wraps, or a goal
/// pill narrowing the row are all real but less common — that one row
/// (and the rows after it) may then grow a little once real, which is
/// the one part of this block allowed to shift.
class LiveExpectedRowSkeleton extends StatelessWidget {
  const LiveExpectedRowSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final c = BirdyColors.of(context);
    return ExcludeSemantics(
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
                BirdySkeleton.box(
                  width: BirdySizes.expectedSlot,
                  height: BirdySizes.expectedSlot,
                  radius: BirdyRadii.pill,
                ),
                const SizedBox(width: BirdySpace.m),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      BirdySkeleton.text(
                        BirdyText.speciesCompact,
                        placeholder: '000000000000000',
                      ),
                      BirdySkeleton.text(
                        BirdyText.caption,
                        placeholder: '00000000000000000000',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
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
              BirdyIcons.tip,
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
