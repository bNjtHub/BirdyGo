/// Texts of the listening summary: headline, caption, duration and the
/// shared text.
library;

import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:intl/intl.dart';

import 'listening_summary.dart';

/// « Belle matinée ! », or « Écoute calme » without any bird.
String summaryHeadline(AppLocalizations l10n, ListeningSummary summary) =>
    summary.isEmpty
        ? l10n.forkSummaryQuietHeadline
        : l10n.forkSummaryHeadline(summary.dayPart.name);

/// « 42 min », « 1 h 05 ».
String summaryDuration(AppLocalizations l10n, Duration duration) {
  final minutes = (duration.inSeconds / 60).round();
  if (minutes < 60) return l10n.forkSummaryMinutes(minutes);
  return l10n.forkSummaryHoursMinutes(
    minutes ~/ 60,
    (minutes % 60).toString().padLeft(2, '0'),
  );
}

/// Clock time in the app language (« 07:26 »).
String summaryTime(AppLocalizations l10n, DateTime time) =>
    DateFormat.Hm(l10n.localeName).format(time.toLocal());

/// « Samedi 26 septembre · 07:12 – 07:54 · Beaulieu-sur-Brenne ».
String summaryCaption(
  AppLocalizations l10n,
  ListeningSummary summary, {
  String? place,
}) {
  final day = DateFormat.MMMMEEEEd(
    l10n.localeName,
  ).format(summary.start.toLocal());
  return [
    day.isEmpty ? day : day[0].toUpperCase() + day.substring(1),
    '${summaryTime(l10n, summary.start)} – ${summaryTime(l10n, summary.end)}',
    if (place != null && place.isNotEmpty) place,
  ].join(' · ');
}

/// Text shared from the summary. Names only the species that are « Sûr »
/// or confirmed, and never the place: a shared list must not point to a
/// sensitive species' spot.
String summaryShareText(
  AppLocalizations l10n,
  ListeningSummary summary, {
  required String Function(SummarySpecies species) nameOf,
}) {
  final verified = [
    for (final s in summary.species)
      if (!s.pending) s,
  ];
  final pending = summary.species.length - verified.length;
  return [
    summaryHeadline(l10n, summary),
    l10n.forkSummaryShareHeader(
      summary.species.length,
      summary.contacts,
      summaryDuration(l10n, summary.duration),
    ),
    if (verified.isNotEmpty) '',
    for (final s in verified) '${nameOf(s)} ×${s.count}',
    if (pending > 0) ...['', l10n.forkSummaryShareToCheck(pending)],
  ].join('\n');
}
