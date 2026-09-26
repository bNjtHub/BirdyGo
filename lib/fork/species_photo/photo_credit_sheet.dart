/// Credit and license of the photo on screen (fork/PLAN.md J6b).
library;

import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

import '../../shared/services/link_launcher.dart';
import '../../shared/utils/app_icons.dart';
import 'online_photos_tile.dart';
import 'photo_credit.dart';

Future<void> showPhotoCreditSheet(BuildContext context, PhotoCredit credit) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => PhotoCreditSheet(credit: credit),
  );
}

/// License as the user reads it: "CC BY-NC", "All rights reserved"…
String photoLicenseText(AppLocalizations l10n, PhotoLicense license) =>
    switch (license.kind) {
      PhotoLicenseKind.reserved => l10n.forkPhotoAllRightsReserved,
      PhotoLicenseKind.publicDomain => l10n.forkPhotoPublicDomain,
      _ => license.label,
    };

class PhotoCreditSheet extends StatelessWidget {
  const PhotoCreditSheet({super.key, required this.credit});

  final PhotoCredit credit;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final license = credit.parsedLicense;
    final licenseUrl = license?.url;
    final pageUrl = credit.pageUrl;

    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                l10n.forkPhotoCredit,
                style: theme.textTheme.titleLarge,
              ),
            ),
            if (credit.isEmpty) ListTile(title: Text(l10n.forkPhotoNoCredit)),
            if (credit.author != null)
              ListTile(title: Text(l10n.forkPhotoAuthor(credit.author!))),
            if (license != null)
              ListTile(
                title: Text(
                  l10n.forkPhotoLicense(photoLicenseText(l10n, license)),
                ),
                trailing:
                    licenseUrl == null ? null : const Icon(AppIcons.openInNew),
                onTap:
                    licenseUrl == null
                        ? null
                        : () => openExternalUrl(context, licenseUrl),
              ),
            if (credit.source != null)
              ListTile(title: Text(l10n.forkPhotoSource(credit.source!))),
            if (pageUrl != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: OutlinedButton.icon(
                  onPressed: () => openExternalUrl(context, pageUrl),
                  icon: const Icon(AppIcons.openInNew),
                  label: Text(l10n.forkPhotoOpenPage),
                ),
              ),
            const Divider(),
            const OnlinePhotosTile(),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
