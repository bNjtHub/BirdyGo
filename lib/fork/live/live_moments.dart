/// Moments of the Live screen (J6e, fork/DESIGN.md « Animations »):
/// « Première rencontre » and the golden card of a rare bird, over the
/// spectrogram and the table, never over « Arrêter » / « Pause ». No
/// sound (the microphone would hear it), no confetti, one light vibration.
library;

import 'dart:async';

import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/explore/explore_providers.dart';
import '../../features/live/live_controller.dart';
import '../data/observation_index_service.dart';
import '../design/birdy_motion.dart';
import '../design/birdy_tokens.dart';
import '../design/birdy_typography.dart';
import '../design/species_accents.dart';
import '../design/widgets/birdy_buttons.dart';
import '../design/widgets/birdy_pill.dart';
import '../design/widgets/species_avatar.dart';
import '../game/game_progress.dart';
import '../game/game_text.dart';
import '../game/game_widgets.dart';
import '../game/moment_appear.dart';
import '../game/verified_species.dart';
import '../notebook/notebook_loader.dart';
import '../reliability/geo_presence_service.dart';
import '../reliability/reliability_config.dart';
import '../replay/replay_button.dart';
import 'live_moments_model.dart';
import 'live_table_model.dart';

/// « Première rencontre » closes by itself after this.
const Duration _firstTimeShown = Duration(seconds: 6);

/// A verdict toast stays this long before the card closes.
const Duration _toastShown = Duration(seconds: 3);

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

  @override
  ConsumerState<LiveMoments> createState() => _LiveMomentsState();
}

