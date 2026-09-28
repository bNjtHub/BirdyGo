/// Home hero card of the daily goal (J6c, fork/maquette/Main.dc.html): the
/// goal's birds as big circles, two rows of four.
///
/// A bird already heard sits on its species tint with a small Lichen check;
/// a bird to find is grey, in a dashed circle. Passive: restoring a
/// checklist never starts a GPS request (the goal screen creates it).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/explore/explore_providers.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/providers/settings_providers.dart';
import '../../shared/utils/app_icons.dart';
import '../design/birdy_tokens.dart';
import '../design/birdy_typography.dart';
import '../design/species_accents.dart';
import '../design/widgets/dashed_border.dart';
import '../design/widgets/pressable.dart';
import '../design/widgets/species_avatar.dart';
import 'daily_goal.dart';
import 'daily_goal_providers.dart';

/// Sizes of the goal card (SPEC.md 9.1, Main.dc.html).
abstract final class DailyGoalCardSizes {
  /// Birds per row.
  static const int columns = 4;

  /// Circle of one bird (shrinks on very narrow screens).
  static const double bird = 60;

  /// Species visual inside a heard bird's circle.
  static const double heardVisual = 46;

  /// Grey species visual inside a dashed circle.
  static const double toFindVisual = 40;

  /// Lichen check on a heard bird, and its ring in the card color.
  static const double check = 22;
  static const double checkIcon = 14;
  static const double checkRing = 2;

  /// Icon disc before the title.
  static const double iconDisc = 40;
  static const double icon = 22;
  static const double chevron = 20;
}

class DailyGoalCard extends ConsumerWidget {
  const DailyGoalCard({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
    final goal = ref.watch(dailyGoalProvider).goal;
    final completed =
        goal == null ? null : ref.watch(dailyGoalProgressProvider);
    final taxonomy = ref.watch(taxonomyServiceProvider).value;
    final speciesLocale = ref.watch(effectiveSpeciesLocaleProvider);

    String name(DailyGoalSpecies bird) =>
        taxonomy
            ?.lookup(bird.scientificName)
            ?.commonNameForLocale(speciesLocale) ??
        bird.commonName;
    ImageProvider? image(DailyGoalSpecies bird) => switch (taxonomy
        ?.assetImagePath(bird.scientificName)) {
      final String path => AssetImage(path),
      null => null,
    };

    final Widget? subtitle;
    final List<Widget> below;
    if (goal == null) {
      subtitle = Text(
        l10n.forkDailyGoalIntro,
        style: BirdyText.bodyCompact.copyWith(color: c.text1),
      );
      below = [
        Text(
          l10n.forkDailyGoalStart,
          style: BirdyText.labelCompact.copyWith(color: c.accentText),
        ),
      ];
    } else if (completed!.hasError) {
      subtitle = Text(
        l10n.forkDailyGoalError,
        style: BirdyText.bodyCompact.copyWith(color: c.text1),
      );
      below = const [];
    } else {
      // While the index loads, every bird shows as still to find.
      final heard = completed.value ?? const <String>{};
      subtitle =
          completed.hasValue
              ? _ProgressText(
                text: l10n.forkDailyGoalProgress(heard.length, goal.total),
                completed: heard.length,
                total: goal.total,
              )
              : null;
      below = [
        _BirdGrid(
          birds: [
            for (final bird in goal.species)
              _GoalBird(
                name: name(bird),
                scientificName: bird.scientificName,
                image: image(bird),
                heard: heard.contains(bird.scientificName),
              ),
          ],
        ),
      ];
    }

    return Pressable(
      child: Material(
        color: c.surface1,
        borderRadius: BorderRadius.circular(BirdyRadii.hero),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              BirdySpace.l,
              BirdySpace.l,
              BirdySpace.l,
              BirdySpace.xl,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: DailyGoalCardSizes.iconDisc,
                      height: DailyGoalCardSizes.iconDisc,
                      decoration: BoxDecoration(
                        color: c.tonal,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        AppIcons.flagRounded,
                        size: DailyGoalCardSizes.icon,
                        color: c.accentText,
                      ),
                    ),
                    const SizedBox(width: BirdySpace.m),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.forkDailyGoalTitle,
                            style: BirdyText.heading.copyWith(color: c.text1),
                          ),
                          if (subtitle != null) subtitle,
                        ],
                      ),
                    ),
                    Icon(
                      AppIcons.chevronRight,
                      size: DailyGoalCardSizes.chevron,
                      color: c.text2,
                    ),
                  ],
                ),
                for (final widget in below) ...[
                  const SizedBox(height: BirdySpace.l),
                  widget,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// « 5/8 espèces entendues », the ratio in bold.
class _ProgressText extends StatelessWidget {
  const _ProgressText({
    required this.text,
    required this.completed,
    required this.total,
  });

  final String text;
  final int completed;
  final int total;

  @override
  Widget build(BuildContext context) {
    final c = BirdyColors.of(context);
    final style = BirdyText.bodyCompact.copyWith(
      color: c.text1,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    // Bold from the first number to the second one, whatever the wording
    // (« 5/8 », « 5 of 8 »); plain text when a translation reorders them.
    final start = text.indexOf('$completed');
    final totalAt =
        start < 0 ? -1 : text.indexOf('$total', start + '$completed'.length);
    if (totalAt < 0) return Text(text, style: style);
    final end = totalAt + '$total'.length;
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: text.substring(0, start)),
          TextSpan(
            text: text.substring(start, end),
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          TextSpan(text: text.substring(end)),
        ],
      ),
      style: style,
    );
  }
}

