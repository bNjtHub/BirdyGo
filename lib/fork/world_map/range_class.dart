/// How a species uses a region (J7 world map): the four classes of the map
/// and how they come from the observation counts of GBIF (or, as a fallback,
/// from the geo-model's four seasons). Pure logic.
library;

import 'dart:math' as math;

import 'season_presence.dart';
import 'world_map_config.dart';
import 'world_regions.dart';

/// The four colors of the map, as on a field guide.
enum RangeClass {
  /// Present in summer only (not in winter): nesting.
  breeding,

  /// Present in winter only.
  wintering,

  /// Present in summer and in winter.
  resident,

  /// Seen in spring and/or autumn only.
  passage,
}

/// Counts of observations per GADM level-1 id, for each season.
typedef SeasonCounts = Map<Season, Map<String, int>>;

/// The class of a region present in the given seasons, or null when absent.
RangeClass? classOfSeasons({
  required bool summer,
  required bool winter,
  required bool passage,
}) {
  if (summer && winter) return RangeClass.resident;
  if (summer) return RangeClass.breeding;
  if (winter) return RangeClass.wintering;
  if (passage) return RangeClass.passage;
  return null;
}

/// Class of each GADM level-1 region, from the species' [species] counts and
/// the all-birds [effort] counts (same filters, same seasons).
///
/// A region is present in a season when [minEffort], [minSpeciesRecords] and
/// [minRate] are met (the rate is species over all birds, so a region with
/// many observers does not look richer than one with few), and, against the
/// noise of little-watched regions, when its rate also reaches
/// [relativeRate] times the median rate of the regions and seasons that
/// passed the first test.
Map<String, RangeClass> classifyGadm(
  SeasonCounts species,
  SeasonCounts effort, {
  int minEffort = WorldMapConfig.minEffort,
  int minSpeciesRecords = WorldMapConfig.minSpeciesRecords,
  double minRate = WorldMapConfig.minRate,
  double relativeRate = WorldMapConfig.relativeRate,
}) {
  final rates = <Season, Map<String, double>>{};
  final all = <double>[];
  for (final season in Season.values) {
    final seen = rates[season] = {};
    final birds = effort[season] ?? const {};
    for (final e in (species[season] ?? const <String, int>{}).entries) {
      final total = birds[e.key] ?? 0;
      if (total < minEffort || e.value < minSpeciesRecords) continue;
      final rate = e.value / total;
      if (rate < minRate) continue;
      seen[e.key] = rate;
      all.add(rate);
    }
  }
  if (all.isEmpty) return const {};
  all.sort();
  final mid = all.length ~/ 2;
  final median = all.length.isOdd ? all[mid] : (all[mid - 1] + all[mid]) / 2;
  final floor = relativeRate * median;
  bool present(Season s, String gid) {
    final rate = rates[s]![gid];
    return rate != null && rate >= floor;
  }

  final out = <String, RangeClass>{};
  for (final gid in {for (final m in rates.values) ...m.keys}) {
    final c = classOfSeasons(
      summer: present(Season.summer, gid),
      winter: present(Season.winter, gid),
      passage: present(Season.spring, gid) || present(Season.autumn, gid),
    );
    if (c != null) out[gid] = c;
  }
  return out;
}

/// Class of each map region from the class of its GADM region ([join]: GADM
/// id to region ids). Regions of a GADM id the species is absent from stay
/// out.
Map<String, RangeClass> classesOnRegions(
  Map<String, RangeClass> byGadm,
  GadmJoin join,
) {
  final out = <String, RangeClass>{};
  for (final e in byGadm.entries) {
    for (final id in join.regionsOf[e.key] ?? const <String>[]) {
      out[id] = e.value;
    }
  }
  return out;
}

/// Fallback: the classes of the regions from the geo-model's presence on its
/// coarse grid. Each region takes the cell holding its centroid (the nearest
/// cell of the eight around when that one is at sea), so the geo-model is
/// asked no more than for the map of before; the result is blockier than
/// the GBIF map, and presented as an estimate.
Map<String, RangeClass> classesFromPresence(
  SeasonPresence presence,
  WorldRegions regions,
) {
  final step = presence.step;
  (int, int) key(double lat, double lon) =>
      ((lat / step).floor(), (lon / step).floor());
  final byKey = <(int, int), int>{
    for (var i = 0; i < presence.cells.length; i++)
      key(presence.cells[i].latitude, presence.cells[i].longitude): i,
  };
  final out = <String, RangeClass>{};
  for (final region in regions.regions) {
    final (row, col) = key(region.centroid.latitude, region.centroid.longitude);
    int? cell = byKey[(row, col)];
    if (cell == null) {
      var best = double.infinity;
      for (var dr = -1; dr <= 1; dr++) {
        for (var dc = -1; dc <= 1; dc++) {
          final i = byKey[(row + dr, col + dc)];
          if (i == null) continue;
          final c = presence.cells[i];
          final d = math.pow(c.latitude - region.centroid.latitude, 2) +
              math.pow(c.longitude - region.centroid.longitude, 2);
          if (d < best) {
            best = d.toDouble();
            cell = i;
          }
        }
      }
    }
    if (cell == null) continue;
    final c = classOfSeasons(
      summer: presence.isPresent(Season.summer, cell),
      winter: presence.isPresent(Season.winter, cell),
      passage:
          presence.isPresent(Season.spring, cell) ||
          presence.isPresent(Season.autumn, cell),
    );
    if (c != null) out[region.id] = c;
  }
  return out;
}
