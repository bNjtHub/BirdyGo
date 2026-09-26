/// BirdyGo home screen (J6c, fork/maquette/Main.dc.html and SPEC.md 9.1).
///
/// Shown by the upstream `HomeScreen`, which keeps its warm-up (model,
/// taxonomy, geo-model, index). Status, streak, challenge and the bottom
/// navigation come with the game (J6e); until then the menu gives every
/// entry the upstream home had.
library;

import 'dart:async';

import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/about/about_screen.dart';
import '../../features/aru/aru_active_screen.dart';
import '../../features/aru/aru_controller.dart';
import '../../features/aru/aru_providers.dart';
import '../../features/aru/aru_setup_screen.dart';
import '../../features/explore/explore_providers.dart';
import '../../features/explore/explore_screen.dart';
import '../../features/explore/widgets/species_info_overlay.dart';
import '../../features/file_analysis/file_analysis_screen.dart';
import '../../features/history/session_library_screen.dart';
import '../../features/home/help_screen.dart';
import '../../features/live/live_screen.dart';
import '../../features/live/live_session.dart';
import '../../features/point_count/point_count_setup_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/survey/survey_setup_screen.dart';
import '../../shared/providers/settings_providers.dart';
import '../../shared/utils/app_icons.dart';
import '../../shared/utils/session_type_visuals.dart';
import '../bilan/bilan_widgets.dart';
import '../data/observation_index_service.dart';
import '../design/birdy_tokens.dart';
import '../design/birdy_typography.dart';
import '../design/widgets/birdy_buttons.dart';
import '../design/widgets/entrance.dart';
import '../garden/garden_count_screen.dart';
import '../map/contact_map_screen.dart';
import '../ranking/ranking_screen.dart';
import '../reliability/quick_review_screen.dart';
import '../sound_library/sound_library_screen.dart';
import 'home_loader.dart';
import 'home_model.dart';
import 'home_text.dart';
import 'home_widgets.dart';

/// Widest column on tablets.
const double _maxWidth = 600;

class ForkHome extends ConsumerStatefulWidget {
  const ForkHome({super.key});

  @override
  ConsumerState<ForkHome> createState() => _ForkHomeState();
}

