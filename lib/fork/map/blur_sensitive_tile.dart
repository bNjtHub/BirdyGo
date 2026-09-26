/// Settings tile of the export option that blurs sensitive species'
/// positions (fork/PLAN.md J5).
library;

import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/providers/app_providers.dart';
import 'sensitive_species.dart';

/// "Blur sensitive species" checkbox, in the export section.
class BlurSensitiveExportTile extends ConsumerStatefulWidget {
  const BlurSensitiveExportTile({super.key});

  @override
  ConsumerState<BlurSensitiveExportTile> createState() =>
      _BlurSensitiveExportTileState();
}

class _BlurSensitiveExportTileState
    extends ConsumerState<BlurSensitiveExportTile> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final prefs = ref.watch(sharedPreferencesProvider);
    return CheckboxListTile(
      dense: true,
      title: Text(l10n.forkBlurSensitiveExport),
      subtitle: Text(l10n.forkBlurSensitiveExportHint),
      value: prefs.getBool(kBlurSensitiveExportPref) ?? true,
      onChanged: (v) async {
        await prefs.setBool(kBlurSensitiveExportPref, v ?? true);
        if (mounted) setState(() {});
      },
    );
  }
}
