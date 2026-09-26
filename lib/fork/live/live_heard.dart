/// Quick end of the « chante » symbol (fork/PLAN.md J6c-bis-b).
///
/// Temporal pooling keeps a species in the results for a few windows after
/// it stops singing. The symbol follows the last window instead: it lights
/// up when the contact opens, and goes out after
/// [ReliabilityConfig.liveSingingHoldWindows] consecutive windows under the
/// support threshold. The mark under the spectrogram ends at [heardUntil],
/// the end of the last window at or above that threshold.
library;

import '../reliability/reliability_config.dart';

/// A contact: species and start of its record ([DetectionRecord.timestamp]).
typedef ContactKey = (String scientificName, DateTime start);

/// Per-cycle state of the « chante » symbol. Fed once per inference cycle.
class LiveHeard {
  LiveHeard({this.holdWindows = ReliabilityConfig.liveSingingHoldWindows});

  /// Consecutive windows under the support threshold that put it out.
  final int holdWindows;

  final Map<String, ContactKey> _open = {};
  final Map<String, int> _misses = {};
  final Map<ContactKey, DateTime> _heardUntil = {};

  /// Species whose symbol is on.
  Set<String> get singingVisual => {
    for (final name in _open.keys)
      if ((_misses[name] ?? 0) < holdWindows) name,
  };

  /// End of the last window at or above the support threshold, per contact.
  /// Never goes back.
  Map<ContactKey, DateTime> get heardUntil => Map.unmodifiable(_heardUntil);

  /// One inference cycle.
  ///
  /// [contacts]: species in the current results, with the start of their
  /// contact. [supported]: species whose window score reached the support
  /// threshold. [windowEnd]: end of the analysed window, [window] its length.
  void update({
    required Map<String, DateTime> contacts,
    required Set<String> supported,
    required DateTime windowEnd,
    required Duration window,
  }) {
    _open.removeWhere((name, _) => !contacts.containsKey(name));
    _misses.removeWhere((name, _) => !contacts.containsKey(name));
    for (final MapEntry(key: name, value: start) in contacts.entries) {
      final key = (name, start);
      final opened = _open[name] != key;
      if (opened) {
        _open[name] = key;
        _misses[name] = 0;
        // The record starts on its first supporting window.
        _raise(key, start.add(window));
      }
      if (supported.contains(name)) {
        _misses[name] = 0;
        _raise(key, windowEnd);
      } else if (!opened) {
        _misses[name] = (_misses[name] ?? 0) + 1;
      }
    }
  }

  void _raise(ContactKey key, DateTime end) {
    final held = _heardUntil[key];
    if (held == null || end.isAfter(held)) _heardUntil[key] = end;
  }

  /// Pause or replay: every symbol goes out, the ends are kept.
  void pause() {
    _open.clear();
    _misses.clear();
  }

  /// New session.
  void reset() {
    pause();
    _heardUntil.clear();
  }
}
