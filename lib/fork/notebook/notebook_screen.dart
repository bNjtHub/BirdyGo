/// « Mon carnet » (J6e, SPEC.md 9.10): the collection. Discovered species in
/// color, species waiting for confirmation with a dashed outline, and
/// mystery silhouettes for the birds expected here this week.
library;

import 'dart:async';

import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/explore/explore_providers.dart';
import '../../features/explore/widgets/species_info_overlay.dart';
import '../../shared/providers/settings_providers.dart';
import '../../shared/utils/app_icons.dart';
import '../data/observation_index_service.dart';
import '../design/birdy_motion.dart';
import '../design/birdy_tokens.dart';
import '../design/birdy_typography.dart';
import '../design/species_accents.dart';
import '../design/widgets/birdy_block.dart';
import '../design/widgets/birdy_buttons.dart';
import '../design/widgets/birdy_filter_chip.dart';
import '../design/widgets/birdy_headers.dart';
import '../design/widgets/birdy_pill.dart';
import '../design/widgets/birdy_skeleton.dart';
import '../design/widgets/empty_state.dart';
import '../design/widgets/species_card.dart';
import '../ranking/ranking_screen.dart';
import '../reliability/quick_review_screen.dart';
import '../species_sheet/species_sheet.dart';
import 'notebook_loader.dart';
import 'notebook_model.dart';
import 'notebook_seen_store.dart';
import 'notebook_visuals.dart';

/// Widest column on tablets.
const double _maxWidth = 600;
const int _columns = 3;
const double _gap = 10;

class NotebookScreen extends ConsumerStatefulWidget {
  const NotebookScreen({super.key});

  @override
  ConsumerState<NotebookScreen> createState() => _NotebookScreenState();
}

