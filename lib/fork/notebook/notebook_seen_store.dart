/// Species whose notebook card was opened (J6e): the « Nouveau » pill stays
/// on a discovered species until then.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../shared/providers/app_providers.dart';

const String kNotebookSeenPref = 'fork_notebook_seen';

class NotebookSeenStore {
  NotebookSeenStore(this._prefs);

  final SharedPreferences _prefs;

  /// Species already seen, or null before the notebook's first opening.
  Set<String>? read() => _prefs.getStringList(kNotebookSeenPref)?.toSet();

  /// Species seen, after marking [discovered] as seen if the notebook was
  /// never opened: species found before the notebook existed are not new.
  Future<Set<String>> readOrSeed(Set<String> discovered) async {
    final seen = read();
    if (seen != null) return seen;
    await _write(discovered);
    return discovered;
  }

  Future<void> markSeen(String scientificName) async {
    final seen = read() ?? <String>{};
    if (seen.add(scientificName)) await _write(seen);
  }

  Future<void> _write(Set<String> seen) =>
      _prefs.setStringList(kNotebookSeenPref, seen.toList()..sort());
}

final notebookSeenStoreProvider = Provider<NotebookSeenStore>(
  (ref) => NotebookSeenStore(ref.watch(sharedPreferencesProvider)),
);
