/// BirdyGo home screen (J6f blocks, « App finale » board AppAccueil; first
/// version J6c, SPEC.md 9.1).
///
/// First tab of the bottom navigation (`ForkShell`, J6e), shown by the
/// upstream `HomeScreen`, which keeps its warm-up (model, taxonomy,
/// geo-model, index). Blocks, told apart by their fill: greeting, last bird
/// hero, goal / série / to-check grid, status, today's species, weekly
/// challenge. « Écouter » is the one strong action, pinned above the bottom
/// bar, and starts listening at once; the menu keeps every upstream entry.
library;

import 'dart:async';

import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/explore/explore_providers.dart';
import '../../features/explore/widgets/species_info_overlay.dart';
import '../../features/history/widgets/clip_player_sheet.dart';
import '../../features/live/live_screen.dart';
import '../../features/live/live_session.dart';
import '../../shared/providers/settings_providers.dart';
import '../../shared/utils/app_icons.dart';
import '../data/observation_index_service.dart';
import '../day/day_times.dart';
import '../daily_goal/daily_goal_block.dart';
import '../daily_goal/daily_goal_screen.dart';
import '../design/birdy_motion.dart';
import '../design/birdy_tokens.dart';
import '../design/widgets/birdy_buttons.dart';
import '../design/widgets/birdy_headers.dart';
import '../design/widgets/entrance.dart';
import '../design/widgets/birdy_cross_fade.dart';
import '../game/challenge_card.dart';
import '../game/challenges.dart';
import '../game/game_loader.dart';
import '../game/status_celebration.dart';
import '../game/streak.dart';
import '../profile/profile_screen.dart';
import '../reliability/quick_review_screen.dart';
import '../settings/fork_prefs.dart';
import '../shell/fork_shell.dart';
import '../summary/open_listening_summary.dart';
import 'day_sheet.dart';
import 'day_strip.dart';
import 'home_loader.dart';
import 'home_model.dart';
import 'home_text.dart';
import 'home_widgets.dart';
import 'more_sheet.dart';

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
  DayTimes? _dayTimes;
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
    final loader = ref.read(homeLoaderProvider);
    final sunrise = await loader.sunrise();
    final sunset = await loader.sunset();
    final times = DayTimes.tryCreate(sunrise: sunrise, sunset: sunset);
    if (mounted && times != null) setState(() => _dayTimes = times);
    final place = await loader.placeName();
    if (mounted && place != null) setState(() => _place = place);
  }

  /// « Réécouter »: the clip of the last bird, in the shared player sheet.
  void _replay(LastBird last, String name) {
    final d = last.detection;
    showClipPlayerSheet(
      context,
      detection: DetectionRecord(
        scientificName: d.scientificName,
        commonName: name,
        confidence: d.confidence,
        timestamp: d.start,
        endTimestamp: d.end,
        audioClipPath: d.clipPath,
        latitude: d.latitude,
        longitude: d.longitude,
        reviewStatus: d.reviewStatus,
      ),
    );
  }

  void _openSpecies(String scientificName, String name) =>
      SpeciesInfoOverlay.show(
        context,
        ref,
        scientificName: scientificName,
        commonName: name,
      );

  /// Straight into listening, like the « Écouter » button.
  void _listen() => _open(const LiveScreen(forceAutoStart: true));

  void _openDaySheet(DayTimes times, DayMoment moment) => showDaySheet(
    context,
    times: times,
    caption: homeDateLine(
      Localizations.localeOf(context).toString(),
      ref.read(homeClockProvider)(),
      place: _place,
    ),
    highlighted: moment,
    onListen: _listen,
  );

  void _open(Widget screen) => Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => screen));

  Future<void> _startChallenge() async {
    await ref.read(challengeStoreProvider).start(ref.read(homeClockProvider)());
    ref.invalidate(gameProgressProvider);
  }

  /// « Aujourd'hui »: the Bilan of today's latest listening. The Bilan sums
  /// up one session, so with several listenings today it opens the most
  /// recent one (the block says so). The session comes from its saved JSON,
  /// the source of truth; a session gone since the index was built shows a
  /// message instead.
  Future<void> _openTodayBilan(String sessionId) async {
    // One level deep: Back returns here, not to the first route.
    final bool opened;
    try {
      opened = await openListeningSummary(
        context,
        ref,
        sessionId: sessionId,
      );
    } catch (_) {
      if (mounted) _showBilanFailure();
      return;
    }
    if (!opened && mounted) _showBilanFailure();
  }

  void _showBilanFailure() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context)!.forkHomeTodayOpenFailed),
      ),
    );
  }

  /// The Profil tab, or the profile page outside the bottom navigation.
  void _openProfile() {
    final shell = ForkShellScope.maybeOf(context);
    if (shell != null) {
      shell.select(ForkTab.profile);
    } else {
      _open(const ProfileScreen());
    }
  }

  // FORK: J6g-c, the menu is now the « Plus » sheet (more_sheet.dart).
  void _showMenu() =>
      showMoreSheet(context, ref, toVerify: _snapshot?.toVerify ?? 0);

  @override
  Widget build(BuildContext context) {
    // A saved session, a review or a rebuild changes the numbers.
    ref.listen(observationIndexServiceProvider, (_, _) => _reload());
    // A new status reached through a review is celebrated here.
    ref.listen(gameProgressProvider, (_, next) {
      if (next.value case final progress?) {
        unawaited(maybeCelebrateStatus(context, ref, progress));
      }
    });

    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
    final localeName = Localizations.localeOf(context).toString();
    final now = ref.watch(homeClockProvider)();
    final taxonomy = ref.watch(taxonomyServiceProvider).value;
    final speciesLocale = ref.watch(effectiveSpeciesLocaleProvider);
    final snapshot = _snapshot;
    final last = snapshot?.last;
    final loadingSnapshot = snapshot == null;

    String nameOf(String scientificName, String fallback) =>
        taxonomy?.lookup(scientificName)?.commonNameForLocale(speciesLocale) ??
        fallback;
    ImageProvider? imageOf(String scientificName) => switch (taxonomy
        ?.assetImagePath(scientificName)) {
      final String path => AssetImage(path),
      null => null,
    };

    final gameAsync = ref.watch(gameProgressProvider);
    final game = gameAsync.value;
    final loadingGame = !gameAsync.hasValue;
    final streak = game?.facts.streak;
    final toVerify = snapshot?.toVerify ?? 0;
    // Both sources (the saved-session snapshot and the game progress) can
    // resolve independently; the header's live region only announces once
    // both have (SPEC.md's common case never announces a second "loading").
    final dataReady = !loadingSnapshot && !loadingGame;
    // The singing logo, small, above the tab header (Accueil only), with the
    // menu button on the same row so both share one vertical center.
    final topBar = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Expanded(child: HomeLogoRow()),
        const SizedBox(width: BirdySpace.s),
        BirdyIconButton(
          icon: AppIcons.menu,
          semanticLabel: l10n.forkHomeMenu,
          onPressed: _showMenu,
        ),
      ],
    );
    final dayTimes = _dayTimes;
    final firstName = ref.watch(firstNameProvider);

    // 'last' (hero): the common case for a returning user is a last bird
    // already on record, so it skeletons while loading; a fresh install
    // with no last bird ever collapses the block once loaded instead
    // (allowed to shift, see HomeHeroSkeleton's doc comment).
    (String, Widget)? heroEntry() {
      if (loadingSnapshot) {
        return (
          'last',
          _crossFade(
            const HomeHeroSkeleton(key: ValueKey('home-last-skeleton')),
          ),
        );
      }
      if (last == null) return null;
      return (
        'last',
        _crossFade(
          HomeHero(
            key: const ValueKey('home-last-real'),
            last: last,
            name: nameOf(last.scientificName, last.detection.commonName),
            when: homeHeardWhen(l10n, localeName, last.detection.start, now),
            image: imageOf(last.scientificName),
            onTap:
                () => _openSpecies(
                  last.scientificName,
                  nameOf(last.scientificName, last.detection.commonName),
                ),
            onReplay:
                last.clipPath == null
                    ? null
                    : () => _replay(
                      last,
                      nameOf(last.scientificName, last.detection.commonName),
                    ),
          ),
        ),
      );
    }

    // 'status': the game progress always carries a status (even "None"
    // before the first species), so this is the only skeleton with no
    // collapsing case once [gameAsync] resolves.
    (String, Widget)? statusEntry() {
      if (loadingGame) {
        return (
          'status',
          _crossFade(
            const StatusBlockSkeleton(key: ValueKey('home-status-skeleton')),
          ),
        );
      }
      if (game == null) return null;
      return (
        'status',
        _crossFade(
          StatusBlock(
            key: const ValueKey('home-status-real'),
            progress: game,
            onTap: _openProfile,
          ),
        ),
      );
    }

    // 'today' / 'empty': the common case for a returning user is at least
    // one species heard today, so it skeletons while loading; a day with
    // nothing heard yet swaps to the smaller empty state once loaded
    // instead (allowed to shift, see TodayBlockSkeleton's doc comment).
    (String, Widget) todayEntry() {
      if (loadingSnapshot) {
        return (
          'today',
          _crossFade(
            const TodayBlockSkeleton(key: ValueKey('home-today-skeleton')),
          ),
        );
      }
      if (snapshot.today.isEmpty) {
        return (
          'empty',
          _crossFade(
            TodayEmptyBlock(
              key: const ValueKey('home-today-empty'),
              onListen: _listen,
            ),
          ),
        );
      }
      return (
        'today',
        _crossFade(
          TodayBlock(
            key: const ValueKey('home-today-real'),
            today: snapshot.today,
            nameOf: (s) => nameOf(s.scientificName, s.commonName),
            imageOf: imageOf,
            onSpecies: (s, name) => _openSpecies(s.scientificName, name),
            onOpen:
                snapshot.today.latestSessionId == null
                    ? null
                    : () => _openTodayBilan(snapshot.today.latestSessionId!),
          ),
        ),
      );
    }

    final head = <(String, Widget)>[
      (
        'greeting',
        Semantics(
          liveRegion: true,
          label: dataReady ? null : l10n.forkHomeLoading,
          child: BirdyTabHeader(
            title: homeGreeting(l10n, now, firstName: firstName),
            caption: homeDateLine(localeName, now, place: _place),
          ),
        ),
      ),
      // No strip without a position (no sunrise or sunset).
      if (dayTimes != null)
        (
          'day',
          _crossFade(
            DayStrip(
              key: const ValueKey('home-day-strip'),
              times: dayTimes,
              onMoment: (moment) => _openDaySheet(dayTimes, moment),
            ),
          ),
        ),
      if (heroEntry() case final entry?) entry,
      (
        'grid',
        HomeGrid(
          goal: DailyGoalBlock(onTap: () => _open(const DailyGoalScreen())),
          // No série block without a running série, and 0 to check: both
          // legitimately empty once loaded, so they collapse (see the
          // skeleton classes' doc comments for the common-case rule).
          streak: _streakSlot(loadingGame, streak),
          toCheck: _toCheckSlot(loadingSnapshot, toVerify),
        ),
      ),
    ];
    final cards = <(String, Widget)>[
      if (statusEntry() case final entry?) entry,
      todayEntry(),
      if (game?.facts.challenge case final challenge?)
        (
          'challenge',
          ChallengeCard(challenge: challenge, onStart: _startChallenge),
        ),
    ];
    final listen = Padding(
      // Equal margins above and below, as wide as the button's glow
      // (BirdyColors.listenGlowExtent): centered, and never cut by the bar.
      padding: const EdgeInsets.all(BirdySpace.xl),
      // Straight into listening: the live screen starts on arrival.
      child: ListenButton(
        onPressed: _listen,
      ),
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
                  Expanded(child: _blocks(head, topBar: topBar)),
                  Expanded(
                    child: Column(
                      children: [
                        Expanded(
                          child: _blocks(cards, firstIndex: head.length),
                        ),
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

  /// Grid's « X jours de suite » cell: skeletons while [loadingGame], the
  /// real block once a running série lands, or null (no cell at all) once
  /// loaded with no série — allowed to shift, see [StreakBlockSkeleton].
  Widget? _streakSlot(bool loadingGame, Streak? streak) {
    if (loadingGame) {
      return _crossFade(
        const StreakBlockSkeleton(key: ValueKey('home-streak-skeleton')),
      );
    }
    if (streak == null || streak.current <= 0) return null;
    return _crossFade(
      StreakBlock(
        key: const ValueKey('home-streak-real'),
        streak: streak,
        onTap: _openProfile,
      ),
    );
  }

  /// Grid's « N à vérifier » cell: skeletons while [loadingSnapshot], the
  /// real block once there is something to check, or null once loaded
  /// with 0 — allowed to shift, see [ToCheckBlockSkeleton].
  Widget? _toCheckSlot(bool loadingSnapshot, int toVerify) {
    if (loadingSnapshot) {
      return _crossFade(
        const ToCheckBlockSkeleton(key: ValueKey('home-to-check-skeleton')),
      );
    }
    if (toVerify <= 0) return null;
    return _crossFade(
      ToCheckBlock(
        key: const ValueKey('home-to-check-real'),
        count: toVerify,
        onTap: () => _open(const QuickReviewScreen()),
      ),
    );
  }

  /// Fades [child] in in place (no move, no scale): a skeleton replaced by
  /// its loaded content. [child]'s own key tells the switcher when to
  /// cross-fade (J6f skeletons, same pattern as the notebook screen's).
  static Widget _crossFade(Widget child) => BirdyCrossFade(child: child);

  /// A scrolling column of [blocks]. The first
  /// [BirdyMotion.staggerMaxItems] rise once, 40 ms apart; the others, and
  /// every block under reduced motion, appear still.
  Widget _blocks(
    List<(String, Widget)> blocks, {
    Widget? topBar,
    int firstIndex = 0,
  }) {
    final still = BirdyMotion.reduced(context);
    return ListView(
      padding: const EdgeInsets.all(BirdySpace.page),
      children: [
        if (topBar != null) topBar,
        for (final (i, (key, block)) in blocks.indexed)
          Padding(
            key: ValueKey('home-$key'),
            padding: EdgeInsets.only(
              top: i == 0 && topBar == null ? 0 : BirdySpace.block,
            ),
            child:
                still || firstIndex + i >= BirdyMotion.staggerMaxItems
                    ? block
                    : BirdyEntrance.staggered(
                      index: firstIndex + i,
                      child: block,
                    ),
          ),
      ],
    );
  }
}