class _ForkHomeState extends ConsumerState<ForkHome> {
  HomeSnapshot? _snapshot;
  String? _place;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    // After the first frame, like the upstream warm-up: « Écouter » is
    // usable at once, the numbers follow.
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_reload());
      unawaited(_loadPlace());
    });
  }

  Future<void> _reload() async {
    final generation = ++_generation;
    final snapshot = await ref.read(homeLoaderProvider).load();
    if (!mounted || generation != _generation) return;
    setState(() => _snapshot = snapshot);
  }

  Future<void> _loadPlace() async {
    final place = await ref.read(homeLoaderProvider).placeName();
    if (mounted && place != null) setState(() => _place = place);
  }

  void _open(Widget screen) => Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => screen));

  void _openAru() {
    final session = ref.read(aruSessionProvider);
    final state = ref.read(aruStateProvider);
    final running =
        session != null &&
        state != AruControllerState.completed &&
        state != AruControllerState.idle;
    _open(running ? const AruActiveScreen() : const AruSetupScreen());
  }

  void _showMenu() {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder:
          (_) => HomeMenuSheet(
            groups: [
              [
                HomeMenuEntry(
                  AppIcons.libraryMusic,
                  l10n.sessionLibraryTitle,
                  () => _open(const SessionLibraryScreen()),
                ),
                HomeMenuEntry(
                  AppIcons.sort,
                  l10n.forkRanking,
                  () => _open(const RankingScreen()),
                ),
                HomeMenuEntry(
                  AppIcons.mapSheet,
                  l10n.forkMap,
                  () => _open(const ContactMapScreen()),
                ),
                HomeMenuEntry(
                  AppIcons.verifiedRounded,
                  l10n.forkQuickReview,
                  () => _open(const QuickReviewScreen()),
                ),
                HomeMenuEntry(
                  AppIcons.graphicEqRounded,
                  l10n.forkSoundLibrary,
                  () => _open(const SoundLibraryScreen()),
                ),
                HomeMenuEntry(
                  AppIcons.parkRounded,
                  l10n.forkGardenTitle,
                  () => _open(const GardenCountScreen()),
                ),
                HomeMenuEntry(
                  AppIcons.searchRounded,
                  l10n.exploreMode,
                  () => _open(const ExploreScreen()),
                ),
              ],
              [
                HomeMenuEntry(
                  sessionTypeIcon(SessionType.pointCount),
                  l10n.pointCountMode,
                  () => _open(const PointCountSetupScreen()),
                ),
                HomeMenuEntry(
                  sessionTypeIcon(SessionType.survey),
                  l10n.surveyMode,
                  () => _open(const SurveySetupScreen()),
                ),
                HomeMenuEntry(
                  sessionTypeIcon(SessionType.aru),
                  l10n.aruMode,
                  _openAru,
                ),
                HomeMenuEntry(
                  sessionTypeIcon(SessionType.fileUpload),
                  l10n.fileAnalysisMode,
                  () => _open(const FileAnalysisScreen()),
                ),
              ],
              [
                HomeMenuEntry(
                  AppIcons.tuneRounded,
                  l10n.settings,
                  () => _open(const SettingsScreen()),
                ),
                HomeMenuEntry(
                  AppIcons.helpOutlineRounded,
                  l10n.helpTitle,
                  () => _open(const HelpScreen()),
                ),
                HomeMenuEntry(
                  AppIcons.infoOutline,
                  l10n.about,
                  () => _open(const AboutScreen()),
                ),
              ],
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // A saved session, a review or a rebuild changes the numbers.
    ref.listen(observationIndexServiceProvider, (_, _) => _reload());

    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
    final localeName = Localizations.localeOf(context).toString();
    final now = DateTime.now();
    final taxonomy = ref.watch(taxonomyServiceProvider).value;
    final speciesLocale = ref.watch(effectiveSpeciesLocaleProvider);
    final snapshot = _snapshot;
    final last = snapshot?.last;

    final topBar = HomeTopBar(onMenu: _showMenu);
    final head = <(String, Widget)>[
      (
        'greeting',
        BilanHero(
          title: homeGreeting(l10n, now),
          dateLine: homeDateLine(localeName, now, place: _place),
        ),
      ),
      if (snapshot != null)
        snapshot.today.isEmpty
            ? (
              'empty',
              Text(
                l10n.forkHomeEmptyDay,
                style: BirdyText.body.copyWith(color: c.text2),
              ),
            )
            : ('today', DayTiles(today: snapshot.today)),
    ];
    final cards = <(String, Widget)>[
      if (last != null)
        (
          'last',
          LastBirdCard(
            last: last,
            name:
                taxonomy
                    ?.lookup(last.scientificName)
                    ?.commonNameForLocale(speciesLocale) ??
                last.detection.commonName,
            when: homeHeardWhen(l10n, localeName, last.detection.start, now),
            image: switch (taxonomy?.assetImagePath(last.scientificName)) {
              final String path => AssetImage(path),
              null => null,
            },
            onTap:
                () => SpeciesInfoOverlay.show(
                  context,
                  ref,
                  scientificName: last.scientificName,
                  commonName:
                      taxonomy
                          ?.lookup(last.scientificName)
                          ?.commonNameForLocale(speciesLocale) ??
                      last.detection.commonName,
                ),
          ),
        ),
      if (snapshot != null && snapshot.toVerify > 0)
        (
          'verify',
          ToVerifyCard(
            count: snapshot.toVerify,
            onTap: () => _open(const QuickReviewScreen()),
          ),
        ),
    ];
    final listen = Padding(
      padding: const EdgeInsets.fromLTRB(
        BirdySpace.xl,
        BirdySpace.s,
        BirdySpace.xl,
        BirdySpace.l,
      ),
      child: ListenButton(onPressed: () => _open(const LiveScreen())),
    );

    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, box) {
            final wide = box.maxWidth > box.maxHeight && box.maxWidth >= 600;
            if (wide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: _blocks([...head], topBar: topBar)),
                  Expanded(
                    child: Column(
                      children: [
                        Expanded(child: _blocks(cards, firstIndex: 2)),
                        listen,
                      ],
                    ),
                  ),
                ],
              );
            }
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: _maxWidth),
                child: Column(
                  children: [
                    Expanded(
                      child: _blocks([...head, ...cards], topBar: topBar),
                    ),
                    listen,
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  /// A scrolling column of [blocks], entering 40 ms apart.
  Widget _blocks(
    List<(String, Widget)> blocks, {
    Widget? topBar,
    int firstIndex = 0,
  }) => ListView(
    padding: const EdgeInsets.fromLTRB(
      BirdySpace.xl,
      BirdySpace.l,
      BirdySpace.xl,
      BirdySpace.l,
    ),
    children: [
      if (topBar != null) topBar,
      for (final (i, (key, block)) in blocks.indexed)
        Padding(
          key: ValueKey('home-$key'),
          padding: EdgeInsets.only(
            top: i == 0 && topBar == null ? 0 : BirdySpace.m,
          ),
          child: BirdyEntrance.staggered(index: firstIndex + i, child: block),
        ),
    ],
  );
}
