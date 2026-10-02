/// The app's short confirmation toast: a floating, Birdy-styled snack bar.
/// Used when a value is committed without a visible change in place (a text
/// field, a picker that closes). Switches and chips are their own feedback.
library;

import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

import '../birdy_tokens.dart';
import '../birdy_typography.dart';

/// Shows [message] as a toast in the nearest messenger, replacing any
/// current one; its live region announces it to screen readers.
void showBirdyToast(BuildContext context, String message) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  final c = BirdyColors.of(context);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: c.surface3,
        duration: const Duration(seconds: 2),
        content: Semantics(
          liveRegion: true,
          child: Text(
            message,
            style: BirdyText.bodyCompact.copyWith(color: c.text1),
          ),
        ),
      ),
    );
}

/// « {setting} : {value} » toast after a choice made in a picker.
void showSettingSaved(BuildContext context, String setting, String value) =>
    showBirdyToast(
      context,
      AppLocalizations.of(context)!.forkSettingSaved(setting, value),
    );

/// « Prénom enregistré » toast.
void showFirstNameSaved(BuildContext context) =>
    showBirdyToast(context, AppLocalizations.of(context)!.forkFirstNameSaved);
