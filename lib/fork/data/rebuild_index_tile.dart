/// Settings tile that rebuilds the observation index from the sessions.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:birdnet_live/l10n/app_localizations.dart';
import '../../shared/utils/app_icons.dart';
import 'observation_index_service.dart';

/// "Rebuild the observation index" entry for the settings screen.
class RebuildObservationIndexTile extends ConsumerWidget {
  const RebuildObservationIndexTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final service = ref.watch(observationIndexServiceProvider);
    return ListTile(
      leading: const Icon(AppIcons.refresh),
      title: Text(l10n.forkRebuildIndex),
      subtitle: Text(
        service.isRebuilding
            ? l10n.forkRebuildIndexRunning
            : l10n.forkRebuildIndexSubtitle,
      ),
      enabled: !service.isRebuilding,
      onTap: () async {
        final messenger = ScaffoldMessenger.of(context);
        await ref.read(observationIndexServiceProvider).rebuild();
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.forkRebuildIndexDone)),
        );
      },
    );
  }
}
