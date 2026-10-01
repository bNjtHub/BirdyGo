/// « Envoyer à Faune-France (LPO) » at the end of a session's review, as in
/// the Bilan mockup (fork/maquette/Resume.dc.html, SPEC 9.8 and 7.7).
library;

import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../design/birdy_tokens.dart';

import '../../features/live/live_session.dart';
import '../../shared/utils/app_icons.dart';
import '../practice/practice.dart';
import '../settings/france_features.dart';
import 'lpo_send_screen.dart';

/// Full-width secondary button and its caption.
class LpoSendButton extends ConsumerWidget {
  const LpoSendButton({super.key, required this.session, this.detections});

  final LiveSession session;

  /// The review screen's current detections (confirmations not saved yet
  /// included).
  final List<DetectionRecord>? detections;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // France-only (see france_features.dart).
    if (!watchFranceFeatures(context, ref)) return const SizedBox.shrink();
    // A recording is not an observation (J5c): nothing to send.
    if (!countsAsObservation(session)) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(BirdySpace.xl, BirdySpace.l, BirdySpace.xl, BirdySpace.s),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
              shape: const StadiumBorder(),
            ),
            icon: const Icon(AppIcons.send),
            label: Text(l10n.forkLpoSendButton),
            onPressed:
                () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder:
                        (_) => LpoSendScreen(
                          session: session,
                          detections:
                              detections == null ? null : List.of(detections!),
                        ),
                  ),
                ),
          ),
          const SizedBox(height: BirdySpace.s),
          Text(
            l10n.forkLpoOnlyConfirmed,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
