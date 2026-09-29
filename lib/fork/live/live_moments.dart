/// Moments of the Live screen (J6e, fork/DESIGN.md « Animations »):
/// « Première rencontre » and the golden card of a rare bird, over the
/// spectrogram and the table, never over « Arrêter » / « Pause » nor the
/// header. No sound (the microphone would hear it), one light vibration.
/// « Première rencontre » plays the AppPremiere sequence (J6f): card pop,
/// bird pop with one ring, texts rising, status landing, two confetti
/// salves from the bird (`BirdyConfetti`) and a few sparkles (`BirdySparkles`),
/// never looping, none with reduced motion.
///
/// Several first encounters make a series (J6h): every « Sûr » bird heard
/// while a card is open, or while the app was in the background, waits in a
/// queue; the card shows « 1 sur 3 nouvelles », a countdown bar, and moves
/// on by itself or on « Espèce suivante ». A rare bird jumps ahead of the
/// series, which goes on after it.
library;

import 'dart:async';

import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/utils/app_icons.dart';
import '../../features/explore/explore_providers.dart';
import '../../features/live/live_controller.dart';
import '../data/observation_index_service.dart';
import '../design/birdy_motion.dart';
import '../design/birdy_tokens.dart';
import '../design/birdy_typography.dart';
import '../design/species_accents.dart';
import '../design/widgets/birdy_block.dart';
import '../design/widgets/birdy_buttons.dart';
import '../design/widgets/birdy_confetti.dart';
import '../design/widgets/birdy_listening_logo.dart';
import '../design/widgets/birdy_pill.dart';
import '../design/widgets/birdy_sparkles.dart';
import '../design/widgets/balanced_text.dart';
import '../design/widgets/birdy_step_dots.dart';
import '../design/widgets/entrance.dart';
import '../design/widgets/species_avatar.dart';
import '../game/game_progress.dart';
import '../game/game_text.dart';
import '../game/game_widgets.dart';
import '../game/moment_appear.dart';
import '../game/verified_species.dart';
import '../notebook/notebook_loader.dart';
import '../reliability/geo_presence_service.dart';
import '../reliability/quick_review_widgets.dart';
import '../reliability/reliability_config.dart';
import '../replay/replay_button.dart';
import 'live_moments_model.dart';
import 'live_table_model.dart';
import 'rare_halo.dart';

enum _RareAnswer { yes, no, later }

class LiveMoments extends ConsumerStatefulWidget {
  const LiveMoments({
    super.key,
    required this.entries,
    required this.controller,
    required this.presenceOf,
    required this.presenceScoreOf,
    required this.clips,
    this.imageFor,
    this.verifiedBefore,
    this.paused = false,
  });

  final List<LiveTableEntry> entries;
  final LiveController controller;
  final GeoPresence? Function(String scientificName) presenceOf;

  /// Raw geo-model score this week here (0–1), for the rare card.
  final double? Function(String scientificName) presenceScoreOf;
  final Map<String, String> clips;
  final ImageProvider? Function(String scientificName)? imageFor;

  /// Species verified before this listening; loaded from the index when
  /// null (tests pass it).
  final Future<Set<String>> Function()? verifiedBefore;

  /// The listening is paused: the countdown of a card stops and resumes.
  final bool paused;

  @override
  ConsumerState<LiveMoments> createState() => _LiveMomentsState();
}

