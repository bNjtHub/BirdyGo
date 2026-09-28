/// « Options d'écoute » of the live header (J6f): one round button whose icon
/// is the active listening mode, and the sheet it opens (listening modes,
/// what the levels mean, help, settings).
library;

import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/utils/app_icons.dart';
import '../design/birdy_tokens.dart';
import '../design/birdy_typography.dart';
import '../design/widgets/birdy_buttons.dart';
import '../listening_mode/listening_mode.dart';
import '../listening_mode/listening_mode_config.dart';
import '../listening_mode/listening_mode_sheet.dart';
import '../reliability/levels_sheet.dart';

/// Icon of the options button: the mode's own icon, except Normal which
/// shows the neutral options icon (nothing special is on).
IconData listeningOptionsIcon(ListeningMode? mode) =>
    mode == ListeningMode.normal
        ? AppIcons.tuneRounded
        : listeningModeIcon(mode);

/// Round 48 dp button « Options d'écoute ». [mode] null means the Settings
/// sliders were moved by hand (« Personnalisé »).
class ListeningOptionsButton extends StatelessWidget {
  const ListeningOptionsButton({
    super.key,
    required this.mode,
    required this.onPressed,
  });

  final ListeningMode? mode;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final label = l10n.forkLiveOptionsButton(listeningModeLabel(l10n, mode));
    // One node read « Options d'écoute, mode Vent », as a button.
    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: label,
      onTap: onPressed,
      excludeSemantics: true,
      child: BirdyIconButton(
        icon: listeningOptionsIcon(mode),
        semanticLabel: label,
        onPressed: onPressed,
      ),
    );
  }
}

/// Opens the options sheet. [onHelp] and [onSettings] run once the sheet is
/// closed; the levels open on top of it, so going back returns to it.
Future<void> showListeningOptionsSheet(
  BuildContext context, {
  required VoidCallback onHelp,
  required VoidCallback onSettings,
}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    useSafeArea: true,
    isScrollControlled: true,
    builder:
        (_) => ListeningOptionsSheet(
          onHelp: onHelp,
          onSettings: onSettings,
          messenger: messenger,
        ),
  );
}

class ListeningOptionsSheet extends ConsumerWidget {
  const ListeningOptionsSheet({
    super.key,
    required this.onHelp,
    required this.onSettings,
    this.messenger,
    this.cityEnabled = kCityModeEnabled,
  });

  final VoidCallback onHelp;
  final VoidCallback onSettings;

  /// Shows « Mode Vent activé » after a pick; the opener's by default.
  final ScaffoldMessengerState? messenger;

  /// Whether « Ville » is offered; [kCityModeEnabled] by default.
  final bool cityEnabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
    void thenClose(VoidCallback action) {
      Navigator.of(context).pop();
      action();
    }

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          BirdySpace.gutter,
          0,
          BirdySpace.gutter,
          BirdySpace.xxl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListeningModeSection(
              cityEnabled: cityEnabled,
              onSelected:
                  (mode) => applyListeningModeChoice(
                    context,
                    ref,
                    mode,
                    messenger: messenger ?? ScaffoldMessenger.maybeOf(context),
                  ),
            ),
            const SizedBox(height: BirdySpace.s),
            Divider(color: c.line, height: 1),
            const SizedBox(height: BirdySpace.s),
            _OptionRow(
              key: const ValueKey('listening-options-levels'),
              icon: AppIcons.infoOutline,
              label: l10n.forkLiveOptionsLevels,
              opensMore: true,
              onTap: () => showLevelsSheet(context),
            ),
            _OptionRow(
              key: const ValueKey('listening-options-help'),
              icon: AppIcons.helpOutlineRounded,
              label: l10n.liveScreenHelpTitle,
              onTap: () => thenClose(onHelp),
            ),
            _OptionRow(
              key: const ValueKey('listening-options-settings'),
              icon: AppIcons.tuneRounded,
              label: l10n.settings,
              onTap: () => thenClose(onSettings),
            ),
          ],
        ),
      ),
    );
  }
}

class _OptionRow extends StatelessWidget {
  const _OptionRow({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.opensMore = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  /// Opens another sheet on top: a chevron says so.
  final bool opensMore;

  @override
  Widget build(BuildContext context) {
    final c = BirdyColors.of(context);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      minTileHeight: BirdySizes.target,
      leading: Icon(icon, color: c.text1),
      title: Text(label, style: BirdyText.label.copyWith(color: c.text1)),
      trailing: opensMore ? Icon(AppIcons.chevronRight, color: c.text2) : null,
      onTap: onTap,
    );
  }
}
