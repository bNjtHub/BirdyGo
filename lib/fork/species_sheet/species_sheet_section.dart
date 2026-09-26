/// The AI species sheet inside the species overlay (fork/PLAN.md J4b).
library;

import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'species_sheet.dart';

/// Section title, localized.
String sheetSectionTitle(AppLocalizations l10n, SheetSection section) =>
    switch (section) {
      SheetSection.summary => l10n.forkSheetSummary,
      SheetSection.size => l10n.forkSheetSize,
      SheetSection.behaviour => l10n.forkSheetBehaviour,
      SheetSection.whyHere => l10n.forkSheetWhyHere,
      SheetSection.migration => l10n.forkSheetMigration,
      SheetSection.byEar => l10n.forkSheetByEar,
      SheetSection.confusions => l10n.forkSheetConfusions,
      SheetSection.anecdote => l10n.forkSheetAnecdote,
    };

/// Shows the species sheet, or nothing when there is none to show.
class SpeciesSheetSection extends ConsumerWidget {
  const SpeciesSheetSection({super.key, required this.scientificName});

  final String scientificName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sheet = watchSpeciesSheet(ref, scientificName);
    if (sheet == null || sheet.sections.isEmpty) return const SizedBox.shrink();
    return SpeciesSheetView(sheet: sheet);
  }
}

/// Layout of a sheet: the summary as a lead, then titled sections.
class SpeciesSheetView extends StatelessWidget {
  const SpeciesSheetView({super.key, required this.sheet});

  final SpeciesSheet sheet;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final summary = sheet.sections[SheetSection.summary];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (summary != null)
            Text(
              summary,
              style: theme.textTheme.bodyLarge?.copyWith(height: 1.45),
            ),
          for (final entry in sheet.sections.entries)
            if (entry.key != SheetSection.summary) ...[
              const SizedBox(height: 16),
              Text(
                sheetSectionTitle(l10n, entry.key),
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                entry.value,
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
              ),
            ],
          const SizedBox(height: 12),
          Text(
            l10n.forkSheetFooter,
            style: theme.textTheme.bodySmall?.copyWith(
              color: muted,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}
