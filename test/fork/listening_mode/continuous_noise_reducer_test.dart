import 'dart:typed_data';

import 'package:birdnet_live/fork/listening_mode/continuous_noise_reducer.dart';
import 'package:flutter_test/flutter_test.dart';

import 'signals.dart';

void main() {
  group('ContinuousNoiseReducer', () {
    test('keeps chunk length and has a fixed latency', () {
      final r = ContinuousNoiseReducer();
      final x = Float32List(1000)..[0] = 1;
      r.process(x);
      expect(x.length, 1000);
      expect(r.latencySamples, 512);
    });

    test('converges on stationary noise (>= 10 dB less after 3 s)', () {
      final r = ContinuousNoiseReducer();
      final x = whiteNoise(kRate * 4, 0.05);
      final input = Float32List.fromList(x);
      inChunks(x, 1600, r.process);
      final last = kRate; // last second
      final before = rms(input, x.length - last - 512, last);
      final after = rms(x, x.length - last, last);
      expect(db(after / before), lessThan(-10));
    });

    test('does not kill a transient chirp in steady noise', () {
      final r = ContinuousNoiseReducer();
      final x = whiteNoise(kRate * 4, 0.05);
      const start = kRate * 3; // after 3 s of noise
      const length = kRate * 3 ~/ 10; // 300 ms chirp
      addTone(x, 3000, 0.05, start: start, length: length);
      final reference = Float32List(x.length);
      addTone(reference, 3000, 0.05, start: start, length: length);

      inChunks(x, 1600, r.process);
      final kept = toneAmplitude(x, 3000, start + r.latencySamples, length);
      final orig = toneAmplitude(reference, 3000, start, length);
      expect(db(kept / orig).abs(), lessThan(3));
    });

    test('passes a loud tone in faint noise almost untouched', () {
      final r = ContinuousNoiseReducer();
      final x = whiteNoise(kRate * 2, 0.001);
      addTone(x, 3000, 0.3, start: kRate, length: kRate ~/ 2);
      inChunks(x, 1024, r.process);
      final kept = toneAmplitude(x, 3000, kRate + 512 + 1000, 8000);
      expect(db(kept / 0.3).abs(), lessThan(1));
    });

    test('hook is a no-op until enabled', () {
      ForkNoiseReductionHook.setEnabled(false);
      final x = whiteNoise(4096, 0.1);
      final copy = Float32List.fromList(x);
      ForkNoiseReductionHook.process(x);
      expect(x, copy);
      ForkNoiseReductionHook.setEnabled(true);
      expect(ForkNoiseReductionHook.enabled, isTrue);
      ForkNoiseReductionHook.process(x);
      expect(x, isNot(copy));
      ForkNoiseReductionHook.setEnabled(false);
    });

    test('benchmark: cost per second of audio', () {
      final r = ContinuousNoiseReducer();
      final x = whiteNoise(kRate * 10, 0.05);
      inChunks(Float32List.fromList(x), 1600, r.process); // warm up JIT
      final sw = Stopwatch()..start();
      inChunks(x, 1600, r.process);
      sw.stop();
      final msPerSecond = sw.elapsedMicroseconds / 1000 / 10;
      // ignore: avoid_print
      print('ContinuousNoiseReducer: ${msPerSecond.toStringAsFixed(2)} ms '
          'per second of audio (host JIT)');
      // Generous bound: 5 % of real time even on a slow CI host.
      expect(msPerSecond, lessThan(50));
    });
  });
}
