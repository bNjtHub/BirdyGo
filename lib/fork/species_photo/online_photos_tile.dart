/// "Large photos (online)" switch, in Settings > Privacy and in the photo
/// credit sheet (fork/PLAN.md J6b).
library;

import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'species_photo_providers.dart';

class OnlinePhotosTile extends ConsumerWidget {
  const OnlinePhotosTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    return SwitchListTile(
      title: Text(l10n.forkOnlinePhotos),
      subtitle: Text(l10n.forkOnlinePhotosHint),
      value: ref.watch(onlinePhotosAllowedProvider),
      onChanged: (v) => ref.read(onlinePhotosAllowedProvider.notifier).set(v),
    );
  }
}