class _NotebookScreenState extends ConsumerState<NotebookScreen> {
  List<HeardSpecies>? _heard;
  List<ExpectedSpecies>? _expected;
  bool _expectedDone = false;
  Set<String> _seen = const {};
  NotebookFilter _filter = NotebookFilter.all;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_reload());
      unawaited(_loadExpected());
    });
  }

  Future<void> _reload() async {
    final generation = ++_generation;
    final heard = await ref.read(notebookLoaderProvider).heard();
    final seen = await ref.read(notebookSeenStoreProvider).readOrSeed({
      for (final species in heard)
        if (species.verified) species.scientificName,
    });
    if (!mounted || generation != _generation) return;
    setState(() {
      _heard = heard;
      _seen = seen;
    });
  }

  Future<void> _loadExpected() async {
    final expected = await ref.read(notebookLoaderProvider).expected();
    if (!mounted) return;
    setState(() {
      _expected = expected;
      _expectedDone = true;
    });
  }

  void _open(Widget screen) => Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => screen));

  Future<void> _openCard(NotebookCard card) async {
    switch (card.kind) {
      case NotebookCardKind.discovered:
        if (card.isNew) {
          setState(() => _seen = {..._seen, card.scientificName});
          unawaited(
            ref.read(notebookSeenStoreProvider).markSeen(card.scientificName),
          );
        }
        SpeciesInfoOverlay.show(
          context,
          ref,
          scientificName: card.scientificName,
          commonName: card.commonName,
        );
      case NotebookCardKind.toConfirm:
        final keys = await ref
            .read(notebookLoaderProvider)
            .reviewKeysFor(card.scientificName);
        if (!mounted) return;
        _open(QuickReviewScreen(onlyKeys: keys));
      case NotebookCardKind.mystery:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    // A saved session or a review changes the collection.
    ref.listen(observationIndexServiceProvider, (_, _) => _reload());

    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
    final taxonomy = ref.watch(taxonomyServiceProvider).value;
    final speciesLocale = ref.watch(effectiveSpeciesLocaleProvider);
    final sheets =
        sheetsApplyTo(speciesLocale)
            ? ref.watch(speciesSheetsProvider).value
            : null;
    String nameOf(String sci, String fallback) =>
        taxonomy?.lookup(sci)?.commonNameForLocale(speciesLocale) ?? fallback;

    final heard = _heard;
    final loadingHeard = heard == null;
    // The species count of `heard()` and the expected-species list of
    // `expected()` (geo-model, needs the location) resolve independently;
    // mystery cards, rarity marks and both progress-block numbers all need
    // the second one, so the notebook is not final until both are in, even
    // once `heard` alone is ready.
    final loadingExpected = !_expectedDone;
    final dataReady = !loadingHeard && !loadingExpected;
    final notebook =
        loadingHeard
            ? null
            : buildNotebook(
              heard: [
                for (final species in heard)
                  if (isBird(taxonomy, species.scientificName))
                    HeardSpecies(
                      scientificName: species.scientificName,
                      commonName: nameOf(
                        species.scientificName,
                        species.commonName,
                      ),
                      contacts: species.contacts,
                      verified: species.verified,
                      inQueue: species.inQueue,
                    ),
              ],
              expected: _expected,
              seen: _seen,
              hint: (sci) => sheets?[sci]?.hint,
            );
    final showScaffold = !dataReady || notebook!.cards.isNotEmpty;

    final slivers = <Widget>[
      // Announced once, while anything is still loading; the skeletons
      // below are excluded from semantics so nothing reads twice. Carried
      // by the header (real size, always painted) rather than a bare node,
      // which a scroll view's semantics can drop when it has none.
      SliverToBoxAdapter(
        child: Semantics(
          liveRegion: true,
          label: dataReady ? null : l10n.forkNotebookLoading,
          child: _header(l10n, c, notebook, loadingHeard),
        ),
      ),
      if (showScaffold) ...[
        SliverToBoxAdapter(child: _progressBlock(l10n, c, notebook, dataReady)),
        SliverToBoxAdapter(child: _countBlocks(l10n, c, notebook, dataReady)),
        SliverToBoxAdapter(child: _filterChips(l10n, c)),
        ..._grid(l10n, c, notebook, dataReady),
      ] else
        SliverFillRemaining(
          hasScrollBody: false,
          child: BirdyEmptyState(
            icon: AppIcons.menuBook,
            title: l10n.forkNotebookEmptyTitle,
            body: l10n.forkNotebookEmpty,
          ),
        ),
    ];

    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _maxWidth),
            child: CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    BirdySpace.page,
                    BirdySpace.page,
                    BirdySpace.page,
                    BirdySpace.page,
                  ),
                  sliver: SliverMainAxisGroup(slivers: slivers),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Fades [child] in in place (no move, no scale): a loaded value replacing
  /// its skeleton, or one final state replacing another. [child]'s own key
  /// tells the switcher when to cross-fade.
  static Widget _crossFade(Widget child) => AnimatedSwitcher(
    duration: BirdyMotion.enter,
    switchInCurve: BirdyMotion.standard,
    switchOutCurve: BirdyMotion.standard,
    transitionBuilder:
        (child, animation) => FadeTransition(opacity: animation, child: child),
    child: child,
  );

  Widget _header(
    AppLocalizations l10n,
    BirdyColors c,
    Notebook? notebook,
    bool loadingHeard,
  ) => Padding(
    key: const ValueKey('notebook-header'),
    padding: const EdgeInsets.only(bottom: BirdySpace.block),
    child: BirdyTabHeader(
      title: l10n.forkNotebookTitle,
      captionWidget: _crossFade(
        // One line, truncated if need be: a stray plural form ("Aucune
        // espèce découverte" vs "N espèces découvertes") must never wrap
        // one state and not the other, so the row's height never depends
        // on which one is showing.
        loadingHeard
            ? BirdySkeleton.text(
              BirdyText.caption,
              key: const ValueKey('notebook-caption-skeleton'),
              placeholder: '00000000000000000000',
            )
            : Text(
              l10n.forkNotebookDiscovered(notebook!.discovered),
              key: const ValueKey('notebook-caption-real'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: BirdyText.caption.copyWith(color: c.text2),
            ),
      ),
      actions: [
        BirdyIconButton(
          icon: AppIcons.leaderboard,
          semanticLabel: l10n.forkRanking,
          onPressed: () => _open(const RankingScreen()),
        ),
      ],
    ),
  );

  /// Body of the progress block, real or skeleton: same shape either way
  /// (number, caption, bar, silhouettes line) so the block never resizes
  /// once [notebook.expected] (SPEC.md geo-model) settles.
  Widget _progressBlockBody(
    AppLocalizations l10n,
    BirdyColors c,
    Notebook? notebook,
  ) {
    final ready = notebook != null;
    final numberStyle = BirdyText.display.copyWith(
      color: c.text1,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final captionStyle = BirdyText.body.copyWith(
      color: c.text1,
      fontWeight: FontWeight.w700,
    );
    return BirdyBlock(
      key: const ValueKey('notebook-progress-block'),
      tone: BirdyBlockTone.tonal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              ready
                  ? Text('${notebook.expectedFound}', style: numberStyle)
                  : BirdySkeleton.text(numberStyle, placeholder: '00'),
              const SizedBox(width: BirdySpace.s),
              Expanded(
                // One line, truncated if need be (see the header caption):
                // the digit count of the geo-model's total must not change
                // how many lines this needs.
                child:
                    ready
                        ? Text(
                          l10n.forkNotebookProgressCaption(notebook.expected!),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: captionStyle,
                        )
                        : BirdySkeleton.text(
                          captionStyle,
                          placeholder: '0000000000000000000000000000000000',
                        ),
              ),
            ],
          ),
          const SizedBox(height: BirdySpace.s),
          BirdyProgressBar(
            value: ready ? notebook.expectedFound / notebook.expected! : 0,
            color: c.accent,
            track: c.surface1,
          ),
          const SizedBox(height: BirdySpace.s),
          ready
              ? Text(
                l10n.forkNotebookSilhouettes,
                style: BirdyText.caption.copyWith(color: c.accentText),
              )
              : BirdySkeleton.text(
                BirdyText.caption,
                placeholder: l10n.forkNotebookSilhouettes,
                maxLines: null,
              ),
        ],
      ),
    );
  }

  Widget _progressBlock(
    AppLocalizations l10n,
    BirdyColors c,
    Notebook? notebook,
    bool dataReady,
  ) {
    if (!dataReady) {
      return _crossFade(
        Padding(
          key: const ValueKey('notebook-progress-skeleton'),
          padding: const EdgeInsets.only(bottom: BirdySpace.block),
          child: _progressBlockBody(l10n, c, null),
        ),
      );
    }
    final expected = notebook!.expected;
    final hasExpected = expected != null && expected > 0;
    if (!hasExpected) {
      if (expected != null) {
        return _crossFade(
          const SizedBox.shrink(key: ValueKey('notebook-progress-hidden')),
        );
      }
      return _crossFade(
        Padding(
          key: const ValueKey('notebook-progress-no-place'),
          padding: const EdgeInsets.only(bottom: BirdySpace.block),
          child: BirdyBlock(
            tone: BirdyBlockTone.tonal,
            child: Text(
              l10n.forkNotebookNoPlace,
              style: BirdyText.body.copyWith(color: c.text1),
            ),
          ),
        ),
      );
    }
    return _crossFade(
      Padding(
        key: const ValueKey('notebook-progress-real'),
        padding: const EdgeInsets.only(bottom: BirdySpace.block),
        child: _progressBlockBody(l10n, c, notebook),
      ),
    );
  }

  Widget _countBlocks(
    AppLocalizations l10n,
    BirdyColors c,
    Notebook? notebook,
    bool dataReady,
  ) {
    final toDiscover =
        dataReady ? notebook!.filtered(NotebookFilter.toDiscover).length : null;
    final rare = dataReady ? notebook!.filtered(NotebookFilter.rare).length : null;
    return Padding(
      padding: const EdgeInsets.only(bottom: BirdySpace.block),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _CountBlock(
                key: const ValueKey('notebook-count-toDiscover'),
                count: toDiscover,
                label: toDiscover == null ? null : l10n.forkNotebookToDiscoverLabel,
                tone: BirdyBlockTone.toCheck,
                onTap:
                    () => setState(() => _filter = NotebookFilter.toDiscover),
              ),
            ),
            const SizedBox(width: BirdySpace.block),
            Expanded(
              child: _CountBlock(
                key: const ValueKey('notebook-count-rare'),
                count: rare,
                // "oiseau rare" (=1) vs "oiseaux rares" (other): one line
                // either way (see `_CountBlock`), so the block's height
                // never hinges on which plural form wins.
                label: rare == null ? null : l10n.forkNotebookRareLabel(rare),
                tone: BirdyBlockTone.oriole,
                onTap: () => setState(() => _filter = NotebookFilter.rare),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterChips(AppLocalizations l10n, BirdyColors c) => Padding(
    key: const ValueKey('notebook-filter-chips'),
    padding: const EdgeInsets.only(bottom: BirdySpace.block),
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final filter in NotebookFilter.values)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: BirdySpace.s),
              child: BirdyFilterChip(
                label: switch (filter) {
                  NotebookFilter.all => l10n.forkNotebookFilterAll,
                  NotebookFilter.discovered =>
                    l10n.forkNotebookFilterDiscovered,
                  NotebookFilter.toDiscover =>
                    l10n.forkNotebookFilterToDiscover,
                  NotebookFilter.rare => l10n.forkNotebookFilterRare,
                },
                selected: _filter == filter,
                selectedColors: switch (filter) {
                  NotebookFilter.all => BirdyChipColors.ink(c),
                  NotebookFilter.discovered => BirdyChipColors.sure(c),
                  NotebookFilter.toDiscover => BirdyChipColors.tonal(c),
                  NotebookFilter.rare => BirdyChipColors.oriole(c),
                },
                onSelected: () => setState(() => _filter = filter),
              ),
            ),
        ],
      ),
    ),
  );

  /// Generic grid rows of 3 columns: [cellBuilder] gets each cell's column
  /// width and index, so the skeleton grid and the real one share the exact
  /// same geometry (widths, gaps) and never shift into one another.
  List<Widget> _columnRows(
    int rowCount,
    Widget Function(int index, double width, double visualSize) cellBuilder,
  ) => [
    SliverList.builder(
      itemCount: rowCount,
      itemBuilder: (context, row) {
        final start = row * _columns;
        return Padding(
          padding: EdgeInsets.only(top: row == 0 ? 0 : _gap),
          child: LayoutBuilder(
            builder: (context, box) {
              final width = (box.maxWidth - _gap * (_columns - 1)) / _columns;
              final visualSize = (width - 20).clamp(40.0, 72.0);
              return IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < _columns; i++) ...[
                      if (i > 0) const SizedBox(width: _gap),
                      Expanded(
                        child: cellBuilder(start + i, width, visualSize),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        );
      },
    ),
  ];

  /// A card-shaped skeleton: same padding, visual size and two text lines
  /// (name, caption) as a real [SpeciesCard], at [BirdySizes.collectionCard]
  /// minimum. Built from the real text styles (not a plain box) so it grows
  /// with the text scale exactly like a real card does, instead of
  /// undershooting it at 130 %.
  Widget _cardSkeleton(BirdyColors c, double width, double visualSize) =>
      DecoratedBox(
        decoration: BoxDecoration(
          color: c.surface1,
          borderRadius: BorderRadius.circular(BirdyRadii.card),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: BirdySizes.collectionCard),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                BirdySkeleton.box(
                  width: visualSize,
                  height: visualSize,
                  radius: BirdyRadii.thumb,
                ),
                const SizedBox(height: 6),
                BirdySkeleton.text(
                  BirdyText.speciesCompact,
                  placeholder: '0000000000000000',
                ),
                const SizedBox(height: 6),
                BirdySkeleton.text(BirdyText.caption, placeholder: '00000000'),
              ],
            ),
          ),
        ),
      );

  /// Same column geometry as the real grid, filled with card-shaped
  /// skeletons at the real card size ([BirdySizes.collectionCard]): the
  /// exact row count depends on data not in yet, but the shape and the
  /// first cell's rect do not change when the real grid takes over.
  List<Widget> _gridSkeleton(BirdyColors c) {
    const skeletonRows = 2;
    return _columnRows(skeletonRows, (index, width, visualSize) {
      final card = _cardSkeleton(c, width, visualSize);
      return index == 0
          ? KeyedSubtree(key: const ValueKey('notebook-grid-cell-0'), child: card)
          : card;
    });
  }

  List<Widget> _grid(
    AppLocalizations l10n,
    BirdyColors c,
    Notebook? notebook,
    bool dataReady,
  ) {
    if (!dataReady) return _gridSkeleton(c);
    final cards = notebook!.filtered(_filter);
    if (cards.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: BirdyEmptyState.inline(
            icon: AppIcons.menuBook,
            title: l10n.forkNotebookEmptyFilteredTitle,
            body: l10n.forkNotebookEmptyFiltered,
            kind: BirdyEmptyKind.filtered,
            action: l10n.forkNotebookShowAll,
            onAction: () => setState(() => _filter = NotebookFilter.all),
          ),
        ),
      ];
    }
    final rows = (cards.length / _columns).ceil();
    return _columnRows(rows, (index, width, visualSize) {
      if (index >= cards.length) return const SizedBox.shrink();
      final card = _card(l10n, cards[index], visualSize);
      return index == 0
          ? KeyedSubtree(key: const ValueKey('notebook-grid-cell-0'), child: card)
          : card;
    });
  }

  Widget _card(AppLocalizations l10n, NotebookCard card, double visualSize) {
    final key = ValueKey('notebook-${card.kind.name}-${card.scientificName}');
    switch (card.kind) {
      case NotebookCardKind.mystery:
        return Semantics(
          key: key,
          label: l10n.forkNotebookMystery,
          excludeSemantics: card.hint == null,
          child: SpeciesCard.mystery(
            name: l10n.forkNotebookFilterToDiscover,
            visual: NotebookVisuals.mystery(
              card.scientificName,
              size: visualSize,
            ),
            caption: card.hint == null ? null : Text(card.hint!),
          ),
        );
      case NotebookCardKind.toConfirm:
        final c = BirdyColors.of(context);
        return SpeciesCard.toConfirm(
          key: key,
          name: card.commonName,
          visual: NotebookVisuals.species(
            ref,
            card.scientificName,
            size: visualSize,
            muted: true,
          ),
          corner: _rarity(l10n, card.rarity),
          caption: Text(
            l10n.forkNotebookToConfirm,
            style: TextStyle(
              color: c.toCheck.foreground,
              fontWeight: FontWeight.w700,
            ),
          ),
          onTap: () => _openCard(card),
        );
      case NotebookCardKind.discovered:
        return SpeciesCard(
          key: key,
          name: card.commonName,
          visual: NotebookVisuals.species(
            ref,
            card.scientificName,
            size: visualSize,
          ),
          tint: SpeciesAccents.tintOf(card.scientificName),
          corner: _rarity(l10n, card.rarity),
          caption: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l10n.forkNotebookTimes(card.contacts)),
              if (card.isNew) ...[
                const SizedBox(height: 6),
                const NoveltyPill(kind: NoveltyKind.isNew),
              ],
            ],
          ),
          onTap: () => _openCard(card),
        );
    }
  }

  Widget? _rarity(AppLocalizations l10n, RarityMark mark) {
    final c = BirdyColors.of(context);
    final (icon, color, label) = switch (mark) {
      RarityMark.none => (null, null, null),
      RarityMark.uncommon => (
        AppIcons.contrast,
        c.text2,
        l10n.forkRarityUncommon,
      ),
      RarityMark.rare => (AppIcons.diamond, c.orioleText, l10n.forkRarityRare),
      RarityMark.exceptional => (
        AppIcons.star,
        c.orioleText,
        l10n.forkRarityExceptional,
      ),
    };
    if (icon == null) return null;
    return Icon(icon, size: 16, color: color, fill: 1, semanticLabel: label);
  }
}

