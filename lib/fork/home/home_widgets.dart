/// Blocks of the home screen (J6c, fork/maquette/SPEC.md 9.1): top row,
/// today's tiles, last bird, detections to check, menu.
library;

import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

import '../../shared/utils/app_icons.dart';
import '../design/birdy_tokens.dart';
import '../design/birdy_typography.dart';
import '../design/species_accents.dart';
import '../design/widgets/animated_count.dart';
import '../design/widgets/birdy_buttons.dart';
import '../design/widgets/dashed_border.dart';
import '../design/widgets/pressable.dart';
import '../design/widgets/species_avatar.dart';
import '../reliability/reliability_badge.dart';
import 'birdygo_logo.dart';
import 'home_model.dart';

/// Mark, name and menu button.
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
          const ExcludeSemantics(child: BirdyGoLogo()),
          const SizedBox(width: BirdySpace.s),
          Expanded(
            child: Text(
              l10n.appTitle,
              style: BirdyText.heading.copyWith(color: c.text1),
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

/// « 13 espèces aujourd'hui · 52 contacts · 1 nouvelle ».
class DayTiles extends StatelessWidget {
  const DayTiles({super.key, required this.today});

  final DaySummary today;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: StatTile.count(
            count: today.species,
            label: l10n.forkHomeSpeciesToday(today.species),
          ),
        ),
        const SizedBox(width: BirdySpace.s),
        Expanded(
          child: StatTile.count(
            count: today.contacts,
            label: l10n.forkLiveContactsStat(today.contacts),
          ),
        ),
        const SizedBox(width: BirdySpace.s),
        Expanded(
          child: StatTile(
            value: AnimatedCount(
              value: today.newSpecies,
              style: BirdyText.numberL.copyWith(
                color: today.newSpecies > 0 ? c.orioleText : c.text1,
              ),
            ),
            label: l10n.forkHomeNewStat(today.newSpecies),
          ),
        ),
      ],
    );
  }
}

/// « Dernier oiseau entendu », on the species color.
class LastBirdCard extends StatelessWidget {
  const LastBirdCard({
    super.key,
    required this.last,
    required this.name,
    required this.when,
    this.image,
    this.onTap,
  });

  final LastBird last;

  /// Localized common name.
  final String name;

  /// « 7 h 52 », « hier, 7 h 52 ».
  final String when;
  final ImageProvider? image;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
    final tint = SpeciesAccents.tintOf(last.scientificName);
    return Pressable(
      enabled: onTap != null,
      child: Material(
        color: c.isDark ? tint.tintDark : tint.tintLight,
        borderRadius: BorderRadius.circular(BirdyRadii.card),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 88),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: BirdySpace.l,
                vertical: BirdySpace.m,
              ),
              child: Row(
                children: [
                  SpeciesAvatar(image: image, tint: tint, size: 64),
                  const SizedBox(width: BirdySpace.m),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.forkHomeLastBird,
                          style: BirdyText.caption.copyWith(color: c.text2),
                        ),
                        Text(
                          name,
                          style: BirdyText.heading.copyWith(color: c.text1),
                        ),
                        const SizedBox(height: BirdySpace.xs),
                        Wrap(
                          spacing: BirdySpace.s,
                          runSpacing: BirdySpace.xs,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            ReliabilityBadge(
                              level: last.level,
                              unexpected: last.unexpected,
                            ),
                            Text(
                              l10n.forkHomeLastBirdMeta(when, last.total),
                              style: BirdyText.caption.copyWith(color: c.text1),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Icon(AppIcons.chevronRight, color: c.text2),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// « 12 détections à vérifier ».
class ToVerifyCard extends StatelessWidget {
  const ToVerifyCard({super.key, required this.count, this.onTap});

  final int count;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
    return Pressable(
      enabled: onTap != null,
      child: Material(
        color: c.surface1,
        borderRadius: BorderRadius.circular(BirdyRadii.card),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: BirdySizes.mainAction),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: BirdySpace.l,
                vertical: BirdySpace.m,
              ),
              child: Row(
                children: [
                  CustomPaint(
                    foregroundPainter: DashedBorderPainter(
                      color: c.toCheck.foreground,
                      radius: BirdyRadii.pill,
                    ),
                    child: SizedBox.square(
                      dimension: 40,
                      child: Icon(
                        AppIcons.question,
                        size: 20,
                        color: c.toCheck.foreground,
                      ),
                    ),
                  ),
                  const SizedBox(width: BirdySpace.m),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.forkHomeToVerify(count),
                          style: BirdyText.labelCompact.copyWith(
                            color: c.text1,
                          ),
                        ),
                        Text(
                          l10n.forkHomeToVerifyHint,
                          style: BirdyText.caption.copyWith(color: c.text2),
                        ),
                      ],
                    ),
                  ),
                  Icon(AppIcons.chevronRight, color: c.text2),
                ],
              ),
            ),
          ),
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
