/// Blocks of the home screen (J6f, « App finale » boards, AppAccueil): top
/// row, last bird hero, goal / série / to-check grid, status, today's
/// species, menu. Blocks stand out by their fill, never by a grey border.
library;

import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/utils/app_icons.dart';
import '../design/birdy_tokens.dart';
import '../design/birdy_typography.dart';
import '../design/species_accents.dart';
import '../design/species_tint.dart';
import '../design/widgets/birdy_block.dart';
import '../design/widgets/birdy_sheet.dart';
import '../design/widgets/birdy_skeleton.dart';
import '../design/widgets/birdygo_wordmark.dart';
import '../design/widgets/pressable.dart';
import '../design/widgets/species_avatar.dart';
import '../game/game_config.dart';
import '../game/game_progress.dart';
import '../game/game_text.dart';
import '../game/game_widgets.dart';
import '../game/streak.dart';
import '../game/streak_dots.dart';
import '../reliability/reliability_badge.dart';
import '../reliability/reliability_config.dart';
import 'home_model.dart';
import 'logo_tweet.dart';
import 'singing_logo.dart';

/// Singing mark and name, small, alone above the header (Accueil only; the
/// menu button now sits in [BirdyTabHeader]'s action row).
class HomeLogoRow extends ConsumerWidget {
  const HomeLogoRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = BirdyColors.of(context);
    return SingingLogo(
      // A tap sings the phrase and plays the BirdyGo tweet.
      onTap: () => playLogoTweet(ref),
      // The startup screen's wordmark, header size.
      wordmark: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: AlignmentDirectional.centerStart,
        child: BirdyGoWordmark(size: _wordmarkSize, color: c.text1),
      ),
    );
  }
}

/// Wordmark size in the home logo row: the startup letters, a little above
/// the board's 20 px name so the Oriole dot stays readable.
const double _wordmarkSize = 24;

/// Icon color on a species [accent] fill: Encre de nuit when it keeps 3:1
/// (non-text contrast), else Brume.
Color inkOnAccent(Color accent) =>
    contrastRatio(BirdyBrand.ink, accent) >= _iconContrast
        ? BirdyBrand.ink
        : BirdyBrand.mist;

/// WCAG 1.4.11 minimum for an icon.
const double _iconContrast = 3;

/// Offsets of the hero's decorative disc and bird from the top end corner
/// (the disc overflows and is clipped by the block's corner).
const double _heroDiscEnd = -28;
const double _heroDiscTop = -18;
const double _heroBirdEnd = 6;
const double _heroBirdTop = 8;

/// « Dernier oiseau entendu · 07:52 », on the species tint.
class HomeHero extends StatelessWidget {
  const HomeHero({
    super.key,
    required this.last,
    required this.name,
    required this.when,
    this.image,
    this.onTap,
    this.onReplay,
  });

  final LastBird last;

  /// Localized common name.
  final String name;

  /// « 07:52 », « hier, 07:52 ».
  final String when;
  final ImageProvider? image;

  /// Opens the species page.
  final VoidCallback? onTap;