/// « N à découvrir » / « N rares » block: tappable, sets the matching
/// filter. Big tabular number, label underneath (J6f).
class _CountBlock extends StatelessWidget {
  const _CountBlock({
    super.key,
    required this.count,
    required this.label,
    required this.tone,
    required this.onTap,
  });

  /// Null while its filter's true count is not settled yet (the geo-model
  /// still loading): a skeleton stands in, same line heights.
  final int? count;

  /// One line, truncated if need be: a plural form must never wrap one
  /// state and not the other (see `_countBlocks`).
  final String? label;
  final BirdyBlockTone tone;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = BirdyColors.of(context);
    final ready = count != null && label != null;
    final numberStyle = BirdyText.display.copyWith(
      color: c.text1,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final labelStyle = BirdyText.body.copyWith(
      color: c.text1,
      fontWeight: FontWeight.w700,
    );
    return BirdyBlock(
      tone: tone,
      onTap: onTap,
      semanticLabel: ready ? '$count $label' : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _NotebookScreenState._crossFade(
            ready
                ? Text('$count', key: const ValueKey('count-real'), style: numberStyle)
                : BirdySkeleton.text(
                  numberStyle,
                  key: const ValueKey('count-skeleton'),
                  placeholder: '00',
                ),
          ),
          const SizedBox(height: BirdySpace.xs),
          _NotebookScreenState._crossFade(
            ready
                ? Text(
                  label!,
                  key: const ValueKey('label-real'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: labelStyle,
                )
                : BirdySkeleton.text(
                  labelStyle,
                  key: const ValueKey('label-skeleton'),
                  placeholder: '000000000000',
                ),
          ),
        ],
      ),
    );
  }
}
