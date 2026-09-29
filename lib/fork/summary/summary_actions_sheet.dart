/// « Autres actions » sheet of the Bilan (J6h): the four secondary actions
/// of a listening summary as [BirdyListRow]s. Each row runs the callback the
/// screen already wired; a null callback hides its row.
library;

import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

import '../../shared/utils/app_icons.dart';
import '../design/birdy_tokens.dart';
import '../design/widgets/birdy_list_block.dart';
import '../design/widgets/birdy_list_row.dart';
import '../design/widgets/birdy_sheet.dart';

/// True when at least one action would show in the sheet.
bool hasSummaryActions({
  VoidCallback? onSend,
  VoidCallback? onAddObservation,
  VoidCallback? onDetails,
  void Function(bool recording)? onMarkRecording,
}) =>
    onSend != null ||
    onAddObservation != null ||
    onDetails != null ||
    onMarkRecording != null;

/// Opens the sheet. Rows close it before running their action.
Future<void> showSummaryActionsSheet(
  BuildContext context, {
  required bool isRecording,
  bool savingObservation = false,
  VoidCallback? onSend,
  VoidCallback? onAddObservation,
  VoidCallback? onDetails,
  void Function(bool recording)? onMarkRecording,
}) => showBirdySheet<void>(
  context: context,
  isScrollControlled: true,
  builder:
      (_) => SummaryActionsSheet(
        isRecording: isRecording,
        savingObservation: savingObservation,
        onSend: onSend,
        onAddObservation: onAddObservation,
        onDetails: onDetails,
        onMarkRecording: onMarkRecording,
      ),
);

class SummaryActionsSheet extends StatelessWidget {
  const SummaryActionsSheet({
    super.key,
    this.isRecording = false,
    this.savingObservation = false,
    this.onSend,
    this.onAddObservation,
    this.onDetails,
    this.onMarkRecording,
  });

  final bool isRecording;
  final bool savingObservation;
  final VoidCallback? onSend;
  final VoidCallback? onAddObservation;
  final VoidCallback? onDetails;

  /// Marks the session as a recording (true) or back as real birds (false).
  final void Function(bool recording)? onMarkRecording;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // Closes the sheet first, so the action opens over the Bilan.
    VoidCallback? closing(VoidCallback? action) =>
        action == null
            ? null
            : () {
              Navigator.of(context).pop();
              action();
            };
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        BirdySpace.page,
        0,
        BirdySpace.page,
        BirdySpace.page,
      ),
      child: BirdyListBlock(
        title: l10n.forkSummaryMoreActions,
        children: [
          if (onSend != null)
            BirdyListRow(
              icon: AppIcons.send,
              title: l10n.forkSummarySendFauneFrance,
              subtitle: l10n.forkSummarySendFauneFranceHint,
              onTap: closing(onSend),
            ),
          if (onAddObservation != null)
            BirdyListRow(
              icon: AppIcons.add,
              title: l10n.forkSummaryAddObservation,
              subtitle: l10n.forkSummaryAddObservationHint,
              onTap: savingObservation ? null : closing(onAddObservation),
            ),
          if (onDetails != null)
            BirdyListRow(
              icon: AppIcons.detections,
              title: l10n.forkSummaryDetailsRow,
              subtitle: l10n.forkSummaryDetailsHint,
              onTap: closing(onDetails),
            ),
          if (onMarkRecording != null)
            BirdyListRow(
              icon: AppIcons.mic,
              title:
                  isRecording
                      ? l10n.forkPracticeUnmark
                      : l10n.forkSummaryMarkRecording,
              subtitle:
                  isRecording
                      ? l10n.forkSummaryUnmarkHint
                      : l10n.forkSummaryMarkRecordingHint,
              onTap: closing(() => onMarkRecording!(!isRecording)),
            ),
        ],
      ),
    );
  }
}
