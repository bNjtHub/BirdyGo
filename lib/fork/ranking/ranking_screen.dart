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
import '../design/birdy_icons.dart';
import '../design/birdy_tokens.dart';
import '../design/birdy_typography.dart';
import '../design/widgets/birdy_block.dart';
import '../design/widgets/birdy_buttons.dart';
import '../design/widgets/birdy_cross_fade.dart';
import '../design/widgets/birdy_filter_chip.dart';
import '../design/widgets/birdy_headers.dart';
import '../design/widgets/birdy_list_block.dart';
import '../design/widgets/birdy_sheet.dart';
import '../design/widgets/birdy_skeleton.dart';
import '../design/widgets/birdy_switch.dart';
import '../design/widgets/empty_state.dart';
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

  // Perf: the query runs when its inputs change, not at every rebuild
  // (taxonomy load, theme, setState of a filter that does not touch it).
  int _indexVersion = 0;
  Object? _loadedFor;
  Future<(List<SpeciesTally>, Set<String>)>? _data;

  Future<(List<SpeciesTally>, Set<String>)> _dataFuture() {
    final key = (_period, _order, _confirmedOnly, _indexVersion);
    if (_loadedFor != key) {
      _loadedFor = key;
      _data = _load();
    }
    return _data!;
  }

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
    ref.listen(observationIndexServiceProvider, (_, _) {
      if (mounted) setState(() => _indexVersion++);
    });
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
              future: _dataFuture(),
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
                        horizontal: BirdySpace.page,
                      ),
                      sliver: SliverList.list(
                        children: [
                          Semantics(
                            key: const ValueKey('ranking-header'),
                            liveRegion: true,
                            label: loading ? l10n.forkRankingLoading : null,
                            child: BirdyOverlayHeader(
                              title: l10n.forkRanking,
                              actions: [
                                BirdyIconButton(
                                  icon: AppIcons.sort,
                                  semanticLabel: l10n.forkRankingSortMenu,
                                  onPressed: _openSortSheet,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: BirdySpace.block),
                          // Tonal hero: the count and the period chips. The
                          // shell (row, spacing) is always built the same
                          // way; only its counts cross-fade, so the chips
                          // never move once the ranking lands.
                          BirdyBlock(
                            tone: BirdyBlockTone.tonal,
                            radius: BirdyRadii.hero,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                KeyedSubtree(
                                  key: const ValueKey('ranking-count'),
                                  child: _crossFade(
                                    loading
                                        ? const _RankingHeaderSkeleton(
                                          key: ValueKey(
                                            'ranking-header-skeleton',
                                          ),
                                        )
                                        : RankingHeader(
                                          key: const ValueKey(
                                            'ranking-header-real',
                                          ),
                                          count: ranked.length,
                                          label: l10n.forkRankingSpeciesWord(
                                            ranked.length,
                                            periodPhrase(l10n, _period, now),
                                          ),
                                          newCountLine: newLine,
                                          dates:
                                              dates == null ||
                                                      _period ==
                                                          RankingPeriod.year
                                                  ? null
                                                  : dates,
                                        ),
                                  ),
                                ),
                                const SizedBox(height: BirdySpace.m),
                                Container(
                                  key: const ValueKey('ranking-chips'),
                                  child: _periodChips(l10n, c),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: BirdySpace.block),
                        ],
                      ),
                    ),
                    if (loading)
                      const SliverPadding(
                        padding: EdgeInsets.symmetric(
                          horizontal: BirdySpace.page,
                        ),
                        sliver: SliverToBoxAdapter(
                          child: _RankingListSkeleton(),
                        ),
                      )
                    else if (ranked.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        // Nothing in the widest period: nothing heard yet.
                        // Otherwise the period hides birds heard before.
                        child:
                            _period == RankingPeriod.all
                                ? BirdyEmptyState(
                                  icon: BirdyIcons.heard,
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
                    else
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: BirdySpace.page,
                        ),
                        sliver: SliverList.list(
                          children: [
                            BirdyBlock(
                              key: const ValueKey('ranking-podium-block'),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _blockTitle(
                                    l10n.forkRankingPodiumTitle,
                                    c,
                                    trailing: _confirmedSwitch(l10n, c),
                                  ),
                                  const SizedBox(height: BirdySpace.m),
                                  RankingPodium(
                                    top: ranked.take(3).toList(),
                                    onOpen: _open,
                                  ),
                                ],
                              ),
                            ),
                            if (ranked.length > 3) ...[
                              const SizedBox(height: BirdySpace.block),
                              BirdyListBlock(
                                key: const ValueKey('ranking-list-block'),
                                title: l10n.forkRankingListTitle,
                                trailing: _sortControl(l10n, c),
                                children: [
                                  for (var i = 3; i < ranked.length; i++)
                                    RankingRow(
                                      rank: i + 1,
                                      species: ranked[i],
                                      fraction: ranked[i].value / leader,
                                      index: i - 3,
                                      onTap: () => _open(ranked[i]),
                                    ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
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

  /// White chips on the hero, the chosen one in ink.
  Widget _periodChips(AppLocalizations l10n, BirdyColors c) => Wrap(
    spacing: BirdySpace.s,
    runSpacing: BirdySpace.s,
    children: [
      for (final p in RankingPeriod.values)
        BirdyFilterChip(
          label: _periodLabel(l10n, p),
          selected: _period == p,
          selectedColors: BirdyChipColors.ink(c),
          onSelected: () => setState(() => _period = p),
        ),
    ],
  );

  /// Title 20 of a white block, with [trailing] on its baseline.
  Widget _blockTitle(String title, BirdyColors c, {required Widget trailing}) =>
      Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(
              title,
              style: BirdyText.heading.copyWith(color: c.text1),
            ),
          ),
          trailing,
        ],
      );

  /// « Confirmées » switch of the podium block header.
  Widget _confirmedSwitch(AppLocalizations l10n, BirdyColors c) => Semantics(
    toggled: _confirmedOnly,
    label: l10n.forkConfirmedOnly,
    excludeSemantics: true,
    child: InkWell(
      onTap: () => setState(() => _confirmedOnly = !_confirmedOnly),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: BirdySizes.target),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.forkConfirmedShort,
              style: BirdyText.bodyCompact.copyWith(color: c.text1),
            ),
            const SizedBox(width: BirdySpace.s),
            BirdySwitch(
              value: _confirmedOnly,
              onChanged: (v) => setState(() => _confirmedOnly = v),
            ),
          ],
        ),
      ),
    ),
  );

  /// « par contacts ▾ » of the list block header: opens the sort sheet.
  Widget _sortControl(AppLocalizations l10n, BirdyColors c) => InkWell(
    onTap: _openSortSheet,
    child: ConstrainedBox(
      constraints: const BoxConstraints(minHeight: BirdySizes.target),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l10n.forkRankingByShort(_orderWord(l10n, _order)),
            style: BirdyText.caption.copyWith(color: c.text2),
          ),
          Icon(AppIcons.expandMore, color: c.text2),
        ],
      ),
    ),
  );

  /// Sort order and « Oiseaux seulement » filter, in a sheet.
  Future<void> _openSortSheet() {
    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
    Widget option(String label, bool checked, VoidCallback onTap) => InkWell(
      onTap: () {
        Navigator.of(context).pop();
        setState(onTap);
      },
      child: Semantics(
        checked: checked,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: BirdySizes.target),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: BirdySpace.xl),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: BirdyText.label.copyWith(color: c.text1),
                  ),
                ),
                if (checked)
                  Icon(BirdyIcons.tick, color: c.accentText)
                else
                  const SizedBox(width: BirdySpace.xxl),
              ],
            ),
          ),
        ),
      ),
    );
    return showBirdySheet<void>(
      context: context,
      builder:
          (_) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  BirdySpace.xl,
                  0,
                  BirdySpace.xl,
                  BirdySpace.s,
                ),
                child: Text(
                  l10n.forkRankingSortMenu,
                  style: BirdyText.heading.copyWith(color: c.text1),
                ),
              ),
              for (final o in RankingOrder.values)
                option(_orderLabel(l10n, o), _order == o, () => _order = o),
              Divider(height: BirdyStroke.hairline, thickness: BirdyStroke.hairline, color: c.line),
              option(
                l10n.forkBirdsOnly,
                _birdsOnly,
                () => _birdsOnly = !_birdsOnly,
              ),
              const SizedBox(height: BirdySpace.s),
            ],
          ),
    );
  }

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
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            BirdySkeleton.text(
              BirdyText.numberXL.copyWith(color: c.text1),
              placeholder: '00',
            ),
            const SizedBox(width: BirdySpace.s),
            Flexible(
              child: BirdySkeleton.text(
                BirdyText.body.copyWith(color: c.text1),
                placeholder: '000000000000000000',
              ),
            ),
          ],
        ),
        const SizedBox(height: BirdySpace.xs),
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

