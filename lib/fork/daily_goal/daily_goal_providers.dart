/// Riverpod wiring: passive restore, explicit creation, and saved progress.
library;

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/location_service.dart';
import '../../features/explore/explore_providers.dart';
import '../../features/inference/geo_model.dart';
import '../../shared/providers/app_providers.dart';
import '../../shared/providers/settings_providers.dart';
import '../data/observation_index_service.dart';
import 'daily_goal.dart';

/// Injectable clock for local-day rollover tests.
final dailyGoalNowProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

typedef DailyGoalCandidateLoader =
    Future<List<DailyGoalSpecies>> Function(AppLocation location, DateTime day);

final dailyGoalCandidateLoaderProvider = Provider<DailyGoalCandidateLoader>(
  (ref) => (location, day) async {
    final model = await ref.read(geoModelProvider.future);
    final classes = await ref.read(audioLabelClassesProvider.future);
    final scores = await model.predict(
      latitude: location.latitude,
      longitude: location.longitude,
      week: GeoModel.dateTimeToWeek(day),
    );
    final taxonomy = await ref.read(taxonomyServiceProvider.future);
    final locale = ref.read(effectiveSpeciesLocaleProvider);
    final fallbackNames = {
      for (final label in model.labels) label.scientificName: label.commonName,
    };
    return dailyGoalCandidates(
      scores: scores,
      audioClasses: classes,
      commonName:
          (name) =>
              taxonomy.lookup(name)?.commonNameForLocale(locale) ??
              fallbackNames[name] ??
              name,
    );
  },
);

class DailyGoalController extends Notifier<DailyGoalState> {
  Timer? _midnight;
  int _generation = 0;
  DateTime? _activeDay;

  DateTime get _now => ref.read(dailyGoalNowProvider)();
  DailyGoalStore get _store =>
      DailyGoalStore(ref.read(sharedPreferencesProvider));

  @override
  DailyGoalState build() {
    final now = _now;
    _activeDay = dailyGoalDay(now);
    _scheduleMidnight(now);
    final observer = _DailyGoalLifecycle(refreshDay);
    WidgetsBinding.instance.addObserver(observer);
    ref.onDispose(() {
      _midnight?.cancel();
      WidgetsBinding.instance.removeObserver(observer);
    });
    final saved = _store.readToday(now);
    return DailyGoalState(
      goal: saved,
      status: saved == null ? DailyGoalStatus.idle : DailyGoalStatus.ready,
    );
  }

  void _scheduleMidnight(DateTime now) {
    _midnight?.cancel();
    final local = now.toLocal();
    final next = DateTime(local.year, local.month, local.day + 1);
    _midnight = Timer(next.difference(local), refreshDay);
  }

  /// Clears yesterday's goal on midnight or resume, without requesting GPS.
  void refreshDay() {
    final now = _now;
    final day = dailyGoalDay(now);
    if (_activeDay != day) {
      _activeDay = day;
      _generation++;
      final saved = _store.readToday(now);
      state = DailyGoalState(
        goal: saved,
        status: saved == null ? DailyGoalStatus.idle : DailyGoalStatus.ready,
      );
    }
    _scheduleMidnight(now);
  }

  /// Call when the goal screen is opened or the user explicitly retries.
  /// Existing same-day goals never change with movement or model availability.
  Future<void> ensureToday() async {
    refreshDay();
    if (state.goal != null || state.status == DailyGoalStatus.loading) return;
    final day = dailyGoalDay(_now);
    final generation = ++_generation;
    state = const DailyGoalState(status: DailyGoalStatus.loading);
    try {
      // The shared provider may still hold yesterday's position.
      ref.invalidate(currentLocationProvider);
      final location = await ref.read(currentLocationProvider.future);
      if (!ref.mounted || generation != _generation) return;
      if (location == null) {
        state = const DailyGoalState(status: DailyGoalStatus.needsLocation);
        return;
      }
      final candidates = await ref.read(dailyGoalCandidateLoaderProvider)(
        location,
        day,
      );
      if (!ref.mounted || generation != _generation) return;
      if (dailyGoalDay(_now) != day) {
        refreshDay();
        return;
      }
      if (candidates.isEmpty) {
        state = const DailyGoalState(status: DailyGoalStatus.noCandidates);
        return;
      }
      final goal = DailyGoal.create(
        day: day,
        latitude: location.latitude,
        longitude: location.longitude,
        candidates: candidates,
      );
      await _store.save(goal);
      if (!ref.mounted || generation != _generation) return;
      if (!goal.isForDay(_now)) {
        refreshDay();
        return;
      }
      state = DailyGoalState(goal: goal, status: DailyGoalStatus.ready);
    } catch (_) {
      if (ref.mounted && generation == _generation) {
        state = const DailyGoalState(status: DailyGoalStatus.error);
      }
    }
  }

  Future<bool> replace(
    String oldScientificName,
    String newScientificName,
  ) async {
    refreshDay();
    final current = state.goal;
    if (current == null) return false;
    final updated = current.replace(oldScientificName, newScientificName);
    if (identical(updated, current)) return false;
    final generation = ++_generation;
    await _store.save(updated);
    if (!ref.mounted || generation != _generation) return false;
    if (!updated.isForDay(_now)) {
      refreshDay();
      return false;
    }
    state = DailyGoalState(goal: updated, status: DailyGoalStatus.ready);
    return true;
  }
}

class _DailyGoalLifecycle extends WidgetsBindingObserver {
  _DailyGoalLifecycle(this.refresh);

  final VoidCallback refresh;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) refresh();
  }
}

final dailyGoalProvider = NotifierProvider<DailyGoalController, DailyGoalState>(
  DailyGoalController.new,
);

/// Saved sessions only: index saves/deletes/reviews automatically refresh it.
/// Read failures remain errors, so the UI does not claim zero progress.
final dailyGoalProgressProvider = FutureProvider<Set<String>>((ref) async {
  final goal = ref.watch(dailyGoalProvider).goal;
  if (goal == null) return const {};
  final service = ref.watch(observationIndexServiceProvider);
  final index = await service.ensureReady();
  final detections = await index.detectionsSince(goal.day);
  return completedDailyGoalSpecies(goal, detections);
});
