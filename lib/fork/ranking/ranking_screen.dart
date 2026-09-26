/// Palmarès: my species ranked over a period (fork/PLAN.md J4, look of
/// J6c, SPEC.md 9.12).
library;

import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../features/explore/explore_providers.dart';
import '../../features/explore/widgets/species_info_overlay.dart';
import '../../shared/providers/settings_providers.dart';
import '../../shared/services/taxonomy_service.dart';
import '../../shared/utils/app_icons.dart';
import '../data/observation_index.dart';
import '../data/observation_index_service.dart';
import '../design/birdy_tokens.dart';
import '../design/birdy_typography.dart';
import '../design/widgets/birdy_buttons.dart';
import 'ranking_logic.dart';
import 'ranking_widgets.dart';

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

/// « espèces en 30 jours »: the word and the period (header, line 1).
String periodPhrase(
  AppLocalizations l10n,
  RankingPeriod period,
  DateTime now,
) => switch (period) {
  RankingPeriod.last30Days => l10n.forkRankingIn30Days,
  RankingPeriod.season => l10n.forkRankingThisSeason,
  RankingPeriod.year => l10n.forkRankingInYear(now.year),
  RankingPeriod.all => l10n.forkRankingSinceStart,
};

/// Dates of the period (header, line 2): « du 27 août au 26 septembre »,
/// « depuis le 1 septembre », « en 2026 », « depuis le 4 oct. 2025 » (the
/// first contact of the list). Null when there is nothing to date.
String? periodDates(
  AppLocalizations l10n,
  String languageCode,
  RankingPeriod period,
  DateTime now, {
  DateTime? firstContact,
}) {
  final range = periodRange(period, now);
  // French writes the first of the month « 1er ».
  String dayMonthOf(DateTime d) {
    final text = DateFormat.MMMMd(languageCode).format(d);
    return languageCode == 'fr' && d.day == 1
        ? text.replaceFirst('1 ', '1er ')
        : text;
  }

  return switch (period) {
    RankingPeriod.last30Days => l10n.forkRankingFromTo(
      dayMonthOf(range.from!),
      dayMonthOf(now.toLocal()),
    ),
    RankingPeriod.season => l10n.forkRankingSince(dayMonthOf(range.from!)),
    RankingPeriod.year => l10n.forkRankingInYear(now.year),
    RankingPeriod.all =>
      firstContact == null
          ? null
          : l10n.forkRankingSince(
            DateFormat.yMMMMd(languageCode).format(firstContact.toLocal()),
          ),
  };
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

  String _orderWord(AppLocalizations l10n, RankingOrder o) => switch (o) {
    RankingOrder.contacts => l10n.forkRankingByContacts,
    RankingOrder.days => l10n.forkRankingByDays,
    RankingOrder.lastHeard => l10n.forkRankingByLastHeard,
  };

  String _orderLabel(AppLocalizations l10n, RankingOrder o) => switch (o) {
    RankingOrder.contacts => l10n.forkOrderContacts,
    RankingOrder.days => l10n.forkOrderDays,
    RankingOrder.lastHeard => l10n.forkOrderLastHeard,
  };

  void _open(RankedSpecies species) => SpeciesInfoOverlay.show(
    context,
    ref,
    scientificName: species.scientificName,
    commonName: species.name,
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
    final language = Localizations.localeOf(context).languageCode;
    // Rebuild when the index changes (a session was saved).
    ref.watch(observationIndexServiceProvider);
    final taxonomy = ref.watch(taxonomyServiceProvider).value;
    final speciesLocale = ref.watch(effectiveSpeciesLocaleProvider);
    final now = DateTime.now();

    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: FutureBuilder(
              future: _load(),
              builder: (context, snapshot) {
                final data = snapshot.data;
                final tallies =
                    data == null
                        ? null
                        : (_birdsOnly ? birdsOnly(data.$1, taxonomy) : data.$1);
                final newThisYear = data?.$2 ?? const <String>{};
                final ranked = [
                  for (final t in tallies ?? const <SpeciesTally>[])
                    _ranked(t, taxonomy, speciesLocale, newThisYear, l10n),
                ];
                final leader =
                    ranked.isEmpty
                        ? 1
                        : ranked
                            .map((r) => r.value)
                            .reduce((a, b) => a > b ? a : b);
                DateTime? firstContact;
                for (final t in tallies ?? const <SpeciesTally>[]) {
                  if (firstContact == null || t.first.isBefore(firstContact)) {
                    firstContact = t.first;
                  }
                }
                final newCount = ranked.where((r) => r.isNew).length;
                final dates = periodDates(
                  l10n,
                  language,
                  _period,
                  now,
                  firstContact: firstContact,
                );
                final newLine = l10n.forkRankingNewThisYear(newCount, now.year);
                return CustomScrollView(
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: BirdySpace.gutter,
                      ),
                      sliver: SliverList.list(
                        children: [
                          _topBar(l10n),
                          if (tallies != null) ...[
                            RankingHeader(
                              count: ranked.length,
                              label: l10n.forkRankingSpeciesWord(
                                ranked.length,
                                periodPhrase(l10n, _period, now),
                              ),
                              caption:
                                  dates == null || _period == RankingPeriod.year
                                      ? newLine
                                      : '$newLine · $dates',
                            ),
                            const SizedBox(height: BirdySpace.m),
                          ],
                          _periodChips(l10n),
                          const SizedBox(height: BirdySpace.xs),
                          _optionsRow(l10n, c),
                          const SizedBox(height: BirdySpace.m),
                        ],
                      ),
                    ),
                    if (tallies == null)
                      const SliverFillRemaining(
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (ranked.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(BirdySpace.xxxl),
                            child: Text(
                              l10n.forkRankingEmpty,
                              textAlign: TextAlign.center,
                              style: BirdyText.body.copyWith(color: c.text2),
                            ),
                          ),
                        ),
                      )
                    else ...[
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: BirdySpace.gutter,
                        ),
                        sliver: SliverToBoxAdapter(
                          child: RankingPodium(
                            top: ranked.take(3).toList(),
                            onOpen: _open,
                          ),
                        ),
                      ),
                      const SliverToBoxAdapter(
                        child: SizedBox(height: BirdySpace.m),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: BirdySpace.gutter,
                        ),
                        sliver: SliverList.builder(
                          itemCount: ranked.length > 3 ? ranked.length - 3 : 0,
                          itemBuilder: (context, i) {
                            final species = ranked[i + 3];
                            return RankingRow(
                              rank: i + 4,
                              species: species,
                              fraction: species.value / leader,
                              onTap: () => _open(species),
                            );
                          },
                        ),
                      ),
                    ],
                    const SliverToBoxAdapter(
                      child: SizedBox(height: BirdySpace.xxl),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  RankedSpecies _ranked(
    SpeciesTally t,
    TaxonomyService? taxonomy,
    String speciesLocale,
    Set<String> newThisYear,
    AppLocalizations l10n,
  ) {
    final value = rankingValue(t, _order);
    final imagePath = taxonomy?.assetImagePath(t.scientificName);
    return RankedSpecies(
      scientificName: t.scientificName,
      name:
          taxonomy
              ?.lookup(t.scientificName)
              ?.commonNameForLocale(speciesLocale) ??
          t.commonName,
      value: value,
      unit:
          _order == RankingOrder.days
              ? l10n.forkRankingUnitDays(value)
              : l10n.forkRankingUnitContacts(value),
      isNew: newThisYear.contains(t.scientificName),
      image: imagePath == null ? null : AssetImage(imagePath),
    );
  }

  Widget _topBar(AppLocalizations l10n) {
    final c = BirdyColors.of(context);
    return SizedBox(
      height: BirdySizes.topBar,
      child: Row(
        children: [
          BirdyIconButton(
            icon: AppIcons.arrowBackRounded,
            semanticLabel: MaterialLocalizations.of(context).backButtonTooltip,
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          const SizedBox(width: BirdySpace.m),
          Expanded(
            child: Text(
              l10n.forkRanking,
              style: BirdyText.heading.copyWith(color: c.text1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _periodChips(AppLocalizations l10n) => Wrap(
    spacing: BirdySpace.s,
    runSpacing: BirdySpace.s,
    children: [
      for (final p in RankingPeriod.values)
        ChoiceChip(
          label: Text(_periodLabel(l10n, p)),
          selected: _period == p,
          onSelected: (_) => setState(() => _period = p),
        ),
    ],
  );

  /// « Confirmées seulement » switch, then the sort and filter menu.
  Widget _optionsRow(AppLocalizations l10n, BirdyColors c) => Row(
    children: [
      Switch(
        value: _confirmedOnly,
        onChanged: (v) => setState(() => _confirmedOnly = v),
      ),
      const SizedBox(width: BirdySpace.s),
      Expanded(
        child: Text(
          l10n.forkConfirmedOnly,
          style: BirdyText.bodyCompact.copyWith(color: c.text1),
        ),
      ),
      const SizedBox(width: BirdySpace.s),
      Flexible(
        child: PopupMenuButton<Object>(
          tooltip: l10n.forkRankingSortMenu,
          onSelected:
              (choice) => setState(() {
                if (choice is RankingOrder) _order = choice;
                if (choice == #birds) _birdsOnly = !_birdsOnly;
              }),
          itemBuilder:
              (context) => [
                for (final o in RankingOrder.values)
                  CheckedPopupMenuItem<Object>(
                    value: o,
                    checked: _order == o,
                    child: Text(_orderLabel(l10n, o)),
                  ),
                const PopupMenuDivider(),
                CheckedPopupMenuItem<Object>(
                  value: #birds,
                  checked: _birdsOnly,
                  child: Text(l10n.forkBirdsOnly),
                ),
              ],
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: BirdySizes.target),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    l10n.forkRankingSortedBy(_orderWord(l10n, _order)),
                    textAlign: TextAlign.end,
                    style: BirdyText.caption.copyWith(color: c.text2),
                  ),
                ),
                Icon(AppIcons.expandMore, color: c.text2),
              ],
            ),
          ),
        ),
      ),
    ],
  );
}
