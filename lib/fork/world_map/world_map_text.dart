/// Words of the world map block (J7): seasons, regions and the legend.
library;

import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:intl/intl.dart';

import 'season_legend.dart';
import 'world_map_config.dart';

String seasonName(AppLocalizations l10n, Season season) => switch (season) {
  Season.winter => l10n.forkWorldSeasonWinter,
  Season.spring => l10n.forkWorldSeasonSpring,
  Season.summer => l10n.forkWorldSeasonSummer,
  Season.autumn => l10n.forkWorldSeasonAutumn,
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
  WorldRegion.other => l10n.forkWorldRegionOther,
};

/// « Été : nord de l'Europe · Hiver : Afrique de l'Ouest · ~4 500 km ».
String legendText(
  AppLocalizations l10n,
  String languageCode,
  SeasonLegend legend,
) {
  switch (legend.kind) {
    case LegendKind.none:
      return l10n.forkWorldLegendNone;
    case LegendKind.passage:
      return l10n.forkWorldLegendPassage;
    case LegendKind.allYear:
      return l10n.forkWorldLegendAllYear;
    case LegendKind.seasons:
      final summer = legend.summer;
      final winter = legend.winter;
      if (legend.southern) return _monthsLegend(l10n, languageCode, legend);
      if (winter == null && summer != null) {
        return l10n.forkWorldLegendSummerOnly(regionName(l10n, summer));
      }
      if (summer == null && winter != null) {
        return l10n.forkWorldLegendWinterOnly(regionName(l10n, winter));
      }
      final km = legend.distanceKm;
      if (km == null) {
        return l10n.forkWorldLegendSeasons(
          regionName(l10n, summer!),
          regionName(l10n, winter!),
        );
      }
      return l10n.forkWorldLegendSeasonsDistance(
        regionName(l10n, summer!),
        regionName(l10n, winter!),
        NumberFormat.decimalPattern(languageCode).format(km),
      );
  }
}

/// The legend of a species of the southern hemisphere: months instead of
/// seasons, since « summer » (June to August) is its winter.
String _monthsLegend(
  AppLocalizations l10n,
  String languageCode,
  SeasonLegend legend,
) {
  String region(WorldRegion? r) =>
      r == null ? l10n.forkWorldLegendOutside : regionName(l10n, r);
  final km = legend.distanceKm;
  if (km == null) {
    return l10n.forkWorldLegendMonthsPair(
      l10n.forkWorldMonthsJunAug,
      region(legend.summer),
      l10n.forkWorldMonthsDecFeb,
      region(legend.winter),
    );
  }
  return l10n.forkWorldLegendMonthsPairDistance(
    l10n.forkWorldMonthsJunAug,
    region(legend.summer),
    l10n.forkWorldMonthsDecFeb,
    region(legend.winter),
    NumberFormat.decimalPattern(languageCode).format(km),
  );
}
