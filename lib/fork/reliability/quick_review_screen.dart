/// Quick review: a stack of cards of detections to check (fork/PLAN.md J3,
/// look of J6c, SPEC.md 9.9).
///
/// Right = « C'est bien lui », left = « Ce n'est pas lui », up = « Je ne
/// sais pas ». The card follows the finger, flies off with the gesture's
/// speed or springs back. Three big buttons do the same, for one-handed or
/// gloved use.
library;

import 'dart:async';
import 'dart:io';

import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:just_audio/just_audio.dart';

import '../../features/explore/explore_providers.dart';
import '../../features/live/live_session.dart';
import '../../shared/providers/settings_providers.dart';
import '../../shared/services/link_launcher.dart';
import '../data/observation_index.dart';
import '../data/observation_index_service.dart';
import '../design/birdy_motion.dart';
import '../design/birdy_tokens.dart';
import '../design/birdy_typography.dart';
import '../ranking/species_activity_section.dart' show lastHeardWhen;
import 'geo_presence_service.dart';
import 'quick_review_widgets.dart';
import 'reliability_badge.dart';
import 'reliability_config.dart';
import 'reliability_screen.dart';
import 'review_writer.dart';

export 'quick_review_widgets.dart' show ReviewAnswer;

/// Decides the answer of a released drag, or null to spring back.
ReviewAnswer? answerForDrag(Offset offset, Offset velocity) {
  const distance = 120.0;
  const speed = 900.0;
  if (offset.dy < -distance || velocity.dy < -speed) {
    if (offset.dy.abs() > offset.dx.abs()) return ReviewAnswer.dontKnow;
  }
  if (offset.dx > distance || velocity.dx > speed) return ReviewAnswer.itIs;
  if (offset.dx < -distance || velocity.dx < -speed) {
    return ReviewAnswer.itIsNot;
  }
  return null;
}

/// Spring of a card released under the thresholds: back to the center,
/// interruptible by a new drag.
final SpringDescription _returnSpring = SpringDescription.withDampingRatio(
  mass: 1,
  stiffness: 400,
  ratio: 0.8,
);

/// Time for an answered card to leave the screen.
const Duration _flyDuration = Duration(milliseconds: 260);

/// Quick review screen.
class QuickReviewScreen extends ConsumerStatefulWidget {
  const QuickReviewScreen({super.key, this.onlyKeys});

  /// Detection keys to review; null reviews the whole queue.
  final Set<String>? onlyKeys;

  @override
  ConsumerState<QuickReviewScreen> createState() => _QuickReviewScreenState();
}

