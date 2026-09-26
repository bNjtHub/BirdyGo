/// « Envoyer à Faune-France (LPO) » at the end of a session's review, as in
/// the Bilan mockup (fork/maquette/Resume.dc.html, SPEC 9.8 and 7.7).
library;

import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

import '../../features/live/live_session.dart';
import '../../shared/utils/app_icons.dart';
import 'lpo_send_screen.dart';

/// Full-width secondary button and its caption.
class LpoSendButton extends StatelessWidget {
  const LpoSendButton({super.key, required this.session, this.detections});

  final LiveSession session;

  /// The review screen's current detections (confirmations not saved yet
  /// included).
  final List<DetectionRecord>? detections;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
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
          const SizedBox(height: 8),
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
