/// Profil (J6e, SPEC.md 9.11): status and its ring, the ladder of the 8
/// statuses, the forgiving série and the badges.
library;

import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../shared/utils/app_icons.dart';
import '../design/birdy_motion.dart';
import '../design/birdy_tokens.dart';
import '../design/birdy_typography.dart';
import '../design/widgets/birdy_block.dart';
import '../design/widgets/birdy_buttons.dart';
import '../design/widgets/birdy_headers.dart';
import '../design/widgets/birdy_skeleton.dart';
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
    final loading = progress == null;

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
                // Announced once, while the game progress is still loading;
                // the skeletons below are excluded from semantics.
                Semantics(
                  key: const ValueKey('profile-header'),
                  liveRegion: true,
                  label: loading ? l10n.forkProfileLoading : null,
                  child: BirdyTabHeader(
                    title: l10n.forkProfileTitle,
                    captionWidget: _crossFade(
                      loading
                          ? BirdySkeleton.text(
                            BirdyText.caption,
                            key: const ValueKey('profile-caption-skeleton'),
                            placeholder: '00000000000000000000000000',
                          )
                          : Text(
                            l10n.forkProfileCaption(
                              progress.verified,
                              progress.facts.streak.current,
                              progress.facts.streak.record,
                            ),
                            key: const ValueKey('profile-caption-real'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: BirdyText.caption.copyWith(color: c.text2),
                          ),
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
                ),
                const SizedBox(height: BirdySpace.block),
                // The card shell (fill, radius, padding) is always built the
                // same way; only its content cross-fades, so the card never
                // resizes once the game progress lands.
                Material(
                  key: const ValueKey('profile-status-card'),
                  color: c.sure.background,
                  borderRadius: BorderRadius.circular(BirdyRadii.hero),
                  clipBehavior: Clip.antiAlias,
                  child: Padding(
                    padding: const EdgeInsets.all(BirdySpace.xl),
                    child: _crossFade(
                      loading
                          ? const _StatusCardSkeletonBody(
                            key: ValueKey('status-skeleton'),
                          )
                          : _StatusCardRealBody(
                            key: const ValueKey('status-real'),
                            progress: progress,
                          ),
                    ),
                  ),
                ),
                const SizedBox(height: BirdySpace.block),
                BirdyBlock(
                  key: const ValueKey('profile-ladder'),
                  child: _crossFade(
                    loading
                        ? const _LadderSkeleton(key: ValueKey('ladder-skeleton'))
                        : _Ladder(
                          key: const ValueKey('ladder-real'),
                          verified: progress.verified,
                        ),
                  ),
                ),
                const SizedBox(height: BirdySpace.block),
                BirdyBlock(
                  key: const ValueKey('profile-streak'),
                  tone: BirdyBlockTone.oriole,
                  padding: const EdgeInsets.all(BirdySpace.l),
                  child: _crossFade(
                    loading
                        ? const _StreakCardSkeletonBody(
                          key: ValueKey('streak-skeleton'),
                        )
                        : _StreakCardBody(
                          key: const ValueKey('streak-real'),
                          streak: progress.facts.streak,
                        ),
                  ),
                ),
                const SizedBox(height: BirdySpace.block),
                BirdyBlock(
                  key: const ValueKey('profile-badges'),
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
                      _crossFade(
                        loading
                            ? const _BadgesSkeleton(
                              key: ValueKey('badges-skeleton'),
                            )
                            : _Badges(
                              key: const ValueKey('badges-real'),
                              badges: progress.badges,
                            ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: BirdySpace.block),
                const _QuizEntry(),
                if (!loading && progress.facts.challenge != null) ...[
                  const SizedBox(height: BirdySpace.block),
                  ChallengeCard(
                    challenge: progress.facts.challenge!,
                    onStart: () async {
                      await ref
                          .read(challengeStoreProvider)
                          .start(DateTime.now());
                      ref.invalidate(gameProgressProvider);
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Fades [child] in in place (no move, no scale): a loaded value replacing
  /// its skeleton. [child]'s own key tells the switcher when to cross-fade.
  static Widget _crossFade(Widget child) => AnimatedSwitcher(
    duration: BirdyMotion.enter,
    switchInCurve: BirdyMotion.standard,
    switchOutCurve: BirdyMotion.standard,
    transitionBuilder:
        (child, animation) => FadeTransition(opacity: animation, child: child),
    child: child,
  );
}

/// Same shape as [StatusCard]'s content (full, not compact): ring, status
/// name, discovered line, next-status caption, then the status line — so the
/// card never resizes once the game progress lands.
class _StatusCardSkeletonBody extends StatelessWidget {
  const _StatusCardSkeletonBody({super.key});

  @override
  Widget build(BuildContext context) {
    final c = BirdyColors.of(context);
    final nameStyle = BirdyText.title.copyWith(color: c.text1);
    final bodyStyle = BirdyText.body.copyWith(color: c.text1);
    final captionStyle = BirdyText.caption.copyWith(color: c.text2);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            BirdySkeleton.box(width: 96, height: 96, radius: 48),
            const SizedBox(width: BirdySpace.l),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  BirdySkeleton.text(
                    nameStyle,
                    placeholder: '000000000000000000000',
                  ),
                  const SizedBox(height: BirdySpace.xs),
                  BirdySkeleton.text(bodyStyle, placeholder: '00000000000000000'),
                  const SizedBox(height: BirdySpace.xs),
                  // One line, like the real caption (see `_StatusCardRealBody`).
                  BirdySkeleton.text(
                    captionStyle,
                    placeholder: '00000000000000000000000000000000',
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: BirdySpace.l),
        // Two lines, like the real status line.
        BirdySkeleton.text(
          bodyStyle,
          placeholder:
              '000000000000000000000000000000000000000000000000000000000000000000000000000000',
          maxLines: 2,
        ),
      ],
    );
  }
}

/// Full (non-compact, no [onTap]) content of [StatusCard], split out so the
/// profile screen's card shell can share it with [_StatusCardSkeletonBody].
class _StatusCardRealBody extends StatelessWidget {
  const _StatusCardRealBody({super.key, required this.progress});

  final GameProgress progress;

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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            StatusRing(
              status: status,
              progress: progress.progress,
              size: 96,
              semanticLabel: l10n.forkStatusRingLabel(percent),
            ),
            const SizedBox(width: BirdySpace.l),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // One line, truncated if need be: same reason as the
                  // caption below.
                  Text(
                    status == null ? l10n.forkStatusNone : statusName(l10n, status),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: BirdyText.title.copyWith(color: c.text1),
                  ),
                  const SizedBox(height: BirdySpace.xs),
                  Text(
                    l10n.forkNotebookDiscovered(progress.verified),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: BirdyText.body.copyWith(color: c.text1),
                  ),
                  const SizedBox(height: BirdySpace.xs),
                  // One line, truncated if need be: the next status's name
                  // must never wrap one loaded card and not the skeleton
                  // that came before it.
                  Text(
                    caption,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: BirdyText.caption.copyWith(color: c.text2),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: BirdySpace.l),
        // Same reason: a long status line must not grow the card past what
        // its skeleton reserved.
        Text(
          statusLine(l10n, status),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: BirdyText.body.copyWith(color: c.text2),
        ),
      ],
    );
  }
}

/// Same layout as [_Ladder] (equal cells, current-status pill, caption),
/// filled with skeleton emblems: [_Ladder] itself needs `verified` to know
/// the current status, not in yet while loading.
class _LadderSkeleton extends StatelessWidget {
  const _LadderSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, box) {
            final cell = box.maxWidth / GameConfig.statuses.length;
            final size = (cell - 4).clamp(20.0, 40.0);
            return Stack(
              clipBehavior: Clip.none,
              children: [
                for (var i = 0; i < GameConfig.statuses.length - 1; i++)
                  Positioned(
                    left: cell * i + cell / 2 + size / 2,
                    right:
                        box.maxWidth - (cell * (i + 1) + cell / 2 - size / 2),
                    top: size / 2 - 1,
                    height: 2,
                    child: ColoredBox(color: c.line),
                  ),
                Row(
                  children: [
                    for (var i = 0; i < GameConfig.statuses.length; i++)
                      Expanded(
                        child: Column(
                          children: [
                            BirdySkeleton.box(
                              width: size,
                              height: size,
                              radius: size / 2,
                            ),
                            const SizedBox(height: BirdySpace.xs),
                            BirdySkeleton.text(
                              BirdyText.caption,
                              placeholder: '00',
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            );
          },
        ),
        const SizedBox(height: BirdySpace.s),
        BirdySkeleton.text(BirdyText.caption, placeholder: l10n.forkStatusLadder),
      ],
    );
  }
}

/// Real body of [_StreakCard] (title, record, 14-day grid, notes), split out
/// so the loading state can share the exact same [BirdyBlock] shell.
class _StreakCardBody extends StatelessWidget {
  const _StreakCardBody({super.key, required this.streak});

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
    return Column(
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
        // Capped, like the status card's caption above: its skeleton must
        // reserve a fixed number of lines, not however many this sentence
        // happens to wrap to at the current text scale.
        Text(
          l10n.forkStreakRestNote,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: caption,
        ),
        const SizedBox(height: BirdySpace.xs),
        Text(
          l10n.forkStreakRule,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: caption,
        ),
      ],
    );
  }
}

/// Same shape as [_StreakCardBody]: title/record line, 14 skeleton dots,
/// two note lines.
class _StreakCardSkeletonBody extends StatelessWidget {
  const _StreakCardSkeletonBody({super.key});

  @override
  Widget build(BuildContext context) {
    final c = BirdyColors.of(context);
    final caption = BirdyText.caption.copyWith(color: c.text2);
    final weekday = DateFormat('EEEEE', Localizations.localeOf(context).toString());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: BirdySpace.m,
          children: [
            BirdySkeleton.text(
              BirdyText.heading.copyWith(color: c.text1),
              placeholder: '000000000',
            ),
            BirdySkeleton.text(caption, placeholder: '0000000000'),
          ],
        ),
        const SizedBox(height: BirdySpace.m),
        // The 14 dates and which one is today do not depend on the loaded
        // game facts (only the per-day state does): shown for real, right
        // from this skeleton, each `FittedBox` cell is pixel-identical to
        // its loaded self, only its dot's fill still a placeholder.
        Row(
          children: [
            for (final day in _skeletonCalendar())
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Column(
                    children: [
                      Text(weekday.format(day.date).toUpperCase(), style: caption),
                      const SizedBox(height: BirdySpace.xs),
                      _DayDotSkeleton(isToday: day.isToday),
                      const SizedBox(height: BirdySpace.xs),
                      Text('${day.date.day}', style: caption),
                    ],
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: BirdySpace.m),
        BirdySkeleton.text(
          caption,
          placeholder:
              '00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000',
          maxLines: 2,
        ),
        const SizedBox(height: BirdySpace.xs),
        BirdySkeleton.text(caption, placeholder: '0000000000000000000000000000'),
      ],
    );
  }
}

/// Same 4-column grid as [_Badges], filled with skeleton tiles at the same
/// tones, one per [BadgeKind] (8, so 2 rows).
class _BadgesSkeleton extends StatelessWidget {
  const _BadgesSkeleton({super.key});

  static const int _columns = 4;
  static const int _count = 8;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var start = 0; start < _count; start += _columns) {
      if (start > 0) rows.add(const SizedBox(height: BirdySpace.s));
      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = start; i < start + _columns; i++) ...[
                if (i > start) const SizedBox(width: BirdySpace.s),
                Expanded(
                  child: _badgeTileSkeleton(
                    context,
                    BadgeKind.values[i],
                    badgeTileTone(i),
                  ),
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

  // The badge's name doesn't depend on the loaded progress (only its tier
  // does): shown for real, right from this skeleton, so a name long enough
  // to wrap to its second line (« Chœur de l'aube », « 7 jours d'affilée »)
  // reserves that same second line instead of a one-line skeleton falling
  // short of it once the real tile takes over.
  Widget _badgeTileSkeleton(
    BuildContext context,
    BadgeKind kind,
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
      child: Column(
        children: [
          BirdySkeleton.box(width: 52, height: 52, radius: 26),
          const SizedBox(height: BirdySpace.xs),
          Text(
            badgeName(l10n, kind),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: BirdyText.labelCompact.copyWith(color: c.text1),
          ),
          const Spacer(),
          const SizedBox(height: BirdySpace.xs),
          BirdySkeleton.text(BirdyText.caption, placeholder: '000000'),
        ],
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
  const _Ladder({super.key, required this.verified});

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
            // Equal cells: one segment per gap, from one emblem's edge to
            // the next one's, so the line never runs behind an emblem
            // (it showed through the current status's ring gap otherwise).
            final cell = box.maxWidth / GameConfig.statuses.length;
            final size = (cell - 4).clamp(20.0, 40.0);
            final currentIndex =
                current == null ? -1 : GameConfig.statuses.indexOf(current);
            return Stack(
              clipBehavior: Clip.none,
              children: [
                for (var i = 0; i < GameConfig.statuses.length - 1; i++)
                  Positioned(
                    left: cell * i + cell / 2 + size / 2,
                    right:
                        box.maxWidth - (cell * (i + 1) + cell / 2 - size / 2),
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

/// The 14 calendar days shown while the game facts (streak included) are
/// still loading: dates and which one is today come from the clock alone,
/// not from the loaded data, so they can be exact from the first frame
/// (`computeStreak` with nothing listened yet gives the same calendar shape
/// `_StreakCardBody` will later show, just with every day unresolved).
List<StreakDay> _skeletonCalendar() =>
    computeStreak(const {}, DateTime.now()).calendar;

/// Same outer size as [_DayDot] (including its "today" ring), filled with a
/// skeleton placeholder instead of the day's real state.
class _DayDotSkeleton extends StatelessWidget {
  const _DayDotSkeleton({required this.isToday});

  final bool isToday;

  @override
  Widget build(BuildContext context) {
    const size = BirdySizes.dayDot;
    final dot = BirdySkeleton.box(width: size, height: size, radius: size / 2);
    if (!isToday) return dot;
    return Container(
      padding: const EdgeInsets.all(1.5),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.transparent, width: 1.5),
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
  const _Badges({super.key, required this.badges});

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
