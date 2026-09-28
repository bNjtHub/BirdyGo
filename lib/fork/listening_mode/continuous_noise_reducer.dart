/// Stationary noise reduction of the « Ville » listening mode (J6f).
///
/// Streaming STFT power subtraction with a slowly adapting noise floor:
///
/// 1. Frames of [kCityFrameSize] samples every [kCityHopSize] samples,
///    square-root Hann on analysis and synthesis (perfect reconstruction at
///    50 % overlap: with no noise removed, output = input delayed by one
///    frame).
/// 2. Per bin, a noise floor follows the frame power with a time constant of
///    [kCityNoiseTimeConstantS]. Bins louder than the floor by
///    [kCitySignalGate] are treated as signal and barely update it, so a
///    song is not learnt as noise.
/// 3. Gain `sqrt(1 - β·noise/smoothedPower)` (β = [kCityOverSubtraction],
///    power smoothed by [kCityPowerSmoothing]), floored at [kCityMinGain],
///    rising instantly and released by [kCityGainRelease] per hop.
///
/// Measured on white noise: -11 dB after 3 s, a 300 ms chirp in that noise
/// kept within 0.5 dB; ~2 ms of CPU per second of audio on a desktop JIT
/// (test/fork/listening_mode/continuous_noise_reducer_test.dart).
///
/// Runs on the audio isolate (main), in place, allocation-free per chunk.
library;

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:fftea/fftea.dart';

import '../../core/constants/app_constants.dart';
import 'listening_mode_config.dart';

class ContinuousNoiseReducer {
  ContinuousNoiseReducer({
    this.frameSize = kCityFrameSize,
    this.hopSize = kCityHopSize,
    int sampleRate = AppConstants.sampleRate,
  }) : assert(frameSize == hopSize * 2, 'Needs 50 % overlap'),
       _fft = FFT(frameSize),
       _window = Float64List(frameSize),
       _in = Float64List(frameSize),
       _ola = Float64List(frameSize),
       _ready = Float64List(hopSize),
       _spectrum = Float64x2List(frameSize),
       _noise = Float64List(frameSize ~/ 2 + 1),
       _smoothed = Float64List(frameSize ~/ 2 + 1),
       _gain = Float64List(frameSize ~/ 2 + 1) {
    final hopsPerSecond = sampleRate / hopSize;
    _alpha = 1 - math.exp(-1 / (kCityNoiseTimeConstantS * hopsPerSecond));
    _warmupFrames = math.max(1, (kCityWarmupS * hopsPerSecond).round());
    // Periodic Hann, square-rooted: w² sums to 1 at 50 % overlap.
    for (var i = 0; i < frameSize; i++) {
      _window[i] = math.sqrt(0.5 - 0.5 * math.cos(2 * math.pi * i / frameSize));
    }
    reset();
  }

  final int frameSize;
  final int hopSize;

  final FFT _fft;
  final Float64List _window;

  /// Last [frameSize] input samples; the newest hop is filled sample by
  /// sample at `frameSize - hopSize + _pos`.
  final Float64List _in;

  /// Overlap-add accumulator of the synthesis frames.
  final Float64List _ola;

  /// Finished output samples, emitted one per input sample.
  final Float64List _ready;

  final Float64x2List _spectrum;
  final Float64List _noise;
  final Float64List _smoothed;
  final Float64List _gain;

  late final double _alpha;
  late final int _warmupFrames;
  int _pos = 0;
  int _frames = 0;

  /// Fixed delay between input and output, in samples.
  int get latencySamples => frameSize;

  /// Clears the noise estimate and the delay line (output starts silent for
  /// [latencySamples]).
  void reset() {
    _in.fillRange(0, _in.length, 0);
    _ola.fillRange(0, _ola.length, 0);
    _ready.fillRange(0, _ready.length, 0);
    _noise.fillRange(0, _noise.length, 0);
    _smoothed.fillRange(0, _smoothed.length, 0);
    _gain.fillRange(0, _gain.length, 1);
    _pos = 0;
    _frames = 0;
  }

  /// Denoises [samples] in place. Same length out as in, delayed by
  /// [latencySamples].
  void process(Float32List samples) {
    final base = frameSize - hopSize;
    for (var i = 0; i < samples.length; i++) {
      _in[base + _pos] = samples[i];
      samples[i] = _ready[_pos];
      _pos++;
      if (_pos == hopSize) {
        _pos = 0;
        _processFrame();
      }
    }
  }

  void _processFrame() {
    final n = frameSize;
    final h = hopSize;
    final spectrum = _spectrum;
    for (var i = 0; i < n; i++) {
      spectrum[i] = Float64x2(_in[i] * _window[i], 0);
    }
    _fft.inPlaceFft(spectrum);

    final warm = _frames < _warmupFrames;
    final a = warm ? 1 / (_frames + 1) : _alpha;
    final half = n ~/ 2;
    for (var k = 0; k <= half; k++) {
      final c = spectrum[k];
      final power = c.x * c.x + c.y * c.y;
      final floor = _noise[k];
      if (warm || power < kCitySignalGate * floor) {
        _noise[k] = floor + a * (power - floor);
      } else {
        _noise[k] = floor + a * kCitySignalLeak * (power - floor);
      }

      final smoothed =
          _smoothed[k] =
              kCityPowerSmoothing * _smoothed[k] +
              (1 - kCityPowerSmoothing) * power;
      var g = 1.0;
      if (smoothed > 0) {
        final r = 1 - kCityOverSubtraction * _noise[k] / smoothed;
        g = r > 0 ? math.sqrt(r) : 0.0;
      } else {
        g = 0.0;
      }
      if (g < kCityMinGain) g = kCityMinGain;
      final released = _gain[k] * kCityGainRelease;
      if (g < released) g = released;
      _gain[k] = g;

      final gv = Float64x2.splat(g);
      spectrum[k] = c * gv;
      if (k != 0 && k != half) spectrum[n - k] = spectrum[n - k] * gv;
    }
    _frames++;

    // Inverse FFT: forward transform, then real parts in reverse order / n.
    _fft.inPlaceFft(spectrum);
    final scale = 1 / n;
    for (var i = 0; i < n; i++) {
      final re = spectrum[i == 0 ? 0 : n - i].x * scale;
      _ola[i] += re * _window[i];
    }

    for (var i = 0; i < h; i++) {
      _ready[i] = _ola[i];
    }
    for (var i = 0; i < n - h; i++) {
      _ola[i] = _ola[i + h];
      _in[i] = _in[i + h];
    }
    for (var i = n - h; i < n; i++) {
      _ola[i] = 0;
    }
  }
}

/// Static hook called by AudioCaptureService after its own DSP (one
/// `// FORK` line). No-op unless the « Ville » mode enabled it.
abstract final class ForkNoiseReductionHook {
  static ContinuousNoiseReducer? _reducer;

  static bool get enabled => _reducer != null;

  /// Turns the reducer on (fresh noise estimate) or off. Idempotent.
  static void setEnabled(bool value) {
    if (value == enabled) return;
    _reducer = value ? ContinuousNoiseReducer() : null;
  }

  /// Called for every captured chunk, after gain and high-pass.
  static void process(Float32List samples) => _reducer?.process(samples);
}
