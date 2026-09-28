/// One-time tip at the first Live listening (fork/PLAN.md J2b): listening
/// goes on with the screen off, and HyperOS-like systems need « no battery
/// restriction » for it to last. Android only.
library;

import 'dart:io';

import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/providers/app_providers.dart';

import '../design/birdy_tokens.dart';
import '../design/birdy_typography.dart';
import '../design/widgets/birdy_buttons.dart';
import '../design/widgets/birdy_sheet.dart';

/// Preference set once the tip has been shown.
const String kBackgroundTipShownKey = 'fork_background_tip_shown';

/// Shows the tip unless it was already shown (or not on Android).
Future<void> showBackgroundTipOnce(
  BuildContext context,
  WidgetRef ref, {
  bool? android,
}) async {
  if (!(android ?? Platform.isAndroid)) return;
  final prefs = ref.read(sharedPreferencesProvider);
  if (prefs.getBool(kBackgroundTipShownKey) ?? false) return;
  await prefs.setBool(kBackgroundTipShownKey, true);
  if (!context.mounted) return;
  await showBirdySheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => const BackgroundTipSheet(),
  );
}

class BackgroundTipSheet extends StatelessWidget {
  const BackgroundTipSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        BirdySpace.gutter,
        0,
        BirdySpace.gutter,
        BirdySpace.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.forkBackgroundTipTitle,
            style: BirdyText.heading.copyWith(color: c.text1),
          ),
          const SizedBox(height: BirdySpace.s),
          Text(
            l10n.forkBackgroundTipBody,
            style: BirdyText.body.copyWith(color: c.text1),
          ),
          const SizedBox(height: BirdySpace.l),
          FilledButton(
            style: BirdyButtonStyles.primary(context),
            onPressed: () {
              Navigator.of(context).pop();
              openAppSettings();
            },
            child: Text(l10n.forkBackgroundTipSettings),
          ),
          const SizedBox(height: BirdySpace.s),
          OutlinedButton(
            style: BirdyButtonStyles.secondary(context),
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.forkBackgroundTipLater),
          ),
        ],
      ),
    );
  }
}
