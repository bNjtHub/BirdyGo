/// Sentences of the species page (J6c).
library;

import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:intl/intl.dart';

import '../data/observation_index.dart';
import '../ranking/species_activity_section.dart';
import 'species_page_model.dart';

/// « Présent de mars à septembre. Pas attendu ici en ce moment. »
String presenceSentence(
  AppLocalizations l10n,
  String languageCode,
  YearPresence year, {
  required DateTime now,
}) {
  final span = year.span;
  final head = switch (span.kind) {
    PresenceKind.allYear => l10n.forkFichePresentAllYear,
    PresenceKind.rare => l10n.forkFicheRare,
    PresenceKind.partOfYear => l10n.forkFichePresentPart,
    PresenceKind.range => l10n.forkFichePresentRange(
      _fromMonth(l10n, _monthName(languageCode, span.from!)),
      _monthName(languageCode, span.to!),
    ),
  };
  final absentNow =
      (span.kind == PresenceKind.range ||
          span.kind == PresenceKind.partOfYear) &&
      !year.presentIn(now.month);
  return absentNow ? '$head ${l10n.forkFicheNotNow}' : head;
}

String _monthName(String languageCode, int month) =>
    DateFormat.MMMM(languageCode).format(DateTime(2026, month));

/// « de mars », « d'avril » (French elides before a vowel).
String _fromMonth(AppLocalizations l10n, String month) =>
    RegExp(r'^[aeiouyàâéèêîôû]', caseSensitive: false).hasMatch(month)
        ? l10n.forkFicheFromMonthVowel(month)
        : l10n.forkFicheFromMonth(month);

/// « janv. – déc. » under the month bars.
String monthsCaption(String languageCode) {
  final format = DateFormat.MMM(languageCode);
  return '${format.format(DateTime(2026))} – '
      '${format.format(DateTime(2026, 12))}';
}

/// « 0,97 · aujourd'hui à 7 h 41 ».
String clipLine(
  AppLocalizations l10n,
  String languageCode,
  IndexedDetection clip, {
  required DateTime now,
}) {
  final score = NumberFormat('0.00', languageCode).format(clip.confidence);
  return '$score · ${lastHeardWhen(l10n, languageCode, clip.start, now: now)}';
}

/// Share text: names, then the user's own count when there is one. No
/// place, like the summary's share.
String speciesShareText({required String name, String? latin, String? heard}) {
  final title = latin == null ? name : '$name ($latin)';
  return heard == null ? title : '$title\n$heard';
}

/// Busiest local hour (0 to 23) of [hours] (24 values), or null when every
/// hour is at zero (J6f-b fix).
int? peakHour(List<int> hours) {
  var best = -1;
  for (var h = 0; h < hours.length; h++) {
    if (hours[h] > 0 && (best == -1 || hours[h] > hours[best])) best = h;
  }
  return best == -1 ? null : best;
}

/// « Surtout vers 7 h », the default caption under the activity-by-hour
/// chart. Null without any activity (J6f-b fix).
String? peakHourCaption(AppLocalizations l10n, List<int> hours) {
  final hour = peakHour(hours);
  return hour == null ? null : l10n.forkFichePeakHour(hour);
}

/// « 7 h — 42 contacts », the caption while a bar is selected (J6f-b fix).
String hourDetailCaption(AppLocalizations l10n, int hour, int count) =>
    // Generated signature puts the plural argument (count) first.
    l10n.forkFicheHourDetail(count, hour);

/// One summary for the whole activity-by-hour chart: the peak hour and the
/// total, so its semantics stay a single node instead of 24 (J6f-b fix,
/// SPEC.md 9.13).
String activityByHourSemanticLabel(AppLocalizations l10n, List<int> hours) {
  final peak = peakHourCaption(l10n, hours);
  final total = hours.fold<int>(0, (sum, h) => sum + h);
  final base = l10n.forkActivityByHour;
  return peak == null ? base : '$base. $peak. ${l10n.forkFicheHourTotal(total)}';
}
