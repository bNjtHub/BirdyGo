/// All-time contact totals per species, read from the observation index.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'observation_index_service.dart';

/// Contacts per species over every saved session (rejected ones excluded).
/// Recomputed whenever the index changes.
final savedSpeciesTotalsProvider = FutureProvider<Map<String, int>>((
  ref,
) async {
  final service = ref.watch(observationIndexServiceProvider);
  final index = await service.ensureReady();
  return index.totalContactsBySpecies();
});

/// Adds the running session's counts to the saved totals, for the species
/// in [sessionCounts] ("×3 · 142": 142 includes these 3). The running
/// session is only saved when it ends, so nothing is counted twice.
Map<String, int> liveTotals({
  required Map<String, int> saved,
  required Map<String, int> sessionCounts,
}) => {
  for (final entry in sessionCounts.entries)
    entry.key: (saved[entry.key] ?? 0) + entry.value,
};
