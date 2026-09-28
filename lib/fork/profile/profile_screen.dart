/// Profil (J6e, SPEC.md 9.11): status and its ring, the ladder of the 8
/// statuses, the forgiving série and the badges.
library;

import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../shared/utils/app_icons.dart';
import '../design/birdy_tokens.dart';
import '../design/birdy_typography.dart';
import '../design/widgets/birdy_block.dart';
import '../design/widgets/birdy_buttons.dart';
import '../design/widgets/birdy_headers.dart';
import '../game/challenge_card.dart';
import '../game/challenges.dart';
import '../game/game_config.dart';
import '../game/game_loader.dart';
import '../game/game_progress.dart';
import '../game/game_text.dart';
import '../game/fine_ear_quiz_screen.dart';
import '../game/game_widgets.dart';
import '../game/streak.dart';
import '../ranking/ranking_screen.dart';

/// Widest column on tablets.
const double _maxWidth = 600;

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
    final progress = ref.watch(gameProgressProvider).value;

    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _maxWidth),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                BirdySpace.page,
                BirdySpace.page,
                BirdySpace.page,
                BirdySpace.page,
              ),
              children: [
                BirdyTabHeader(
                  title: l10n.forkProfileTitle,
                  caption:
                      progress == null
                          ? null
                          : l10n.forkProfileCaption(
                            progress.verified,
                            progress.facts.streak.current,
                            progress.facts.streak.record,
                          ),
                  actions: [
                    BirdyIconButton(
                      icon: AppIcons.leaderboard,
                      semanticLabel: l10n.forkRanking,
                      onPressed:
                          () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const RankingScreen(),
                            ),
                          ),
                    ),
                  ],
                ),
                if (progress != null) ...[
                  const SizedBox(height: BirdySpace.block),
                  StatusCard(progress: progress, background: c.sure.background),
                  const SizedBox(height: BirdySpace.block),
                  BirdyBlock(child: _Ladder(verified: progress.verified)),
                  const SizedBox(height: BirdySpace.block),
                  _StreakCard(streak: progress.facts.streak),
                  const SizedBox(height: BirdySpace.block),
                  BirdyBlock(
                    tone: BirdyBlockTone.plain,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Semantics(
                          header: true,
                          child: Text(
                            l10n.forkBadges,
                            style: BirdyText.heading.copyWith(color: c.text1),
                          ),
                        ),
                        const SizedBox(height: BirdySpace.m),
                        _Badges(badges: progress.badges),
                      ],
                    ),
                  ),
                  const SizedBox(height: BirdySpace.block),
                  const _QuizEntry(),
                  if (progress.facts.challenge case final challenge?) ...[
                    const SizedBox(height: BirdySpace.block),
                    ChallengeCard(
                      challenge: challenge,
                      onStart: () async {
                        await ref
                            .read(challengeStoreProvider)
                            .start(DateTime.now());
                        ref.invalidate(gameProgressProvider);
                      },
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Status card: ring, status name, species count and what comes next.
/// Also on the home screen ([compact], with [onTap]).
class StatusCard extends StatelessWidget {
  const StatusCard({
    super.key,
    required this.progress,
    this.compact = false,
    this.onTap,
    this.background,
  });

  final GameProgress progress;
  final bool compact;
  final VoidCallback? onTap;

  /// Fill of the card. Defaults to [BirdyColors.surface1]; the full Profil
  /// screen (J6f) uses the sure tone instead.
  final Color? background;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
    final status = progress.status;
    final next = progress.next;
    final percent = (progress.progress * 100).round();
    final caption =
        next == null
            ? l10n.forkStatusTop
            : l10n.forkStatusNext(progress.remaining, statusName(l10n, next));
    final radius = compact ? BirdyRadii.card : BirdyRadii.hero;

    final content = Padding(
      padding: EdgeInsets.all(compact ? BirdySpace.l : BirdySpace.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              StatusRing(
                status: status,
                progress: progress.progress,
                size: compact ? 84 : 96,
                semanticLabel: l10n.forkStatusRingLabel(percent),
              ),
              const SizedBox(width: BirdySpace.l),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      status == null
                          ? l10n.forkStatusNone
                          : statusName(l10n, status),
                      style: (compact ? BirdyText.heading : BirdyText.title)
                          .copyWith(color: c.text1),
                    ),
                    const SizedBox(height: BirdySpace.xs),
                    Text(
                      l10n.forkNotebookDiscovered(progress.verified),
                      style: BirdyText.body.copyWith(color: c.text1),
                    ),
                    const SizedBox(height: BirdySpace.xs),
                    Text(
                      caption,
                      style: BirdyText.caption.copyWith(color: c.text2),
                    ),
                  ],
                ),
              ),
              if (onTap != null)
                Icon(AppIcons.chevronRight, size: 20, color: c.text2),
            ],
          ),
          if (!compact) ...[
            const SizedBox(height: BirdySpace.l),
            Text(
              statusLine(l10n, status),
              style: BirdyText.body.copyWith(color: c.text2),
            ),
          ],
        ],
      ),
    );
    return Material(
      color: background ?? c.surface1,
      borderRadius: BorderRadius.circular(radius),
      clipBehavior: Clip.antiAlias,
      child: onTap == null ? content : InkWell(onTap: onTap, child: content),
    );
  }
}

