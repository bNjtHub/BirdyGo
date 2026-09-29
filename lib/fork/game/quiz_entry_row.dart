/// « Qui chante ? » entry row (J6h): the same row as the Profil's quiz entry
/// (`_QuizEntry` in profile_screen.dart), shared so other screens (the
/// species page) can show it with their own subtitle.
library;

import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

import '../../shared/utils/app_icons.dart';
import '../design/birdy_tokens.dart';
import '../design/birdy_typography.dart';
import '../design/widgets/pressable.dart';
import 'fine_ear_quiz_screen.dart';
import 'quiz_logo.dart';

class QuizEntryRow extends StatelessWidget {
  const QuizEntryRow({
    super.key,
    this.subtitle,
    this.onTap,
    this.bordered = false,
  });

  /// Defaults to the Profil's line.
  final String? subtitle;

  /// Defaults to opening the quiz.
  final VoidCallback? onTap;

  /// A hairline outline (the Profil's look, on its background).
  final bool bordered;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
    final line = subtitle ?? l10n.forkQuizEntrySubtitle;
    return Semantics(
      label: '${l10n.forkQuizTitle}. $line',
      button: true,
      excludeSemantics: true,
      child: Pressable(
        child: Material(
          color: c.surface1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(BirdyRadii.card),
            side: bordered ? BorderSide(color: c.line) : BorderSide.none,
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap:
                onTap ??
                () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const FineEarQuizScreen(),
                  ),
                ),
            child: Padding(
              padding: const EdgeInsets.all(BirdySpace.l),
              child: Row(
                children: [
                  const ExcludeSemantics(child: QuizLogo()),
                  const SizedBox(width: BirdySpace.l),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.forkQuizTitle,
                          style: BirdyText.heading.copyWith(color: c.text1),
                        ),
                        const SizedBox(height: BirdySpace.xs),
                        Text(
                          line,
                          style: BirdyText.bodyCompact.copyWith(color: c.text2),
                        ),
                      ],
                    ),
                  ),
                  Icon(AppIcons.chevronRight, color: c.text2),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
