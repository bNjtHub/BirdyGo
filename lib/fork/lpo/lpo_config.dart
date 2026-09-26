/// Settings of the guided sending to the LPO (fork/PLAN.md J5b).
///
/// Faune-France has no open access for third-party apps: BirdyGo never
/// sends anything by itself and never asks for a Faune-France password. It
/// prepares a card the observer reports by hand in NaturaList or on
/// faune-france.org.
library;

import 'package:flutter/foundation.dart';

/// Fork-owned constants of the LPO sending and the garden count.
abstract final class LpoConfig {
  /// Confirmed detections of one species closer than this (meters) to the
  /// first one of their group make a single observation. Farther ones (a
  /// walk, a transect) become separate observations.
  static const double samePlaceMeters = 250;

  /// A GPS fix of the session track is used for a detection's accuracy
  /// when it was taken within this time of the detection.
  static const Duration gpsAccuracyWindow = Duration(seconds: 60);

  /// An observation is "here and now" (so `geoCommonnessProvider`, which
  /// is computed at the current place and week, applies to it) when it
  /// falls in the current geo-model week and closer than this (km) to the
  /// current position.
  static const double hereRadiusKm = 10;

  /// Garden count duration during the two national weekends.
  static const Duration gardenNationalDuration = Duration(hours: 1);

  /// Months of the national "Oiseaux des jardins" weekends (the last full
  /// weekend of each).
  static const List<int> gardenNationalMonths = [
    DateTime.january,
    DateTime.may,
  ];

  /// Largest count a garden counter accepts.
  static const int gardenMaxCount = 999;

  /// Largest number of birds an LPO card accepts.
  static const int lpoMaxCount = 999;

  static const String naturaListPlayStore =
      'https://play.google.com/store/apps/details?id=ch.biolovision.naturalist';

  /// Used on iOS (fork/PLAN.md, iOS phase).
  static const String naturaListAppStore =
      'https://apps.apple.com/app/naturalist/id1175280268';

  static const String fauneFrance = 'https://www.faune-france.org/';

  static const String oiseauxDesJardins = 'https://www.oiseauxdesjardins.fr/';

  /// xeno-canto search for [scientificName], to compare with reference
  /// recordings before sending.
  static String xenoCantoSearch(String scientificName) =>
      Uri.https('xeno-canto.org', '/explore', {
        'query': scientificName,
      }).toString();

  /// NaturaList store page (the store shows « Ouvrir » when installed; no
  /// pre-filling is documented).
  static String naturaList(TargetPlatform platform) =>
      platform == TargetPlatform.iOS ? naturaListAppStore : naturaListPlayStore;
}