/// The 8 statuses in a row, the current one ringed.
class _Ladder extends StatelessWidget {
  const _Ladder({required this.verified});

  final int verified;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
    final current = statusFor(verified);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, box) {
            // Equal cells: the line runs from the first center to the last.
            final cell = box.maxWidth / GameConfig.statuses.length;
            final size = (cell - 4).clamp(20.0, 40.0);
            final currentIndex =
                current == null ? -1 : GameConfig.statuses.indexOf(current);
            return Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: cell / 2,
                  right: cell / 2,
                  top: size / 2 - 1,
                  height: 2,
                  child: ColoredBox(color: c.line),
                ),
                // J6f: the current status sits on a tonal pill.
                if (currentIndex >= 0)
                  Positioned(
                    left: cell * currentIndex,
                    width: cell,
                    top: -BirdySpace.xs,
                    bottom: -BirdySpace.xs,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: c.tonal,
                        borderRadius: BorderRadius.circular(BirdyRadii.thumb),
                      ),
                    ),
                  ),
                Row(
                  children: [
                    for (final status in GameConfig.statuses)
                      Expanded(
                        child: Semantics(
                          label: statusName(l10n, status),
                          selected: status == current,
                          child: Column(
                            children: [
                              StatusEmblem(
                                status: status,
                                size: size,
                                reached: verified >= status.from,
                                current: status == current,
                              ),
                              const SizedBox(height: BirdySpace.xs),
                              ExcludeSemantics(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    '${status.from}',
                                    style: BirdyText.caption.copyWith(
                                      color:
                                          status == current
                                              ? c.accentText
                                              : c.text2,
                                      fontWeight:
                                          status == current
                                              ? FontWeight.w800
                                              : null,
                                      fontFeatures: const [
                                        FontFeature.tabularFigures(),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            );
          },
        ),
        const SizedBox(height: BirdySpace.s),
        Text(
          l10n.forkStatusLadder,
          style: BirdyText.caption.copyWith(color: c.text2),
        ),
      ],
    );
  }
}

class _StreakCard extends StatelessWidget {
  const _StreakCard({required this.streak});

  final Streak streak;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
    final localeName = Localizations.localeOf(context).toString();
    final weekday = DateFormat('EEEEE', localeName);
    final dateLabel = DateFormat.MMMMEEEEd(localeName);
    final caption = BirdyText.caption.copyWith(
      color: c.text2,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    return BirdyBlock(
      tone: BirdyBlockTone.oriole,
      padding: const EdgeInsets.all(BirdySpace.l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: BirdySpace.m,
            children: [
              Text(
                l10n.forkStreakTitle(streak.current),
                style: BirdyText.heading.copyWith(color: c.text1),
              ),
              Text(l10n.forkStreakRecord(streak.record), style: caption),
            ],
          ),
          const SizedBox(height: BirdySpace.m),
          Row(
            children: [
              for (final day in streak.calendar)
                Expanded(
                  child: Semantics(
                    label:
                        '${dateLabel.format(day.date)}, ${switch (day.state) {
                          StreakDayState.listened => l10n.forkStreakDayListened,
                          StreakDayState.rest => l10n.forkStreakDayRest,
                          StreakDayState.missed => l10n.forkStreakDayMissed,
                          StreakDayState.open => l10n.forkStreakDayOpen,
                        }}',
                    child: ExcludeSemantics(
                      // 14 cells: small phones and large text shrink them.
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Column(
                          children: [
                            Text(
                              weekday.format(day.date).toUpperCase(),
                              style: caption,
                            ),
                            const SizedBox(height: BirdySpace.xs),
                            _DayDot(day: day),
                            const SizedBox(height: BirdySpace.xs),
                            Text('${day.date.day}', style: caption),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: BirdySpace.m),
          Text(l10n.forkStreakRestNote, style: caption),
          const SizedBox(height: BirdySpace.xs),
          Text(l10n.forkStreakRule, style: caption),
        ],
      ),
    );
  }
}

class _DayDot extends StatelessWidget {
  const _DayDot({required this.day});

  final StreakDay day;

  @override
  Widget build(BuildContext context) {
    final c = BirdyColors.of(context);
    const size = BirdySizes.dayDot;
    final Widget dot = switch (day.state) {
      StreakDayState.listened => Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          color: BirdyBrand.oriole,
          shape: BoxShape.circle,
        ),
        child: const Icon(AppIcons.check, size: 10, color: BirdyBrand.ink),
      ),
      StreakDayState.rest => CustomPaint(
        size: const Size.square(size),
        painter: _DashedCircle(BirdyBrand.oriole),
      ),
      StreakDayState.missed => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: c.line, shape: BoxShape.circle),
      ),
      StreakDayState.open => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: c.borderStrong, width: 1.5),
        ),
      ),
    };
    if (!day.isToday) return dot;
    return Container(
      padding: const EdgeInsets.all(1.5),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: c.text1, width: 1.5),
      ),
      child: dot,
    );
  }
}

