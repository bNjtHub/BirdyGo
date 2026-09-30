/// Where the geo-model expects a species in each season (J7 world map).
///
/// The model is asked cell by cell on the land grid, for the four
/// representative weeks. Presence uses the same threshold as the rest of the
/// species page (`kAbundanceInclusionThreshold`).
library;

import '../../features/inference/geo_abundance.dart';
import 'world_grid.dart';
import 'world_map_config.dart';

/// The geo-model's `predict`, as far as this feature needs it.
typedef GeoPredict =
    Future<Map<String, double>> Function({
      required double latitude,
      required double longitude,
      required int week,
    });

/// Presence flags of one species on the land grid, one list per season.
class SeasonPresence {
  const SeasonPresence(this.cells, this.flags);

  final List<GridCell> cells;

  /// For each season, one flag per cell of [cells].
  final Map<Season, List<bool>> flags;

  bool isPresent(Season season, int cell) => flags[season]![cell];

  /// Cells where the species is expected in [season].
  List<GridCell> cellsOf(Season season) => [
    for (var i = 0; i < cells.length; i++)
      if (flags[season]![i]) cells[i],
  ];

  /// Whether the species is expected nowhere on the map, in any season.
  bool get isEmpty => Season.values.every((s) => !flags[s]!.contains(true));
}

/// Computes the four seasons of [scientificName] on [cells]. Asynchronous and
/// gentle with the UI thread: after every [batchSize] predictions it waits
/// [pause], so frames keep flowing while the geo-model works.
Future<SeasonPresence> computeSeasonPresence({
  required String scientificName,
  required GeoPredict predict,
  required List<GridCell> cells,
  double threshold = kAbundanceInclusionThreshold,
  Map<Season, int> weeks = WorldMapConfig.seasonWeeks,
  int batchSize = WorldMapConfig.batchSize,
  Duration pause = WorldMapConfig.batchPause,
}) async {
  final flags = {
    for (final s in Season.values) s: List<bool>.filled(cells.length, false),
  };
  var sinceLastPause = 0;
  for (var i = 0; i < cells.length; i++) {
    for (final season in Season.values) {
      final scores = await predict(
        latitude: cells[i].latitude,
        longitude: cells[i].longitude,
        week: weeks[season]!,
      );
      flags[season]![i] = (scores[scientificName] ?? 0) >= threshold;
      if (++sinceLastPause >= batchSize) {
        sinceLastPause = 0;
        await Future<void>.delayed(pause);
      }
    }
  }
  return SeasonPresence(cells, flags);
}
