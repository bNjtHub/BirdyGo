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
import '../design/birdy_tokens.dart';
import '../design/birdy_typography.dart';
import '../design/species_accents.dart';
import '../design/widgets/birdy_block.dart';
import '../design/widgets/birdy_buttons.dart';
import '../design/widgets/birdy_filter_chip.dart';
import '../design/widgets/birdy_headers.dart';
import '../design/widgets/birdy_pill.dart';
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
    final notebook =
        heard == null
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

    final slivers = <Widget>[
      SliverToBoxAdapter(child: _header(l10n, c, notebook)),
      if (notebook != null) ...[
        if (notebook.cards.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: BirdyEmptyState(
              icon: AppIcons.menuBook,
              title: l10n.forkNotebookEmptyTitle,
              body: l10n.forkNotebookEmpty,
            ),
          )
        else ...[
          SliverToBoxAdapter(child: _progressBlock(l10n, c, notebook)),
          SliverToBoxAdapter(child: _countBlocks(l10n, c, notebook)),
          SliverToBoxAdapter(child: _filterChips(l10n, c)),
          ..._grid(l10n, c, notebook.filtered(_filter)),
        ],
      ],
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

  Widget _header(AppLocalizations l10n, BirdyColors c, Notebook? notebook) =>
      Padding(
        padding: const EdgeInsets.only(bottom: BirdySpace.block),
        child: BirdyTabHeader(
          title: l10n.forkNotebookTitle,
          caption:
              notebook == null
                  ? null
                  : l10n.forkNotebookDiscovered(notebook.discovered),
          actions: [
            BirdyIconButton(
              icon: AppIcons.leaderboard,
              semanticLabel: l10n.forkRanking,
              onPressed: () => _open(const RankingScreen()),
            ),
          ],
        ),
      );

  Widget _progressBlock(
    AppLocalizations l10n,
    BirdyColors c,
    Notebook notebook,
  ) {
    final expected = notebook.expected;
    final hasExpected = expected != null && expected > 0;
    if (!hasExpected) {
      if (expected != null || !_expectedDone) {
        return const SizedBox.shrink();
      }
      return Padding(
        padding: const EdgeInsets.only(bottom: BirdySpace.block),
        child: BirdyBlock(
          tone: BirdyBlockTone.tonal,
          child: Text(
            l10n.forkNotebookNoPlace,
            style: BirdyText.body.copyWith(color: c.text1),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: BirdySpace.block),
      child: BirdyBlock(
        key: const ValueKey('notebook-progress-block'),
        tone: BirdyBlockTone.tonal,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  '${notebook.expectedFound}',
                  style: BirdyText.display.copyWith(
                    color: c.text1,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(width: BirdySpace.s),
                Expanded(
                  child: Text(
                    l10n.forkNotebookProgressCaption(expected),
                    style: BirdyText.body.copyWith(
                      color: c.text1,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: BirdySpace.s),
            BirdyProgressBar(
              value: notebook.expectedFound / expected,
              color: c.accent,
              track: c.surface1,
            ),
            const SizedBox(height: BirdySpace.s),
            Text(
              l10n.forkNotebookSilhouettes,
              style: BirdyText.caption.copyWith(color: c.accentText),
            ),
          ],
        ),
      ),
    );
  }

  Widget _countBlocks(AppLocalizations l10n, BirdyColors c, Notebook notebook) {
    final toDiscover = notebook.filtered(NotebookFilter.toDiscover).length;
    final rare = notebook.filtered(NotebookFilter.rare).length;
    return Padding(
      padding: const EdgeInsets.only(bottom: BirdySpace.block),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _CountBlock(
                count: toDiscover,
                label: l10n.forkNotebookToDiscoverLabel,
                tone: BirdyBlockTone.toCheck,
                onTap:
                    () => setState(() => _filter = NotebookFilter.toDiscover),
              ),
            ),
            const SizedBox(width: BirdySpace.block),
            Expanded(
              child: _CountBlock(
                count: rare,
                label: l10n.forkNotebookRareLabel(rare),
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

  List<Widget> _grid(
    AppLocalizations l10n,
    BirdyColors c,
    List<NotebookCard> cards,
  ) {
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
    return [
      SliverList.builder(
        itemCount: rows,
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
                          child:
                              start + i < cards.length
                                  ? _card(l10n, cards[start + i], visualSize)
                                  : const SizedBox.shrink(),
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
    required this.count,
    required this.label,
    required this.tone,
    required this.onTap,
  });

  final int count;
  final String label;
  final BirdyBlockTone tone;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = BirdyColors.of(context);
    return BirdyBlock(
      tone: tone,
      onTap: onTap,
      semanticLabel: '$count $label',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$count',
            style: BirdyText.display.copyWith(
              color: c.text1,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: BirdySpace.xs),
          Text(
            label,
            style: BirdyText.body.copyWith(
              color: c.text1,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