  /// Plays the clip; the button is hidden without it.
  final VoidCallback? onReplay;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
    final tint = SpeciesAccents.tintOf(last.scientificName);
    final content = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: BirdySizes.heroMinHeight),
      child: Padding(
        padding: const EdgeInsets.all(BirdySpace.l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Padding(
              // Keeps the name clear of the bird.
              padding: const EdgeInsetsDirectional.only(
                end: BirdySizes.heroBird - BirdySpace.xl,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.forkHomeLastBirdAt(when),
                    style: BirdyText.caption.copyWith(color: c.text2),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: BirdySpace.block),
                  // Fixed line counts, shared with [HomeHeroSkeleton], so
                  // the hero never changes height when the data lands.
                  SizedBox(
                    height: heroNameHeight(context),
                    child: Text(
                      name,
                      style: BirdyText.title.copyWith(color: c.text1),
                      maxLines: heroNameLines,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    last.scientificName,
                    style: BirdyText.latinCompact.copyWith(color: c.text2),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(height: BirdySpace.block),
            Wrap(
              spacing: BirdySpace.s,
              runSpacing: BirdySpace.s,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (onReplay != null)
                  _ReplayButton(accent: tint.accent, onPressed: onReplay!),
                ReliabilityBadge(
                  level: last.level,
                  unexpected: last.unexpected,
                  score: last.detection.confidence,
                ),
                Text(
                  l10n.forkLiveTotal(last.total),
                  style: BirdyText.caption.copyWith(
                    color: c.text1,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    return Pressable(
      enabled: onTap != null,
      child: Material(
        color: tint.cardBackground(c.brightness),
        borderRadius: BorderRadius.circular(BirdyRadii.hero),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Stack(
            children: [
              PositionedDirectional(
                end: _heroDiscEnd,
                top: _heroDiscTop,
                child: Container(
                  width: BirdySizes.heroDisc,
                  height: BirdySizes.heroDisc,
                  decoration: BoxDecoration(
                    color: tint.accent.withValues(alpha: BirdyAlpha.heroDisc),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              PositionedDirectional(
                end: _heroBirdEnd,
                top: _heroBirdTop,
                child: SpeciesAvatar(
                  image: image,
                  tint: tint,
                  size: BirdySizes.heroBird,
                ),
              ),
              content,
            ],
          ),
        ),
      ),
    );
  }
}

/// Lines kept for the hero's species name: two-word names wrap at 130 %.
const int heroNameLines = 2;

/// Height of [heroNameLines] lines of the hero name at the current text
/// scale: the name always takes it, so the hero height does not depend on
/// the name's length.
double heroNameHeight(BuildContext context) {
  final painter = TextPainter(
    text: TextSpan(
      text: List.filled(heroNameLines, 'A').join('\n'),
      style: BirdyText.title,
    ),
    textScaler: MediaQuery.textScalerOf(context),
    textDirection: Directionality.of(context),
  )..layout();
  final height = painter.height;
  painter.dispose();
  return height;
}

/// Loading placeholder of [HomeHero], same [BirdySizes.heroMinHeight]
/// minimum and padding. The common case for a returning user is a last
/// bird already on record, so the skeleton fills that shape; a fresh
/// install with no last bird ever collapses the block instead once loaded,
/// which is the one case allowed to change the layout (J6f skeletons).
class HomeHeroSkeleton extends StatelessWidget {
  const HomeHeroSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
    return ExcludeSemantics(
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: BirdySizes.heroMinHeight),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: c.surface1,
            borderRadius: BorderRadius.circular(BirdyRadii.hero),
          ),
          child: Padding(
            padding: const EdgeInsets.all(BirdySpace.l),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Padding(
                  padding: const EdgeInsetsDirectional.only(
                    end: BirdySizes.heroBird - BirdySpace.xl,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Same fixed line counts as [HomeHero].
                      BirdySkeleton.text(
                        BirdyText.caption,
                        placeholder: l10n.forkHomeLastBirdAt('07:52'),
                        maxLines: 1,
                      ),
                      const SizedBox(height: BirdySpace.block),
                      SizedBox(
                        height: heroNameHeight(context),
                        child: Align(
                          alignment: AlignmentDirectional.topStart,
                          child: BirdySkeleton.text(
                            BirdyText.title,
                            placeholder: 'Rougegorge familier',
                            maxLines: 1,
                          ),
                        ),
                      ),
                      BirdySkeleton.text(
                        BirdyText.latinCompact,
                        placeholder: 'Erithacus rubecula',
                        maxLines: 1,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: BirdySpace.block),
                // Same Wrap config as [HomeHero]'s bottom row: the badge
                // and the total text are real widget-shaped (not plain
                // boxes), since their width — and so whether this row
                // wraps to one or two lines — grows with the text scale
                // exactly like the real ones do.
                Wrap(
                  spacing: BirdySpace.s,
                  runSpacing: BirdySpace.s,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    BirdySkeleton.box(
                      width: BirdySizes.target,
                      height: BirdySizes.target,
                      radius: BirdyRadii.pill,
                    ),
                    const _ReliabilityBadgeSkeleton(),
                    BirdySkeleton.text(
                      BirdyText.caption,
                      placeholder: l10n.forkLiveTotal(142),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Loading placeholder of [ReliabilityBadge] (its non-compact [BirdyPill]
/// shape): same padding, glyph size and [BirdySizes.pill] minimum height,
/// built from [BirdyText.badge] so its width grows with the text scale
/// like the real pill's label does.
class _ReliabilityBadgeSkeleton extends StatelessWidget {
  const _ReliabilityBadgeSkeleton();

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(minHeight: BirdySizes.pill),
    child: Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(7, 4, 10, 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          BirdySkeleton.box(width: 12, height: 12, radius: BirdyRadii.thumb),
          const SizedBox(width: 5),
          // « Sûr », the shortest level label: a longer one only grows
          // this pill a little once real, never shrinks it.
          BirdySkeleton.text(BirdyText.badge, placeholder: 'Sûr'),
        ],
      ),
    ),
  );
}

/// Round « Réécouter » button on the species accent.
class _ReplayButton extends StatelessWidget {
  const _ReplayButton({required this.accent, required this.onPressed});

  final Color accent;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Semantics(
      container: true,
      button: true,
      label: l10n.forkReplay,
      excludeSemantics: true,
      child: Material(
        key: const ValueKey('home-replay'),
        color: accent,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: SizedBox.square(
            dimension: BirdySizes.target,
            child: Icon(AppIcons.playArrowRounded, color: inkOnAccent(accent)),
          ),
        ),
      ),
    );
  }
}

/// The goal on the left, spanning both rows; série and to-check blocks on
/// the right. Missing right blocks give the goal the full width.
class HomeGrid extends StatelessWidget {
  const HomeGrid({super.key, required this.goal, this.streak, this.toCheck});

  final Widget goal;
  final Widget? streak;
  final Widget? toCheck;

  @override
  Widget build(BuildContext context) {
    final right = [
      if (streak case final streak?) streak,
      if (toCheck case final toCheck?) toCheck,
    ];
    if (right.isEmpty) return goal;
    // Intrinsic height: no LayoutBuilder may sit inside these blocks.
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: goal),
          const SizedBox(width: BirdySpace.block),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (i, block) in right.indexed) ...[
                  if (i > 0) const SizedBox(height: BirdySpace.block),
                  Expanded(child: block),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// « 9 jours de suite » and this week's day dots, on Loriot. The 7 dots
/// are [StreakDots] (J6f-b), shared with the Profil série block so both
/// show the exact same look.
class StreakBlock extends StatelessWidget {
  const StreakBlock({super.key, required this.streak, this.onTap});

  final Streak streak;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
    final week = lastSevenDays(streak);
    final listened =
        week.where((d) => d.state == StreakDayState.listened).length;
    final days = l10n.forkHomeStreakDays(streak.current);
    return BirdyBlock(
      key: const ValueKey('home-streak'),
      tone: BirdyBlockTone.oriole,
      onTap: onTap,
      semanticLabel:
          '${streak.current} $days. ${l10n.forkHomeStreakWeek(listened)}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: BirdySpace.s,
            crossAxisAlignment: WrapCrossAlignment.end,
            children: [
              Text(
                '${streak.current}',
                style: BirdyText.numberXL.copyWith(color: c.text1),
              ),
              Text(
                days,
                style: BirdyText.caption.copyWith(
                  color: c.orioleText,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: BirdySpace.s),
          StreakDots(days: week, localeName: l10n.localeName),
        ],
      ),
    );
  }
}

/// Loading placeholder of [StreakBlock], same shape (number row, then the
/// 7 day dots): the common case for a returning user is an active série,
/// so the skeleton fills that shape; a fresh série (0 days) collapses the
/// block once loaded instead, which is the one case allowed to change the
/// layout (J6f skeletons).
class StreakBlockSkeleton extends StatelessWidget {
  const StreakBlockSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final numberStyle = BirdyText.numberXL;
    return ExcludeSemantics(
      child: BirdyBlock(
        tone: BirdyBlockTone.tonal,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: BirdySpace.s,
              crossAxisAlignment: WrapCrossAlignment.end,
              children: [
                BirdySkeleton.text(numberStyle, placeholder: '00'),
                BirdySkeleton.text(
                  BirdyText.caption,
                  placeholder: '0000000000',
                ),
              ],
            ),
            const SizedBox(height: BirdySpace.s),
            StreakDotsSkeleton(
              days: _skeletonWeek(),
              localeName: Localizations.localeOf(context).toString(),
            ),
          ],
        ),
      ),
    );
  }
}

/// The last 7 days shown while the streak facts are still loading: dates
/// and which one is today come from the clock alone, not from the loaded
/// data, so they can be exact from the first frame ([computeStreak] with
/// nothing listened yet gives the same 7-day window [StreakBlock] will
/// later show, just with every day unresolved).
List<StreakDay> _skeletonWeek() =>
    lastSevenDays(computeStreak(const {}, DateTime.now()));

/// « 12 à vérifier · 2 min de revue », white with the dashed outline.
class ToCheckBlock extends StatelessWidget {
  const ToCheckBlock({super.key, required this.count, this.onTap});

  final int count;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
    final time = l10n.forkHomeReviewTime(reviewMinutes(count));
    return BirdyBlock(
      key: const ValueKey('home-to-check'),
      tone: BirdyBlockTone.toCheck,
      onTap: onTap,
      semanticLabel: '${l10n.forkHomeToVerify(count)}, $time',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    '$count',
                    style: BirdyText.numberXL.copyWith(
                      color: c.toCheck.foreground,
                    ),
                  ),
                ),
              ),
              Icon(
                AppIcons.question,
                size: BirdySizes.blockIcon,
                color: c.toCheck.foreground,
              ),
            ],
          ),
          Text(
            l10n.forkHomeToCheckLabel,
            style: BirdyText.caption.copyWith(
              color: c.text1,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(time, style: BirdyText.caption.copyWith(color: c.text2)),
        ],
      ),
    );
  }
}

