/// « Fiche espèce » (J6c, fork/maquette/SPEC.md 9.13): full page, or a
/// dark sheet while a listening session runs so the user never leaves it.
/// Wires [species_page_view.dart] to the index, the geo-model, the
/// taxonomy, the AI sheets and the other screens.
library;

import 'dart:async';

import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../features/explore/explore_providers.dart';
import '../../features/explore/widgets/pick_wikipedia_url.dart';
import '../../features/live/live_controller.dart';
import '../../features/live/live_providers.dart';
import '../../features/live/live_screen.dart'; // FORK: listen button of the never-heard block (J7)
import '../audio_output/volume_guard.dart';
import '../../shared/models/taxonomy_species.dart';
import '../../shared/providers/app_providers.dart';
import '../../shared/providers/settings_providers.dart';
import '../../shared/services/link_launcher.dart';
import '../../shared/utils/share_sheet.dart';
import '../data/observation_index.dart';
import '../data/observation_index_service.dart';
import '../design/birdy_tokens.dart';
import '../design/species_accents.dart';
import '../design/widgets/birdy_cross_fade.dart';
import '../design/widgets/birdy_sheet.dart';
import '../map/base_layers.dart';
import '../map/contact_map_screen.dart';
import '../map/contact_map_sheets.dart';
import '../lpo/species_lpo_entry.dart';
import '../settings/france_features.dart'; // FORK: France-only gate
import '../ranking/species_activity_section.dart';
import '../reliability/reliability_screen.dart' show precisionLine; // FORK: heard inset (J7)
import '../sound_library/sound_library_screen.dart';
import '../species_photo/species_photo.dart';
import '../species_sheet/species_sheet.dart';
import 'meet_species_block.dart';
import 'never_heard_block.dart';
import '../world_map/world_map_providers.dart'; // FORK: world map (J7)
import '../world_map/world_map_section.dart'; // FORK: world map (J7)
import 'section_title.dart';
import 'species_clip_player.dart';
import 'species_mini_map.dart';
import 'species_page_drag_close.dart';
import 'species_page_loader.dart';
import 'species_page_model.dart';
import 'species_page_text.dart';
import 'species_page_view.dart';

/// Opens the species page: a full page, or a sheet over a running listening
/// session (Live, point count, survey), themed like the screen under it.
Future<void> showSpeciesPage(
  BuildContext context,
  WidgetRef ref, {
  required String scientificName,
  required String commonName,
}) {
  final state = ref.read(liveStateProvider);
  final listening = state == LiveState.active || state == LiveState.paused;
  if (!listening) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder:
            (_) => SpeciesPage(
              scientificName: scientificName,
              commonName: commonName,
            ),
      ),
    );
  }
  return showBirdySheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: false,
    // The DraggableScrollableSheet below already sizes itself to (nearly)
    // the full screen height: wrapping it in the helper's usual outer
    // bottom padding would shrink that available height instead of just
    // clearing the nav bar. SpeciesPage adds the same inset itself, as
    // trailing padding inside its own scroll view (species_page_screen.dart
    // `MediaQuery.viewPaddingOf(context).bottom`).
    addBottomInset: false,
    clipBehavior: Clip.antiAlias,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(BirdyRadii.card),
      ),
    ),
    builder:
        (_) => DraggableScrollableSheet(
          initialChildSize: 0.9,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder:
              (_, controller) => SpeciesPage(
                scientificName: scientificName,
                commonName: commonName,
                scrollController: controller,
              ),
        ),
  );
}

/// Base layer of the mini map; null in tests and while the online-map
/// consent (`privacyAllowMapProvider`, off by default) is not given: the same
/// gate as OSM everywhere else, and it covers the IGN base maps too.
final speciesMiniMapTilesProvider = Provider<Widget?>((ref) {
  if (!ref.watch(privacyAllowMapProvider)) return null;
  return buildBaseTileLayer(
    MapBaseLayer.fromName(
      ref.read(sharedPreferencesProvider).getString(kMapBaseLayerPref),
    ),
  );
});

class SpeciesPage extends ConsumerStatefulWidget {
  const SpeciesPage({
    super.key,
    required this.scientificName,
    required this.commonName,
    this.scrollController,
    this.clock,
  });

