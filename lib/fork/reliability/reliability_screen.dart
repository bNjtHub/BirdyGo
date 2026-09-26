/// Measured precision of the app, from the user's own reviews (J3).
library;

import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/explore/explore_providers.dart';
import '../../shared/providers/settings_providers.dart';
import '../data/observation_index_service.dart';
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
    final theme = Theme.of(context);
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
      appBar: AppBar(title: Text(l10n.forkReliabilityTitle)),
      body: FutureBuilder(
        future: data,
        builder: (context, snapshot) {
          final value = snapshot.data;
          if (value == null) {
            return const Center(child: CircularProgressIndicator());
          }
          final (bands, species) = value;
          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Text(
                  l10n.forkReliabilityIntro,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
              for (final level in ReliabilityLevel.values)
                ListTile(
                  leading: ReliabilityBadge(level: level, compact: true),
                  title: Text(reliabilityLabel(l10n, level)),
                  subtitle: Text(
                    precisionLine(
                          l10n,
                          bands[level.name]?.confirmed ?? 0,
                          bands[level.name]?.reviewed ?? 0,
                        ) ??
                        l10n.forkPrecisionNone,
                  ),
                  trailing: _Percent(
                    confirmed: bands[level.name]?.confirmed ?? 0,
                    reviewed: bands[level.name]?.reviewed ?? 0,
                  ),
                ),
              const Divider(height: 32),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(
                  l10n.forkReliabilityBySpecies(
                    ReliabilityConfig.minReviewsForSpeciesPrecision,
                  ),
                  style: theme.textTheme.titleMedium,
                ),
              ),
              if (species.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(l10n.forkPrecisionNone),
                ),
              for (final s in species)
                ListTile(
                  title: Text(
                    taxonomy
                            ?.lookup(s.scientificName)
                            ?.commonNameForLocale(speciesLocale) ??
                        s.commonName,
                  ),
                  subtitle: Text(
                    l10n.forkPrecisionLine(s.confirmed, s.reviewed),
                  ),
                  trailing: _Percent(
                    confirmed: s.confirmed,
                    reviewed: s.reviewed,
                  ),
                ),
            ],
          );
        },
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
    return Text(
      '${(100 * confirmed / reviewed).round()} %',
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        fontFeatures: const [FontFeature.tabularFigures()],
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
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              const ReliabilityBadge(
                level: ReliabilityLevel.sure,
                compact: true,
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(line)),
            ],
          ),
        );
      },
    );
  }
}