/// Loading placeholder of [ToCheckBlock], same shape (number + icon row,
/// label, review time): the common case for a returning user is
/// detections waiting for review, so the skeleton fills that shape; 0 to
/// check collapses the block once loaded instead, which is the one case
/// allowed to change the layout (J6f skeletons).
class ToCheckBlockSkeleton extends StatelessWidget {
  const ToCheckBlockSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final numberStyle = BirdyText.numberXL;
    return ExcludeSemantics(
      child: BirdyBlock(
        tone: BirdyBlockTone.tonal,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: AlignmentDirectional.centerStart,
                    child: BirdySkeleton.text(numberStyle, placeholder: '00'),
                  ),
                ),
                BirdySkeleton.box(
                  width: BirdySizes.blockIcon,
                  height: BirdySizes.blockIcon,
                  radius: BirdyRadii.thumb,
                ),
              ],
            ),
            BirdySkeleton.text(BirdyText.caption, placeholder: '0000000000'),
            BirdySkeleton.text(BirdyText.caption, placeholder: '00000000'),
          ],
        ),
      ),
    );
  }
}

/// Status disc, name, « 24/35 » and the bar to the next status, on Lichen.
class StatusBlock extends StatelessWidget {
  const StatusBlock({super.key, required this.progress, this.onTap});

