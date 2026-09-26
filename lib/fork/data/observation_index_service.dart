/// Owns the [ObservationIndex] for the running app: opens it, fills it once
/// in the background, and keeps it in sync with session saves and deletes.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../../features/history/session_repository.dart';
import '../../features/live/live_providers.dart';
import '../../features/live/live_session.dart';
import '../../shared/providers/app_providers.dart';
import 'fork_session_hooks.dart';
import 'observation_index.dart';

/// SharedPreferences key: schema version the index was last filled with.
const String kObservationIndexFilledVersion = 'fork_observation_index_filled';

/// Keeps the observation index alive and in sync.
class ObservationIndexService extends ChangeNotifier
    implements SessionChangeListener {
  ObservationIndexService({
    required SessionRepository repository,
    required SharedPreferences prefs,
    Future<ObservationIndex> Function()? openIndex,
  }) : _repository = repository,
       _prefs = prefs,
       _openIndex = openIndex ?? _openDefault;

  final SessionRepository _repository;
  final SharedPreferences _prefs;
  final Future<ObservationIndex> Function() _openIndex;

  Future<ObservationIndex>? _index;
  bool _rebuilding = false;

  /// True while a full rebuild runs.
  bool get isRebuilding => _rebuilding;

  static Future<ObservationIndex> _openDefault() async {
    final dir = await getApplicationDocumentsDirectory();
    return ObservationIndex.open(
      databaseFactory,
      '${dir.path}/fork/observation_index.db',
    );
  }

  /// Opens the index, registers the session hooks and, the first time (or
  /// after a schema change), fills it from all saved sessions.
  Future<ObservationIndex> ensureReady() {
    return _index ??= () async {
      final index = await _openIndex();
      ForkSessionHooks.listener = this;
      final filled = _prefs.getInt(kObservationIndexFilledVersion);
      if (index.needsRebuild || filled != ObservationIndex.schemaVersion) {
        unawaited(_rebuild(index));
      }
      return index;
    }();
  }

  /// Rebuilds the whole index from the session files ("Reconstruire").
  Future<void> rebuild() async => _rebuild(await ensureReady());

  Future<void> _rebuild(ObservationIndex index) async {
    if (_rebuilding) return;
    _rebuilding = true;
    notifyListeners();
    try {
      // listAll parses the JSON files in a background isolate; sqflite runs
      // the inserts off the UI thread, in one transaction.
      final sessions = await _repository.listAll();
      await index.rebuild(sessions);
      await _prefs.setInt(
        kObservationIndexFilledVersion,
        ObservationIndex.schemaVersion,
      );
    } catch (error, stack) {
      debugPrint('ObservationIndex rebuild failed: $error\n$stack');
    } finally {
      _rebuilding = false;
      notifyListeners();
    }
  }

  @override
  void sessionSaved(LiveSession session) =>
      _apply((index) => index.upsertSession(session));

  @override
  void sessionDeleted(String sessionId) =>
      _apply((index) => index.removeSession(sessionId));

  @override
  void allSessionsDeleted() => _apply((index) => index.clear());

  void _apply(Future<void> Function(ObservationIndex index) change) {
    unawaited(() async {
      try {
        await change(await ensureReady());
        notifyListeners();
      } catch (error, stack) {
        // The index is derived: a failed update is repaired by a rebuild.
        debugPrint('ObservationIndex update failed: $error\n$stack');
        await _prefs.remove(kObservationIndexFilledVersion);
      }
    }());
  }
}

/// App-wide observation index service.
final observationIndexServiceProvider =
    ChangeNotifierProvider<ObservationIndexService>((ref) {
      return ObservationIndexService(
        repository: ref.read(sessionRepositoryProvider),
        prefs: ref.read(sharedPreferencesProvider),
      );
    });
