/// A full-page bird picker with a pinned heading and bundled species photos.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/explore/explore_providers.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/providers/settings_providers.dart';
import '../../shared/utils/app_icons.dart';
import '../../shared/widgets/content_width_constraint.dart';
import '../design/birdy_tokens.dart';
import '../design/birdy_typography.dart';
import '../design/species_accents.dart';
import '../design/widgets/species_avatar.dart';
import '../design/widgets/species_tile.dart';
import 'daily_goal.dart';

class DailyGoalReplacementScreen extends ConsumerWidget {
  const DailyGoalReplacementScreen({
    super.key,
    required this.replacing,
    required this.alternatives,
  });

  final DailyGoalSpecies replacing;
  final List<DailyGoalSpecies> alternatives;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final colors = BirdyColors.of(context);
    final taxonomy = ref.watch(taxonomyServiceProvider).value;
    final locale = ref.watch(effectiveSpeciesLocaleProvider);
    String nameOf(DailyGoalSpecies bird) =>
        taxonomy?.lookup(bird.scientificName)?.commonNameForLocale(locale) ??
        bird.commonName;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: ContentWidthConstraint(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  BirdySpace.s,
                  BirdySpace.s,
                  BirdySpace.gutter,
                  BirdySpace.m,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    IconButton(
                      icon: const Icon(AppIcons.arrowBackRounded),
                      tooltip:
                          MaterialLocalizations.of(context).backButtonTooltip,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: BirdySpace.s),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: BirdySpace.s),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.forkDailyGoalChooseReplacement,
                              style: BirdyText.title.copyWith(
                                color: colors.text1,
                              ),
                            ),
                            const SizedBox(height: BirdySpace.xs),
                            Text(
                              l10n.forkDailyGoalReplace(nameOf(replacing)),
                              style: BirdyText.caption.copyWith(
                                color: colors.text2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child:
                    alternatives.isEmpty
                        ? ListView(
                          padding: const EdgeInsets.all(BirdySpace.gutter),
                          children: [
                            Text(
                              l10n.forkDailyGoalNoReplacement,
                              style: BirdyText.body.copyWith(
                                color: colors.text2,
                              ),
                            ),
                          ],
                        )
                        : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(
                            BirdySpace.gutter,
                            0,
                            BirdySpace.gutter,
                            BirdySpace.xxl,
                          ),
                          itemCount: alternatives.length,
                          separatorBuilder:
                              (_, _) => const SizedBox(height: BirdySpace.s),
                          itemBuilder: (context, index) {
                            final bird = alternatives[index];
                            final name = nameOf(bird);
                            void select() => Navigator.of(context).pop(bird);
                            return SpeciesTile(
                              name: name,
                              scientificName:
                                  taxonomy
                                      ?.lookup(bird.scientificName)
                                      ?.displayScientificName ??
                                  bird.scientificName,
                              avatar: SpeciesAvatar(
                                size: 64,
                                tint: SpeciesAccents.tintOf(
                                  bird.scientificName,
                                ),
                                image: switch (taxonomy?.assetImagePath(
                                  bird.scientificName,
                                )) {
                                  final String path => AssetImage(path),
                                  null => null,
                                },
                              ),
                              action: IconButton.filledTonal(
                                icon: const Icon(AppIcons.addRounded),
                                tooltip: name,
                                onPressed: select,
                              ),
                              onTap: select,
                            );
                          },
                        ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
