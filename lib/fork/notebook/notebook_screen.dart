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
import '../design/widgets/birdy_buttons.dart';
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
      SliverToBoxAdapter(child: _titleRow(l10n, c)),
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
          SliverToBoxAdapter(child: _progressCard(l10n, c, notebook)),
          SliverToBoxAdapter(child: _filterChips(l10n)),
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
                    BirdySpace.xl,
                    BirdySpace.l,
                    BirdySpace.xl,
                    BirdySpace.xl,
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

  Widget _titleRow(AppLocalizations l10n, BirdyColors c) => SizedBox(
    height: BirdySizes.topBar,
    child: Row(
      children: [
        Expanded(
          child: Semantics(
            header: true,
            child: Text(
              l10n.forkNotebookTitle,
              style: BirdyText.title.copyWith(color: c.text1),
            ),
          ),
        ),
        BirdyIconButton(
          icon: AppIcons.leaderboard,
          semanticLabel: l10n.forkRanking,
          onPressed: () => _open(const RankingScreen()),
        ),
      ],
    ),
  );

  Widget _progressCard(
    AppLocalizations l10n,
    BirdyColors c,
    Notebook notebook,
  ) {
    final expected = notebook.expected;
    final hasExpected = expected != null && expected > 0;
    final caption = BirdyText.caption.copyWith(color: c.text2);
    return Padding(
      padding: const EdgeInsets.only(top: BirdySpace.m),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: c.surface1,
          borderRadius: BorderRadius.circular(BirdyRadii.card),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: BirdySpace.l,
            vertical: 14,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.forkNotebookDiscovered(notebook.discovered),
                style: BirdyText.body.copyWith(
                  color: c.text1,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (hasExpected) ...[
                const SizedBox(height: BirdySpace.xs),
                Text(
                  l10n.forkNotebookProgress(notebook.expectedFound, expected),
                  style: BirdyText.body.copyWith(color: c.text1),
                ),
                const SizedBox(height: BirdySpace.s),
                _ProgressBar(value: notebook.expectedFound / expected),
                const SizedBox(height: BirdySpace.s),
                Text(l10n.forkNotebookSilhouettes, style: caption),
              ] else if (expected == null && _expectedDone) ...[
                const SizedBox(height: BirdySpace.xs),
                Text(l10n.forkNotebookNoPlace, style: caption),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _filterChips(AppLocalizations l10n) => Padding(
    padding: const EdgeInsets.only(top: BirdySpace.m, bottom: BirdySpace.m),
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final filter in NotebookFilter.values)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: BirdySpace.s),
              child: ChoiceChip(
                label: Text(switch (filter) {
                  NotebookFilter.all => l10n.forkNotebookFilterAll,
                  NotebookFilter.discovered =>
                    l10n.forkNotebookFilterDiscovered,
                  NotebookFilter.toDiscover =>
                    l10n.forkNotebookFilterToDiscover,
                  NotebookFilter.rare => l10n.forkNotebookFilterRare,
                }),
                selected: _filter == filter,
                onSelected: (_) => setState(() => _filter = filter),
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

/// Light progress bar (SPEC.md 5.7), Martin-pêcheur, no gain animation.
class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    final c = BirdyColors.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(BirdyRadii.pill),
      child: SizedBox(
        height: 10,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: c.line),
            FractionallySizedBox(
              alignment: AlignmentDirectional.centerStart,
              widthFactor: value.clamp(0.0, 1.0),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: c.accent,
                  borderRadius: BorderRadius.circular(BirdyRadii.pill),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
