/// Short explanation behind « Rare ici · à confirmer » (fork/PLAN.md J3b):
/// the song matches, the place or the season is what surprises.
library;

import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

import '../../shared/utils/app_icons.dart';
import '../design/birdy_tokens.dart';
import '../design/birdy_typography.dart';
import '../design/widgets/birdy_sheet.dart';

Future<void> showRareHereSheet(BuildContext context) {
  return showBirdySheet<void>(
    context: context,
    builder: (_) => const RareHereSheet(),
  );
}

class RareHereSheet extends StatelessWidget {
  const RareHereSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
    return Padding(
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
          Row(
            children: [
              Icon(AppIcons.diamond, size: 20, fill: 1, color: c.orioleText),
              const SizedBox(width: BirdySpace.s),
              Flexible(
                child: Text(
                  l10n.forkRareHereToConfirm,
                  style: BirdyText.heading.copyWith(color: c.text1),
                ),
              ),
            ],
          ),
          const SizedBox(height: BirdySpace.m),
          Text(
            l10n.forkRareHereExplanation,
            style: BirdyText.body.copyWith(color: c.text1),
          ),
        ],
      ),
    );
  }
}
