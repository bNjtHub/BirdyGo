/// Blocks of the home screen (J6f, « App finale » boards, AppAccueil): top
/// row, last bird hero, goal / série / to-check grid, status, today's
/// species, menu. Blocks stand out by their fill, never by a grey border.
library;

import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../shared/utils/app_icons.dart';
import '../design/birdy_tokens.dart';
import '../design/birdy_typography.dart';
import '../design/species_accents.dart';
import '../design/species_tint.dart';
import '../design/widgets/birdy_block.dart';
import '../design/widgets/birdygo_wordmark.dart';
import '../design/widgets/birdy_buttons.dart';
import '../design/widgets/pressable.dart';
import '../design/widgets/species_avatar.dart';
import '../game/game_config.dart';
import '../game/game_progress.dart';
import '../game/game_text.dart';
import '../game/game_widgets.dart';
import '../game/streak.dart';
import '../reliability/reliability_badge.dart';
import '../reliability/reliability_config.dart';
import 'home_model.dart';
import 'singing_logo.dart';

/// Singing mark, name and menu button.
class HomeTopBar extends StatelessWidget {
  const HomeTopBar({super.key, required this.onMenu});

  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: BirdySizes.target),
      child: Row(
        children: [
          Expanded(
            child: SingingLogo(
              // The startup screen's wordmark, header size.
              wordmark: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: AlignmentDirectional.centerStart,
                child: BirdyGoWordmark(size: _wordmarkSize, color: c.text1),
              ),
            ),
          ),
          BirdyIconButton(
            icon: AppIcons.menu,
            semanticLabel: l10n.forkHomeMenu,
            onPressed: onMenu,
          ),
        ],
      ),
    );
  }
}

/// Wordmark size in the home header: the startup letters, a little above
/// the board's 20 px name so the Oriole dot stays readable.
const double _wordmarkSize = 24;

/// « Bonjour » and the date line.
class HomeGreeting extends StatelessWidget {
  const HomeGreeting({super.key, required this.title, required this.dateLine});

  final String title;
  final String dateLine;

  @override
  Widget build(BuildContext context) {
    final c = BirdyColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(title, style: BirdyText.display.copyWith(color: c.text1)),
        ),
        const SizedBox(height: BirdySpace.xs),
        Text(dateLine, style: BirdyText.caption.copyWith(color: c.text2)),
      ],
    );
  }
}

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
                  ),
                  const SizedBox(height: BirdySpace.block),
                  Text(name, style: BirdyText.title.copyWith(color: c.text1)),
                  Text(
                    last.scientificName,
                    style: BirdyText.latinCompact.copyWith(color: c.text2),
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

/// Current week of the série (Monday to Sunday), from its two-week calendar.
List<StreakDay> streakWeek(Streak streak) {
  final days = streak.calendar;
  return days.length <= 7 ? days : days.sublist(days.length - 7);
}

/// « 9 jours de suite » and this week's day dots, on Loriot.
class StreakBlock extends StatelessWidget {
  const StreakBlock({super.key, required this.streak, this.onTap});

  final Streak streak;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
    final weekday = DateFormat('EEEEE', l10n.localeName);
    final week = streakWeek(streak);
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
          Row(
            children: [
              for (final day in week)
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Column(
                      children: [
                        _DayDot(listened: day.state == StreakDayState.listened),
                        const SizedBox(height: BirdySpace.xs),
                        Text(
                          weekday.format(day.date).toUpperCase(),
                          style: BirdyText.caption.copyWith(
                            color: c.orioleText,
                            fontWeight:
                                day.isToday ? FontWeight.w700 : FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Filled when listened, outlined otherwise. Loriot text color, not the
/// Loriot fill: the fill is too pale on its own container.
class _DayDot extends StatelessWidget {
  const _DayDot({required this.listened});

  final bool listened;

  @override
  Widget build(BuildContext context) {
    final c = BirdyColors.of(context);
    return Container(
      key: ValueKey(listened ? 'day-listened' : 'day-open'),
      width: BirdySizes.dayDot,
      height: BirdySizes.dayDot,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: listened ? c.orioleText : null,
        border:
            listened
                ? null
                : Border.all(
                  color: c.orioleText.withValues(
                    alpha: BirdyAlpha.dayDotOutline,
                  ),
                  width: BirdySizes.dayDotStroke,
                ),
      ),
    );
  }
}

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
      padding: const EdgeInsets.only(bottom: BirdySpace.l),
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
