/// Profil (J6f, Claude Design « AppProfil »): the « Mon niveau » card (ring,
/// interactive ladder of the 8 levels, info box), the « Série » card and the
/// « À gagner » card (plumes counter, weekly challenge, badges, quiz entry).
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
import '../design/widgets/birdy_skeleton.dart';
import '../design/widgets/birdy_cross_fade.dart';
import '../design/widgets/birdy_sheet.dart';
import '../design/widgets/dashed_border.dart';
import '../design/widgets/pressable.dart';
import '../design/widgets/species_card.dart' show twoLineTextHeight;
import '../game/streak_dots.dart';
import '../game/challenge_card.dart';
import '../game/challenges.dart';
import '../game/game_config.dart';
import '../game/game_loader.dart';
import '../game/game_progress.dart';
import '../game/game_text.dart';
import '../game/fine_ear_quiz_screen.dart';
import '../game/game_widgets.dart';
import '../game/quiz_entry_row.dart';
import '../game/streak.dart';
import '../settings/fork_prefs.dart';
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
    final firstName = ref.watch(firstNameProvider);
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
                // Announced once, while the game progress is still loading.
                Semantics(
                  key: const ValueKey('profile-header'),
                  liveRegion: true,
                  label: loading ? l10n.forkProfileLoading : null,
                  child: BirdyTabHeader(
                    title: l10n.forkProfileTitle,
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
                BirdyBlock(
                  key: const ValueKey('profile-level-card'),
                  tone: BirdyBlockTone.sure,
                  radius: BirdyRadii.hero,
                  padding: const EdgeInsets.all(BirdySpace.xl),
                  child: _crossFade(
                    loading
                        ? const _LevelCardSkeleton(key: ValueKey('level-skeleton'))
                        : _LevelCard(
                          key: const ValueKey('level-real'),
                          progress: progress,
                          firstName: firstName,
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
                  key: const ValueKey('profile-earn'),
                  tone: BirdyBlockTone.plain,
                  radius: BirdyRadii.hero,
                  padding: const EdgeInsets.all(BirdySpace.xl),
                  child: _crossFade(
                    loading
                        ? const _EarnCardSkeleton(key: ValueKey('earn-skeleton'))
                        : _EarnCard(
                          key: const ValueKey('earn-real'),
                          progress: progress,
                          onStartChallenge: () async {
                            await ref
                                .read(challengeStoreProvider)
                                .start(DateTime.now());
                            ref.invalidate(gameProgressProvider);
                          },
                        ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Fades [child] in in place (no move, no scale): a loaded value replacing
  /// its skeleton. [child]'s own key tells the switcher when to cross-fade.
  static Widget _crossFade(Widget child) => BirdyCrossFade(child: child);
}

// ---------------------------------------------------------------------------
// « Mon niveau » card
// ---------------------------------------------------------------------------

/// Same overall shape as [_LevelCard] (ring row, ladder, info box, hint), so
/// the card never resizes once the game progress lands.
class _LevelCardSkeleton extends StatelessWidget {
  const _LevelCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
    final nameStyle = BirdyText.title.copyWith(color: c.text1);
    final bodyStyle = BirdyText.body.copyWith(color: c.text1);
    final captionStyle = BirdyText.caption.copyWith(color: c.text2);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            BirdySkeleton.box(width: 96, height: 96, radius: 48),
            const SizedBox(width: BirdySpace.l),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  BirdySkeleton.text(captionStyle, placeholder: '00000000000000'),
                  const SizedBox(height: BirdySpace.xs),
                  BirdySkeleton.text(bodyStyle, placeholder: '00000000000000000'),
                  const SizedBox(height: BirdySpace.xs),
                  SizedBox(
                    height: twoLineTextHeight(context, nameStyle),
                    child: Align(
                      alignment: AlignmentDirectional.topStart,
                      child: BirdySkeleton.text(
                        nameStyle,
                        placeholder: '000000000000000000000',
                        maxLines: 2,
                      ),
                    ),
                  ),
                  const SizedBox(height: BirdySpace.xs),
                  BirdySkeleton.text(bodyStyle, placeholder: '00000000000000000'),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: BirdySpace.l),
        for (var row = 0; row < 2; row++) ...[
          if (row > 0) const SizedBox(height: BirdySpace.xs),
          Row(
            children: [
              for (var i = 0; i < 4; i++) ...[
                if (i > 0) const SizedBox(width: BirdySpace.xs),
                Expanded(
                  child: Column(
                    children: [
                      BirdySkeleton.box(
                        width: BirdySizes.levelEmblem,
                        height: BirdySizes.levelEmblem,
                        radius: BirdySizes.levelEmblem / 2,
                      ),
                      const SizedBox(height: BirdySpace.xs),
                      BirdySkeleton.text(BirdyText.caption, placeholder: '000'),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ],
        const SizedBox(height: BirdySpace.l),
        // Same shape as `_LevelInfoBox` in its default (next-level) state:
        // icon, caption, name, segmented-bar placeholder, detail line.
        DecoratedBox(
          decoration: BoxDecoration(
            color: c.surface1,
            borderRadius: BorderRadius.circular(BirdyRadii.card),
          ),
          child: Padding(
            padding: const EdgeInsets.all(BirdySpace.l),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BirdySkeleton.box(
                  width: BirdySizes.levelInfoIcon,
                  height: BirdySizes.levelInfoIcon,
                  radius: BirdySizes.levelInfoIcon / 2,
                ),
                const SizedBox(width: BirdySpace.m),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      BirdySkeleton.text(captionStyle, placeholder: '00000000000000'),
                      SizedBox(
                        height: twoLineTextHeight(
                          context,
                          BirdyText.heading.copyWith(color: c.text1),
                        ),
                        child: Align(
                          alignment: AlignmentDirectional.topStart,
                          child: BirdySkeleton.text(
                            BirdyText.heading.copyWith(color: c.text1),
                            placeholder: '000000000000000',
                            maxLines: 2,
                          ),
                        ),
                      ),
                      const SizedBox(height: BirdySpace.xs),
                      BirdySkeleton.box(
                        width: double.infinity,
                        height: BirdySizes.segmentHeight,
                        radius: BirdyRadii.pill,
                      ),
                      const SizedBox(height: BirdySpace.xs),
                      BirdySkeleton.text(bodyStyle, placeholder: '000000000000000'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: BirdySpace.s),
        BirdySkeleton.text(captionStyle, placeholder: l10n.forkLevelHint),
      ],
    );
  }
}

/// « Mon niveau »: ring, interactive ladder of the 8 levels and its info
/// box. Tapping an emblem picks it (tapping it again clears the pick); with
/// nothing picked, the info box shows the next level (or, at the top, a
/// short message).
class _LevelCard extends StatefulWidget {
  const _LevelCard({super.key, required this.progress, this.firstName});

  final GameProgress progress;
  final String? firstName;

  @override
  State<_LevelCard> createState() => _LevelCardState();
}

class _LevelCardState extends State<_LevelCard> {
  int? _picked;

  void _togglePick(int index) =>
      setState(() => _picked = _picked == index ? null : index);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
    final progress = widget.progress;
    final firstName = widget.firstName?.trim();
    final status = progress.status;
    final statuses = GameConfig.statuses;
    final currentIndex = status == null ? -1 : statuses.indexOf(status);
    final percent = (progress.progress * 100).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
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
                  if (status != null) ...[
                    Text(
                      l10n.forkLevelRankCaption(currentIndex + 1, statuses.length),
                      style: BirdyText.caption.copyWith(
                        color: c.sure.foreground,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: BirdySpace.xs),
                    Text(
                      (firstName == null || firstName.isEmpty)
                          ? l10n.forkLevelCongrats
                          : l10n.forkLevelCongratsNamed(firstName),
                      style: BirdyText.body.copyWith(
                        color: c.text1,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                  const SizedBox(height: BirdySpace.xs),
                  SizedBox(
                    height: twoLineTextHeight(
                      context,
                      BirdyText.title.copyWith(color: c.text1),
                    ),
                    child: Align(
                      alignment: AlignmentDirectional.topStart,
                      child: Text(
                        status == null
                            ? l10n.forkStatusNone
                            : statusName(l10n, status),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: BirdyText.title.copyWith(color: c.text1),
                      ),
                    ),
                  ),
                  const SizedBox(height: BirdySpace.xs),
                  Text(
                    status == null
                        ? statusLine(l10n, null)
                        : l10n.forkNotebookDiscovered(progress.verified),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: BirdyText.body.copyWith(color: c.text1),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: BirdySpace.l),
        _Ladder(
          currentIndex: currentIndex,
          picked: _picked,
          onPick: _togglePick,
        ),
        const SizedBox(height: BirdySpace.l),
        _LevelInfoBox(progress: progress, picked: _picked),
        const SizedBox(height: BirdySpace.s),
        Text(
          l10n.forkLevelHint,
          style: BirdyText.caption.copyWith(color: c.sure.foreground),
        ),
      ],
    );
  }
}

/// The 8 levels, 2 rows of 4. Each row's connecting line is colored (thick,
/// [BirdyColors.sure]'s foreground) only when every level in that row is
/// reached; otherwise it stays a plain thin [BirdyColors.border] line.
class _Ladder extends StatelessWidget {
  const _Ladder({
    required this.currentIndex,
    required this.picked,
    required this.onPick,
  });

  final int currentIndex;
  final int? picked;
  final ValueChanged<int> onPick;

  static const int _perRow = 4;

  @override
  Widget build(BuildContext context) {
    final c = BirdyColors.of(context);
    final statuses = GameConfig.statuses;
    final rows = <Widget>[];
    for (var start = 0; start < statuses.length; start += _perRow) {
      if (rows.isNotEmpty) rows.add(const SizedBox(height: BirdySpace.xs));
      final count = (statuses.length - start).clamp(0, _perRow);
      final rowReached = start + count - 1 <= currentIndex;
      rows.add(
        _LadderRow(
          startIndex: start,
          count: count,
          lineColor: rowReached ? c.sure.foreground : c.border,
          lineWidth:
              rowReached ? BirdySizes.levelLineThick : BirdySizes.levelLineThin,
          currentIndex: currentIndex,
          picked: picked,
          onPick: onPick,
        ),
      );
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: rows);
  }
}

class _LadderRow extends StatelessWidget {
  const _LadderRow({
    required this.startIndex,
    required this.count,
    required this.lineColor,
    required this.lineWidth,
    required this.currentIndex,
    required this.picked,
    required this.onPick,
  });

  final int startIndex;
  final int count;
  final Color lineColor;
  final double lineWidth;
  final int currentIndex;
  final int? picked;
  final ValueChanged<int> onPick;

  @override
  Widget build(BuildContext context) {
    const emblem = BirdySizes.levelEmblem;
    return LayoutBuilder(
      builder: (context, box) {
        final cell = box.maxWidth / count;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            // J6h: one stroke between each pair of emblems, cell width minus
            // the emblems' half widths, centered on the emblem (cell padding
            // included) so it never crosses the current emblem's ring.
            for (var j = 0; j < count - 1; j++)
              Positioned(
                key: ValueKey('ladder-stroke-$j'),
                left: cell * j + cell / 2 + BirdySizes.levelLineInset / 2,
                width: cell - BirdySizes.levelLineInset,
                top:
                    BirdySizes.levelCellPadTop +
                    emblem / 2 -
                    lineWidth / 2,
                height: lineWidth,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: lineColor,
                    borderRadius: BorderRadius.circular(lineWidth / 2),
                  ),
                ),
              ),
            Row(
              children: [
                for (var j = 0; j < count; j++)
                  Expanded(
                    child: _LadderCell(
                      index: startIndex + j,
                      currentIndex: currentIndex,
                      picked: picked,
                      onPick: onPick,
                    ),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _LadderCell extends StatelessWidget {
  const _LadderCell({
    required this.index,
    required this.currentIndex,
    required this.picked,
    required this.onPick,
  });

  final int index;
  final int currentIndex;
  final int? picked;
  final ValueChanged<int> onPick;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
    final status = GameConfig.statuses[index];
    final reached = index <= currentIndex;
    final isCurrent = index == currentIndex;
    final selected = picked == index;

    var label = l10n.forkLevelEmblemLabel(
      status.rank,
      statusName(l10n, status),
      status.from,
    );
    if (isCurrent) {
      label += l10n.forkLevelEmblemSuffixCurrent;
    } else if (reached) {
      label += l10n.forkLevelEmblemSuffixReached;
    }

    return Pressable(
      child: Semantics(
        label: label,
        button: true,
        selected: selected,
        excludeSemantics: true,
        child: Material(
          color: selected ? c.surface1 : Colors.transparent,
          borderRadius: BorderRadius.circular(BirdyRadii.inset),
          child: InkWell(
            borderRadius: BorderRadius.circular(BirdyRadii.inset),
            onTap: () => onPick(index),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: BirdySizes.levelCellMinHeight,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: BirdySizes.levelCellPadTop,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        StatusEmblem(
                          status: status,
                          size: BirdySizes.levelEmblem,
                          reached: reached,
                          current: isCurrent,
                          innerRing: reached,
                        ),
                        if (isCurrent)
                          Positioned(
                            top: -3,
                            right: -3,
                            child: Container(
                              width: BirdySizes.levelCheckBadge,
                              height: BirdySizes.levelCheckBadge,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: BirdyBrand.checkGreen,
                                border: Border.all(
                                  color: c.sure.background,
                                  width: 2,
                                ),
                              ),
                              child: const Icon(
                                AppIcons.check,
                                size: 12,
                                color: Colors.white,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: BirdySpace.xs),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        '${status.from}',
                        style: BirdyText.caption.copyWith(
                          color: isCurrent ? c.text1 : c.sure.foreground,
                          fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w400,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Below the ladder: the picked level, or (nothing picked) the next one to
/// reach with its segmented bar, or (nothing picked, top level) a short
/// message. A live region: it changes on every tap.
class _LevelInfoBox extends StatelessWidget {
  const _LevelInfoBox({required this.progress, required this.picked});

  final GameProgress progress;
  final int? picked;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
    final statuses = GameConfig.statuses;
    final current = progress.status;
    final next = progress.next;
    final currentIndex = current == null ? -1 : statuses.indexOf(current);
    final nextIndex = next == null ? -1 : currentIndex + 1;
    final showIndex = picked ?? (next != null ? nextIndex : currentIndex);
    final status = statuses[showIndex];
    final reached = showIndex <= currentIndex;
    final isNext = next != null && showIndex == nextIndex;
    final isTopDefault = picked == null && next == null;

    final String caption;
    if (isNext) {
      caption = l10n.forkStatusNextTitle;
    } else if (showIndex == currentIndex) {
      caption = l10n.forkLevelYours;
    } else if (reached) {
      caption = l10n.forkLevelPickedReached(status.rank);
    } else {
      caption = l10n.forkLevelPicked(status.rank);
    }

    Widget? segments;
    String? detail;
    String? line;
    String? topMessage;

    if (isTopDefault) {
      topMessage = l10n.forkStatusTop;
    } else if (isNext) {
      final from = current?.from ?? 0;
      final to = status.from;
      final total = to - from;
      final filled = (progress.verified - from).clamp(0, total);
      segments = Semantics(
        label: l10n.forkLevelSegmentsLabel(filled, total),
        excludeSemantics: true,
        child: SegmentedBar(
          count: total,
          filled: filled,
          color: c.accentText,
          track: c.line,
        ),
      );
      detail = l10n.forkLevelRemainingCount(status.from - progress.verified);
    } else {
      detail =
          reached
              ? l10n.forkLevelFrom(status.from)
              : l10n.forkLevelRemainingCount(status.from - progress.verified);
      line = statusLine(l10n, status);
    }

    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(BirdySpace.l),
        decoration: BoxDecoration(
          color: c.surface1,
          borderRadius: BorderRadius.circular(BirdyRadii.card),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            StatusEmblem(
              status: status,
              size: BirdySizes.levelInfoIcon,
              reached: reached,
              innerRing: reached,
            ),
            const SizedBox(width: BirdySpace.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(caption, style: BirdyText.caption.copyWith(color: c.text2)),
                  Text(
                    statusName(l10n, status),
                    style: BirdyText.heading.copyWith(color: c.text1),
                  ),
                  if (segments != null) ...[
                    const SizedBox(height: BirdySpace.xs),
                    segments,
                  ],
                  if (detail != null) ...[
                    const SizedBox(height: BirdySpace.xs),
                    Text(
                      detail,
                      style: BirdyText.body.copyWith(
                        color: c.text1,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                  if (line != null) ...[
                    const SizedBox(height: BirdySpace.xs),
                    Text(line, style: BirdyText.body.copyWith(color: c.text1)),
                  ],
                  if (topMessage != null) ...[
                    const SizedBox(height: BirdySpace.xs),
                    Text(
                      topMessage,
                      style: BirdyText.body.copyWith(
                        color: c.text1,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// « Série » card
// ---------------------------------------------------------------------------

/// Real body of [_StreakCard] (title, record, the last 7 days), split out
/// so the loading state can share the exact same [BirdyBlock] shell. The
/// 7-day dot strip is [StreakDots] (J6f), shared with the home série block
/// so both show the exact same look.
class _StreakCardBody extends StatelessWidget {
  const _StreakCardBody({super.key, required this.streak});

  final Streak streak;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
    final localeName = Localizations.localeOf(context).toString();
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
        StreakDots(
          days: lastSevenDays(streak),
          localeName: localeName,
          dayLabel:
              (day) =>
                  '${dateLabel.format(day.date)}, ${day.state == StreakDayState.listened ? l10n.forkStreakDayListened : l10n.forkStreakDayMissed}',
        ),
        const SizedBox(height: BirdySpace.m),
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

/// Same shape as [_StreakCardBody]: title/record line, the 7 skeleton
/// dots, one note line.
class _StreakCardSkeletonBody extends StatelessWidget {
  const _StreakCardSkeletonBody({super.key});

  @override
  Widget build(BuildContext context) {
    final c = BirdyColors.of(context);
    final caption = BirdyText.caption.copyWith(color: c.text2);
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
        // The 7 dates and which one is today do not depend on the loaded
        // game facts (only which ones were listened to does): shown for
        // real, right from this skeleton, each cell is pixel-identical to
        // its loaded self, only its dot's fill still a placeholder.
        StreakDotsSkeleton(
          days: _skeletonWeek(),
          localeName: Localizations.localeOf(context).toString(),
        ),
        const SizedBox(height: BirdySpace.m),
        BirdySkeleton.text(
          caption,
          placeholder: '0000000000000000000000000000',
        ),
      ],
    );
  }
}

/// The last 7 days shown while the streak facts are still loading: dates
/// and which one is today come from the clock alone, not from the loaded
/// data, so they can be exact from the first frame ([computeStreak] with
/// nothing listened yet gives the same 7-day window [_StreakCardBody] will
/// later show, just with every day unresolved).
List<StreakDay> _skeletonWeek() =>
    lastSevenDays(computeStreak(const {}, DateTime.now()));

// ---------------------------------------------------------------------------
// « À gagner » card
// ---------------------------------------------------------------------------

/// Same shape as [_EarnCard]: title row, an inset placeholder for the
/// weekly challenge, the badges title and a 3-column grid, then the quiz
/// entry row. The quiz row does not depend on the loaded progress, so it is
/// shown for real from this skeleton too.
class _EarnCardSkeleton extends StatelessWidget {
  const _EarnCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.forkProfileEarnTitle,
                style: BirdyText.title.copyWith(color: c.text1),
              ),
            ),
            BirdySkeleton.box(width: 64, height: 36, radius: BirdyRadii.pill),
          ],
        ),
        const SizedBox(height: BirdySpace.m),
        BirdySkeleton.box(
          width: double.infinity,
          height: 118,
          radius: BirdyRadii.card,
        ),
        const SizedBox(height: BirdySpace.l),
        Text(l10n.forkBadges, style: BirdyText.heading.copyWith(color: c.text1)),
        const SizedBox(height: BirdySpace.m),
        _BadgesSkeleton(),
        const SizedBox(height: BirdySpace.m),
        const QuizEntryRow(bordered: true),
      ],
    );
  }
}

class _BadgesSkeleton extends StatelessWidget {
  const _BadgesSkeleton();

  static const int _columns = 3;
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
                  child:
                      i < _count
                          ? _tileSkeleton(context)
                          : const SizedBox.shrink(),
                ),
              ],
            ],
          ),
        ),
      );
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: rows);
  }

  Widget _tileSkeleton(BuildContext context) {
    final c = BirdyColors.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: BirdySizes.badgeTile),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: c.surface1,
          borderRadius: BorderRadius.circular(BirdyRadii.inset),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: BirdySpace.m,
            vertical: 6,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              BirdySkeleton.box(width: 56, height: 56, radius: 28),
              const SizedBox(height: BirdySpace.xs),
              BirdySkeleton.text(BirdyText.labelCompact, placeholder: '0000000'),
            ],
          ),
        ),
      ),
    );
  }
}

class _EarnCard extends StatelessWidget {
  const _EarnCard({super.key, required this.progress, required this.onStartChallenge});

  final GameProgress progress;
  final VoidCallback onStartChallenge;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
    final challenge = progress.facts.challenge;
    final totalPlumes = progress.badges.fold<int>(0, (sum, b) => sum + b.tier);
    final earned = progress.badges.where((b) => b.tier > 0).toList();
    final locked = progress.badges.where((b) => b.tier == 0).toList();
    final sortedBadges = [...earned, ...locked];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Semantics(
                header: true,
                child: Text(
                  l10n.forkProfileEarnTitle,
                  style: BirdyText.title.copyWith(color: c.text1),
                ),
              ),
            ),
            const SizedBox(width: BirdySpace.m),
            _PlumesPill(total: totalPlumes),
          ],
        ),
        if (challenge != null) ...[
          const SizedBox(height: BirdySpace.m),
          ChallengeCard(
            challenge: challenge,
            onStart: onStartChallenge,
            background: c.tonal,
            captionColor: c.accentText,
          ),
        ],
        const SizedBox(height: BirdySpace.l),
        Semantics(
          header: true,
          child: Text(l10n.forkBadges, style: BirdyText.heading.copyWith(color: c.text1)),
        ),
        const SizedBox(height: BirdySpace.m),
        _Badges(badges: sortedBadges),
        const SizedBox(height: BirdySpace.m),
        const QuizEntryRow(bordered: true),
      ],
    );
  }
}

/// The plumes counter pill: the feather glyph of level 2 (« Jeune plume »,
/// the feather emblem in [GameConfig]) and the total plumes across badges.
class _PlumesPill extends StatelessWidget {
  const _PlumesPill({required this.total});

  final int total;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
    return Semantics(
      label: l10n.forkPlumesEarned(total),
      excludeSemantics: true,
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: c.orioleContainer,
          borderRadius: BorderRadius.circular(BirdyRadii.pill),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            GlyphIcon(
              glyph: GameConfig.statuses[1].glyph,
              color: c.orioleText,
              size: 20,
            ),
            const SizedBox(width: 6),
            Text(
              '$total',
              style: BirdyText.labelCompact.copyWith(
                color: c.orioleText,
                fontWeight: FontWeight.w800,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Badges grid, 3 columns, earned badges first: earned tiles take their
/// medal's own pale tone, locked ones stay white with a dashed outline.
class _Badges extends StatelessWidget {
  const _Badges({required this.badges});

  final List<BadgeProgress> badges;

  static const int _columns = 3;

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
                          ? _badgeTile(context, badges[i])
                          : const SizedBox.shrink(),
                ),
              ],
            ],
          ),
        ),
      );
    }
    return Column(
      key: const ValueKey('profile-badges-grid'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: rows,
    );
  }

  Widget _badgeTile(BuildContext context, BadgeProgress badge) {
    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
    final earned = badge.tier > 0;
    final metal = earned ? GameConfig.badgeMedals[badge.tier - 1] : null;
    // The mockup's pale medal tone (bronze/silver/gold) is a light-theme
    // wash: on dark it fails AA for `text1` (near-white). The dark theme
    // keeps the same idea with a faint metal tint over its own surface
    // instead, the same trick as `BirdyColors.tonal` on dark.
    final tileColor =
        !earned
            ? c.surface1
            : c.isDark
            ? Color.alphaBlend(metal!.base.withValues(alpha: 0.22), c.surface1)
            : metal!.tone;

    Widget card = Material(
      color: tileColor,
      borderRadius: BorderRadius.circular(BirdyRadii.inset),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _showBadge(context, badge),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: BirdySizes.badgeTile),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: BirdySpace.m,
              vertical: 6,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Opacity(
                  opacity: earned ? 1 : 0.6,
                  child: BadgeMedal(
                    tier: badge.tier,
                    icon: badgeIcon(badge.kind),
                    glyph: badgeGlyph(badge.kind),
                    size: 56,
                  ),
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
                if (earned)
                  TierDots(filled: badge.tier)
                else ...[
                  FractionallySizedBox(
                    widthFactor: 0.72,
                    child: BirdyProgressBar(
                      value: badge.value / badge.nextTarget!,
                      color: c.accentText,
                      track: c.line,
                    ),
                  ),
                  const SizedBox(height: BirdySpace.xs),
                  Text(
                    l10n.forkBadgeProgress(badge.value, badge.nextTarget!),
                    textAlign: TextAlign.center,
                    style: BirdyText.caption.copyWith(color: c.text2),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
    if (!earned) {
      card = CustomPaint(
        foregroundPainter: DashedBorderPainter(
          color: c.dashed,
          radius: BirdyRadii.inset,
        ),
        child: card,
      );
    }
    return Pressable(
      child: Semantics(
        label:
            '${badgeName(l10n, badge.kind)}, ${l10n.forkBadgeTier(badge.tier)}',
        button: true,
        excludeSemantics: true,
        child: card,
      ),
    );
  }

  void _showBadge(BuildContext context, BadgeProgress badge) {
    final l10n = AppLocalizations.of(context)!;
    showBirdySheet<void>(
      context: context,
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
