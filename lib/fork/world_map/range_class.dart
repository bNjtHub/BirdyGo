/// How a species uses a region (J7 world map): the four classes of the map
/// and how the fallback gets them from the geo-model's four seasons (the GBIF
/// classes come precomputed, see world_ranges.dart). Pure logic.
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
