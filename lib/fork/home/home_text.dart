/// Texts of the home screen (J6c): greeting, date line, when the last bird
/// was heard.
library;

import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:intl/intl.dart';

import '../bilan/bilan_model.dart';
import '../bilan/bilan_text.dart';

/// « Bonjour », « Bon après-midi », « Bonsoir », « Bonne nuit » (same hours
/// as the Bilan's title).
String homeGreeting(AppLocalizations l10n, DateTime now) => switch (momentOf(
  now,
)) {
  BilanMoment.morning => l10n.forkHomeMorning,
  BilanMoment.afternoon => l10n.forkHomeAfternoon,
  BilanMoment.evening => l10n.forkHomeEvening,
  BilanMoment.night => l10n.forkHomeNight,
};

/// « Samedi 26 septembre · Beaulieu-sur-Brenne ».
String homeDateLine(String localeName, DateTime now, {String? place}) {
  final day = DateFormat('EEEE d MMMM', localeName).format(now.toLocal());
  return [
    day.isEmpty ? day : day[0].toUpperCase() + day.substring(1),
    if (place != null && place.isNotEmpty) place,
  ].join(' · ');
}

/// « 7 h 52 » today, « hier, 7 h 52 », else « 24 sept., 7 h 52 ».
String homeHeardWhen(
  AppLocalizations l10n,
  String localeName,
  DateTime time,
  DateTime now,
) {
  final local = time.toLocal();
  final clock = bilanClock(l10n, local);
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(local.year, local.month, local.day);
  // Rounded: a day is 23 or 25 hours long when the clocks change.
  final daysAgo = (today.difference(day).inHours / 24).round();
  if (daysAgo <= 0) return clock;
  if (daysAgo == 1) return l10n.forkHomeYesterdayAt(clock);
  return '${DateFormat('d MMM', localeName).format(local)}, $clock';
}
