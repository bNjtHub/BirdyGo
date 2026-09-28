/// Synthetic test signals for the listening-mode DSP tests.
library;

import 'dart:math' as math;
import 'dart:typed_data';

const int kRate = 32000;

/// Gaussian white noise of standard deviation [rms].
Float32List whiteNoise(int length, double rms, {int seed = 1}) {
  final rnd = math.Random(seed);
  final out = Float32List(length);
  for (var i = 0; i < length; i++) {
    // Box-Muller.
    final u1 = rnd.nextDouble().clamp(1e-12, 1.0);
    final u2 = rnd.nextDouble();
    out[i] = rms * math.sqrt(-2 * math.log(u1)) * math.cos(2 * math.pi * u2);
  }
  return out;
}

/// Adds a sine of [amp] and [hz] to [x] over `[start, start + length)`, with
/// 5 ms raised-cosine ramps.
void addTone(
  Float32List x,
  double hz,
  double amp, {
  int start = 0,
  int? length,
}) {
  final n = length ?? x.length - start;
  const ramp = kRate * 5 ~/ 1000;
  for (var i = 0; i < n; i++) {
    var env = 1.0;
    if (i < ramp) env = 0.5 - 0.5 * math.cos(math.pi * i / ramp);
    if (n - i < ramp) env = 0.5 - 0.5 * math.cos(math.pi * (n - i) / ramp);
    x[start + i] += amp * env * math.sin(2 * math.pi * hz * i / kRate);
  }
}

/// Amplitude of the [hz] component of `x[start, start + length)` (Goertzel).
double toneAmplitude(Float32List x, double hz, int start, int length) {
  final w = 2 * math.pi * hz / kRate;
  final coeff = 2 * math.cos(w);
  var s1 = 0.0, s2 = 0.0;
  for (var i = 0; i < length; i++) {
    final s0 = x[start + i] + coeff * s1 - s2;
    s2 = s1;
    s1 = s0;
  }
  final power = s1 * s1 + s2 * s2 - coeff * s1 * s2;
  return 2 * math.sqrt(math.max(power, 0)) / length;
}

double rms(Float32List x, int start, int length) {
  var sum = 0.0;
  for (var i = 0; i < length; i++) {
    sum += x[start + i] * x[start + i];
  }
  return math.sqrt(sum / length);
}

double db(double ratio) => 20 * math.log(ratio) / math.ln10;

/// Feeds [x] through [process] in chunks of [chunk] samples (like the mic).
void inChunks(Float32List x, int chunk, void Function(Float32List) process) {
  for (var i = 0; i < x.length; i += chunk) {
    final end = math.min(i + chunk, x.length);
    process(Float32List.sublistView(x, i, end));
  }
}
