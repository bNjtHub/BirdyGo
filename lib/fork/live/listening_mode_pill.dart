/// Listening mode pill of the live header (J6f): the current listening
/// conditions; a tap opens the modes sheet ([LiveListeningModePill]).
/// Without [ListeningModePill.onPressed] it only shows the mode.
library;

import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/utils/app_icons.dart';
import '../design/birdy_tokens.dart';
import '../design/birdy_typography.dart';
import '../design/widgets/pressable.dart';
import '../listening_mode/listening_mode.dart';
import '../listening_mode/listening_mode_sheet.dart';

class ListeningModePill extends StatelessWidget {
  const ListeningModePill({
    super.key,
    required this.label,
    this.icon = AppIcons.graphicEqRounded,
    this.onPressed,
  });

  /// Name of the current mode (« Normal »).
  final String label;

  /// Icon of the current mode.
  final IconData icon;

  /// Opens the modes; null shows the mode only (no chevron).
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
    final shape = StadiumBorder(
      side: BorderSide(
        color: c.accentText.withValues(alpha: BirdyAlpha.modePillBorder),
      ),
    );
    final pill = Material(
      color: c.tonal,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        customBorder: shape,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: BirdySizes.target),
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              BirdySpace.s,
              0,
              BirdySpace.m,
              0,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: BirdySizes.modeIcon, color: c.accentText),
                const SizedBox(width: BirdySpace.s),
                Text(
                  label,
                  maxLines: 1,
                  style: BirdyText.labelCompact.copyWith(color: c.text1),
                ),
                if (onPressed != null) ...[
                  const SizedBox(width: BirdySpace.xs),
                  Icon(
                    AppIcons.expandMore,
                    size: BirdySizes.modeChevron,
                    color: c.text2,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
    return Semantics(
      button: onPressed != null,
      label: l10n.forkLiveModeButton(label),
      onTap: onPressed,
      excludeSemantics: true,
      child: Pressable(enabled: onPressed != null, child: pill),
    );
  }
}

/// The pill wired to the stored listening mode: its name (« Personnalisé »
/// once the Settings sliders were moved by hand) and icon; a tap opens the
/// sheet, the change applies without stopping the listening.
class LiveListeningModePill extends ConsumerWidget {
  const LiveListeningModePill({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final mode = ref.watch(activeListeningModeProvider);
    return ListeningModePill(
      label: listeningModeLabel(l10n, mode),
      icon: listeningModeIcon(mode),
      onPressed: () => showListeningModeSheet(context, ref),
    );
  }
}