@immutable
class _GoalBird {
  const _GoalBird({
    required this.name,
    required this.scientificName,
    required this.image,
    required this.heard,
  });

  final String name;
  final String scientificName;
  final ImageProvider? image;
  final bool heard;
}

/// Rows of [DailyGoalCardSizes.columns] circles, evenly spread.
class _BirdGrid extends StatelessWidget {
  const _BirdGrid({required this.birds});

  final List<_GoalBird> birds;

  @override
  Widget build(BuildContext context) {
    const columns = DailyGoalCardSizes.columns;
    return LayoutBuilder(
      builder: (context, box) {
        // Keep a little room for the check that overhangs the circle.
        final cell = box.maxWidth / columns;
        final size =
            cell.isFinite
                ? (cell - BirdySpace.xs).clamp(0.0, DailyGoalCardSizes.bird)
                : DailyGoalCardSizes.bird;
        final rows = (birds.length + columns - 1) ~/ columns;
        return Column(
          key: const ValueKey('daily-goal-grid'),
          children: [
            for (var r = 0; r < rows; r++) ...[
              if (r > 0) const SizedBox(height: BirdySpace.m),
              Row(
                key: ValueKey('daily-goal-row-$r'),
                children: [
                  for (var i = r * columns; i < (r + 1) * columns; i++)
                    Expanded(
                      child: Center(
                        child:
                            i < birds.length
                                ? _BirdCircle(bird: birds[i], size: size)
                                : const SizedBox.shrink(),
                      ),
                    ),
                ],
              ),
            ],
          ],
        );
      },
    );
  }
}

/// One bird of the goal: tinted with a check when heard, grey and dashed
/// while still to find.
class _BirdCircle extends StatelessWidget {
  const _BirdCircle({required this.bird, required this.size});

  final _GoalBird bird;
  final double size;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
    final tint = SpeciesAccents.tintOf(bird.scientificName);
    final scale = size / DailyGoalCardSizes.bird;
    final Widget circle;
    if (bird.heard) {
      circle = Stack(
        key: const ValueKey('daily-goal-heard'),
        clipBehavior: Clip.none,
        children: [
          Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: tint.cardBackground(c.brightness),
              shape: BoxShape.circle,
            ),
            child: SpeciesAvatar(
              image: bird.image,
              tint: tint,
              size: DailyGoalCardSizes.heardVisual * scale,
            ),
          ),
          PositionedDirectional(
            end: -DailyGoalCardSizes.checkRing,
            bottom: -DailyGoalCardSizes.checkRing,
            child: Container(
              width: DailyGoalCardSizes.check,
              height: DailyGoalCardSizes.check,
              decoration: BoxDecoration(
                color: c.sure.foreground,
                shape: BoxShape.circle,
                border: Border.all(
                  color: c.surface1,
                  width: DailyGoalCardSizes.checkRing,
                ),
              ),
              child: Icon(
                AppIcons.checkRounded,
                size: DailyGoalCardSizes.checkIcon,
                color: c.surface1,
              ),
            ),
          ),
        ],
      );
    } else {
      circle = CustomPaint(
        key: const ValueKey('daily-goal-to-find'),
        foregroundPainter: DashedBorderPainter(
          color: c.dashed,
          radius: BirdyRadii.pill,
        ),
        child: SizedBox.square(
          dimension: size,
          child: Center(
            child: SpeciesAvatar(
              image: bird.image,
              tint: tint,
              size: DailyGoalCardSizes.toFindVisual * scale,
              muted: true,
            ),
          ),
        ),
      );
    }
    return Semantics(
      image: true,
      label:
          bird.heard
              ? l10n.forkDailyGoalBirdHeard(bird.name)
              : l10n.forkDailyGoalBirdToFind(bird.name),
      child: ExcludeSemantics(child: circle),
    );
  }
}
