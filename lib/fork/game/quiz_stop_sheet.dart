/// « Arrêter la partie ? » (J6h): the sheet the cross of a « Qui chante ? »
/// round (and the system back) opens before leaving. The right answers of
/// the round are already counted for Oreille fine, and the sheet says so.
library;

import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

import '../design/birdy_tokens.dart';
import '../design/birdy_typography.dart';
import '../design/widgets/birdy_buttons.dart';
import '../design/widgets/birdy_sheet.dart';
import 'quiz_logo.dart';

/// Asks whether to stop the round. Resolves to true when the player chose
/// « Arrêter »; false for « Continuer » or a dismissed sheet.
Future<bool> showQuizStopSheet(
  BuildContext context, {
  required int right,
}) async {
  final stop = await showBirdySheet<bool>(
    context: context,
    builder: (_) => QuizStopSheet(right: right),
  );
  return stop ?? false;
}

class QuizStopSheet extends StatelessWidget {
  const QuizStopSheet({super.key, required this.right});

  /// Right answers so far in this round.
  final int right;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        BirdySpace.xl,
        BirdySpace.xs,
        BirdySpace.xl,
        BirdySpace.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // The quiz's own emblem, as on its Profil entry row.
          const ExcludeSemantics(
            child: QuizLogo(size: BirdySizes.quizSheetDisc),
          ),
          const SizedBox(height: BirdySpace.m),
          Semantics(
            header: true,
            child: Text(
              l10n.forkQuizStopTitle,
              textAlign: TextAlign.center,
              style: BirdyText.title.copyWith(color: c.text1),
            ),
          ),
          const SizedBox(height: BirdySpace.s),
          Text(
            l10n.forkQuizStopBody(right),
            textAlign: TextAlign.center,
            style: BirdyText.body.copyWith(color: c.text2),
          ),
          const SizedBox(height: BirdySpace.xl),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: BirdyButtonStyles.secondary(context),
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text(l10n.forkQuizStopYes),
                ),
              ),
              const SizedBox(width: BirdySpace.m),
              Expanded(
                child: FilledButton(
                  style: BirdyButtonStyles.primary(context),
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(l10n.forkQuizStopKeep),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
