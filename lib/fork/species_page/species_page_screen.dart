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
import '../ranking/species_activity_section.dart';
import '../sound_library/sound_library_screen.dart';
import '../species_photo/species_photo.dart';
import '../species_sheet/species_sheet.dart';
import 'meet_species_block.dart';
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
  });

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
  }

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
      now: DateTime.now(),
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
    final now = DateTime.now();
    final detail = _detail;
    final referenceUrl = detail?.ebirdListenUrl;
    final inSheet = widget.scrollController != null;

    final loadingRecord = record == null;
    final showSounds =
        loadingRecord || (record.clips.isNotEmpty || referenceUrl != null);
    final showActivity = loadingRecord || record.heard;

    final blocks = <Widget>[
      // The counters, recordings and activity/map blocks are always in
      // place from the first frame (their skeletons reserve the same shape
      // `_load...` will fill in): only the AI sheet/description and the
      // links block below still wait on their own data to appear, since
      // whether they will show at all is not knowable ahead of time.
      KeyedSubtree(
        key: const ValueKey('fiche-heard'),
        child: _crossFade(
          loadingRecord
              ? KeyedSubtree(
                key: const ValueKey('fiche-heard-skeleton'),
                child: HeardBlock.skeleton(context),
              )
              : KeyedSubtree(
                key: const ValueKey('fiche-heard-real'),
                child: HeardBlock(record: record, heard: heard),
              ),
        ),
      ),
      // FORK-owned order (J7): the user's own sounds come right after the
      // counters, before what the geo-model says about the year.
      if (showSounds)
        KeyedSubtree(
          key: const ValueKey('fiche-sounds'),
          child: _crossFade(
            loadingRecord
                ? KeyedSubtree(
                  key: const ValueKey('fiche-sounds-skeleton'),
                  child: MySoundsBlock.skeleton(context),
                )
                : KeyedSubtree(
                  key: const ValueKey('fiche-sounds-real'),
                  child: ValueListenableBuilder<String?>(
                    valueListenable: _player.playing,
                    builder:
                        (context, playing, _) => MySoundsBlock(
                          clips: record.clips,
                          favorites: record.favorites,
                          playing: playing,
                          lineOf:
                              (clip) =>
                                  clipLine(l10n, language, clip, now: now),
                          onPlay: _play,
                          onFavorite: _setFavorite,
                          onReference:
                              referenceUrl == null
                                  ? null
                                  : () =>
                                      openExternalUrl(context, referenceUrl),
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
      if (_year != null)
        HereNowCard(
          year: _year!,
          sentence: presenceSentence(l10n, language, _year!, now: now),
          currentMonth: now.month,
          rareNote: _unexpectedNow ? l10n.forkRareHereExplanation : null,
        ),
      if (sheet != null && sheet.sections.isNotEmpty)
        MeetSpeciesBlock(sheet: sheet)
      else if (_description != null)
        DescriptionBlock(
          text: _description!,
          source: detail?.descriptionSource,
        ),
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
      if (detail != null)
        LinksBlock(
          links: _links(detail),
          onOpen: (url) => openExternalUrl(context, url),
        ),
      if (_lpoSessionId != null) SpeciesLpoEntry(onSend: _sendToLpo),
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
                  for (final block in blocks) ...[
                    if (block != blocks.first)
                      const SizedBox(height: BirdySpace.block),
                    block,
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
