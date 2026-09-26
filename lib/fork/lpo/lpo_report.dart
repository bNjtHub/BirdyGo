/// Text of an LPO card, shown on screen and copied as is (J5b).
library;

import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:intl/intl.dart';

import 'atlas_codes.dart';
import 'lpo_observation.dart';

/// What the observer answered and chose for one observation.
class LpoCardChoices {
  const LpoCardChoices({
    required this.seen,
    this.count = 1,
    this.atlasCode,
    this.hideData = false,
  });

  /// Answer to « Tu l'as vu ? ».
  final bool seen;

  /// Number of birds.
  final int count;

  /// Atlas code kept, only during the breeding period.
  final AtlasCode? atlasCode;

  /// Sensitive species: ask Faune-France to hide the data.
  final bool hideData;
}

/// Label of an atlas code, e.g. « 3 – Mâle chanteur en période de
/// nidification ».
String atlasCodeLabel(AppLocalizations l10n, AtlasCode code) =>
    l10n.forkLpoAtlasCode(code.number, switch (code) {
      AtlasCode.presentInHabitat => l10n.forkLpoAtlasPresent,
      AtlasCode.singingMale => l10n.forkLpoAtlasSinging,
    });

/// The remark every card carries (SPEC 7.7): a sound contact, identified
/// with the AI and confirmed by the observer.
String lpoRemark(
  AppLocalizations l10n,
  LpoObservation observation, {
  required bool seen,
}) {
  if (!observation.aiAssisted) {
    return seen ? l10n.forkLpoRemarkManualSeen : l10n.forkLpoRemarkManual;
  }
  return seen ? l10n.forkLpoRemarkAiSeen : l10n.forkLpoRemarkAi;
}

/// Lines of the card, in the order of the Faune-France form.
List<String> lpoReportLines(
  AppLocalizations l10n,
  LpoObservation observation, {
  required String frenchName,
  required LpoCardChoices choices,
}) {
  final local = observation.time.toLocal();
  final lat = observation.latitude?.toStringAsFixed(5);
  final lon = observation.longitude?.toStringAsFixed(5);
  final accuracy = observation.accuracyMeters?.round();
  return [
    l10n.forkLpoFieldSpecies(frenchName, observation.scientificName),
    l10n.forkLpoFieldDate(DateFormat('dd/MM/yyyy').format(local)),
    l10n.forkLpoFieldTime(DateFormat('HH:mm').format(local)),
    if (lat == null || lon == null)
      l10n.forkLpoFieldNoPosition
    else if (accuracy == null)
      l10n.forkLpoFieldPosition(lat, lon)
    else
      l10n.forkLpoFieldPositionAccuracy(lat, lon, accuracy),
    l10n.forkLpoFieldCount(choices.count),
    l10n.forkLpoFieldContact(
      choices.seen ? l10n.forkLpoHeardAndSeen : l10n.forkLpoHeard,
    ),
    if (choices.atlasCode != null)
      l10n.forkLpoFieldAtlas(atlasCodeLabel(l10n, choices.atlasCode!)),
    if (choices.hideData) l10n.forkLpoFieldHidden,
    l10n.forkLpoFieldRemark(lpoRemark(l10n, observation, seen: choices.seen)),
  ];
}

/// The card as one block of text, for the clipboard.
String lpoReportText(
  AppLocalizations l10n,
  LpoObservation observation, {
  required String frenchName,
  required LpoCardChoices choices,
}) => lpoReportLines(
  l10n,
  observation,
  frenchName: frenchName,
  choices: choices,
).join('\n');
