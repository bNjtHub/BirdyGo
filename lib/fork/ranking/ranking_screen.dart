/// Palmarès: my species ranked over a period (fork/PLAN.md J4).
library;

import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/explore/explore_providers.dart';
import '../../features/explore/widgets/species_info_overlay.dart';
import '../../shared/providers/settings_providers.dart';
import '../../shared/services/taxonomy_service.dart';
import '../data/observation_index.dart';
import '../data/observation_index_service.dart';
import 'ranking_logic.dart';

/// Metric shown and sorted on.
int rankingValue(SpeciesTally tally, RankingOrder order) => switch (order) {
  RankingOrder.contacts || RankingOrder.lastHeard => tally.contacts,
  RankingOrder.days => tally.days,
};

/// Keeps birds only, when the taxonomy knows the species' group. Species
/// missing from the taxonomy are kept (better shown than silently lost).
List<SpeciesTally> birdsOnly(
  List<SpeciesTally> tallies,
  TaxonomyService? taxonomy,
) {
  if (taxonomy == null) return tallies;
  return [
    for (final t in tallies)
      if ((taxonomy.lookup(t.scientificName)?.taxonGroup ?? 'Aves') == 'Aves')
        t,
  ];
}

/// Palmarès screen.
class RankingScreen extends ConsumerStatefulWidget {
  const RankingScreen({super.key});

  @override
  ConsumerState<RankingScreen> createState() => _RankingScreenState();
}

class _RankingScreenState extends ConsumerState<RankingScreen> {
  RankingPeriod _period = RankingPeriod.last30Days;
  RankingOrder _order = RankingOrder.contacts;
  bool _confirmedOnly = false;
  bool _birdsOnly = true;

  Future<(List<SpeciesTally>, Set<String>)> _load() async {
    final index = await ref.read(observationIndexServiceProvider).ensureReady();
    final range = periodRange(_period, DateTime.now());
    final tallies = await index.speciesRanking(
      from: range.from,
      to: range.to,
      confirmedOnly: _confirmedOnly,
      order: _order,
    );
    final newThisYear = await index.speciesFirstHeardSince(
      DateTime(DateTime.now().year),
    );
    return (tallies, newThisYear);
  }

  String _periodLabel(AppLocalizations l10n, RankingPeriod p) => switch (p) {
    RankingPeriod.last30Days => l10n.forkPeriod30Days,
    RankingPeriod.season => l10n.forkPeriodSeason,
    RankingPeriod.year => l10n.forkPeriodYear,
    RankingPeriod.all => l10n.forkPeriodAll,
  };

  String _orderLabel(AppLocalizations l10n, RankingOrder o) => switch (o) {
    RankingOrder.contacts => l10n.forkOrderContacts,
    RankingOrder.days => l10n.forkOrderDays,
    RankingOrder.lastHeard => l10n.forkOrderLastHeard,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    // Rebuild when the index changes (a session was saved).
    ref.watch(observationIndexServiceProvider);
    final taxonomy = ref.watch(taxonomyServiceProvider).value;
    final speciesLocale = ref.watch(effectiveSpeciesLocaleProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.forkRanking)),
      body: FutureBuilder(
        future: _load(),
        builder: (context, snapshot) {
          final data = snapshot.data;
          final tallies =
              data == null
                  ? null
                  : (_birdsOnly ? birdsOnly(data.$1, taxonomy) : data.$1);
          final newThisYear = data?.$2 ?? const <String>{};
          final maxValue =
              tallies == null || tallies.isEmpty
                  ? 1
                  : tallies
                      .map((t) => rankingValue(t, _order))
                      .reduce((a, b) => a > b ? a : b);
          final newCount =
              tallies
                  ?.where((t) => newThisYear.contains(t.scientificName))
                  .length ??
              0;
          return CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                sliver: SliverList.list(
                  children: [
                    if (tallies != null) ...[
                      Text(
                        l10n.forkRankingSpeciesCount(tallies.length),
                        style: theme.textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l10n.forkRankingNewThisYear(
                          newCount,
                          DateTime.now().year,
                        ),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final p in RankingPeriod.values)
                          ChoiceChip(
                            label: Text(_periodLabel(l10n, p)),
                            selected: _period == p,
                            onSelected: (_) => setState(() => _period = p),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final o in RankingOrder.values)
                          ChoiceChip(
                            label: Text(_orderLabel(l10n, o)),
                            selected: _order == o,
                            onSelected: (_) => setState(() => _order = o),
                          ),
                        FilterChip(
                          label: Text(l10n.forkConfirmedOnly),
                          selected: _confirmedOnly,
                          onSelected: (v) => setState(() => _confirmedOnly = v),
                        ),
                        FilterChip(
                          label: Text(l10n.forkBirdsOnly),
                          selected: _birdsOnly,
                          onSelected: (v) => setState(() => _birdsOnly = v),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (tallies == null)
                const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (tallies.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        l10n.forkRankingEmpty,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyLarge,
                      ),
                    ),
                  ),
                )
              else
                SliverList.builder(
                  itemCount: tallies.length,
                  itemBuilder: (context, i) {
                    final t = tallies[i];
                    final name =
                        taxonomy
                            ?.lookup(t.scientificName)
                            ?.commonNameForLocale(speciesLocale) ??
                        t.commonName;
                    final value = rankingValue(t, _order);
                    return _RankingRow(
                      rank: i + 1,
                      name: name,
                      isNew: newThisYear.contains(t.scientificName),
                      value: value,
                      fraction: value / maxValue,
                      onTap:
                          () => SpeciesInfoOverlay.show(
                            context,
                            ref,
                            scientificName: t.scientificName,
                            commonName: name,
                          ),
                    );
                  },
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          );
        },
      ),
    );
  }
}

class _RankingRow extends StatelessWidget {
  const _RankingRow({
    required this.rank,
    required this.name,
    required this.isNew,
    required this.value,
    required this.fraction,
    required this.onTap,
  });

  final int rank;
  final String name;
  final bool isNew;
  final int value;
  final double fraction;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    const tabular = [FontFeature.tabularFigures()];
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              SizedBox(
                width: 32,
                child: Text(
                  '$rank',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontFeatures: tabular,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            name,
                            style: theme.textTheme.bodyLarge,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isNew) ...[
                          const SizedBox(width: 8),
                          Text(
                            l10n.forkNewBadge,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.tertiary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: fraction.clamp(0.02, 1.0),
                        minHeight: 6,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Text(
                '$value',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontFeatures: tabular,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