class _LiveMomentsState extends ConsumerState<LiveMoments> {
  LiveMomentTracker? _tracker;
  LiveMoment? _shown;
  _RareAnswer? _answer;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    unawaited(_loadVerified());
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
    _check();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _check() {
    final tracker = _tracker;
    if (tracker == null) return;
    final taxonomy = ref.read(taxonomyServiceProvider).value;
    final moment = tracker.next(
      widget.entries,
      presenceOf: widget.presenceOf,
      isBird: (name) => isBird(taxonomy, name),
    );
    // One moment at a time; the others wait for the Bilan.
    if (moment == null || _shown != null) return;
    BirdyHaptics.light();
    // Called from didUpdateWidget too: build after this frame's build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _shown = moment;
        _answer = null;
      });
      if (moment.kind == LiveMomentKind.firstTime) {
        _closeAfter(_firstTimeShown);
      }
    });
  }

  void _closeAfter(Duration delay) {
    _timer?.cancel();
    _timer = Timer(delay, _close);
  }

  void _close() {
    _timer?.cancel();
    if (mounted) setState(() => _shown = null);
  }

  /// Writes the verdict on every detection of the species in this
  /// listening; they are saved with the session at « Arrêter ».
  void _answerRare(_RareAnswer answer) {
    final moment = _shown;
    if (moment == null) return;
    final name = moment.entry.scientificName;
    final detections = widget.controller.session?.detections ?? const [];
    switch (answer) {
      case _RareAnswer.yes:
        for (final d in detections.where((d) => d.scientificName == name)) {
          d.markConfirmed();
        }
        _tracker?.confirmed();
        BirdyHaptics.light();
      case _RareAnswer.no:
        for (final d in detections.where((d) => d.scientificName == name)) {
          d.markRejected();
        }
        _closeAfter(_toastShown);
      case _RareAnswer.later:
        _closeAfter(_toastShown);
    }
    setState(() => _answer = answer);
  }

  @override
  Widget build(BuildContext context) {
    final moment = _shown;
    if (moment == null) return const SizedBox.shrink();
    final c = BirdyColors.of(context);
    final tint = SpeciesAccents.tintOf(moment.entry.scientificName);
    return Stack(
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
        Center(
          child: SingleChildScrollView(
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
                          clipPath: widget.clips[moment.entry.scientificName],
                          controller: widget.controller,
                          onClose: _close,
                        )
                        : _RareCard(
                          moment: moment,
                          image: widget.imageFor?.call(
                            moment.entry.scientificName,
                          ),
                          clipPath: widget.clips[moment.entry.scientificName],
                          controller: widget.controller,
                          presenceScore: widget.presenceScoreOf(
                            moment.entry.scientificName,
                          ),
                          answer: _answer,
                          onAnswer: _answerRare,
                          onClose: _close,
                        ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.moment, required this.image});

  final LiveMoment moment;
  final ImageProvider? image;

  @override
  Widget build(BuildContext context) {
    final c = BirdyColors.of(context);
    final entry = moment.entry;
    return Column(
      children: [
        SpeciesAvatar(
          image: image,
          tint: SpeciesAccents.tintOf(entry.scientificName),
          size: 112,
        ),
        const SizedBox(height: BirdySpace.m),
        Text(
          entry.commonName,
          textAlign: TextAlign.center,
          style: BirdyText.title.copyWith(color: c.text1),
        ),
        Text(
          entry.scientificName,
          textAlign: TextAlign.center,
          style: BirdyText.latin.copyWith(color: c.text2),
        ),
      ],
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
  });

  final LiveMoment moment;
  final ImageProvider? image;
  final String? clipPath;
  final LiveController controller;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
    final tint = SpeciesAccents.tintOf(moment.entry.scientificName);
    final status = statusFor(moment.rank);
    final next = nextStatus(status);
    final caption = BirdyText.caption.copyWith(color: c.text2);
    return _Card(
      border: tint.accent.withValues(alpha: 0.5),
      children: [
        Text(l10n.forkMomentListeningGoesOn, style: caption),
        const SizedBox(height: BirdySpace.s),
        const NoveltyPill(kind: NoveltyKind.firstTime),
        const SizedBox(height: BirdySpace.m),
        _Header(moment: moment, image: image),
        const SizedBox(height: BirdySpace.m),
        Semantics(
          liveRegion: true,
          child: Text(
            l10n.forkMomentFirstTitle,
            textAlign: TextAlign.center,
            style: BirdyText.heading.copyWith(color: c.text1),
          ),
        ),
        const SizedBox(height: BirdySpace.xs),
        Text(
          l10n.forkMomentAdded(moment.rank),
          textAlign: TextAlign.center,
          style: BirdyText.label.copyWith(color: c.text1),
        ),
        if (status != null) ...[
          const SizedBox(height: BirdySpace.m),
          Row(
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
        ],
        if (next != null) ...[
          const SizedBox(height: BirdySpace.xs),
          Text(
            l10n.forkStatusNext(
              next.from - moment.rank,
              statusName(l10n, next),
            ),
            textAlign: TextAlign.center,
            style: caption,
          ),
        ],
        const SizedBox(height: BirdySpace.l),
        _Buttons(
          clipPath: clipPath,
          controller: controller,
          primary: l10n.forkMomentContinue,
          onPrimary: onClose,
        ),
        const SizedBox(height: BirdySpace.s),
        Text(l10n.forkMomentClosesSoon, style: caption),
      ],
    );
  }
}

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
  });

  final LiveMoment moment;
  final ImageProvider? image;
  final String? clipPath;
  final LiveController controller;
  final double? presenceScore;
  final _RareAnswer? answer;
  final void Function(_RareAnswer) onAnswer;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
    final caption = BirdyText.caption.copyWith(color: c.text2);
    final percent = presenceScore == null ? null : (presenceScore! * 100);

    if (answer == _RareAnswer.yes) {
      return _Card(
        border: BirdyBrand.oriole,
        children: [
          const NoveltyPill(kind: NoveltyKind.unexpectedHere),
          const SizedBox(height: BirdySpace.m),
          _Ring(child: _Header(moment: moment, image: image)),
          const SizedBox(height: BirdySpace.m),
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
          const SizedBox(height: BirdySpace.xs),
          Text(
            l10n.forkMomentRareKeep,
            textAlign: TextAlign.center,
            style: caption,
          ),
          const SizedBox(height: BirdySpace.l),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: BirdyButtonStyles.primary(context),
              onPressed: onClose,
              child: Text(l10n.forkMomentContinue),
            ),
          ),
        ],
      );
    }

    return _Card(
      border: BirdyBrand.oriole.withValues(alpha: 0.65),
      children: [
        const NoveltyPill(kind: NoveltyKind.rareHereToConfirm),
        const SizedBox(height: BirdySpace.m),
        _Header(moment: moment, image: image),
        const SizedBox(height: BirdySpace.s),
        Text(
          l10n.forkMomentRareHere,
          textAlign: TextAlign.center,
          style: BirdyText.label.copyWith(
            color: BirdyBrand.oriole,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (percent != null) ...[
          const SizedBox(height: BirdySpace.xs),
          Text(
            percent < 1
                ? l10n.forkMomentPresenceLow
                : l10n.forkMomentPresence(percent.round()),
            textAlign: TextAlign.center,
            style: BirdyText.bodyCompact.copyWith(color: c.text2),
          ),
        ],
        const SizedBox(height: BirdySpace.m),
        if (answer == null) ...[
          if (clipPath != null) ...[
            ReplayButton(controller: controller, clipPath: clipPath!),
            const SizedBox(height: BirdySpace.s),
          ],
          Text(
            l10n.forkMomentRareAsk,
            textAlign: TextAlign.center,
            style: BirdyText.heading.copyWith(color: c.text1),
          ),
          const SizedBox(height: BirdySpace.xs),
          Text(
            l10n.forkMomentRareMic,
            textAlign: TextAlign.center,
            style: caption,
          ),
          const SizedBox(height: BirdySpace.m),
          for (final (a, label, style) in [
            (
              _RareAnswer.yes,
              l10n.forkReviewItIs,
              BirdyButtonStyles.primary(context),
            ),
            (
              _RareAnswer.later,
              l10n.forkReviewDontKnow,
              BirdyButtonStyles.secondary(context),
            ),
            (
              _RareAnswer.no,
              l10n.forkReviewItIsNot,
              BirdyButtonStyles.secondary(context),
            ),
          ]) ...[
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: style,
                onPressed: () => onAnswer(a),
                child: Text(label),
              ),
            ),
            const SizedBox(height: BirdySpace.s),
          ],
          Text(
            l10n.forkMomentRareNote,
            textAlign: TextAlign.center,
            style: caption,
          ),
        ] else
          Semantics(
            liveRegion: true,
            child: Text(
              answer == _RareAnswer.no
                  ? l10n.forkMomentRareNo
                  : l10n.forkMomentRareLater,
              textAlign: TextAlign.center,
              style: BirdyText.body.copyWith(color: c.text1),
            ),
          ),
      ],
    );
  }
}