  /// The page's clock, for the date-dependent lines (heard line, current
  /// month); the real time when null. Tests pass a fixed one.
  final DateTime Function()? clock;

  final String scientificName;

  /// Shown until the taxonomy gives the localized name.
  final String commonName;

  /// Set inside a sheet: close X and grab handle, the sheet scrolls.
  final ScrollController? scrollController;

  @override
  ConsumerState<SpeciesPage> createState() => _SpeciesPageState();
}

class _SpeciesPageState extends ConsumerState<SpeciesPage> {
  // Read once here: `ref` is off limits in dispose.
  late final SpeciesPageLoader _loader;
  late final SpeciesClipPlayer _player;
  late final ObservationIndexService _indexService;

  TaxonomySpecies? _detail;
  String? _description;
  SpeciesRecord? _record;
  YearPresence? _year;

  /// Session « Envoyer à Faune-France » sends from; null hides the entry.
  String? _lpoSessionId;

  /// Only used outside a sheet (a sheet already carries its own drag
  /// controller): lets the drag-to-close gesture tell whether the page is
  /// scrolled to the top (J6f-b fix).
  final ScrollController _pageScroll = ScrollController();

  /// Unexpected here this week (J3b): the page explains why.
  bool _unexpectedNow = false;

  /// « Peu commun » here this week (J7 tag), from the geo-model.
  bool _uncommonNow = false;
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    _loader = ref.read(speciesPageLoaderProvider);
    _player = ref.read(speciesClipPlayerProvider);
    _indexService = ref.read(observationIndexServiceProvider)
      ..addListener(_loadRecord);
    unawaited(_loadTaxonomy());
    unawaited(_loadRecord());
    unawaited(_loadYear());
  }

  @override
  void dispose() {
    _indexService.removeListener(_loadRecord);
    final playing = _player.playing.value;
    if (playing != null &&
        (_record?.clips ?? const []).any((c) => c.clipPath == playing)) {
      unawaited(_player.stop());
    }
    _pageScroll.dispose();
    super.dispose();
  }

  Future<void> _loadTaxonomy() async {
    try {
      final locale = ref.read(effectiveSpeciesLocaleProvider);
      final taxonomy = await ref.read(taxonomyServiceProvider.future);
      final description = await ref
          .read(speciesDescriptionServiceProvider)
          .getDescription(widget.scientificName, locale);
      if (!mounted) return;
      setState(() {
        _detail = taxonomy.lookup(widget.scientificName);
        _description = description;
      });
    } catch (error) {
      debugPrint('[SpeciesPage] taxonomy not loaded: $error');
    }
  }

  /// Also runs whenever the index changes (session saved, review, rebuild).
  Future<void> _loadRecord() async {
    final generation = ++_loadGeneration;
    final record = await _loader.record(widget.scientificName);
    if (!mounted || generation != _loadGeneration) return;
    setState(() => _record = record);
    final lpo = await _loader.lastConfirmedSession(widget.scientificName);
    if (mounted && generation == _loadGeneration && lpo != _lpoSessionId) {
      setState(() => _lpoSessionId = lpo);
    }
  }

  Future<void> _sendToLpo() async {
    final id = _lpoSessionId;
    if (id == null) return;
    final session = await ref.read(sessionRepositoryProvider).load(id);
    if (session == null || !mounted) return;
    await openLpoSendForSpecies(
      context,
      session: session,
      scientificName: widget.scientificName,
    );
  }

  Future<void> _loadYear() async {
    final year = await _loader.presence(widget.scientificName);
    if (mounted && year != null) setState(() => _year = year);
    final unexpected = await _loader.unexpectedNow(
      widget.scientificName,
      now: DateTime.now(),
    );
    if (mounted && unexpected) setState(() => _unexpectedNow = true);
    final uncommon = await _loader.uncommonNow(
      widget.scientificName,
      now: DateTime.now(),
    );
    if (mounted && uncommon) setState(() => _uncommonNow = true);
  }

  /// Tag pills of the header: notebook state, season, local rarity. Each one
  /// waits for its own data.
  List<SpeciesTag> _tags() {
    final record = _record;
    final year = _year;
    return [
      if (record != null)
        record.heard ? SpeciesTag.inBook : SpeciesTag.toDiscover,
      if (year != null)
        switch (year.weekSpan.kind) {
          PresenceKind.allYear => SpeciesTag.allYear,
          // Never expected here at any week: neither migrant nor resident.
          PresenceKind.rare => null,
          _ => SpeciesTag.migrant,
        },
      if (_unexpectedNow)
        SpeciesTag.rare
      else if (_uncommonNow)
        SpeciesTag.uncommon,
    ].whereType<SpeciesTag>().toList();
  }

  /// The « Écouter » action, like the shell's disc: inside a sheet over a
  /// listening, closes the sheet instead of stacking a second screen.
  void _listen() {
    if (widget.scrollController != null) {
      Navigator.of(context).maybePop();
      return;
    }
    final state = ref.read(liveStateProvider);
    final running = state == LiveState.active || state == LiveState.paused;
    _push(running ? const LiveScreen() : const LiveScreen(forceAutoStart: true));
  }

  DateTime _now() => widget.clock?.call() ?? DateTime.now();

  String get _name =>
      _detail?.commonNameForLocale(ref.read(effectiveSpeciesLocaleProvider)) ??
      widget.commonName;

  String? _heard(AppLocalizations l10n, String language) {
    final tally = _record?.tally;
    if (tally == null) return null;
    return heardSentence(
      l10n,
      language,
      contacts: tally.contacts,
      days: tally.days,
      last: tally.last,
      now: _now(),
    );
  }

  /// « Entendu 142 fois, dernière fois hier à 7 h 42 »: the heard inset.
  String? _heardShort(AppLocalizations l10n, String language) {
    final tally = _record?.tally;
    if (tally == null) return null;
    return l10n.forkFicheHeardShort(
      tally.contacts,
      lastHeardWhen(l10n, language, tally.last, now: _now()),
    );
  }

  Future<void> _share(String? latin, String? heard) => reportShareFailure(
    context,
    SharePlus.instance.share(
      ShareParams(
        text: speciesShareText(name: _name, latin: latin, heard: heard),
        sharePositionOrigin: shareOriginFrom(context),
      ),
    ),
  );

  Future<void> _play(IndexedDetection clip) async {
    final path = clip.clipPath;
    if (path == null) return;
    if (_player.playing.value == path) {
      await _player.stop();
    } else {
      ensureAudible(context, ref);
      await _player.play(path);
    }
  }

  Future<void> _setFavorite(IndexedDetection clip, bool favorite) async {
    final record = _record;
    if (record == null) return;
    // Shown at once; the index notifies and the page reloads after.
    setState(
      () =>
          _record = record.copyWith(
            favorites:
                favorite
                    ? {...record.favorites, clip.key}
                    : ({...record.favorites}..remove(clip.key)),
          ),
    );
    await _loader.setFavorite(clip.key, favorite: favorite);
    await _loadRecord();
  }

  void _push(Widget screen) => Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => screen));

  List<SpeciesLink> _links(TaxonomySpecies detail) => [
    if (detail.ebirdUrl != null)
      (
        label: 'eBird',
        iconAsset: 'assets/images/icon-ebird.png',
        url: detail.ebirdUrl!,
      ),
    if (detail.inatUrl != null)
      (
        label: 'iNaturalist',
        iconAsset: 'assets/images/icon-inat.png',
        url: detail.inatUrl!,
      ),
    (
      label: 'Wikipedia',
      iconAsset: 'assets/images/icon-wikipedia.png',
      url: pickWikipediaUrl(
        scientificName: widget.scientificName,
        bundledUrls: detail.wikipediaUrls,
        locale: ref.read(effectiveSpeciesLocaleProvider),
      ),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
    final language = Localizations.localeOf(context).languageCode;
    ref.watch(effectiveSpeciesLocaleProvider);
    final latin =
        ref.watch(showSciNamesProvider)
            ? (_detail?.displayScientificName ?? widget.scientificName)
            : null;
    final sheet = watchSpeciesSheet(ref, widget.scientificName);
    final tint = SpeciesAccents.tintOf(widget.scientificName);
    final record = _record;
    final heard = _heard(l10n, language);
    final heardShort = _heardShort(l10n, language);
    final now = _now();
    final detail = _detail;
    final referenceUrl = detail?.ebirdListenUrl;
    final inSheet = widget.scrollController != null;

    final loadingRecord = record == null;
    final showSounds =
        loadingRecord || (record.clips.isNotEmpty || referenceUrl != null);
    final showActivity = loadingRecord || record.heard;
    final summary = sheet?.sections[SheetSection.summary];
    final byEar = sheet?.sections[SheetSection.byEar];
    final migration = sheet?.sections[SheetSection.migration];
    final showMeet = sheet != null && meetHasContent(sheet);
    final showWorldMap = ref.watch(worldMapVisibleProvider(widget.scientificName));

    // FORK-owned list (J7): seven blocks, one title each, in the order people
    // ask questions. Who is it (the header: tags, summary, heard inset), its
    // song, getting to know it, when to see it, where it lives, my
    // encounters, going further. Never heard: the invitation comes first.
    // The song and activity/map blocks are always in place from the first
    // frame (their skeletons reserve the same shape the loaded block will
    // fill in), and so is the heard inset of the header (a one-line
    // skeleton): only the AI sheet/description, the geo-model blocks and the
    // links block still wait on their own data to appear, since whether they
    // will show at all is not knowable ahead of time.
    final blocks = <Widget>[
      if (!loadingRecord && !record.heard)
        NeverHeardBlock(
          key: const ValueKey('fiche-never-heard'),
          onListen: _listen,
        ),
      // 2. Son chant: reference, « À l'oreille », my best recordings.
      if (showSounds || byEar != null)
        KeyedSubtree(
          key: const ValueKey('fiche-sounds'),
          child: _crossFade(
            loadingRecord
                ? KeyedSubtree(
                  key: const ValueKey('fiche-sounds-skeleton'),
                  child: SongBlock.skeleton(context),
                )
                : KeyedSubtree(
                  key: const ValueKey('fiche-sounds-real'),
                  child: ValueListenableBuilder<String?>(
                    valueListenable: _player.playing,
                    builder:
                        (context, playing, _) => SongBlock(
                          byEar: byEar,
                          clips: record.clips,
                          favorites: record.favorites,
                          playing: playing,
                          lineOf:
                              (clip) => clipLine(l10n, language, clip, now: now),
                          onPlay: _play,
                          onFavorite: _setFavorite,
                          onReference:
                              referenceUrl == null
                                  ? null
                                  : () => openExternalUrl(context, referenceUrl),
                          moreCount: record.clipCount,
                          onMore:
                              () => _push(
                                SpeciesClipsScreen(
                                  scientificName: widget.scientificName,
                                  fallbackName: _name,
                                ),
                              ),
                        ),
                  ),
                ),
          ),
        ),
      // 3. Fais sa connaissance (the block carries its own title).
      if (showMeet)
        MeetSpeciesBlock(sheet: sheet)
      else if ((sheet == null || sheet.sections.isEmpty) && _description != null)
        DescriptionBlock(text: _description!, source: detail?.descriptionSource),
      // 4. Quand le voir: the year and the migration text.
      if (_year != null)
        HereNowCard(
          year: _year!,
          sentence: presenceSentence(l10n, language, _year!, now: now),
          currentMonth: now.month,
          rareNote: _unexpectedNow ? l10n.forkRareHereExplanation : null,
          migration: migration,
        )
      else if (migration != null)
        // No geo-model: the migration text alone, in its own tonal block.
        SheetTextBlock(
          key: const ValueKey('fiche-migration'),
          section: SheetSection.migration,
          text: migration,
        ),
      // 5. The world map of the seasonal range (FORK: J7), hidden without a
      // geo-model. The nesting line lives in this block only.
      if (showWorldMap)
        WorldMapSection(
          scientificName: widget.scientificName,
          speciesName: widget.commonName, // FORK: title of the full-screen map
          nesting: sheet?.nesting,
        ),
      // 6. Hours and mini map; only when heard.
      if (showActivity)
        KeyedSubtree(
          key: const ValueKey('fiche-activity'),
          child: _crossFade(
            loadingRecord
                ? KeyedSubtree(
                  key: const ValueKey('fiche-activity-skeleton'),
                  child: ActivityAndMap.skeleton(context),
                )
                : KeyedSubtree(
                  key: const ValueKey('fiche-activity-real'),
                  child: ActivityAndMap(
                    hours: record.hours,
                    map:
                        record.spots.isEmpty
                            ? null
                            : SpeciesMiniMap(
                              spots: record.spots,
                              tileLayer: ref.watch(speciesMiniMapTilesProvider),
                              semanticLabel: l10n.forkFicheMapLabel,
                              onTap: _openMap,
                            ),
                    onSeeOnMap: record.spots.isEmpty ? null : _openMap,
                  ),
                ),
          ),
        ),
      // 7. Pour aller plus loin: links, then the LPO entry and the footer.
      if (detail != null)
        GoFurtherBlock(
          key: const ValueKey('fiche-go-further'),
          links: _links(detail),
          onOpen: (url) => openExternalUrl(context, url),
        ),
      if (_lpoSessionId != null && watchFranceFeatures(context, ref))
        SpeciesLpoEntry(onSend: _sendToLpo),
      const SpeciesPageFooter(),
    ];

    // FORK: species tint for the block titles (J6h fix)
    final content = SpeciesTintScope(
      tint: tint,
      child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: kSpeciesPageMaxWidth),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SpeciesPageHeader(
              name: _name,
              latin: latin,
              tint: tint,
              photo: SpeciesPhoto(species: detail),
              onShare: () => _share(latin, heard),
              // The sheet closes like the page (J6g-e).
              onBack: () => Navigator.of(context).maybePop(),
              inSheet: inSheet,
              // FORK: J7 7 blocks, the tags, the summary and the heard inset
              // live in the header.
              tags: _tags(),
              summary: summary,
              heardLine: heardShort,
              heardLoading: loadingRecord,
              verified: record?.verified ?? false,
              precision:
                  record == null
                      ? null
                      : precisionLine(l10n, record.confirmed, record.reviewed),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                BirdySpace.page,
                BirdySpace.l,
                BirdySpace.page,
                // FORK: viewPaddingOf, not paddingOf — inside a sheet
                // (showBirdySheet, useSafeArea: true) the ambient padding
                // does not carry the bottom nav bar inset, only viewPadding
                // does (J6f-b bugfix).
                BirdySpace.xxxl + MediaQuery.viewPaddingOf(context).bottom,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < blocks.length; i++) ...[
                    if (i > 0) const SizedBox(height: BirdySpace.block),
                    blocks[i],
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      ),
    );

    // The sheet already scrolls with its own controller; outside a sheet,
    // this page needs one of its own to tell the drag-to-close gesture
    // whether it is scrolled to the top.
    final effectiveController = widget.scrollController ?? _pageScroll;
    final scroll = SingleChildScrollView(
      controller: effectiveController,
      child: content,
    );
    // Drag down to close, like a sheet, on Android too (J6f-b fix): a drag
    // from the header, or anywhere once scrolled back to the top, follows
    // the finger and pops the page past a threshold or a fling.
    final body = SpeciesPageDragClose(
      scrollController: effectiveController,
      onClose: () => Navigator.of(context).maybePop(),
      child: scroll,
    );
    if (inSheet) return ColoredBox(color: c.background, child: body);
    return Scaffold(backgroundColor: c.background, body: body);
  }

  void _openMap() => _push(
    ContactMapScreen(
      initialSpecies: SpeciesChoice(widget.scientificName, _name),
    ),
  );

  /// Fades [child] in in place: a loaded block replacing its skeleton.
  /// [child]'s own key tells the switcher when to cross-fade.
  static Widget _crossFade(Widget child) => BirdyCrossFade(child: child);
}

/// Whether `SpeciesInfoOverlay.show` opens this page instead of the
/// upstream sheet, which stays in its file for merges.
const bool kForkSpeciesPage = true;
