/// Compact daily goal block of the home grid (J6f, « App finale » boards):
/// progress ring, species still to find, all on the tonal fill.
///
/// Passive like the goal card: restoring a checklist never starts a GPS
/// request (the goal screen creates it).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/explore/explore_providers.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/providers/settings_providers.dart';
import '../design/birdy_tokens.dart';
import '../design/birdy_typography.dart';
import '../design/species_accents.dart';
import '../design/widgets/birdy_block.dart';
import '../design/widgets/dashed_border.dart';
import '../design/widgets/species_avatar.dart';
import 'daily_goal.dart';
import 'daily_goal_providers.dart';

/// Species still to find shown under the ring, at most.
const int dailyGoalBlockSlots = 3;

class DailyGoalBlock extends ConsumerWidget {
  const DailyGoalBlock({super.key, required this.onTap});

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

    final List<Widget> body;
    if (goal == null) {
      body = [
        Text(
          l10n.forkDailyGoalInvite,
          style: BirdyText.bodyCompact.copyWith(color: c.text1),
        ),
        Text(
          l10n.forkDailyGoalStart,
          style: BirdyText.labelCompact.copyWith(color: c.accentText),
        ),
      ];
    } else if (completed!.hasError) {
      body = [
        Text(
          l10n.forkDailyGoalError,
          style: BirdyText.bodyCompact.copyWith(color: c.text1),
        ),
      ];
    } else {
      // While the index loads, every bird shows as still to find.
      final heard = completed.value ?? const <String>{};
      final count =
          goal.species.where((b) => heard.contains(b.scientificName)).length;
      final missing = [
        for (final bird in goal.species)
          if (!heard.contains(bird.scientificName)) bird,
      ];
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
      body = [
        Center(
          child: Semantics(
            container: true,
            label: l10n.forkDailyGoalProgress(count, goal.total),
            child: ExcludeSemantics(
              child: BirdyProgressRing(
                key: const ValueKey('daily-goal-ring'),
                value: goal.total == 0 ? 0 : count / goal.total,
                color: c.accent,
                track: birdyTrackOnTint(c),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Padding(
                    padding: const EdgeInsets.all(BirdySizes.ringStroke),
                    child: Text(
                      '$count/${goal.total}',
                      style: BirdyText.numberM.copyWith(
                        color: c.text1,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        Text(
          l10n.forkDailyGoalLeft(goal.total - count),
          style: BirdyText.labelCompact.copyWith(color: c.text1),
        ),
        if (missing.isNotEmpty)
          Wrap(
            spacing: BirdySpace.s,
            runSpacing: BirdySpace.s,
            children: [
              for (final bird in missing.take(dailyGoalBlockSlots))
                _Slot(name: name(bird), bird: bird, image: image(bird)),
            ],
          ),
      ];
    }

    return BirdyBlock(
      tone: BirdyBlockTone.tonal,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.forkDailyGoalTitle,
            style: BirdyText.caption.copyWith(
              color: c.accentText,
              fontWeight: FontWeight.w700,
            ),
          ),
          for (final widget in body) ...[
            const SizedBox(height: BirdySpace.block),
            widget,
          ],
        ],
      ),
    );
  }
}

/// Dashed silhouette of a bird still to find.
class _Slot extends StatelessWidget {
  const _Slot({required this.name, required this.bird, required this.image});

  final String name;
  final DailyGoalSpecies bird;
  final ImageProvider? image;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
    return Semantics(
      container: true,
      image: true,
      label: l10n.forkDailyGoalBirdToFind(name),
      child: ExcludeSemantics(
        child: CustomPaint(
          key: const ValueKey('daily-goal-slot'),
          foregroundPainter: DashedBorderPainter(
            color: c.accentText,
            radius: BirdyRadii.pill,
          ),
          child: Container(
            width: BirdySizes.goalSlot,
            height: BirdySizes.goalSlot,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: birdySlotFill(c),
              shape: BoxShape.circle,
            ),
            child: SpeciesAvatar(
              image: image,
              tint: SpeciesAccents.tintOf(bird.scientificName),
              size: BirdySizes.goalSlotVisual,
              muted: true,
            ),
          ),
        ),
      ),
    );
  }
}
