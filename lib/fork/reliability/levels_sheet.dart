/// What « Sûr », « Probable », « À vérifier » and « Rare ici » mean, opened
/// from the Live screen's « i » button (fork/PLAN.md J6c-bis-c).
library;

import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

import '../../shared/utils/app_icons.dart';
import '../design/birdy_tokens.dart';
import '../design/birdy_typography.dart';
import '../design/widgets/birdy_pill.dart';
import 'reliability_badge.dart';
import 'reliability_config.dart';

/// [onHelp] and [onSettings] add the live screen's help and settings under
/// the levels (J6f: the listening mode pill took the menu's place).
Future<void> showLevelsSheet(
  BuildContext context, {
  VoidCallback? onHelp,
  VoidCallback? onSettings,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (_) => LevelsSheet(onHelp: onHelp, onSettings: onSettings),
  );
}

class LevelsSheet extends StatelessWidget {
  const LevelsSheet({super.key, this.onHelp, this.onSettings});

  final VoidCallback? onHelp;
  final VoidCallback? onSettings;

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
            if (onHelp != null || onSettings != null) ...[
              const SizedBox(height: BirdySpace.l),
              Divider(color: c.line, height: 1),
              const SizedBox(height: BirdySpace.s),
              if (onHelp != null)
                _SheetLink(
                  icon: AppIcons.helpOutlineRounded,
                  label: l10n.liveScreenHelpTitle,
                  onTap: onHelp!,
                ),
              if (onSettings != null)
                _SheetLink(
                  icon: AppIcons.tuneRounded,
                  label: l10n.settings,
                  onTap: onSettings!,
                ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Closes the sheet, then opens [onTap]'s screen or sheet.
class _SheetLink extends StatelessWidget {
  const _SheetLink({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = BirdyColors.of(context);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      minTileHeight: BirdySizes.target,
      leading: Icon(icon, color: c.text1),
      title: Text(label, style: BirdyText.label.copyWith(color: c.text1)),
      onTap: () {
        Navigator.of(context).pop();
        onTap();
      },
    );
  }
}