class _QuickReviewScreenState extends ConsumerState<QuickReviewScreen>
    with SingleTickerProviderStateMixin {
  List<IndexedDetection>? _queue;
  int _position = 0;
  int _done = 0;
  bool _busy = false;
  final AudioPlayer _player = AudioPlayer();

  /// Drives both the spring back and the fly-off, from [_from] to [_to].
  late final AnimationController _motion = AnimationController.unbounded(
    vsync: this,
  )..addListener(_onMotion);
  final ValueNotifier<Offset> _offset = ValueNotifier(Offset.zero);
  Offset _from = Offset.zero;
  Offset _to = Offset.zero;

  /// Opacity of the leaving card when motion is reduced (fade only).
  final ValueNotifier<double> _fade = ValueNotifier(1);
  bool _fading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final index = await ref.read(observationIndexServiceProvider).ensureReady();
    final queue = await index.reviewQueue(
      limit: 200,
      onlyKeys: widget.onlyKeys,
    );
    if (!mounted) return;
    setState(() {
      _queue = queue;
      _position = 0;
    });
    _autoPlay();
  }

  IndexedDetection? get _current {
    final queue = _queue;
    if (queue == null || _position >= queue.length) return null;
    return queue[_position];
  }

  Future<void> _autoPlay() async {
    final path = _current?.clipPath;
    try {
      await _player.stop();
      if (path == null || !File(path).existsSync()) return;
      await _player.setFilePath(path);
      unawaited(_player.play());
    } catch (_) {
      // No sound: the card still shows the spectrogram.
    }
  }

  Future<void> _togglePlay() async {
    if (_player.playing &&
        _player.processingState != ProcessingState.completed) {
      await _player.stop();
    } else {
      await _autoPlay();
    }
  }

  void _onMotion() {
    final t = _motion.value;
    if (_fading) {
      _fade.value = (1 - t).clamp(0, 1);
    } else {
      _offset.value = Offset.lerp(_from, _to, t)!;
    }
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (_busy) return;
    _motion.stop();
    _offset.value += details.delta;
  }

  void _onDragEnd(DragEndDetails details) {
    if (_busy) return;
    final velocity = details.velocity.pixelsPerSecond;
    final answer = answerForDrag(_offset.value, velocity);
    if (answer == null) {
      _springBack(velocity);
    } else {
      _flyOff(answer);
    }
  }

  void _springBack(Offset velocity) {
    _from = _offset.value;
    _to = Offset.zero;
    _fading = false;
    final distance = _from.distance;
    // Velocity along the way back, as a fraction of the distance per second.
    final speed =
        distance == 0
            ? 0.0
            : -(velocity.dx * _from.dx + velocity.dy * _from.dy) /
                (distance * distance);
    _motion.value = 0;
    _motion.animateWith(SpringSimulation(_returnSpring, 0, 1, speed));
  }

  /// Sends the card off in the answer's direction, then records it.
  Future<void> _flyOff(ReviewAnswer answer) async {
    if (_busy || _current == null) return;
    setState(() => _busy = true);
    final size = MediaQuery.sizeOf(context);
    _fading = BirdyMotion.reduced(context);
    _from = _offset.value;
    _to = switch (answer) {
      ReviewAnswer.itIs => Offset(size.width * 1.2, _from.dy),
      ReviewAnswer.itIsNot => Offset(-size.width * 1.2, _from.dy),
      ReviewAnswer.dontKnow => Offset(_from.dx, -size.height),
    };
    _motion.value = 0;
    await _motion.animateTo(
      1,
      duration: _fading ? BirdyMotion.exit : _flyDuration,
      curve: BirdyMotion.standard,
    );
    await _record(answer);
  }

  Future<void> _record(ReviewAnswer answer) async {
    final detection = _current;
    if (detection == null) return;
    final writer = ref.read(reviewWriterProvider);
    switch (answer) {
      case ReviewAnswer.itIs:
        await writer.setStatus(detection, ReviewStatus.confirmed);
      case ReviewAnswer.itIsNot:
        await writer.setStatus(detection, ReviewStatus.rejected);
      case ReviewAnswer.dontKnow:
        await writer.skip(detection);
    }
    if (!mounted) return;
    _offset.value = Offset.zero;
    _fade.value = 1;
    _fading = false;
    setState(() {
      _busy = false;
      _position++;
      _done++;
    });
    _autoPlay();
  }

  @override
  void dispose() {
    _motion.dispose();
    _offset.dispose();
    _fade.dispose();
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
    final queue = _queue;
    final current = _current;
    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: BirdySpace.gutter,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ReviewTopBar(
                    position:
                        queue == null || current == null ? null : _position + 1,
                    total: queue?.length ?? 0,
                    loading: queue == null,
                    onClose: () => Navigator.of(context).maybePop(),
                    onReliability:
                        () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const ReliabilityScreen(),
                          ),
                        ),
                  ),
                  // FORK: room between the header row and the progress bar
                  // below it, they were touching on phone (J6f-b feedback).
                  const SizedBox(height: BirdySpace.l),
                  Expanded(
                    child:
                        queue == null
                            ? _loadingBody()
                            : current == null
                            ? ReviewAllDone(sorted: _done)
                            : _body(l10n, queue, current),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Same shape as [_body] (progress, one card, room below): the queue's
  /// length is not known yet, so a static placeholder stands in for the
  /// progress bar and the top card, no swipe hints or verdict buttons
  /// (they need a real detection to answer for).
  Widget _loadingBody() {
    return SingleChildScrollView(
      key: const ValueKey('quick-review-loading'),
      padding: const EdgeInsets.only(bottom: BirdySpace.l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ReviewProgress.skeleton(context),
          const SizedBox(height: BirdySpace.m),
          ReviewCardStack(behind: 0, top: ReviewCard.skeleton(context)),
        ],
      ),
    );
  }

  Widget _body(
    AppLocalizations l10n,
    List<IndexedDetection> queue,
    IndexedDetection current,
  ) {
    final c = BirdyColors.of(context);
    // FORK: J6h, the card stack is centered between the progress bar and the
    // verdict buttons; when it does not fit (short screen, large text) the
    // middle area scrolls instead of overflowing.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ReviewProgress(value: _position / queue.length, sorted: _done),
        Expanded(
          child: LayoutBuilder(
            builder:
                (context, box) => SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: box.maxHeight),
                    child: Center(
                      key: const ValueKey('quick-review-stack-area'),
                      child: ReviewCardStack(
                        behind: queue.length - _position - 1,
                        top: GestureDetector(
                          onPanUpdate: _onDragUpdate,
                          onPanEnd: _onDragEnd,
                          child: ValueListenableBuilder<Offset>(
                            valueListenable: _offset,
                            builder:
                                (context, offset, child) => Transform.translate(
                                  offset: offset,
                                  child: child,
                                ),
                            child: ValueListenableBuilder<double>(
                              valueListenable: _fade,
                              builder:
                                  (context, fade, child) =>
                                      Opacity(opacity: fade, child: child),
                              child: _EnteringCard(
                                key: ValueKey(current.key),
                                child: _card(current),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
          ),
        ),
        const SizedBox(height: BirdySpace.s),
        const SwipeHints(),
        const SizedBox(height: BirdySpace.m),
        VerdictButtons(enabled: !_busy, onAnswer: _flyOff),
        const SizedBox(height: BirdySpace.m),
        Text(
          l10n.forkQuickReviewDontKnowNote,
          textAlign: TextAlign.center,
          style: BirdyText.caption.copyWith(color: c.text2),
        ),
        const SizedBox(height: BirdySpace.l),
      ],
    );
  }

  Widget _card(IndexedDetection detection) {
    final l10n = AppLocalizations.of(context)!;
    final language = Localizations.localeOf(context).languageCode;
    final speciesLocale = ref.watch(effectiveSpeciesLocaleProvider);
    final taxonomy = ref.watch(taxonomyServiceProvider).value;
    final species = taxonomy?.lookup(detection.scientificName);
    final name =
        species?.commonNameForLocale(speciesLocale) ?? detection.commonName;
    final showLatin = ref.watch(showSciNamesProvider);
    final imagePath = taxonomy?.assetImagePath(detection.scientificName);
    final reference = species?.ebirdListenUrl;
    final score = NumberFormat('0.00', language).format(detection.confidence);
    return ValueListenableBuilder<Offset>(
      valueListenable: _offset,
      builder:
          (context, offset, _) => StreamBuilder<PlayerState>(
            stream: _player.playerStateStream,
            builder: (context, snapshot) {
              final state = snapshot.data;
              final playing =
                  (state?.playing ?? false) &&
                  state?.processingState != ProcessingState.completed;
              return ReviewCard(
                name: name,
                latin: showLatin ? detection.scientificName : null,
                when: _capitalized(
                  lastHeardWhen(
                    l10n,
                    language,
                    detection.start,
                    now: DateTime.now(),
                  ),
                ),
                detail: l10n.forkQuickReviewScore(score),
                badge: _Badge(detection: detection),
                image: imagePath == null ? null : AssetImage(imagePath),
                clipPath: detection.clipPath,
                playing: playing,
                onPlay: _togglePlay,
                onReference:
                    reference == null
                        ? null
                        : () => openExternalUrl(context, reference),
                hint: _busy ? null : answerForDrag(offset, Offset.zero),
              );
            },
          ),
    );
  }

  static String _capitalized(String text) =>
      text.isEmpty ? text : text[0].toUpperCase() + text.substring(1);
}

/// Reliability badge of the card, from the geo-model at the detection's
/// place and week (« Rare ici · à confirmer » included, J3b).
class _Badge extends ConsumerWidget {
  const _Badge({required this.detection});

  final IndexedDetection detection;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<GeoPresence?>(
      future: ref
          .read(geoPresenceServiceProvider)
          .presenceAt(
            detection.scientificName,
            latitude: detection.latitude,
            longitude: detection.longitude,
            time: detection.start,
          ),
      builder: (context, snapshot) {
        final presence = snapshot.data;
        return ReliabilityBadge(
          level: reliabilityFor(
            score: detection.confidence,
            presence: presence,
          ),
          unexpected: presence?.unexpected ?? false,
          score: detection.confidence,
        );
      },
    );
  }
}

/// The next card arrives: fade and 0.97 to 1 scale, 220 ms; fade only with
/// reduced motion.
class _EnteringCard extends StatelessWidget {
  const _EnteringCard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final reduced = BirdyMotion.reduced(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: BirdyMotion.enter,
      curve: BirdyMotion.standard,
      builder:
          (context, t, child) => Opacity(
            opacity: t,
            child:
                reduced
                    ? child
                    : Transform.scale(
                      scale:
                          BirdyMotion.enterScale +
                          (1 - BirdyMotion.enterScale) * t,
                      child: child,
                    ),
          ),
      child: child,
    );
  }
}
