/// Measured precision of the app, from the user's own reviews (J3).
library;

import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/explore/explore_providers.dart';
import '../../shared/providers/settings_providers.dart';
import '../data/observation_index_service.dart';
import '../design/birdy_tokens.dart';
import '../design/birdy_typography.dart';
import '../design/widgets/birdy_block.dart';
import '../design/widgets/birdy_headers.dart';
import '../design/widgets/birdy_skeleton.dart';
import 'reliability_badge.dart';
import 'reliability_config.dart';

/// "11 bonnes sur 12 vérifiées" style line, or null with no review yet.
String? precisionLine(AppLocalizations l10n, int confirmed, int reviewed) =>
    reviewed == 0 ? null : l10n.forkPrecisionLine(confirmed, reviewed);

/// Precision per score band and per well-reviewed species.
class ReliabilityScreen extends ConsumerWidget {
  const ReliabilityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
    final service = ref.watch(observationIndexServiceProvider);
    final speciesLocale = ref.watch(effectiveSpeciesLocaleProvider);
    final taxonomy = ref.watch(taxonomyServiceProvider).value;
    final data = service.ensureReady().then(
      (index) async => (
        await index.precisionByScoreBand(
          sureMin: ReliabilityConfig.sureMinScore,
          probableMin: ReliabilityConfig.probableMinScore,
        ),
        await index.precisionBySpecies(
          minReviews: ReliabilityConfig.minReviewsForSpeciesPrecision,
        ),
      ),
    );
    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                BirdySpace.page,
                BirdySpace.s,
                BirdySpace.page,
                BirdySpace.s,
              ),
              child: BirdyOverlayHeader(title: l10n.forkReliabilityTitle),
            ),
            Expanded(
              child: FutureBuilder(
                future: data,
                builder: (context, snapshot) {
                  final value = snapshot.data;
                  if (value == null) {
                    return _Skeleton(l10n: l10n);
                  }
                  final (bands, species) = value;
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(
                      BirdySpace.page,
                      BirdySpace.s,
                      BirdySpace.page,
                      BirdySpace.xxxl,
                    ),
                    children: [
                      BirdyBlock(
                        tone: BirdyBlockTone.tonal,
                        radius: BirdyRadii.hero,
                        padding: const EdgeInsets.all(BirdySpace.xl),
                        child: Text(
                          l10n.forkReliabilityIntro,
                          style: BirdyText.bodyCompact.copyWith(color: c.text1),
                        ),
                      ),
                      const SizedBox(height: BirdySpace.block),
                      for (final level in ReliabilityLevel.values) ...[
                        _Row(
                          leading: ReliabilityBadge(
                            level: level,
                            compact: true,
                          ),
                          title: reliabilityLabel(l10n, level),
                          subtitle:
                              precisionLine(
                                l10n,
                                bands[level.name]?.confirmed ?? 0,
                                bands[level.name]?.reviewed ?? 0,
                              ) ??
                              l10n.forkPrecisionNone,
                          confirmed: bands[level.name]?.confirmed ?? 0,
                          reviewed: bands[level.name]?.reviewed ?? 0,
                        ),
                        const SizedBox(height: BirdySpace.s),
                      ],
                      const SizedBox(height: BirdySpace.m),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: BirdySpace.xs,
                        ),
                        child: Semantics(
                          header: true,
                          child: Text(
                            l10n.forkReliabilityBySpecies(
                              ReliabilityConfig.minReviewsForSpeciesPrecision,
                            ),
                            style: BirdyText.heading.copyWith(color: c.text1),
                          ),
                        ),
                      ),
                      const SizedBox(height: BirdySpace.m),
                      if (species.isEmpty)
                        BirdyBlock(
                          child: Text(
                            l10n.forkPrecisionNone,
                            style: BirdyText.bodyCompact.copyWith(
                              color: c.text2,
                            ),
                          ),
                        ),
                      for (final s in species) ...[
                        _Row(
                          title:
                              taxonomy
                                  ?.lookup(s.scientificName)
                                  ?.commonNameForLocale(speciesLocale) ??
                              s.commonName,
                          subtitle: l10n.forkPrecisionLine(
                            s.confirmed,
                            s.reviewed,
                          ),
                          confirmed: s.confirmed,
                          reviewed: s.reviewed,
                        ),
                        const SizedBox(height: BirdySpace.s),
                      ],
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Loading placeholder shaped like the final list: the intro block, three
/// level rows, then a few species rows.
class _Skeleton extends StatelessWidget {
  const _Skeleton({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: const ValueKey('reliabilitySkeleton'),
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        BirdySpace.page,
        BirdySpace.s,
        BirdySpace.page,
        BirdySpace.xxxl,
      ),
      children: [
        BirdySkeleton.box(
          width: double.infinity,
          height: BirdySizes.heroMinHeight / 2,
          radius: BirdyRadii.hero,
        ),
        const SizedBox(height: BirdySpace.block),
        for (var i = 0; i < 3 + 3; i++) ...[
          BirdySkeleton.box(
            width: double.infinity,
            height: BirdySizes.row,
            radius: BirdyRadii.card,
          ),
          const SizedBox(height: BirdySpace.s),
        ],
      ],
    );
  }
}

/// One precision line in a plain block: optional badge, title, detail and
/// the percentage on the right.
class _Row extends StatelessWidget {
  const _Row({
    this.leading,
    required this.title,
    required this.subtitle,
    required this.confirmed,
    required this.reviewed,
  });

  final Widget? leading;
  final String title;
  final String subtitle;
  final int confirmed;
  final int reviewed;

  @override
  Widget build(BuildContext context) {
    final c = BirdyColors.of(context);
    return BirdyBlock(
      padding: const EdgeInsets.symmetric(
        horizontal: BirdySpace.l,
        vertical: BirdySpace.m,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: BirdySizes.target),
        child: Row(
          children: [
            if (leading != null) ...[
              leading!,
              const SizedBox(width: BirdySpace.m),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: BirdyText.species.copyWith(color: c.text1),
                  ),
                  Text(
                    subtitle,
                    style: BirdyText.caption.copyWith(color: c.text2),
                  ),
                ],
              ),
            ),
            _Percent(confirmed: confirmed, reviewed: reviewed),
          ],
        ),
      ),
    );
  }
}

class _Percent extends StatelessWidget {
  const _Percent({required this.confirmed, required this.reviewed});

  final int confirmed;
  final int reviewed;

  @override
  Widget build(BuildContext context) {
    if (reviewed == 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(left: BirdySpace.m),
      child: Text(
        '${(100 * confirmed / reviewed).round()} %',
        style: BirdyText.numberM.copyWith(color: BirdyColors.of(context).text1),
      ),
    );
  }
}

/// Precision line for the species sheet ("11 bonnes sur 12 vérifiées").
class SpeciesPrecisionLine extends ConsumerWidget {
  const SpeciesPrecisionLine({super.key, required this.scientificName});

  final String scientificName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final service = ref.watch(observationIndexServiceProvider);
    return FutureBuilder(
      future: service.ensureReady().then(
        (index) => index.speciesPrecision(scientificName),
      ),
      builder: (context, snapshot) {
        final value = snapshot.data;
        final line =
            value == null
                ? null
                : precisionLine(l10n, value.confirmed, value.reviewed);
        if (line == null) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: BirdySpace.xs),
          child: Row(
            children: [
              const ReliabilityBadge(
                level: ReliabilityLevel.sure,
                compact: true,
              ),
              const SizedBox(width: BirdySpace.s),
              Expanded(child: Text(line)),
            ],
          ),
        );
      },
    );
  }
}