  final GameProgress progress;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
    final status = progress.status;
    final next = progress.next;
    final name =
        status == null ? l10n.forkStatusNone : statusName(l10n, status);
    final caption =
        next == null
            ? l10n.forkStatusTop
            : l10n.forkStatusNext(progress.remaining, statusName(l10n, next));
    final percent = (progress.progress * 100).round();
    return BirdyBlock(
      key: const ValueKey('home-status-block'),
      tone: BirdyBlockTone.sure,
      onTap: onTap,
      semanticLabel:
          '$name. ${l10n.forkNotebookDiscovered(progress.verified)}. '
          '${l10n.forkStatusRingLabel(percent)}. $caption',
      child: Row(
        children: [
          Container(
            width: BirdySizes.statusDisc,
            height: BirdySizes.statusDisc,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: BirdyBrand.lichen,
              shape: BoxShape.circle,
            ),
            child: StatusEmblem(
              status: status ?? GameConfig.statuses.first,
              reached: status != null,
              size: BirdySizes.statusDisc - 2 * BirdySpace.xs,
            ),
          ),
          const SizedBox(width: BirdySpace.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: BirdyText.species.copyWith(color: c.text1),
                      ),
                    ),
                    if (next != null) ...[
                      const SizedBox(width: BirdySpace.s),
                      Text(
                        '${progress.verified}/${next.from}',
                        style: BirdyText.labelCompact.copyWith(
                          color: c.sure.foreground,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: BirdySpace.s),
                BirdyProgressBar(
                  value: progress.progress,
                  color: c.sure.foreground,
                  track: birdyTrackOnTint(c),
                ),
                const SizedBox(height: BirdySpace.s),
                Text(
                  caption,
                  style: BirdyText.caption.copyWith(color: c.text2),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Loading placeholder of [StatusBlock], same shape (disc, name row,
/// fraction, bar, caption): the status block is always shown once the
/// game progress resolves (even a fresh account has a "no status yet"
/// state), so this is the only home skeleton with no collapsing case.
class StatusBlockSkeleton extends StatelessWidget {
  const StatusBlockSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
    // A real, representative phrase for the caption's wrapping (one line
    // or two, at 130 %): the actual status name is not known yet, so this
    // uses the longest one, or the block would still resize once a
    // shorter real caption turns out to wrap less than this reserved.
    final longestStatus = GameConfig.statuses.fold(
      GameConfig.statuses.first,
      (longest, status) =>
          statusName(l10n, status).length > statusName(l10n, longest).length
              ? status
              : longest,
    );
    // The widest gap between two statuses (SPEC.md 7.2): a smaller
    // remaining count only shrinks the digits, never grows them.
    final widestGap = Iterable.generate(
      GameConfig.statuses.length - 1,
      (i) => GameConfig.statuses[i + 1].from - GameConfig.statuses[i].from,
    ).reduce((a, b) => a > b ? a : b);
    final placeholderCaption = l10n.forkStatusNext(
      widestGap,
      statusName(l10n, longestStatus),
    );
    return ExcludeSemantics(
      child: BirdyBlock(
        tone: BirdyBlockTone.sure,
        child: Row(
          children: [
            BirdySkeleton.box(
              width: BirdySizes.statusDisc,
              height: BirdySizes.statusDisc,
              radius: BirdyRadii.pill,
            ),
            const SizedBox(width: BirdySpace.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      // No maxLines: the longest status name (« Sentinelle
                      // des haies ») can wrap to two lines at 130 %.
                      Expanded(
                        child: BirdySkeleton.text(
                          BirdyText.species,
                          placeholder: statusName(l10n, longestStatus),
                          maxLines: null,
                        ),
                      ),
                      const SizedBox(width: BirdySpace.s),
                      BirdySkeleton.text(
                        BirdyText.labelCompact,
                        placeholder: '0000',
                      ),
                    ],
                  ),
                  const SizedBox(height: BirdySpace.s),
                  BirdyProgressBar(
                    value: 0,
                    color: c.sure.foreground,
                    track: birdyTrackOnTint(c),
                  ),
                  const SizedBox(height: BirdySpace.s),
                  BirdySkeleton.text(
                    BirdyText.caption,
                    placeholder: placeholderCaption,
                    maxLines: null,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// « Aujourd'hui », its numbers, and today's species as tinted cards.
class TodayBlock extends StatelessWidget {
  const TodayBlock({
    super.key,
    required this.today,
    required this.nameOf,
    this.imageOf,
    this.onSpecies,
  });

  final DaySummary today;

  /// Localized common name of a species of the day.
  final String Function(DaySpecies species) nameOf;
  final ImageProvider? Function(String scientificName)? imageOf;
  final void Function(DaySpecies species, String name)? onSpecies;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
    const bold = TextStyle(fontWeight: FontWeight.w700);
    final numbers = <(int, String)>[
      (today.species, l10n.forkHomeSpeciesStat(today.species)),
      (today.contacts, l10n.forkLiveContactsStat(today.contacts)),
      if (today.newSpecies > 0)
        (today.newSpecies, l10n.forkHomeNewStat(today.newSpecies)),
    ];
    return BirdyBlock(
      padding: const EdgeInsetsDirectional.only(
        start: BirdySpace.l,
        top: BirdySpace.l,
        bottom: BirdySpace.l,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.only(end: BirdySpace.l),
            child: Wrap(
              spacing: BirdySpace.m,
              runSpacing: BirdySpace.xs,
              crossAxisAlignment: WrapCrossAlignment.end,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    l10n.forkHomeTodayTitle,
                    style: BirdyText.heading.copyWith(color: c.text1),
                  ),
                ),
                Text.rich(
                  TextSpan(
                    children: [
                      for (final (i, (count, label)) in numbers.indexed) ...[
                        if (i > 0) const TextSpan(text: ' · '),
                        TextSpan(text: '$count', style: bold),
                        TextSpan(text: ' $label'),
                      ],
                    ],
                  ),
                  style: BirdyText.caption.copyWith(
                    color: c.text2,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
          if (today.heard.isNotEmpty) ...[
            const SizedBox(height: BirdySpace.block),
            SingleChildScrollView(
              key: const ValueKey('home-today-row'),
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsetsDirectional.only(end: BirdySpace.l),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final (i, species) in today.heard.indexed) ...[
                      if (i > 0) const SizedBox(width: BirdySpace.s),
                      _SpeciesChipCard(
                        species: species,
                        name: nameOf(species),
                        image: imageOf?.call(species.scientificName),
                        onTap:
                            onSpecies == null
                                ? null
                                : () => onSpecies!(species, nameOf(species)),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Loading placeholder of [TodayBlock], same padding, title/numbers row
/// and one scrolling row of chip-shaped cards: the common case for a
/// returning user is at least one species heard today, so the skeleton
/// fills that shape. A day with nothing heard yet swaps to the smaller
/// empty state instead of this block once loaded, which is the one case
/// allowed to change the layout (J6f skeletons).
class TodayBlockSkeleton extends StatelessWidget {
  const TodayBlockSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
    // A real, plural-correct phrase (species · contacts · new), not a run
    // of zeros: its wrapping (one line or two, at 130 %) must match the
    // real numbers row, or the block would still resize once it lands.
    final placeholderNumbers = [
      '00 ${l10n.forkHomeSpeciesStat(2)}',
      '00 ${l10n.forkLiveContactsStat(2)}',
      '0 ${l10n.forkHomeNewStat(1)}',
    ].join(' · ');
    return ExcludeSemantics(
      child: BirdyBlock(
        padding: const EdgeInsetsDirectional.only(
          start: BirdySpace.l,
          top: BirdySpace.l,
          bottom: BirdySpace.l,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.only(end: BirdySpace.l),
              child: Wrap(
                spacing: BirdySpace.m,
                runSpacing: BirdySpace.xs,
                crossAxisAlignment: WrapCrossAlignment.end,
                children: [
                  Text(
                    l10n.forkHomeTodayTitle,
                    style: BirdyText.heading.copyWith(color: c.text1),
                  ),
                  BirdySkeleton.text(
                    BirdyText.caption,
                    placeholder: placeholderNumbers,
                    maxLines: null,
                  ),
                ],
              ),
            ),
            const SizedBox(height: BirdySpace.block),
            Padding(
              padding: const EdgeInsetsDirectional.only(end: BirdySpace.l),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < 3; i++) ...[
                      if (i > 0) const SizedBox(width: BirdySpace.s),
                      const _SpeciesChipCardSkeleton(),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Loading placeholder of [_SpeciesChipCard]: same width, padding, avatar
/// size and two lines of name, so [TodayBlockSkeleton]'s row is exactly
/// the height the real one will be. Most French common names (« Rougegorge
/// familier », « Mésange charbonnière »…) wrap to two lines at this card's
/// width, so the skeleton reserves two; a short one-word name is the rarer
/// case, and shrinks the row when it lands.
class _SpeciesChipCardSkeleton extends StatelessWidget {
  const _SpeciesChipCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: BirdySizes.speciesChipCard,
      child: BirdyBlock(
        padding: const EdgeInsets.fromLTRB(
          BirdySpace.xs,
          BirdySpace.m,
          BirdySpace.xs,
          BirdySpace.m,
        ),
        child: Column(
          children: [
            BirdySkeleton.box(
              width: BirdySizes.speciesChipAvatar,
              height: BirdySizes.speciesChipAvatar,
              radius: BirdyRadii.pill,
            ),
            const SizedBox(height: BirdySpace.s),
            BirdySkeleton.text(
              BirdyText.caption,
              placeholder: '00000000000000000000',
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }
}

/// A species of the day: its visual and name on its tint.
class _SpeciesChipCard extends StatelessWidget {
  const _SpeciesChipCard({
    required this.species,
    required this.name,
    this.image,
    this.onTap,
  });

  final DaySpecies species;
  final String name;
  final ImageProvider? image;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = BirdyColors.of(context);
    final SpeciesTint tint = SpeciesAccents.tintOf(species.scientificName);
    return SizedBox(
      width: BirdySizes.speciesChipCard,
      child: BirdyBlock(
        color: tint.cardBackground(c.brightness),
        onTap: onTap,
        semanticLabel: name,
        padding: const EdgeInsets.fromLTRB(
          BirdySpace.xs,
          BirdySpace.m,
          BirdySpace.xs,
          BirdySpace.m,
        ),
        child: Column(
          children: [
            SpeciesAvatar(
              image: image,
              tint: tint,
              size: BirdySizes.speciesChipAvatar,
            ),
            const SizedBox(height: BirdySpace.s),
            Text(
              name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: BirdyText.caption.copyWith(
                color: c.text1,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One entry of the home menu.
@immutable
class HomeMenuEntry {
  const HomeMenuEntry(this.icon, this.label, this.onTap);

  final IconData icon;
  final String label;
  final VoidCallback onTap;
}

/// Everything the upstream home offered, in groups separated by a line.
class HomeMenuSheet extends StatelessWidget {
  const HomeMenuSheet({super.key, required this.groups});

  final List<List<HomeMenuEntry>> groups;

  @override
  Widget build(BuildContext context) {
    final c = BirdyColors.of(context);
    return ListView(
      shrinkWrap: true,
      // The bottom nav bar inset goes here, as trailing scroll padding,
      // rather than around this ListView from showBirdySheet
      // (addBottomInset: false in fork_home.dart) — this list can grow to
      // fill the sheet, and outer padding would shrink that scrolling
      // viewport instead of just clearing the nav bar (J6f-c bugfix).
      padding: EdgeInsets.only(
        bottom: BirdySpace.l + birdySheetBottomInset(context),
      ),
      children: [
        for (final (i, group) in groups.indexed) ...[
          if (i > 0) Divider(color: c.line, height: BirdySpace.l),
          for (final entry in group)
            ListTile(
              minTileHeight: BirdySizes.target,
              leading: Icon(entry.icon, color: c.text1),
              title: Text(
                entry.label,
                style: BirdyText.body.copyWith(color: c.text1),
              ),
              onTap: () {
                Navigator.of(context).pop();
                entry.onTap();
              },
            ),
        ],
      ],
    );
  }
}
