/// « Pas encore dans ton carnet » block of the species page (J7): shown
/// when the user has never heard the species, with a button to go listen.
library;

import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

import '../design/birdy_tokens.dart';
import '../design/birdy_typography.dart';
import '../design/widgets/birdy_block.dart';
import '../design/widgets/birdy_buttons.dart';
import '../design/widgets/pressable.dart';
import '../design/widgets/species_avatar.dart';
import '../../shared/utils/app_icons.dart';

class NeverHeardBlock extends StatelessWidget {
  const NeverHeardBlock({super.key, required this.onListen});

  final VoidCallback onListen;

  /// Diameter of the grey mystery bird disc.
  static const double _disc = 64;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
    return BirdyBlock(
      tone: BirdyBlockTone.toCheck,
      radius: BirdyRadii.hero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Center(
            child: ExcludeSemantics(
              child: SpeciesAvatar(size: _disc, mystery: true),
            ),
          ),
          const SizedBox(height: BirdySpace.m),
          Semantics(
            header: true,
            child: Text(
              l10n.forkFicheNotInBookTitle,
              textAlign: TextAlign.center,
              style: BirdyText.heading.copyWith(color: c.text1),
            ),
          ),
          const SizedBox(height: BirdySpace.xs),
          Text(
            l10n.forkFicheNeverHeard,
            textAlign: TextAlign.center,
            style: BirdyText.body.copyWith(color: c.text2),
          ),
          const SizedBox(height: BirdySpace.l),
          Pressable(
            child: FilledButton.icon(
              onPressed: onListen,
              style: BirdyButtonStyles.primary(context),
              icon: const Icon(AppIcons.hearing),
              label: Text(l10n.forkFicheListenToFind),
            ),
          ),
        ],
      ),
    );
  }
}
