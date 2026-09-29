/// "Large photos (online)" switch, in Settings > Privacy, in the simple
/// settings and in the photo credit sheet (fork/PLAN.md J6b, J6g-c).
library;

import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../settings/birdy_switch_row.dart';
import 'species_photo_providers.dart';

class OnlinePhotosTile extends ConsumerWidget {
  const OnlinePhotosTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    return BirdySwitchRow(
      title: l10n.forkOnlinePhotos,
      hint: l10n.forkOnlinePhotosHint,
      value: ref.watch(onlinePhotosAllowedProvider),
      onChanged: (v) => ref.read(onlinePhotosAllowedProvider.notifier).set(v),
    );
  }
}
