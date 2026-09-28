/// What « Sûr », « Probable », « À vérifier » and « Rare ici » mean, opened
/// from the live options sheet (fork/PLAN.md J6c-bis-c).
library;

import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

import '../design/birdy_tokens.dart';
import '../design/birdy_typography.dart';
import '../design/widgets/birdy_pill.dart';
import '../design/widgets/birdy_sheet.dart';
import 'reliability_badge.dart';
import 'reliability_config.dart';

/// J6f: opened from the live options sheet (« À quel point l'app est
/// sûre »), on top of it.
Future<void> showLevelsSheet(BuildContext context) {
  return showBirdySheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => const LevelsSheet(),
  );
}

class LevelsSheet extends StatelessWidget {
  const LevelsSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
    Widget row(Widget badge, String text) => Padding(
      padding: const EdgeInsets.only(bottom: BirdySpace.m),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          badge,
          const SizedBox(height: BirdySpace.xs),
          Text(text, style: BirdyText.bodyCompact.copyWith(color: c.text1)),
        ],
      ),
    );
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        BirdySpace.gutter,
        0,
        BirdySpace.gutter,
        BirdySpace.xxl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.forkLevelsInfoTitle,
            style: BirdyText.heading.copyWith(color: c.text1),
          ),
          const SizedBox(height: BirdySpace.l),
          row(
            const ReliabilityBadge(level: ReliabilityLevel.sure),
            l10n.forkLevelsInfoSure,
          ),
          row(
            const ReliabilityBadge(level: ReliabilityLevel.probable),
            l10n.forkLevelsInfoProbable,
          ),
          row(
            const ReliabilityBadge(level: ReliabilityLevel.toCheck),
            l10n.forkLevelsInfoToCheck,
          ),
          row(
            const NoveltyPill(kind: NoveltyKind.rareHereToConfirm),
            l10n.forkLevelsInfoRareHere,
          ),
          const SizedBox(height: BirdySpace.xs),
          Text(
            l10n.forkLevelsInfoFooter,
            style: BirdyText.caption.copyWith(color: c.text2),
          ),
        ],
      ),
    );
  }
}
