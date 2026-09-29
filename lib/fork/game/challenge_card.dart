/// « Défi de la semaine » card (J6e, SPEC.md 9.1 and 9.11): offered with
/// « Commencer », then dots or a count, then « Défi réussi ».
library;

import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

import '../../shared/utils/app_icons.dart';
import '../design/birdy_tokens.dart';
import '../design/birdy_typography.dart';
import '../design/birdygo_silhouette.dart';
import '../design/widgets/birdy_block.dart';
import '../design/widgets/birdy_buttons.dart';
import 'challenges.dart';
import 'game_config.dart';

String challengeTitle(AppLocalizations l10n, WeeklyChallenge c) => switch (c
    .kind) {
  ChallengeKind.dawnMornings => l10n.forkChallengeDawnMornings(c.target),
  ChallengeKind.listeningDays => l10n.forkChallengeListeningDays(c.target),
  ChallengeKind.weekSpecies => l10n.forkChallengeWeekSpecies(c.target),
};

String challengeBody(AppLocalizations l10n, ChallengeKind kind) =>
    switch (kind) {
      ChallengeKind.dawnMornings => l10n.forkChallengeDawnMorningsBody,
      ChallengeKind.listeningDays => l10n.forkChallengeListeningDaysBody,
      ChallengeKind.weekSpecies => l10n.forkChallengeWeekSpeciesBody,
    };

/// Glyph of the challenge disc: an icon, or the BirdyGo silhouette for the
/// species challenge (J6h, in place of the raven).
Widget challengeGlyph(ChallengeKind kind, Color color, double size) =>
    switch (kind) {
      ChallengeKind.dawnMornings => Icon(
        AppIcons.wbTwilightRounded,
        size: size,
        color: color,
      ),
      ChallengeKind.listeningDays => Icon(
        AppIcons.calendarToday,
        size: size,
        color: color,
      ),
      ChallengeKind.weekSpecies => BirdyGoSilhouetteIcon.glyph(
        size: size,
        color: color,
      ),
    };

/// Dots up to this target, a count beyond.
const int _maxDots = 5;

class ChallengeCard extends StatelessWidget {
  const ChallengeCard({
    super.key,
    required this.challenge,
    required this.onStart,
    this.background,
    this.captionColor,
  });

  final WeeklyChallenge challenge;
  final VoidCallback onStart;

  /// Overrides the block's own tone fill (J6f Profil « À gagner »: an inset
  /// on the tonal color instead of its own plain/Loriot block).
  final Color? background;

  /// Overrides the leading caption's color (defaults to [BirdyColors.text2],
  /// the Profil inset uses [BirdyColors.accentText] instead).
  final Color? captionColor;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
    final caption = BirdyText.caption.copyWith(color: c.text2);
    final leadCaption = BirdyText.caption.copyWith(
      color: captionColor ?? c.text2,
      fontWeight: captionColor == null ? null : FontWeight.w700,
    );
    final started = challenge.started;
    final done = challenge.done;

    // J6f: a plain block, on Loriot once done (fills, never borders); the
    // Profil « À gagner » inset overrides the fill entirely.
    return BirdyBlock(
      tone: done ? BirdyBlockTone.oriole : BirdyBlockTone.plain,
      color: background,
      padding: const EdgeInsets.symmetric(
        horizontal: BirdySpace.l,
        vertical: BirdySpace.comfy,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: BirdySizes.blockIconDisc,
                height: BirdySizes.blockIconDisc,
                decoration: BoxDecoration(
                  color: done ? c.oriole : c.tonal,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child:
                      done
                          ? Icon(AppIcons.check, size: BirdyGlyph.xxl, color: c.onOriole)
                          : challengeGlyph(challenge.kind, c.accentText, 22),
                ),
              ),
              const SizedBox(width: BirdySpace.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.forkChallengeWeek, style: leadCaption),
                    Text(
                      challengeTitle(l10n, challenge),
                      style: BirdyText.species.copyWith(color: c.text1),
                    ),
                  ],
                ),
              ),
              if (started) ...[
                const SizedBox(width: BirdySpace.s),
                _Progress(challenge: challenge),
              ],
            ],
          ),
          const SizedBox(height: BirdySpace.s),
          if (done) ...[
            Text(
              l10n.forkChallengeDone,
              style: BirdyText.label.copyWith(
                color: c.orioleText,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(l10n.forkChallengeDoneBody, style: caption),
          ] else if (started)
            Text(
              l10n.forkChallengeProgress(
                challenge.value.clamp(0, challenge.target),
                challenge.target,
              ),
              style: caption,
            )
          else ...[
            Text(
              challengeBody(l10n, challenge.kind),
              style: BirdyText.bodyCompact.copyWith(color: c.text1),
            ),
            const SizedBox(height: BirdySpace.s),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: FilledButton(
                style: BirdyButtonStyles.tonal(context),
                onPressed: onStart,
                child: Text(l10n.forkChallengeStart),
              ),
            ),
            const SizedBox(height: BirdySpace.xs),
            Text(l10n.forkChallengeOptIn, style: caption),
          ],
        ],
      ),
    );
  }
}

class _Progress extends StatelessWidget {
  const _Progress({required this.challenge});

  final WeeklyChallenge challenge;

  @override
  Widget build(BuildContext context) {
    final c = BirdyColors.of(context);
    final value = challenge.value.clamp(0, challenge.target);
    if (challenge.target > _maxDots) {
      return Text(
        '$value/${challenge.target}',
        style: BirdyText.label.copyWith(
          color: c.text1,
          fontWeight: FontWeight.w700,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      );
    }
    return ExcludeSemantics(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < challenge.target; i++)
            Container(
              width: BirdySpace.comfy,
              height: BirdySpace.comfy,
              margin: const EdgeInsets.only(left: BirdySpace.xs),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i < value ? c.accent : null,
                border:
                    i < value
                        ? null
                        : Border.all(color: c.borderStrong, width: BirdyStroke.regular),
              ),
            ),
        ],
      ),
    );
  }
}
