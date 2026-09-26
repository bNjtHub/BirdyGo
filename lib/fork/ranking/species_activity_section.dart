/// Species sheet section: one sentence and two activity charts (J4).
library;

import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../data/observation_index_service.dart';
import 'activity_bars.dart';
import 'ranking_logic.dart';

/// "Entendu 23 fois sur 9 jours, la dernière fois hier à 7 h 42".
String heardSentence(
  AppLocalizations l10n,
  String languageCode, {
  required int contacts,
  required int days,
  required DateTime last,
  required DateTime now,
}) {
  final local = last.toLocal();
  final time = shortTime(local, languageCode);
  final when = switch (relativeDay(local, now)) {
    0 => l10n.forkLastToday(time),
    1 => l10n.forkLastYesterday(time),
    _ => l10n.forkLastOn(DateFormat.MMMd(languageCode).format(local), time),
  };
  return l10n.forkHeardSentence(contacts, days, when);
}

/// Sentence plus hour and month charts for one species; empty if never
/// heard.
class SpeciesActivitySection extends ConsumerWidget {
  const SpeciesActivitySection({super.key, required this.scientificName});

  final String scientificName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final language = Localizations.localeOf(context).languageCode;
    final service = ref.watch(observationIndexServiceProvider);
    final data = service.ensureReady().then(
      (index) async => (
        await index.speciesTally(scientificName),
        await index.activityByHour(scientificName: scientificName),
        await index.activityByMonth(scientificName: scientificName),
      ),
    );
    return FutureBuilder(
      future: data,
      builder: (context, snapshot) {
        final value = snapshot.data;
        final tally = value?.$1;
        if (value == null || tally == null) return const SizedBox.shrink();
        final months = DateFormat.MMMMd(language).dateSymbols.NARROWMONTHS;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                heardSentence(
                  l10n,
                  language,
                  contacts: tally.contacts,
                  days: tally.days,
                  last: tally.last,
                  now: DateTime.now(),
                ),
                style: theme.textTheme.bodyLarge,
              ),
              const SizedBox(height: 16),
              Text(l10n.forkActivityByHour, style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              ActivityBars(
                values: value.$2,
                labels: const {0: '0 h', 6: '6 h', 12: '12 h', 18: '18 h'},
                semanticLabel: l10n.forkActivityByHour,
              ),
              const SizedBox(height: 16),
              Text(l10n.forkActivityByMonth, style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              ActivityBars(
                values: value.$3,
                labels: {for (var i = 0; i < 12; i++) i: months[i]},
                semanticLabel: l10n.forkActivityByMonth,
              ),
            ],
          ),
        );
      },
    );
  }
}