/// One soft ring around the confirmed rare bird, once (450 ms).
class _Ring extends StatefulWidget {
  const _Ring({required this.child});

  final Widget child;

  @override
  State<_Ring> createState() => _RingState();
}

class _RingState extends State<_Ring> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: BirdyMotion.rareBird,
  )..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (BirdyMotion.reduced(context)) return widget.child;
    return Stack(
      alignment: Alignment.topCenter,
      children: [
        AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final t = BirdyMotion.standard.transform(_controller.value);
            return Opacity(
              opacity: 1 - t,
              child: Transform.scale(
                scale: 1 + 0.35 * t,
                child: Container(
                  width: 112,
                  height: 112,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: BirdyBrand.oriole, width: 2),
                  ),
                ),
              ),
            );
          },
        ),
        widget.child,
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
  });

  final String? clipPath;
  final LiveController controller;
  final String primary;
  final VoidCallback onPrimary;

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
          child: Text(primary),
        ),
      ),
    ],
  );
}

class _Card extends StatelessWidget {
  const _Card({required this.border, required this.children});

  final Color border;
  final List<Widget> children;

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
        padding: const EdgeInsets.fromLTRB(
          BirdySpace.l,
          BirdySpace.xl,
          BirdySpace.l,
          BirdySpace.l,
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: children),
      ),
    );
  }
}
