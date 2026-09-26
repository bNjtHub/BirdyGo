/// Inference timing of the live screen (J6c-bis-a): how long the model
/// takes on a window, and how late its result reaches the screen after the
/// end of that window. Logged outside release builds only; nothing here
/// touches inference itself.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

/// Percentile [p] (0 to 1) of [values], nearest-rank; 0 when empty.
int percentile(List<int> values, double p) {
  if (values.isEmpty) return 0;
  final sorted = [...values]..sort();
  final rank = (p * sorted.length).ceil().clamp(1, sorted.length);
  return sorted[rank - 1];
}

/// Rolling p50 and p95 of the last [cycles] inference cycles.
class InferenceTiming {
  InferenceTiming({this.cycles = 30, void Function(String message)? log})
    : log = log ?? debugPrint;

  /// Cycles per log line (about 30 s at one cycle per second).
  final int cycles;

  final void Function(String message) log;

  final List<int> _inferMs = [];
  final List<int> _delayMs = [];

  /// Analysis times of the current batch, in ms.
  List<int> get inferMs => List.unmodifiable(_inferMs);

  /// Window end to display delays of the current batch, in ms.
  List<int> get delayMs => List.unmodifiable(_delayMs);

  /// Records one cycle: [infer] is the model time, [windowEnd] the end of
  /// the analysed audio. The delay is taken after the next frame, once the
  /// result is on screen. No-op in release builds.
  void record(Duration infer, {required DateTime windowEnd}) {
    if (kReleaseMode) return;
    final binding = SchedulerBinding.instance;
    binding.addPostFrameCallback((_) {
      add(infer, delay: DateTime.now().difference(windowEnd));
    });
    binding.ensureVisualUpdate();
  }

  /// Adds one measured cycle; logs and restarts every [cycles].
  void add(Duration infer, {required Duration delay}) {
    _inferMs.add(infer.inMilliseconds);
    _delayMs.add(delay.inMilliseconds);
    if (_inferMs.length < cycles) return;
    log(
      '[InferenceTiming] $cycles cycles — '
      'analysis p50=${percentile(_inferMs, 0.5)} ms '
      'p95=${percentile(_inferMs, 0.95)} ms; '
      'window end to display p50=${percentile(_delayMs, 0.5)} ms '
      'p95=${percentile(_delayMs, 0.95)} ms',
    );
    _inferMs.clear();
    _delayMs.clear();
  }
}
