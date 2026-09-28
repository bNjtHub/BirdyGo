/// Bottom sheet « Conditions d'écoute » (fork/PLAN.md J6f).
library;

import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/utils/app_icons.dart';
import '../design/birdy_tokens.dart';
import '../design/birdy_typography.dart';
import 'listening_mode.dart';
import 'listening_mode_config.dart';

/// Opens the mode picker. Picking a mode applies it at once (listening keeps
/// going), closes the sheet and confirms with a snackbar.
Future<void> showListeningModeSheet(BuildContext context, WidgetRef ref) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    useSafeArea: true,
    isScrollControlled: true,
    builder:
        (sheetContext) => ListeningModeSheet(
          onSelected:
              (mode) => applyListeningModeChoice(
                sheetContext,
                ref,
                mode,
                messenger: messenger,
              ),
        ),
  );
}

/// Closes the sheet of [sheetContext], applies [mode] (listening keeps going)
/// and confirms it in [messenger] (« Mode Vent activé »).
Future<void> applyListeningModeChoice(
  BuildContext sheetContext,
  WidgetRef ref,
  ListeningMode mode, {
  ScaffoldMessengerState? messenger,
}) async {
  final l10n = AppLocalizations.of(sheetContext)!;
  final c = BirdyColors.of(sheetContext);
  // Read before the pop: the sheet's ref goes with it.
  final modes = ref.read(listeningModeProvider.notifier);
  Navigator.of(sheetContext).pop();
  await modes.select(mode);
  messenger
    ?..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: c.surface3,
        content: Row(
          children: [
            Icon(mode.icon, size: 20, color: listeningModeColor(c, mode)),
            const SizedBox(width: BirdySpace.s),
            Expanded(
              child: Text(
                l10n.forkListeningModeActivated(listeningModeLabel(l10n, mode)),
                style: BirdyText.bodyCompact.copyWith(color: c.text1),
              ),
            ),
          ],
        ),
      ),
    );
}

class ListeningModeSheet extends StatelessWidget {
  const ListeningModeSheet({
    super.key,
    required this.onSelected,
    this.cityEnabled = kCityModeEnabled,
  });

  final ValueChanged<ListeningMode> onSelected;

  /// Whether « Ville » is offered; [kCityModeEnabled] by default.
  final bool cityEnabled;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        BirdySpace.gutter,
        0,
        BirdySpace.gutter,
        BirdySpace.xxl,
      ),
      child: ListeningModeSection(
        onSelected: onSelected,
        cityEnabled: cityEnabled,
      ),
    ),
  );
}

/// « Conditions d'écoute »: title, subtitle and one option per mode, the
/// active one checked. The body of [ListeningModeSheet] and the first section
/// of the live options sheet.
class ListeningModeSection extends ConsumerWidget {
  const ListeningModeSection({
    super.key,
    required this.onSelected,
    this.cityEnabled = kCityModeEnabled,
  });

  final ValueChanged<ListeningMode> onSelected;

  /// Whether « Ville » is offered; [kCityModeEnabled] by default.
  final bool cityEnabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
    final active = ref.watch(activeListeningModeProvider);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(
            l10n.forkListeningModeTitle,
            style: BirdyText.heading.copyWith(color: c.text1),
          ),
        ),
        const SizedBox(height: BirdySpace.xs),
        Text(
          l10n.forkListeningModeSubtitle,
          style: BirdyText.caption.copyWith(color: c.text2),
        ),
        const SizedBox(height: BirdySpace.l),
        for (final mode in availableListeningModes(
          cityEnabled: cityEnabled,
        )) ...[
          _ModeOption(
            mode: mode,
            selected: mode == active,
            onTap: () => onSelected(mode),
          ),
          const SizedBox(height: BirdySpace.s),
        ],
      ],
    );
  }
}

class _ModeOption extends StatelessWidget {
  const _ModeOption({
    required this.mode,
    required this.selected,
    required this.onTap,
  });

  final ListeningMode mode;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
    final modeColor = listeningModeColor(c, mode);
    final radius = BorderRadius.circular(BirdyRadii.inset);
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? c.surface2 : c.surface1,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(
            color: selected ? c.accentText : c.borderOpaque,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: InkWell(
          key: ValueKey('listening-mode-${mode.name}'),
          borderRadius: radius,
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: BirdySizes.target),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: BirdySpace.l,
                vertical: BirdySpace.m,
              ),
              child: Row(
                children: [
                  // Always the mode's own color, selected or not: the outline
                  // and the check already say which one is active (J6f).
                  Icon(mode.icon, size: 24, color: modeColor),
                  const SizedBox(width: BirdySpace.m),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          listeningModeLabel(l10n, mode),
                          style: BirdyText.bodyCompact.copyWith(
                            color: modeColor,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          listeningModeDescription(l10n, mode),
                          style: BirdyText.caption.copyWith(color: c.text2),
                        ),
                      ],
                    ),
                  ),
                  if (selected) ...[
                    const SizedBox(width: BirdySpace.s),
                    Icon(
                      AppIcons.listeningSelected,
                      size: 22,
                      color: c.accentText,
                      semanticLabel: l10n.forkListeningModeSelected,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
