/// The online-map consent dialog (`mapTileConsent*` strings), shared by the
/// fork screens that need it: asks, and on « Allow » turns
/// `privacyAllowMapProvider` on. Returns whether the consent is now given.
library;

import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/providers/settings_providers.dart';

Future<bool> requestMapTileConsent(BuildContext context, WidgetRef ref) async {
  final l10n = AppLocalizations.of(context)!;
  final agreed = await showDialog<bool>(
    context: context,
    builder:
        (context) => AlertDialog(
          title: Text(l10n.mapTileConsentTitle),
          content: Text(l10n.mapTileConsentBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.mapTileConsentCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l10n.mapTileConsentAllow),
            ),
          ],
        ),
  );
  if (agreed != true) return false;
  await ref.read(privacyAllowMapProvider.notifier).set(true);
  return true;
}
