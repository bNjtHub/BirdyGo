/// Species sheet section: one sentence and two activity charts (J4).
library;

import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import '../design/birdy_tokens.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../data/observation_index.dart' show SpeciesTally;
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
}) => l10n.forkHeardSentence(
  contacts,
  days,
  lastHeardWhen(l10n, languageCode, last, now: now),
);

/// « aujourd'hui à 7 h 42 », « hier à 7 h 42 », « le 12 sept. à 8 h 03 ».
String lastHeardWhen(
  AppLocalizations l10n,
  String languageCode,
  DateTime time, {
  required DateTime now,
}) {
  final local = time.toLocal();
  final clock = shortTime(local, languageCode);
  return switch (relativeDay(local, now)) {
    0 => l10n.forkLastToday(clock),
    1 => l10n.forkLastYesterday(clock),
    _ => l10n.forkLastOn(DateFormat.MMMd(languageCode).format(local), clock),
  };
}

/// Sentence plus hour and month charts for one species; empty if never
/// heard.
class SpeciesActivitySection extends ConsumerStatefulWidget {
  const SpeciesActivitySection({super.key, required this.scientificName});

  final String scientificName;

  @override
  ConsumerState<SpeciesActivitySection> createState() =>
      _SpeciesActivitySectionState();
}

class _SpeciesActivitySectionState
    extends ConsumerState<SpeciesActivitySection> {
  // Perf: the three queries run once per species and index change, not at
  // every rebuild of the parent.
  Future<(SpeciesTally?, List<int>, List<int>)>? _data;
  String? _loadedFor;

  Future<(SpeciesTally?, List<int>, List<int>)> _load() {
    final name = widget.scientificName;
    final service = ref.read(observationIndexServiceProvider);
    return service.ensureReady().then(
      (index) async => (
        await index.speciesTally(name),
        await index.activityByHour(scientificName: name),
        await index.activityByMonth(scientificName: name),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scientificName = widget.scientificName;
    ref.listen(observationIndexServiceProvider, (_, _) {
      if (mounted) setState(() => _loadedFor = null);
    });
    if (_loadedFor != scientificName) {
      _loadedFor = scientificName;
      _data = _load();
    }
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final language = Localizations.localeOf(context).languageCode;
    return FutureBuilder(
      future: _data,
      builder: (context, snapshot) {
        final value = snapshot.data;
        final tally = value?.$1;
        if (value == null || tally == null) return const SizedBox.shrink();
        final months = DateFormat.MMMMd(language).dateSymbols.NARROWMONTHS;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: BirdySpace.s),
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
              const SizedBox(height: BirdySpace.l),
              Text(l10n.forkActivityByHour, style: theme.textTheme.titleSmall),
              const SizedBox(height: BirdySpace.s),
              ActivityBars(
                values: value.$2,
                labels: const {0: '0 h', 6: '6 h', 12: '12 h', 18: '18 h'},
                semanticLabel: l10n.forkActivityByHour,
              ),
              const SizedBox(height: BirdySpace.l),
              Text(l10n.forkActivityByMonth, style: theme.textTheme.titleSmall),
              const SizedBox(height: BirdySpace.s),
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
