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
import '../design/widgets/birdy_block.dart';
import '../design/widgets/birdy_buttons.dart';
import '../design/widgets/birdy_headers.dart';
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
                  BirdySpace.page,
                  BirdySpace.s,
                  BirdySpace.page,
                  BirdySpace.s,
                ),
                child: BirdyOverlayHeader(
                  title: l10n.forkDailyGoalChooseReplacement,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  BirdySpace.page,
                  0,
                  BirdySpace.page,
                  BirdySpace.block,
                ),
                child: BirdyBlock(
                  tone: BirdyBlockTone.tonal,
                  child: Text(
                    l10n.forkDailyGoalReplace(nameOf(replacing)),
                    style: BirdyText.bodyCompact.copyWith(color: colors.text1),
                  ),
                ),
              ),
              Expanded(
                child:
                    alternatives.isEmpty
                        ? ListView(
                          padding: const EdgeInsets.all(BirdySpace.page),
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
                            BirdySpace.page,
                            0,
                            BirdySpace.page,
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
                                size: BirdySizes.mainAction + BirdySpace.s,
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
                              action: BirdyIconButton(
                                icon: AppIcons.addRounded,
                                semanticLabel: name,
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
