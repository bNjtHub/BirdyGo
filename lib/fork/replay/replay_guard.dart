/// Keeps inference from scoring audio captured while a clip is replayed
/// through the speaker (fork/PLAN.md, J2).
///
/// Ranges live on the ring buffer's absolute sample timeline
/// (`RingBuffer.totalWritten`), not on wall-clock time: windows are analyzed
/// up to one window length after their audio was captured, so only sample
/// positions say which windows heard the speaker. Recording is untouched;
/// only inference skips those windows.
library;

/// Sample ranges during which a replay was audible.
class ReplayGuard {
  int? _openStart;
  final List<(int start, int end)> _closed = [];

  /// True while a replay is playing.
  bool get isReplaying => _openStart != null;

  /// A replay starts now, at absolute sample [nowSample].
  void begin(int nowSample) {
    _openStart ??= nowSample;
  }

  /// The replay stopped at [nowSample]; windows keep being skipped for
  /// [paddingSamples] more (the room echo and the speaker's tail).
  void end(int nowSample, {required int paddingSamples}) {
    final start = _openStart;
    if (start == null) return;
    _closed.add((start, nowSample + paddingSamples));
    _openStart = null;
  }

  /// Whether the window `[windowStart, windowEnd)` overlaps a replay and must
  /// not be scored. Windows arrive in capture order, so ranges that end
  /// before [windowStart] are forgotten.
  bool overlaps(int windowStart, int windowEnd) {
    _closed.removeWhere((range) => range.$2 <= windowStart);
    final open = _openStart;
    if (open != null && windowEnd > open) return true;
    for (final (start, end) in _closed) {
      if (windowStart < end && windowEnd > start) return true;
    }
    return false;
  }

  /// Forget every range (new session).
  void reset() {
    _openStart = null;
    _closed.clear();
  }
}
