/// Texts of the Bilan (J6c): title, date line, durations, novelty heading and
/// the summary shared with « Partager ».
library;

import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:intl/intl.dart';

import '../map/sensitive_species.dart';
import 'bilan_model.dart';

/// « Belle matinée ! », or the empty-outing title.
String bilanTitle(AppLocalizations l10n, BilanSummary summary) {
  if (summary.isEmpty) return l10n.forkBilanEmptyTitle;
  return switch (summary.moment) {
    BilanMoment.morning => l10n.forkBilanMorning,
    BilanMoment.afternoon => l10n.forkBilanAfternoon,
    BilanMoment.evening => l10n.forkBilanEvening,
    BilanMoment.night => l10n.forkBilanNight,
  };
}

/// « 7 h 12 » (fr), « 7:12 » (en).
String bilanClock(AppLocalizations l10n, DateTime time) {
  final local = time.toLocal();
  return l10n.forkBilanClock(
    '${local.hour}',
    local.minute.toString().padLeft(2, '0'),
  );
}

/// « Samedi 26 septembre · 7 h 12 – 7 h 54 · Beaulieu-sur-Brenne ».
String bilanDateLine(
  AppLocalizations l10n,
  String localeName,
  BilanSummary summary, {
  String? place,
}) {
  final day = DateFormat(
    'EEEE d MMMM',
    localeName,
  ).format(summary.start.toLocal());
  return [
    day.isEmpty ? day : day[0].toUpperCase() + day.substring(1),
    '${bilanClock(l10n, summary.start)} – ${bilanClock(l10n, summary.end)}',
    if (place != null && place.isNotEmpty) place,
  ].join(' · ');
}

/// « 42 min », « 1 h 05 ».
String bilanDuration(AppLocalizations l10n, Duration duration) {
  var minutes = (duration.inSeconds + 30) ~/ 60;
  if (minutes == 0 && duration > Duration.zero) minutes = 1;
  if (minutes < 60) return l10n.forkBilanMinutes(minutes);
  return l10n.forkBilanHoursMinutes(
    minutes ~/ 60,
    (minutes % 60).toString().padLeft(2, '0'),
  );
}

/// « Une nouvelle, peut-être deux », or null without novelty.
String? bilanNoveltyHeading(AppLocalizations l10n, BilanSummary summary) {
  final sure = summary.newVerified.length;
  final maybe = summary.newPending.length;
  if (sure == 0 && maybe == 0) return null;
  if (maybe == 0) return l10n.forkBilanNewSure(sure);
  if (sure == 0) return l10n.forkBilanNewMaybe(maybe);
  return l10n.forkBilanNewSureMaybe(sure, sure + maybe);
}

/// Plain-text summary for « Partager ». The place is left out when a
/// sensitive species was heard (same care as the exports, J5).
String bilanShareText(
  AppLocalizations l10n,
  String localeName,
  BilanSummary summary, {
  String? place,
}) {
  final sensitive = summary.species.any(
    (s) => isSensitiveSpecies(s.scientificName),
  );
  final numbers = [
    '${summary.species.length} ${l10n.forkLiveSpeciesStat(summary.species.length)}',
    '${summary.contacts} ${l10n.forkLiveContactsStat(summary.contacts)}',
    bilanDuration(l10n, summary.duration),
  ].join(' · ');
  return [
    bilanTitle(l10n, summary),
    bilanDateLine(l10n, localeName, summary, place: sensitive ? null : place),
    numbers,
    if (summary.species.isNotEmpty) '',
    for (final s in summary.species)
      '${s.commonName} ×${s.count}'
          '${s.pending ? ' (${l10n.forkBilanPendingNote})' : ''}',
    '',
    l10n.forkBilanShareFooter,
  ].join('\n');
}
