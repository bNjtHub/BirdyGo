/// Discreet « Enregistrement » strip under the listening screen's header
/// while listening to a recording (fork/PLAN.md J5c).
library;

import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

import '../../shared/utils/app_icons.dart';
import '../design/birdy_tokens.dart';
import '../design/birdy_typography.dart';

class PracticeBanner extends StatelessWidget {
  const PracticeBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
    final style = BirdyText.caption.copyWith(color: c.text2);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: BirdySpace.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(AppIcons.musicNote, size: BirdyGlyph.m, color: c.text2),
          const SizedBox(width: BirdySpace.xs),
          Text(l10n.forkPracticeBanner, style: style),
        ],
      ),
    );
  }
}
