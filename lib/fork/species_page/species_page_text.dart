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
