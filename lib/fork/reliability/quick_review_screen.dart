/// Quick review: a stack of cards of detections to check (fork/PLAN.md J3).
///
/// Right = « C'est bien lui », left = « Ce n'est pas lui », up = « Je ne
/// sais pas ». Three big buttons do the same, for one-handed or gloved use.
library;

import 'dart:async';
import 'dart:io';

import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:just_audio/just_audio.dart';

import '../../features/explore/explore_providers.dart';
import '../../features/live/live_session.dart';
import '../../shared/providers/settings_providers.dart';
import '../../shared/utils/app_icons.dart';
import '../data/observation_index.dart';
import '../data/observation_index_service.dart';
import 'clip_spectrogram.dart';
import 'geo_presence_service.dart';
import 'reliability_badge.dart';
import 'reliability_config.dart';
import 'reliability_screen.dart';
import 'review_writer.dart';

/// Answers of the quick review.
enum ReviewAnswer { itIs, itIsNot, dontKnow }

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

/// Quick review screen.
class QuickReviewScreen extends ConsumerStatefulWidget {
  const QuickReviewScreen({super.key, this.keys});

  /// Only these detections (the Bilan's « Vérifier 3 détections »); the whole
  /// queue when null.
  final List<String>? keys;

  @override
  ConsumerState<QuickReviewScreen> createState() => _QuickReviewScreenState();
}

class _QuickReviewScreenState extends ConsumerState<QuickReviewScreen> {
  List<IndexedDetection>? _queue;
  int _position = 0;
  int _done = 0;
  Offset _drag = Offset.zero;
  bool _busy = false;
  final AudioPlayer _player = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final index = await ref.read(observationIndexServiceProvider).ensureReady();
    final queue = await index.reviewQueue(limit: 200, keys: widget.keys);
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
    await _player.stop();
    if (path == null || !File(path).existsSync()) return;
    try {
      await _player.setFilePath(path);
      unawaited(_player.play());
    } catch (_) {
      // No sound: the card still shows the spectrogram.
    }
  }

  Future<void> _answer(ReviewAnswer answer) async {
    final detection = _current;
    if (detection == null || _busy) return;
    setState(() => _busy = true);
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
    setState(() {
      _busy = false;
      _drag = Offset.zero;
      _position++;
      _done++;
    });
    _autoPlay();
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final queue = _queue;
    final current = _current;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.forkQuickReview),
        actions: [
          IconButton(
            tooltip: l10n.forkReliabilityTitle,
            icon: const Icon(AppIcons.verifiedRounded),
            onPressed:
                () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const ReliabilityScreen(),
                  ),
                ),
          ),
        ],
      ),
      body: SafeArea(
        child:
            queue == null
                ? const Center(child: CircularProgressIndicator())
                : current == null
                ? _AllDone(done: _done)
                : Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        l10n.forkQuickReviewProgress(
                          _position + 1,
                          queue.length,
                        ),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: _position / queue.length,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: GestureDetector(
                          onPanUpdate: (d) => setState(() => _drag += d.delta),
                          onPanEnd: (d) {
                            final answer = answerForDrag(
                              _drag,
                              d.velocity.pixelsPerSecond,
                            );
                            if (answer == null) {
                              setState(() => _drag = Offset.zero);
                            } else {
                              _answer(answer);
                            }
                          },
                          child: Transform.translate(
                            offset: _drag,
                            child: Transform.rotate(
                              angle: _drag.dx / 1200,
                              child: _ReviewCard(
                                key: ValueKey(current.key),
                                detection: current,
                                onReplay: _autoPlay,
                                hint: answerForDrag(_drag, Offset.zero),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _AnswerButtons(enabled: !_busy, onAnswer: _answer),
                    ],
                  ),
                ),
      ),
    );
  }
}

class _ReviewCard extends ConsumerWidget {
  const _ReviewCard({
    super.key,
    required this.detection,
    required this.onReplay,
    required this.hint,
  });

  final IndexedDetection detection;
  final VoidCallback onReplay;

  /// Answer the current drag would give, to tint the card.
  final ReviewAnswer? hint;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toString();
    final speciesLocale = ref.watch(effectiveSpeciesLocaleProvider);
    final name =
        ref
            .watch(taxonomyServiceProvider)
            .value
            ?.lookup(detection.scientificName)
            ?.commonNameForLocale(speciesLocale) ??
        detection.commonName;
    final border = switch (hint) {
      ReviewAnswer.itIs => theme.colorScheme.primary,
      ReviewAnswer.itIsNot => theme.colorScheme.error,
      ReviewAnswer.dontKnow => theme.colorScheme.tertiary,
      null => theme.colorScheme.outlineVariant,
    };
    final clip = detection.clipPath;
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: border, width: hint == null ? 1 : 3),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name, style: theme.textTheme.headlineSmall),
            Text(
              detection.scientificName,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontStyle: FontStyle.italic,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            FutureBuilder<GeoPresence?>(
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
                return Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    ReliabilityBadge(
                      level: reliabilityFor(
                        score: detection.confidence,
                        presence: presence,
                      ),
                      unexpected: presence?.unexpected ?? false,
                    ),
                    if (presence?.unexpected ?? false)
                      Text(
                        l10n.forkUnexpectedHere,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.tertiary,
                        ),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 8),
            Text(
              DateFormat.yMMMMd(
                locale,
              ).add_Hm().format(detection.start.toLocal()),
              style: theme.textTheme.bodyMedium,
            ),
            const Spacer(),
            if (clip != null) ...[
              ClipSpectrogram(path: clip),
              const SizedBox(height: 12),
              Center(
                child: FilledButton.tonalIcon(
                  onPressed: onReplay,
                  icon: const Icon(AppIcons.playArrow),
                  label: Text(l10n.forkReplay),
                ),
              ),
            ] else
              Text(
                l10n.forkQuickReviewNoClip,
                style: theme.textTheme.bodySmall,
              ),
          ],
        ),
      ),
    );
  }
}

class _AnswerButtons extends StatelessWidget {
  const _AnswerButtons({required this.enabled, required this.onAnswer});

  final bool enabled;
  final void Function(ReviewAnswer answer) onAnswer;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    Widget button(ReviewAnswer answer, String label, IconData icon, Color c) =>
        Expanded(
          child: SizedBox(
            height: 64,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: c,
                side: BorderSide(color: c),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: enabled ? () => onAnswer(answer) : null,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 22),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    style: const TextStyle(fontSize: 13, height: 1.1),
                  ),
                ],
              ),
            ),
          ),
        );
    return Row(
      children: [
        button(
          ReviewAnswer.itIsNot,
          l10n.forkReviewItIsNot,
          AppIcons.close,
          scheme.error,
        ),
        const SizedBox(width: 8),
        button(
          ReviewAnswer.dontKnow,
          l10n.forkReviewDontKnow,
          AppIcons.helpOutline,
          scheme.tertiary,
        ),
        const SizedBox(width: 8),
        button(
          ReviewAnswer.itIs,
          l10n.forkReviewItIs,
          AppIcons.check,
          scheme.primary,
        ),
      ],
    );
  }
}

class _AllDone extends StatelessWidget {
  const _AllDone({required this.done});

  final int done;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              AppIcons.checkCircle,
              size: 56,
              fill: 1,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              done == 0 ? l10n.forkQuickReviewEmpty : l10n.forkQuickReviewDone,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
          ],
        ),
      ),
    );
  }
}
