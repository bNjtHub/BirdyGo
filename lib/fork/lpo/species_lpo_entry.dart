/// « Envoyer à Faune-France » on the species page (J6g-e): sends this
/// species' confirmed sightings from the latest session that has some, by
/// the same guided [LpoSendScreen] as the Bilan.
library;

import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

import '../../features/live/live_session.dart';
import '../../shared/utils/app_icons.dart';
import '../design/birdy_tokens.dart';
import '../design/birdy_typography.dart';
import '../design/widgets/birdy_buttons.dart';
import '../design/widgets/pressable.dart';
import 'lpo_send_screen.dart';

/// Opens [LpoSendScreen] for [scientificName] only, from [session].
Future<void> openLpoSendForSpecies(
  BuildContext context, {
  required LiveSession session,
  required String scientificName,
}) => Navigator.of(context).push(
  MaterialPageRoute<void>(
    builder:
        (_) => LpoSendScreen(
          session: session,
          detections: [
            for (final d in session.detections)
              if (d.scientificName == scientificName) d,
          ],
        ),
  ),
);

/// Full-width secondary button and its caption.
class SpeciesLpoEntry extends StatelessWidget {
  const SpeciesLpoEntry({super.key, required this.onSend});

  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Pressable(
          child: OutlinedButton.icon(
            key: const ValueKey('fiche-lpo-send'),
            style: BirdyButtonStyles.secondary(context),
            icon: const Icon(AppIcons.send),
            label: Text(l10n.forkLpoSendSpecies),
            onPressed: onSend,
          ),
        ),
        const SizedBox(height: BirdySpace.xs),
        Text(
          l10n.forkLpoSpeciesCaption,
          textAlign: TextAlign.center,
          style: BirdyText.caption.copyWith(color: c.text2),
        ),
      ],
    );
  }
}
