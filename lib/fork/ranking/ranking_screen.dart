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
import '../design/widgets/birdy_filter_chip.dart';
import '../design/widgets/birdy_headers.dart';
import '../design/widgets/birdy_skeleton.dart';
import '../design/widgets/empty_state.dart';
import '../design/widgets/birdy_cross_fade.dart';
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
                final loading = tallies == null;
                return CustomScrollView(
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: BirdySpace.gutter,
                      ),
                      sliver: SliverList.list(
                        children: [
                          Semantics(
                            key: const ValueKey('ranking-header'),
                            liveRegion: true,
                            label: loading ? l10n.forkRankingLoading : null,
                            child: BirdyOverlayHeader(title: l10n.forkRanking),
                          ),
                          // The shell (row, spacing) is always built the same
                          // way; only its counts cross-fade, so the chips and
                          // options below never move once the ranking lands.
                          KeyedSubtree(
                            key: const ValueKey('ranking-count'),
                            child: _crossFade(
                              loading
                                  ? const _RankingHeaderSkeleton(
                                    key: ValueKey('ranking-header-skeleton'),
                                  )
                                  : RankingHeader(
                                    key: const ValueKey('ranking-header-real'),
                                    count: ranked.length,
                                    label: l10n.forkRankingSpeciesWord(
                                      ranked.length,
                                      periodPhrase(l10n, _period, now),
                                    ),
                                    caption:
                                        dates == null ||
                                                _period == RankingPeriod.year
                                            ? newLine
                                            : '$newLine · $dates',
                                  ),
                            ),
                          ),
                          const SizedBox(height: BirdySpace.m),
                          Container(
                            key: const ValueKey('ranking-chips'),
                            child: _periodChips(l10n),
                          ),
                          const SizedBox(height: BirdySpace.xs),
                          Container(
                            key: const ValueKey('ranking-options'),
                            child: _optionsRow(l10n, c),
                          ),
                          const SizedBox(height: BirdySpace.m),
                        ],
                      ),
                    ),
                    if (loading)
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: BirdySpace.gutter,
                        ),
                        sliver: const _RankingListSkeleton(),
                      )
                    else if (ranked.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        // Nothing in the widest period: nothing heard yet.
                        // Otherwise the period hides birds heard before.
                        child:
                            _period == RankingPeriod.all
                                ? BirdyEmptyState(
                                  icon: AppIcons.hearing,
                                  title: l10n.forkRankingEmptyTitle,
                                  body: l10n.forkRankingEmpty,
                                )
                                : BirdyEmptyState(
                                  kind: BirdyEmptyKind.filtered,
                                  icon: AppIcons.searchOff,
                                  title: l10n.forkRankingEmptyTitle,
                                  body: l10n.forkRankingEmptyFiltered,
                                  action: l10n.forkRankingAllPeriods,
                                  onAction:
                                      () => setState(
                                        () => _period = RankingPeriod.all,
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

  Widget _periodChips(AppLocalizations l10n) => Wrap(
    spacing: BirdySpace.s,
    runSpacing: BirdySpace.s,
    children: [
      for (final p in RankingPeriod.values)
        BirdyFilterChip(
          label: _periodLabel(l10n, p),
          selected: _period == p,
          onSelected: () => setState(() => _period = p),
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

  /// Fades [child] in in place: a loaded value replacing its skeleton.
  /// [child]'s own key tells the switcher when to cross-fade.
  static Widget _crossFade(Widget child) => BirdyCrossFade(child: child);
}

/// Same shape as [RankingHeader]: big number, label, caption line — so the
/// period chips right under it never move once the ranking lands.
class _RankingHeaderSkeleton extends StatelessWidget {
  const _RankingHeaderSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final c = BirdyColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.end,
          spacing: BirdySpace.s,
          children: [
            BirdySkeleton.text(
              BirdyText.numberXL.copyWith(color: c.text1),
              placeholder: '00',
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: BirdySkeleton.text(
                BirdyText.body.copyWith(color: c.text1),
                placeholder: '000000000000000000',
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        // Two lines, like the real caption's cap (ranking_widgets.dart).
        BirdySkeleton.text(
          BirdyText.caption.copyWith(color: c.text2),
          placeholder:
              '00000000000000000000000000000000000000000000000000000000000000000000000000',
          maxLines: 2,
        ),
      ],
    );
  }
}

/// A sensible number of skeleton rows, at [RankingRow]'s own minimum
/// height, filling a typical viewport under the header and chips.
class _RankingListSkeleton extends StatelessWidget {
  const _RankingListSkeleton();

  static const int _rows = 6;

  @override
  Widget build(BuildContext context) {
    final c = BirdyColors.of(context);
    return SliverList.builder(
      itemCount: _rows,
      itemBuilder: (context, index) {
        final key = index == 0 ? const ValueKey('ranking-list-first') : null;
        return Padding(
          key: key,
          padding: const EdgeInsets.symmetric(vertical: BirdySpace.xs),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Row(
              children: [
                SizedBox(
                  width: 28,
                  child: BirdySkeleton.text(BirdyText.label, placeholder: '00'),
                ),
                BirdySkeleton.box(width: 36, height: 36, radius: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      BirdySkeleton.text(
                        BirdyText.species,
                        placeholder: '000000000000000',
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(BirdyRadii.pill),
                        child: SizedBox(
                          height: 8,
                          child: ColoredBox(color: c.skeleton),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: BirdySpace.m),
                BirdySkeleton.text(BirdyText.numberM, placeholder: '00'),
              ],
            ),
          ),
        );
      },
    );
  }
}
