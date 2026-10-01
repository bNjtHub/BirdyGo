/// Words of the world map block (J7): the four classes, the regions and the
/// summary under the map.
library;

import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:intl/intl.dart';

import 'range_class.dart';
import 'range_legend.dart';

String className(AppLocalizations l10n, RangeClass c) => switch (c) {
  RangeClass.breeding => l10n.forkWorldClassBreeding,
  RangeClass.wintering => l10n.forkWorldClassWintering,
  RangeClass.resident => l10n.forkWorldClassResident,
  RangeClass.passage => l10n.forkWorldClassPassage,
};

String regionName(
  AppLocalizations l10n,
  WorldRegion region,
) => switch (region) {
  WorldRegion.northernEurope => l10n.forkWorldRegionNorthernEurope,
  WorldRegion.westernEurope => l10n.forkWorldRegionWesternEurope,
  WorldRegion.centralEasternEurope => l10n.forkWorldRegionCentralEasternEurope,
  WorldRegion.mediterranean => l10n.forkWorldRegionMediterranean,
  WorldRegion.northAfrica => l10n.forkWorldRegionNorthAfrica,
  WorldRegion.westAfrica => l10n.forkWorldRegionWestAfrica,
  WorldRegion.centralAfrica => l10n.forkWorldRegionCentralAfrica,
  WorldRegion.eastAfrica => l10n.forkWorldRegionEastAfrica,
  WorldRegion.southernAfrica => l10n.forkWorldRegionSouthernAfrica,
  WorldRegion.middleEast => l10n.forkWorldRegionMiddleEast,
  WorldRegion.centralAsia => l10n.forkWorldRegionCentralAsia,
  WorldRegion.southAsia => l10n.forkWorldRegionSouthAsia,
  WorldRegion.eastAsia => l10n.forkWorldRegionEastAsia,
  WorldRegion.southeastAsia => l10n.forkWorldRegionSoutheastAsia,
  WorldRegion.oceania => l10n.forkWorldRegionOceania,
  WorldRegion.northAmerica => l10n.forkWorldRegionNorthAmerica,
  WorldRegion.centralAmerica => l10n.forkWorldRegionCentralAmerica,
  WorldRegion.southAmerica => l10n.forkWorldRegionSouthAmerica,
  WorldRegion.other => l10n.forkWorldRegionOther,
};

/// « Nidification : nord de l'Europe · Hivernage : Afrique de l'Ouest ·
/// ~4 500 km ». One part per class present, in the order of the key; the
/// distance only for a migration.
String legendText(
  AppLocalizations l10n,
  String languageCode,
  RangeLegend legend,
) {
  if (legend.isEmpty) return l10n.forkWorldLegendNone;
  final parts = [
    for (final c in RangeClass.values)
      if (legend.regions[c] case final region?)
        l10n.forkWorldLegendClass(
          className(l10n, c),
          regionName(l10n, region),
        ),
    if (legend.distanceKm case final km?)
      l10n.forkWorldLegendDistance(
        NumberFormat.decimalPattern(languageCode).format(km),
      ),
  ];
  return parts.join(' · ');
}
