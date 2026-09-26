/// Summary of a garden count, to report on oiseauxdesjardins.fr (J5b).
library;

import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:intl/intl.dart';

import 'garden_count.dart';

/// « 1 h 05 » or « 42 min ».
String gardenDuration(AppLocalizations l10n, Duration duration) {
  final minutes = duration.inMinutes;
  if (minutes < 60) return l10n.forkGardenMinutes(minutes);
  return l10n.forkGardenHours(
    minutes ~/ 60,
    (minutes % 60).toString().padLeft(2, '0'),
  );
}

/// Lines of the summary: date, start and duration, then each species seen
/// with its largest number at once, and the totals. [names] gives the
/// displayed name of a scientific name.
List<String> gardenSummaryLines(
  AppLocalizations l10n,
  GardenCount count, {
  required String Function(String scientificName) names,
  required DateTime now,
}) {
  final start = count.start.toLocal();
  final seen = count.seen;
  final total = seen.values.fold<int>(0, (a, b) => a + b);
  return [
    l10n.forkGardenSummaryTitle(DateFormat('dd/MM/yyyy').format(start)),
    l10n.forkGardenSummaryTime(
      DateFormat('HH:mm').format(start),
      gardenDuration(l10n, count.elapsed(now)),
    ),
    for (final e in seen.entries)
      l10n.forkGardenSummaryLine(names(e.key), e.value),
    l10n.forkGardenSummaryTotal(seen.length, total),
  ];
}