class _LiveMomentsState extends ConsumerState<LiveMoments>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  LiveMomentTracker? _tracker;
  LiveMoment? _shown;
  _RareAnswer? _answer;

  /// Moments waiting behind the shown one: the rare birds first, then the
  /// first encounters in the order they were heard.
  final List<LiveMoment> _queue = [];

  /// First-encounter cards shown in the current series (the shown one
  /// included); 0 outside a series.
  int _seriesPos = 0;

  /// The app is in the background: moments queue up, and show on return.
  bool _background = false;

  /// The shown card counts down: a first encounter from the start, a rare
  /// bird once it is answered (J6h).
  bool get _counting =>
      _shown != null &&
      (_shown!.kind == LiveMomentKind.firstTime || _answer != null);

  /// Countdown of a card, [BirdyMotion.firstEncounterShown] unless a rare
  /// answer sets its own. Its own pace whatever the platform's animation
  /// scale; reduced motion only steps the bar.
  late final AnimationController _count = AnimationController(
    vsync: this,
    duration: BirdyMotion.firstEncounterShown,
    animationBehavior: AnimationBehavior.preserve,
  )..addStatusListener((status) {
    if (status == AnimationStatus.completed) _advance();
  });

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_loadVerified());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        _background = true;
        _count.stop();
      case AppLifecycleState.resumed:
        if (!_background) return;
        _background = false;
        // What was heard meanwhile comes as a series; a card that was open
        // gets its full time again.
        _check();
        if (_counting && !widget.paused) _count.forward(from: 0);
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        break;
    }
  }

  Future<void> _loadVerified() async {
    Set<String> verified;
    try {
      verified =
          await (widget.verifiedBefore?.call() ??
              () async {
                final index =
                    await ref
                        .read(observationIndexServiceProvider)
                        .ensureReady();
                return gameVerifiedSpecies(
                  index: index,
                  presence: ref.read(geoPresenceServiceProvider),
                );
              }());
    } catch (_) {
      // Without the index nothing can be called a first: no moments.
      return;
    }
    if (!mounted) return;
    _tracker = LiveMomentTracker(verifiedBefore: verified);
    _check();
  }

  @override
  void didUpdateWidget(LiveMoments old) {
    super.didUpdateWidget(old);
    if (widget.paused != old.paused && _counting && !_background) {
      if (widget.paused) {
        _count.stop();
      } else {
        _count.forward();
      }
    }
    _check();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _count.dispose();
    super.dispose();
  }

  void _check() {
    final tracker = _tracker;
    if (tracker == null) return;
    final taxonomy = ref.read(taxonomyServiceProvider).value;
    final moments = tracker.nextAll(
      widget.entries,
      presenceOf: widget.presenceOf,
      isBird: (name) => isBird(taxonomy, name),
    );
    for (final moment in moments) {
      if (moment.kind == LiveMomentKind.rare) {
        // A rare bird passes before the series, after the rare ones before.
        final at = _queue.indexWhere((m) => m.kind == LiveMomentKind.firstTime);
        _queue.insert(at < 0 ? _queue.length : at, moment);
      } else {
        _queue.add(moment);
      }
    }
    if (_queue.isEmpty || _background) return;
    final interrupts =
        _shown?.kind == LiveMomentKind.firstTime &&
        _queue.first.kind == LiveMomentKind.rare;
    if (_shown != null && !interrupts) return;
    // Called from didUpdateWidget too: build after this frame's build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _background || _queue.isEmpty) return;
      final shown = _shown;
      if (shown != null) {
        // Only a rare bird may take the place of a first encounter, which
        // then comes back first among its series.
        if (shown.kind != LiveMomentKind.firstTime ||
            _queue.first.kind != LiveMomentKind.rare) {
          return;
        }
        _seriesPos--;
        _tracker?.released(shown);
        final at = _queue.indexWhere((m) => m.kind == LiveMomentKind.firstTime);
        _queue.insert(at < 0 ? _queue.length : at, shown);
      }
      setState(_showNext);
    });
  }

  /// Shows the head of the queue (inside a setState).
  void _showNext() {
    final moment = _queue.removeAt(0);
    BirdyHaptics.light();
    _count.stop();
    _shown = moment;
    _answer = null;
    _tracker?.shown(moment);
    if (moment.kind == LiveMomentKind.firstTime) {
      _seriesPos++;
      _count.duration = BirdyMotion.firstEncounterShown;
      if (!widget.paused) _count.forward(from: 0);
    }
  }

  /// Next moment of the queue, or the end of the series.
  void _advance() {
    _count.stop();
    if (!mounted) return;
    setState(() {
      if (_queue.isEmpty) {
        _shown = null;
        _seriesPos = 0;
      } else {
        _showNext();
      }
    });
  }

  /// First encounters of the series, the shown one included.
  int get _seriesTotal =>
      _seriesPos +
      _queue.where((m) => m.kind == LiveMomentKind.firstTime).length;

  /// Writes the verdict on every detection of the species in this
  /// listening; they are saved with the session at « Arrêter ». « Je ne
  /// sais pas » writes nothing: the detections stay unreviewed, so the quick
  /// review picks them up. The card then counts down and closes.
  void _answerRare(_RareAnswer answer) {
    final moment = _shown;
    if (moment == null || _answer != null) return;
    final name = moment.entry.scientificName;
    final detections = widget.controller.session?.detections ?? const [];
    switch (answer) {
      case _RareAnswer.yes:
        for (final d in detections.where((d) => d.scientificName == name)) {
          d.markConfirmed();
        }
        _tracker?.confirmed(moment);
        BirdyHaptics.light();
      case _RareAnswer.no:
        for (final d in detections.where((d) => d.scientificName == name)) {
          d.markRejected();
        }
      case _RareAnswer.later:
        break;
    }
    _count.stop();
    _count.duration =
        answer == _RareAnswer.yes
            ? BirdyMotion.rareConfirmedShown
            : BirdyMotion.rareAnsweredShown;
    setState(() => _answer = answer);
    if (!widget.paused && !_background) _count.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final moment = _shown;
    if (moment == null) return const SizedBox.shrink();
    final c = BirdyColors.of(context);
    final tint = SpeciesAccents.tintOf(moment.entry.scientificName);
    // The confetti and the ring overflow the card, not the moment's area.
    return ClipRect(
      child: Stack(
        fit: StackFit.expand,
        children: [
          // The veil takes the taps meant for the table below.
          MomentAppear(
            duration: BirdyMotion.enter,
            child: ColoredBox(
              color: c.background.withValues(alpha: 0.82),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [
                      (moment.kind == LiveMomentKind.rare
                              ? BirdyBrand.oriole
                              : tint.accent)
                          .withValues(alpha: BirdyMotion.tintMaxOpacity),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          // The card fits between the header and the control bar: gaps
          // tighten when the room is short, and it only scrolls as a last
          // resort (large text).
          LayoutBuilder(
            builder: (context, box) {
              final compact = box.maxHeight < BirdySizes.momentCompactBelow;
              return Center(
                child: SingleChildScrollView(
                  clipBehavior: Clip.none,
                  padding: const EdgeInsets.all(BirdySpace.l),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 380),
                    child: MomentAppear(
                      key: ValueKey(moment.entry.scientificName),
                      duration:
                          moment.kind == LiveMomentKind.rare
                              ? BirdyMotion.rareBird
                              : BirdyMotion.firstEncounter,
                      child:
                          moment.kind == LiveMomentKind.firstTime
                              ? _FirstTimeCard(
                                moment: moment,
                                image: widget.imageFor?.call(
                                  moment.entry.scientificName,
                                ),
                                clipPath:
                                    widget.clips[moment.entry.scientificName],
                                controller: widget.controller,
                                onClose: _advance,
                                count: _count,
                                paused: widget.paused,
                                compact: compact,
                                hasNext: _queue.isNotEmpty,
                                seriesPos: _seriesPos,
                                seriesTotal: _seriesTotal,
                              )
                              : _RareCard(
                                moment: moment,
                                image: widget.imageFor?.call(
                                  moment.entry.scientificName,
                                ),
                                clipPath:
                                    widget.clips[moment.entry.scientificName],
                                controller: widget.controller,
                                presenceScore: widget.presenceScoreOf(
                                  moment.entry.scientificName,
                                ),
                                answer: _answer,
                                onAnswer: _answerRare,
                                onClose: _advance,
                                count: _count,
                                paused: widget.paused,
                                compact: compact,
                              ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Species picture of a moment ([BirdySizes.momentAvatar]).
class _Avatar extends StatelessWidget {
  const _Avatar({super.key, required this.moment, required this.image});

  final LiveMoment moment;
  final ImageProvider? image;

  @override
  Widget build(BuildContext context) => SpeciesAvatar(
    image: image,
    tint: SpeciesAccents.tintOf(moment.entry.scientificName),
    size: BirdySizes.momentAvatar,
  );
}

/// Common name only (no Latin name on the cards, J6h), on balanced lines.
class _Names extends StatelessWidget {
  const _Names({required this.moment});

  final LiveMoment moment;

  @override
  Widget build(BuildContext context) {
    final c = BirdyColors.of(context);
    return BalancedText(
      moment.entry.commonName,
      style: BirdyText.title.copyWith(color: c.text1),
    );
  }
}

class _FirstTimeCard extends StatelessWidget {
  const _FirstTimeCard({
    required this.moment,
    required this.image,
    required this.clipPath,
    required this.controller,
    required this.onClose,
    required this.count,
    required this.paused,
    required this.compact,
    required this.hasNext,
    required this.seriesPos,
    required this.seriesTotal,
  });

  final LiveMoment moment;
  final ImageProvider? image;
  final String? clipPath;
  final LiveController controller;

  /// « Espèce suivante » or « Continuer l'écoute »: on to the next moment.
  final VoidCallback onClose;

  /// Countdown, 0 → 1 over [BirdyMotion.firstEncounterShown].
  final Animation<double> count;
  final bool paused;

  /// Little room: tighter gaps.
  final bool compact;

  /// Another moment waits behind this one.
  final bool hasNext;

  /// Position in the series (1-based) and its length.
  final int seriesPos;
  final int seriesTotal;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
    final tint = SpeciesAccents.tintOf(moment.entry.scientificName);
    final series = seriesTotal >= 2;
    final status = statusFor(moment.rank);
    final next = nextStatus(status);
    final caption = BirdyText.caption.copyWith(color: c.text2);
    final gap = compact ? BirdySpace.s : BirdySpace.m;
    final bigGap = compact ? BirdySpace.m : BirdySpace.l;
    // AppPremiere: once the bird is in, the texts rise one after the other.
    Duration textDelay(int index) =>
        BirdyMotion.firstEncounterTextDelay + BirdyMotion.staggerDelay(index);
    Widget rise(int index, Widget child) =>
        BirdyEntrance(delay: textDelay(index), child: child);
    return _Card(
      border: tint.accent.withValues(alpha: 0.5),
      compact: compact,
      children: [
        _ListeningLine(paused: paused),
        const SizedBox(height: BirdySpace.s),
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: BirdySpace.s,
          runSpacing: BirdySpace.xs,
          children: [
            const NoveltyPill(kind: NoveltyKind.firstTime),
            if (series)
              Text(
                l10n.forkMomentSeriesPos(seriesPos, seriesTotal),
                style: BirdyText.captionTabular.copyWith(
                  color: c.text2,
                  fontWeight: FontWeight.w700,
                ),
              ),
          ],
        ),
        SizedBox(height: gap),
        _Encounter(
          color: tint.accent,
          confetti: [
            tint.accent,
            ...BirdyConfettiColors.burstOf(context),
            tint.deep,
          ],
          child: _Avatar(
            key: const ValueKey('first-time-bird'),
            moment: moment,
            image: image,
          ),
        ),
        SizedBox(height: gap),
        rise(0, _Names(moment: moment)),
        SizedBox(height: gap),
        rise(
          1,
          Semantics(
            liveRegion: true,
            child: Text(
              l10n.forkMomentFirstTitle,
              textAlign: TextAlign.center,
              style: BirdyText.heading.copyWith(color: c.text1),
            ),
          ),
        ),
        const SizedBox(height: BirdySpace.xs),
        rise(
          2,
          Text(
            l10n.forkMomentAdded(moment.rank),
            textAlign: TextAlign.center,
            style: BirdyText.label.copyWith(color: c.text1),
          ),
        ),
        if (status != null) ...[
          SizedBox(height: gap),
          // bg-land: the status lands, a little slower than the texts.
          BirdyEntrance(
            delay: textDelay(3),
            duration: BirdyMotion.firstEncounter,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                StatusEmblem(status: status, size: 28),
                const SizedBox(width: BirdySpace.s),
                Flexible(
                  child: Text(
                    statusName(l10n, status),
                    style: BirdyText.label.copyWith(
                      color: c.text1,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        if (next != null) ...[
          const SizedBox(height: BirdySpace.xs),
          rise(
            4,
            Text(
              l10n.forkStatusNext(
                next.from - moment.rank,
                statusName(l10n, next),
              ),
              textAlign: TextAlign.center,
              style: caption,
            ),
          ),
        ],
        SizedBox(height: bigGap),
        // The buttons come with the card: tappable at once.
        _Buttons(
          clipPath: clipPath,
          controller: controller,
          primary:
              hasNext ? l10n.forkMomentNextSpecies : l10n.forkMomentContinue,
          primaryIcon: hasNext ? AppIcons.arrowForwardRounded : null,
          onPrimary: onClose,
        ),
        SizedBox(height: gap),
        _Countdown(
          count: count,
          paused: paused,
          hasNext: hasNext,
          seriesPos: series ? seriesPos : 0,
          seriesTotal: seriesTotal,
        ),
      ],
    );
  }
}

/// The bird of « Première rencontre » (AppPremiere, J6f): it pops in just
/// after the card (bg-pop), a soft glow and one ring spread behind it once
/// (bg-glow, bg-ring), two confetti salves leave its center and four
/// sparkles pop around it. With reduced motion: the bird fades in, no glow,
/// ring, confetti nor sparkles.
class _Encounter extends StatefulWidget {
  const _Encounter({
    required this.color,
    required this.confetti,
    required this.child,
  });

  final Color color;
  final List<Color> confetti;
  final Widget child;

  @override
  State<_Encounter> createState() => _EncounterState();
}

class _EncounterState extends State<_Encounter>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ring = AnimationController(
    vsync: this,
    duration: BirdyMotion.firstEncounterRing,
  );
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(BirdyMotion.firstEncounterBirdDelay, () {
      if (mounted) _ring.forward();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ring.dispose();
    super.dispose();
  }

  /// The ring and glow start a little outside the picture.
  static const double _ringBase =
      (BirdySizes.momentAvatar + 2 * BirdySpace.m) / BirdySizes.momentAvatar;

  /// CSS keyframes 0 → [peak] at [at] → 0, each interval eased.
  static double _peak(double t, double at, double peak) {
    const e = BirdyMotion.standard;
    if (t <= at) return peak * e.transform(t / at);
    return peak * (1 - e.transform((t - at) / (1 - at)));
  }

  @override
  Widget build(BuildContext context) {
    final bird = MomentAppear(
      duration: BirdyMotion.firstEncounter,
      delay: BirdyMotion.firstEncounterBirdDelay,
      child: widget.child,
    );
    if (BirdyMotion.reduced(context)) return bird;
    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        ExcludeSemantics(
          child: AnimatedBuilder(
            animation: _ring,
            builder: (context, _) {
              final t = _ring.value;
              final grow = BirdyMotion.standard.transform(t);
              return Transform.scale(
                // Around the picture, without taking layout room.
                scale: _ringBase * (1 + (BirdyMotion.ringScale - 1) * grow),
                child: Container(
                  width: BirdySizes.momentAvatar,
                  height: BirdySizes.momentAvatar,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.color.withValues(
                      alpha: _peak(
                        t,
                        BirdyMotion.glowPeakAt,
                        BirdyMotion.tintMaxOpacity,
                      ),
                    ),
                    border: Border.all(
                      color: widget.color.withValues(
                        alpha: _peak(
                          t,
                          BirdyMotion.ringPeakAt,
                          BirdyMotion.ringPeakOpacity,
                        ),
                      ),
                      width: 2,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        bird,
        // Two salves, then a few sparkles: fireworks, once.
        BirdyConfetti.burst(
          colors: widget.confetti,
          delay: BirdyMotion.firstEncounterConfettiDelay,
          settings: BirdyConfettiBurst.firstEncounterMain,
        ),
        BirdyConfetti.burst(
          colors: widget.confetti,
          delay:
              BirdyMotion.firstEncounterConfettiDelay +
              BirdyMotion.firstEncounterSecondSalveDelay,
          settings: BirdyConfettiBurst.firstEncounterSecond,
        ),
        const BirdySparkles(
          offsets: BirdySparkles.aroundBird,
          delay: BirdyMotion.firstEncounterSparkleDelay,
        ),
      ],
    );
  }
}

/// « L'écoute continue » with the small listening logo, on top of a card.
class _ListeningLine extends StatelessWidget {
  const _ListeningLine({required this.paused});

  final bool paused;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        BirdyListeningLogo(
          size: BirdySizes.liveLogoSmall,
          running: !paused,
          frozen: paused,
        ),
        const SizedBox(width: BirdySpace.xs),
        Flexible(
          child: Text(
            l10n.forkMomentListeningGoesOn,
            style: BirdyText.caption.copyWith(color: c.text2),
          ),
        ),
      ],
    );
  }
}

/// The card of a rare bird (J6h, AppEcoute mockup): the question first, one
/// group at a time (the bird, the chance to hear it, the replay and the
/// three verdicts), then the answer with its countdown.
class _RareCard extends StatelessWidget {
  const _RareCard({
    required this.moment,
    required this.image,
    required this.clipPath,
    required this.controller,
    required this.presenceScore,
    required this.answer,
    required this.onAnswer,
    required this.onClose,
    required this.count,
    required this.paused,
    required this.compact,
  });

  final LiveMoment moment;
  final ImageProvider? image;
  final String? clipPath;
  final LiveController controller;
  final double? presenceScore;
  final _RareAnswer? answer;
  final void Function(_RareAnswer) onAnswer;
  final VoidCallback onClose;

  /// Countdown after an answer, 0 → 1 over its own length.
  final Animation<double> count;
  final bool paused;

  /// Little room: tighter gaps.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
    final caption = BirdyText.caption.copyWith(color: c.text2);
    final gap = compact ? BirdySpace.s : BirdySpace.m;
    final group = compact ? BirdySpace.m : BirdySpace.xl;
    final yes = answer == _RareAnswer.yes;
    final chance = rareChanceN(presenceScore);

    Widget continueButton() => SizedBox(
      width: double.infinity,
      child: FilledButton(
        style: BirdyButtonStyles.primary(context),
        onPressed: onClose,
        child: Text(l10n.forkMomentContinue),
      ),
    );

    return _Card(
      border:
          yes ? BirdyBrand.oriole : BirdyBrand.oriole.withValues(alpha: 0.65),
      compact: compact,
      children: [
        _ListeningLine(paused: paused),
        const SizedBox(height: BirdySpace.s),
        NoveltyPill(
          kind: yes ? NoveltyKind.unexpectedHere : NoveltyKind.rareHereToConfirm,
        ),
        SizedBox(height: gap),
        // One tree position for the bird whatever the answer: its arrival
        // plays once, on the question.
        _RareBird(moment: moment, image: image, confirmed: yes),
        const SizedBox(height: BirdySpace.s),
        _Names(moment: moment),
        if (answer == null) ...[
          if (chance != null) ...[
            const SizedBox(height: BirdySpace.s),
            BirdyEntrance(
              delay: BirdyMotion.rareDiamondDelay,
              child: _ChanceLine(
                label:
                    presenceScore! < rareLowPresenceBelow
                        ? l10n.forkMomentPresenceLow
                        : l10n.forkMomentRareChance(chance),
              ),
            ),
          ],
          SizedBox(height: group),
          _ReplayLine(
            clipPath: clipPath,
            controller: controller,
            title: l10n.forkMomentRareAskShort,
            caption: l10n.forkMomentRareListenFirst,
          ),
          SizedBox(height: group),
          VerdictButtons(
            enabled: true,
            notLabel: l10n.forkVerdictNotShort,
            yesLabel: l10n.forkVerdictYesShort,
            onAnswer:
                (a) => onAnswer(switch (a) {
                  ReviewAnswer.itIs => _RareAnswer.yes,
                  ReviewAnswer.itIsNot => _RareAnswer.no,
                  ReviewAnswer.dontKnow => _RareAnswer.later,
                }),
          ),
          SizedBox(height: gap),
          Text(
            l10n.forkMomentRareNoteShort,
            textAlign: TextAlign.center,
            style: caption,
          ),
        ] else if (yes) ...[
          SizedBox(height: gap),
          Semantics(
            liveRegion: true,
            child: Text(
              l10n.forkMomentRareConfirmed,
              textAlign: TextAlign.center,
              style: BirdyText.heading.copyWith(color: c.text1),
            ),
          ),
          const SizedBox(height: BirdySpace.s),
          MomentAppear(
            duration: BirdyMotion.rareBird,
            delay: BirdyMotion.newStatusTextDelay,
            child: BirdyPill(
              label: l10n.forkMomentRarePlusOne,
              foreground: c.onOriole,
              background: c.oriole,
            ),
          ),
          const SizedBox(height: BirdySpace.s),
          Text(
            l10n.forkMomentRareEnters(moment.entry.commonName, moment.rank),
            textAlign: TextAlign.center,
            style: BirdyText.body.copyWith(color: c.text1),
          ),
          SizedBox(height: group),
          continueButton(),
          SizedBox(height: gap),
          _Countdown(
            count: count,
            paused: paused,
            hasNext: false,
            seriesPos: 0,
            seriesTotal: 0,
            total: BirdyMotion.rareConfirmedShown,
          ),
        ] else ...[
          SizedBox(height: gap),
          Semantics(
            liveRegion: true,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: c.surface1,
                borderRadius: BorderRadius.circular(BirdyRadii.card),
              ),
              child: Padding(
                padding: const EdgeInsets.all(BirdySpace.m),
                child: Row(
                  children: [
                    Icon(
                      answer == _RareAnswer.no
                          ? AppIcons.close
                          : AppIcons.question,
                      size: BirdySizes.alertDiscIcon,
                      color: c.text2,
                    ),
                    const SizedBox(width: BirdySpace.s),
                    Expanded(
                      child: Text(
                        answer == _RareAnswer.no
                            ? l10n.forkMomentRareNo
                            : l10n.forkMomentRareLater,
                        style: BirdyText.body.copyWith(color: c.text1),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(height: gap),
          continueButton(),
          SizedBox(height: gap),
          _Countdown(
            count: count,
            paused: paused,
            hasNext: false,
            seriesPos: 0,
            seriesTotal: 0,
            total: BirdyMotion.rareAnsweredShown,
          ),
        ],
      ],
    );
  }
}

/// The rare bird's picture in its halo. On the question the dotted ring,
/// the halo and the diamonds arrive once; once confirmed the ring is full
/// and golden confetti leave the bird (none with reduced motion).
class _RareBird extends StatelessWidget {
  const _RareBird({
    required this.moment,
    required this.image,
    required this.confirmed,
  });

  final LiveMoment moment;
  final ImageProvider? image;
  final bool confirmed;

  @override
  Widget build(BuildContext context) => Stack(
    alignment: Alignment.center,
    clipBehavior: Clip.none,
    children: [
      RareHalo(size: BirdySizes.momentAvatar, solid: confirmed),
      _Avatar(
        key: const ValueKey('rare-bird'),
        moment: moment,
        image: image,
      ),
      if (confirmed)
        BirdyConfetti.burst(
          colors: BirdyConfettiColors.rareOf(context),
          settings: BirdyConfettiBurst.firstEncounterMain,
        ),
    ],
  );
}

/// « ◆ 1 chance sur 50 de l'entendre ici »: oriole, with the diamond.
class _ChanceLine extends StatelessWidget {
  const _ChanceLine({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final c = BirdyColors.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(
          AppIcons.diamond,
          size: BirdySizes.statusModeIcon,
          fill: 1,
          color: c.orioleText,
        ),
        const SizedBox(width: BirdySpace.xs),
        Flexible(
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: BirdyText.label.copyWith(
              color: c.orioleText,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

/// The replay button leading « C'est bien lui ? » and its hint.
class _ReplayLine extends StatelessWidget {
  const _ReplayLine({
    required this.clipPath,
    required this.controller,
    required this.title,
    required this.caption,
  });

  final String? clipPath;
  final LiveController controller;
  final String title;
  final String caption;

  @override
  Widget build(BuildContext context) {
    final c = BirdyColors.of(context);
    final hasClip = clipPath != null;
    final texts = Column(
      crossAxisAlignment:
          hasClip ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        Text(
          title,
          textAlign: hasClip ? TextAlign.start : TextAlign.center,
          style: BirdyText.heading.copyWith(color: c.text1),
        ),
        Text(
          caption,
          textAlign: hasClip ? TextAlign.start : TextAlign.center,
          style: BirdyText.caption.copyWith(color: c.text2),
        ),
      ],
    );
    if (!hasClip) return texts;
    return Row(
      children: [
        ReplayButton(
          controller: controller,
          clipPath: clipPath!,
          size: BirdySizes.mainAction,
        ),
        const SizedBox(width: BirdySpace.m),
        Expanded(child: texts),
      ],
    );
  }
}

class _Buttons extends StatelessWidget {
  const _Buttons({
    required this.clipPath,
    required this.controller,
    required this.primary,
    required this.onPrimary,
    this.primaryIcon,
  });

  final String? clipPath;
  final LiveController controller;
  final String primary;
  final VoidCallback onPrimary;

  /// After the label, e.g. « Espèce suivante ».
  final IconData? primaryIcon;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      if (clipPath != null) ...[
        ReplayButton(controller: controller, clipPath: clipPath!),
        const SizedBox(width: BirdySpace.s),
      ],
      Expanded(
        child: FilledButton(
          style: BirdyButtonStyles.primary(context),
          onPressed: onPrimary,
          child:
              primaryIcon == null
                  ? Text(primary)
                  : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(child: Text(primary)),
                      const SizedBox(width: BirdySpace.s),
                      Icon(primaryIcon, size: BirdySizes.buttonIcon),
                    ],
                  ),
        ),
      ),
    ],
  );
}

/// Progress of a series (dots), the countdown bar and its text, under the
/// buttons of a first-encounter card, and of an answered rare card. The bar
/// empties linearly over [total]; with reduced motion it steps once a
/// second, with the text. The text stops with the pause and says so.
class _Countdown extends StatelessWidget {
  const _Countdown({
    required this.count,
    required this.paused,
    required this.hasNext,
    required this.seriesPos,
    required this.seriesTotal,
    this.total = BirdyMotion.firstEncounterShown,
  });

  final Animation<double> count;
  final bool paused;
  final bool hasNext;

  /// Length of the countdown (the rare card's answers set their own).
  final Duration total;

  /// 0 outside a series: no dots.
  final int seriesPos;
  final int seriesTotal;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
    final reduced = BirdyMotion.reduced(context);
    final total = this.total.inSeconds;
    final track = c.progressTrack;
    return Column(
      children: [
        if (seriesPos > 0) ...[
          BirdyStepDots(
            count: seriesTotal,
            current: seriesPos - 1,
            activeColor: c.accentText,
            doneColor: c.accentText,
            inactiveColor: c.progressTrack,
            height: BirdySizes.countdownBar,
            activeWidth: BirdySizes.countdownDotActive,
            gap: BirdySpace.xs,
          ),
          const SizedBox(height: BirdySpace.s),
        ],
        AnimatedBuilder(
          animation: count,
          builder: (context, _) {
            final left = ((1 - count.value) * total).ceil().clamp(0, total);
            final text =
                hasNext
                    ? l10n.forkMomentNextIn(left)
                    : l10n.forkMomentClosesIn(left);
            return Column(
              children: [
                BirdyProgressBar(
                  value: reduced ? left / total : 1 - count.value,
                  color: c.accentText,
                  track: track,
                  height: BirdySizes.countdownBar,
                ),
                const SizedBox(height: BirdySpace.xs),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    paused ? '$text ${l10n.forkMomentPausedSuffix}' : text,
                    textAlign: TextAlign.center,
                    style: BirdyText.captionTabular.copyWith(color: c.text2),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({
    required this.border,
    required this.children,
    this.compact = false,
  });

  final Color border;
  final List<Widget> children;

  /// Little room: less padding above.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final c = BirdyColors.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.surface2,
        borderRadius: BorderRadius.circular(BirdyRadii.hero),
        border: Border.all(color: border, width: 1.5),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          BirdySpace.l,
          compact ? BirdySpace.l : BirdySpace.xl,
          BirdySpace.l,
          compact ? BirdySpace.m : BirdySpace.l,
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: children),
      ),
    );
  }
}