/// A sensible number of skeleton rows in one white block, at [RankingRow]'s
/// own minimum height, filling a typical viewport under the hero.
class _RankingListSkeleton extends StatelessWidget {
  const _RankingListSkeleton();

  static const int _rows = 5;

  @override
  Widget build(BuildContext context) {
    return BirdyListBlock(
      children: [
        for (var index = 0; index < _rows; index++)
          ConstrainedBox(
            key: index == 0 ? const ValueKey('ranking-list-first') : null,
            constraints: const BoxConstraints(minHeight: BirdySizes.row),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: BirdySpace.l,
                vertical: BirdySpace.s,
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: BirdyGlyph.x5l,
                    child: BirdySkeleton.text(
                      BirdyText.label,
                      placeholder: '00',
                    ),
                  ),
                  BirdySkeleton.box(width: BirdyGlyph.disc36, height: BirdyGlyph.disc36, radius: BirdyRadii.pill),
                  const SizedBox(width: BirdySpace.cozy),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        BirdySkeleton.text(
                          BirdyText.species,
                          placeholder: '000000000000000',
                        ),
                        const SizedBox(height: BirdySpace.snug),
                        BirdySkeleton.bar(height: BirdySpace.s),
                      ],
                    ),
                  ),
                  const SizedBox(width: BirdySpace.m),
                  BirdySkeleton.text(BirdyText.numberM, placeholder: '00'),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
