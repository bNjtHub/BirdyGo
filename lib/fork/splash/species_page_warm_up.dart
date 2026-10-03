/// Idle warm-up for the species page: once the home screen has had its first
/// frames, the heavy one-time resources the page waits for are loaded one
/// after the other, so the first species page opens without a wait.
///
/// Every provider warmed here is a plain (non autoDispose) one, kept for the
/// app run; the parsing already runs in background isolates. No network.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/explore/explore_providers.dart';
import '../../shared/providers/settings_providers.dart';
import '../species_page/species_page_loader.dart';
import '../world_map/world_map_providers.dart';

/// Waits after the splash before the optional work starts.
const Duration kSpeciesPageWarmUpDelay = Duration(milliseconds: 1500);

/// The warm steps, cheapest to dearest on the phone, with their names (for
/// logs and tests). Each one only reads a keepAlive provider.
Map<String, Future<void> Function()> speciesPageWarmUpTasks(
  ProviderContainer container,
) => {
  // The page's description (locale bundle + English fallback), cached in the
  // singleton service.
  'descriptions':
      () => container
          .read(speciesDescriptionServiceProvider)
          .getDescription('', container.read(effectiveSpeciesLocaleProvider)),
  'worldRegions': () => container.read(worldRegionsProvider.future),
  'worldRanges': () => container.read(worldRangesProvider.future),
  'landCells': () => container.read(landCellsProvider.future),
  // The year chart: the geo-model's 48 weeks at the phone's place. Never
  // asks for the location permission (null without it).
  'yearScores': () => container.read(speciesYearScoresProvider.future),
};

/// Runs [tasks] in order, a frame apart. Stops early when [isForeground]
/// says the app left the screen (battery: nothing optional in background).
/// A failing step is skipped. Returns the names of the steps that ran.
Future<List<String>> runSpeciesPageWarmUp(
  Map<String, Future<void> Function()> tasks, {
  bool Function()? isForeground,
  Future<void> Function()? pause,
  Duration delay = kSpeciesPageWarmUpDelay,
}) async {
  final ran = <String>[];
  if (delay > Duration.zero) await Future<void>.delayed(delay);
  for (final MapEntry(:key, :value) in tasks.entries) {
    if (isForeground != null && !isForeground()) break;
    await pause?.call();
    try {
      await value();
      ran.add(key);
    } catch (error) {
      debugPrint('[SpeciesPageWarmUp] $key failed: $error');
    }
  }
  return ran;
}

/// True while the app is in the foreground.
bool appIsForeground() {
  final state = SchedulerBinding.instance.lifecycleState;
  return state == null || state == AppLifecycleState.resumed;
}
