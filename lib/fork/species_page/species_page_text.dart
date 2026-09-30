/// Sentences of the species page (J6c).
library;

import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:intl/intl.dart';

import '../data/observation_index.dart';
import '../../features/inference/geo_model.dart';
import '../ranking/species_activity_section.dart';
import '../species_sheet/species_sheet.dart';
import 'species_page_model.dart';

/// « Présent de mars à septembre. Pas attendu ici en ce moment. »
String presenceSentence(
  AppLocalizations l10n,
  String languageCode,
  YearPresence year, {
  required DateTime now,
}) {
  if (year.weeks.isNotEmpty) {
    final weekSpan = year.weekSpan;
    final head = switch (weekSpan.kind) {
      PresenceKind.allYear => l10n.forkFichePresentAllYear,
      PresenceKind.rare => l10n.forkFicheRare,
      PresenceKind.partOfYear => l10n.forkFichePresentPart,
      PresenceKind.range => l10n.forkFicheArrivesLeaves(
        weekPhrase(l10n, languageCode, weekSpan.from!),
        weekPhrase(l10n, languageCode, weekSpan.to!),
      ),
    };
    final absentNow =
        (weekSpan.kind == PresenceKind.range ||
            weekSpan.kind == PresenceKind.partOfYear) &&
        !year.presentInWeek(
          (GeoModel.dateTimeToWeek(now) - 1).clamp(0, weeksPerYear - 1),
        );
    return absentNow ? '$head ${l10n.forkFicheNotNow}' : head;
  }
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

/// « début mars », « vers la mi-mars », « fin mars » for week [index]
/// (0 to 47) of the geo-model year.
String weekPhrase(AppLocalizations l10n, String languageCode, int index) {
  final month = _monthName(languageCode, monthOfWeek(index));
  return switch (monthPartOfWeek(index)) {
    MonthPart.early => l10n.forkFicheWeekEarly(month),
    MonthPart.mid => l10n.forkFicheWeekMid(month),
    MonthPart.late => l10n.forkFicheWeekLate(month),
  };
}

/// « Nidification : avril à juillet ».
String nestingLegend(
  AppLocalizations l10n,
  String languageCode,
  NestingPeriod period,
) => l10n.forkFicheNestingRange(
  _monthName(languageCode, period.from),
  _monthName(languageCode, period.to),
);

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

/// Busiest month (1 to 12) of [months] (the geo-model's best week per
/// month, `YearPresence.months`), or null when every month is at zero
/// (J6f-b fix).
int? peakMonth(List<double> months) {
  var best = -1;
  for (var m = 0; m < months.length; m++) {
    if (months[m] > 0 && (best == -1 || months[m] > months[best])) best = m;
  }
  return best == -1 ? null : best + 1;
}

/// « Surtout en mai », the default caption under the seasons chart. Null
/// without any presence (J6f-b fix).
String? peakMonthCaption(
  AppLocalizations l10n,
  String languageCode,
  List<double> months,
) {
  final month = peakMonth(months);
  return month == null
      ? null
      : l10n.forkFichePeakMonth(_monthName(languageCode, month));
}

/// « Mai — 82 % du pic », the caption while a bar is selected: [percent] is
/// the month's share of the year's busiest month, 0 to 100 (J6f-b fix).
String monthDetailCaption(
  AppLocalizations l10n,
  String languageCode,
  int month,
  int percent,
) => l10n.forkFicheMonthDetail(_capitalized(_monthName(languageCode, month)), percent);

/// One summary for the whole seasons chart: the peak month, so its
/// semantics stay a single node instead of 12 (J6f-b fix, SPEC.md 9.13).
String seasonsChartSemanticLabel(
  AppLocalizations l10n,
  String languageCode,
  List<double> months,
) {
  final peak = peakMonthCaption(l10n, languageCode, months);
  final base = l10n.forkFichePresenceChart;
  return peak == null ? base : '$base. $peak';
}

String _capitalized(String text) =>
    text.isEmpty ? text : text[0].toUpperCase() + text.substring(1);