class _DashedCircle extends CustomPainter {
  const _DashedCircle(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5;
    final rect = (Offset.zero & size).deflate(1);
    const dashes = 10;
    const sweep = 2 * 3.141592653589793 / dashes;
    for (var i = 0; i < dashes; i++) {
      canvas.drawArc(rect, i * sweep, sweep * 0.55, false, paint);
    }
  }

  @override
  bool shouldRepaint(_DashedCircle old) => old.color != color;
}

/// Tones of the badge tiles (J6f), in turn so neighbours never share one.
const List<BirdyBlockTone> kBadgeTileTones = [
  BirdyBlockTone.oriole,
  BirdyBlockTone.tonal,
  BirdyBlockTone.sure,
];

/// Tone of the badge tile at [index] in the grid.
BirdyBlockTone badgeTileTone(int index) =>
    kBadgeTileTones[index % kBadgeTileTones.length];

class _Badges extends StatelessWidget {
  const _Badges({required this.badges});

  final List<BadgeProgress> badges;

  static const int _columns = 4;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var start = 0; start < badges.length; start += _columns) {
      if (start > 0) rows.add(const SizedBox(height: BirdySpace.s));
      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = start; i < start + _columns; i++) ...[
                if (i > start) const SizedBox(width: BirdySpace.s),
                Expanded(
                  child:
                      i < badges.length
                          ? _badgeTile(context, badges[i], badgeTileTone(i))
                          : const SizedBox.shrink(),
                ),
              ],
            ],
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: rows,
    );
  }

  Widget _badgeTile(
    BuildContext context,
    BadgeProgress badge,
    BirdyBlockTone tone,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
    return BirdyBlock(
      tone: tone,
      radius: BirdyRadii.inset,
      padding: const EdgeInsets.symmetric(
        horizontal: BirdySpace.xs,
        vertical: BirdySpace.s,
      ),
      semanticLabel:
          '${badgeName(l10n, badge.kind)}, ${l10n.forkBadgeTier(badge.tier)}',
      onTap: () => _showBadge(context, badge),
      child: Column(
        children: [
          BadgeMedal(
            tier: badge.tier,
            icon: badgeIcon(badge.kind),
            glyph: badgeGlyph(badge.kind),
          ),
          const SizedBox(height: BirdySpace.xs),
          Text(
            badgeName(l10n, badge.kind),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: BirdyText.labelCompact.copyWith(color: c.text1),
          ),
          const Spacer(),
          const SizedBox(height: BirdySpace.xs),
          if (badge.tier == 0)
            Text(
              l10n.forkBadgeProgress(badge.value, badge.nextTarget!),
              textAlign: TextAlign.center,
              style: BirdyText.caption.copyWith(color: c.text2),
            )
          else
            TierDots(filled: badge.tier),
        ],
      ),
    );
  }

  void _showBadge(BuildContext context, BadgeProgress badge) {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (context) {
        final c = BirdyColors.of(context);
        final next = badge.nextTarget;
        return Padding(
          padding: const EdgeInsets.fromLTRB(
            BirdySpace.xl,
            0,
            BirdySpace.xl,
            BirdySpace.xxl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              BadgeMedal(
                tier: badge.tier,
                icon: badgeIcon(badge.kind),
                glyph: badgeGlyph(badge.kind),
                size: 72,
              ),
              const SizedBox(height: BirdySpace.m),
              Text(
                badgeName(l10n, badge.kind),
                style: BirdyText.heading.copyWith(color: c.text1),
              ),
              const SizedBox(height: BirdySpace.xs),
              Text(
                l10n.forkBadgeTier(badge.tier),
                style: BirdyText.label.copyWith(color: c.text2),
              ),
              const SizedBox(height: BirdySpace.m),
              Text(
                badgeRule(l10n, badge.kind),
                textAlign: TextAlign.center,
                style: BirdyText.body.copyWith(color: c.text1),
              ),
              const SizedBox(height: BirdySpace.s),
              Text(
                next == null
                    ? l10n.forkBadgeAllTiers
                    : l10n.forkBadgeProgress(badge.value, next),
                style: BirdyText.body.copyWith(
                  color: c.text1,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: BirdySpace.xs),
              Text(
                l10n.forkBadgeTiers(badge.tiers.join(' · ')),
                style: BirdyText.caption.copyWith(color: c.text2),
              ),
              if (badge.kind == BadgeKind.fineEar) ...[
                const SizedBox(height: BirdySpace.xl),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: BirdyButtonStyles.primary(context),
                    onPressed: () {
                      Navigator.of(context).pop();
                      _openQuiz(context);
                    },
                    child: Text(l10n.forkQuizStart),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

void _openQuiz(BuildContext context) => Navigator.of(
  context,
).push(MaterialPageRoute<void>(builder: (_) => const FineEarQuizScreen()));

/// « Qui chante ? »: the quiz behind the Oreille fine badge. A tonal block
/// (J6f) led by a Martin-pêcheur disc with a Loriot question mark.
class _QuizEntry extends StatelessWidget {
  const _QuizEntry();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
    return BirdyBlock(
      tone: BirdyBlockTone.tonal,
      onTap: () => _openQuiz(context),
      child: Row(
        children: [
          const ExcludeSemantics(child: _QuizIllustration()),
          const SizedBox(width: BirdySpace.l),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.forkQuizTitle,
                  style: BirdyText.heading.copyWith(color: c.text1),
                ),
                const SizedBox(height: BirdySpace.xs),
                Text(
                  l10n.forkQuizEntrySubtitle,
                  style: BirdyText.bodyCompact.copyWith(color: c.text2),
                ),
              ],
            ),
          ),
          Icon(AppIcons.chevronRight, color: c.accentText),
        ],
      ),
    );
  }
}

class _QuizIllustration extends StatelessWidget {
  const _QuizIllustration();

  @override
  Widget build(BuildContext context) {
    final c = BirdyColors.of(context);
    const disc = BirdySizes.quizDisc;
    const badge = BirdySizes.quizDiscBadge;
    return SizedBox.square(
      dimension: disc + badge / 3,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            bottom: 0,
            child: Container(
              width: disc,
              height: disc,
              decoration: BoxDecoration(
                color: c.accent,
                shape: BoxShape.circle,
              ),
              child: Icon(
                AppIcons.headphones,
                size: disc / 2,
                color: c.onAccent,
              ),
            ),
          ),
          Positioned(
            right: 0,
            top: 0,
            child: Container(
              width: badge,
              height: badge,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: c.oriole,
                shape: BoxShape.circle,
              ),
              child: Text(
                '?',
                textScaler: TextScaler.noScaling,
                style: BirdyText.label.copyWith(
                  color: c.onOriole,
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
