/// End-to-end check of the modes through the real AudioCaptureService DSP:
/// mic bytes in → gain → high-pass → fork noise hook → ring buffer out.
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:birdnet_live/features/audio/audio_capture_service.dart';
import 'package:birdnet_live/features/audio/ring_buffer.dart';
import 'package:birdnet_live/fork/listening_mode/continuous_noise_reducer.dart';
import 'package:birdnet_live/fork/listening_mode/listening_mode.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:record/record.dart';

import 'signals.dart';

class _FakeRecord extends RecordPlatform {
  StreamController<Uint8List>? _ctrl;

  void emit(Uint8List bytes) => _ctrl?.add(bytes);

  @override
  Future<void> create(String recorderId) async {}

  @override
  Future<bool> hasPermission(String recorderId, {bool request = true}) async =>
      true;

  @override
  Future<Stream<Uint8List>> startStream(
    String recorderId,
    RecordConfig config,
  ) async {
    _ctrl = StreamController<Uint8List>.broadcast(sync: true);
    return _ctrl!.stream;
  }

  @override
  void setOnConfigChanged(
    String recorderId,
    void Function(RecordConfig config)? handler,
  ) {}

  @override
  Stream<RecordState> onStateChanged(String recorderId) =>
      const Stream<RecordState>.empty();

  @override
  Future<String?> stop(String recorderId) async {
    await _ctrl?.close();
    _ctrl = null;
    return null;
  }

  @override
  Future<void> dispose(String recorderId) async {
    await _ctrl?.close();
    _ctrl = null;
  }

  @override
  Future<bool> isRecording(String recorderId) async => _ctrl != null;

  @override
  Future<List<InputDevice>> listInputDevices(String recorderId) async =>
      const [];

  @override
  Future<bool> isEncoderSupported(
    String recorderId,
    AudioEncoder encoder,
  ) async => true;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Uint8List _toPcm16(Float32List x) {
  final bytes = ByteData(x.length * 2);
  for (var i = 0; i < x.length; i++) {
    bytes.setInt16(
      i * 2,
      (x[i].clamp(-1.0, 1.0) * 32767).round(),
      Endian.little,
    );
  }
  return bytes.buffer.asUint8List();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late RecordPlatform original;
  late _FakeRecord fake;
  late AudioCaptureService service;

  setUp(() async {
    original = RecordPlatform.instance;
    fake = _FakeRecord();
    RecordPlatform.instance = fake;
    service = AudioCaptureService(ringBuffer: RingBuffer(capacity: kRate * 4));
    await service.start();
  });

  tearDown(() async {
    ForkNoiseReductionHook.setEnabled(false);
    await service.dispose();
    RecordPlatform.instance = original;
  });

  /// Runs 2 s of [signal] through the capture chain with [mode] applied the
  /// way the live screens do, and returns the last second out.
  Future<Float32List> run(ListeningMode mode, Float32List signal) async {
    final preset = mode.preset;
    service.setGain(preset.gain);
    service.setHighPassCutoff(preset.highPassHz);
    ForkNoiseReductionHook.setEnabled(preset.noiseReduction);
    for (var i = 0; i < signal.length; i += 1600) {
      fake.emit(_toPcm16(Float32List.sublistView(signal, i, i + 1600)));
    }
    await pumpEventQueue();
    return service.ringBuffer.readLast(kRate);
  }

  Float32List humAndSong() {
    final x = Float32List(kRate * 2);
    addTone(x, 100, 0.2); // wind / handling rumble stand-in
    addTone(x, 3000, 0.1); // song
    return x;
  }

  test('Normal leaves hum and song as they are', () async {
    final out = await run(ListeningMode.normal, humAndSong());
    expect(toneAmplitude(out, 100, 0, kRate), closeTo(0.2, 0.01));
    expect(toneAmplitude(out, 3000, 0, kRate), closeTo(0.1, 0.01));
  });

  test('Vent cuts a 100 Hz hum and keeps a 3 kHz song', () async {
    final out = await run(ListeningMode.wind, humAndSong());
    expect(db(toneAmplitude(out, 100, 0, kRate) / 0.2), lessThan(-25));
    expect(db(toneAmplitude(out, 3000, 0, kRate) / 0.1).abs(), lessThan(1));
  });

  test('Vent keeps a low owl-like 400 Hz call within 2 dB', () async {
    final x = Float32List(kRate * 2);
    addTone(x, 400, 0.1);
    final out = await run(ListeningMode.wind, x);
    expect(db(toneAmplitude(out, 400, 0, kRate) / 0.1).abs(), lessThan(2));
  });

  test('Boost doubles the song', () async {
    final out = await run(ListeningMode.boost, humAndSong());
    expect(db(toneAmplitude(out, 3000, 0, kRate) / 0.1), closeTo(6, 0.5));
  });

  test('Ville goes through the fork hook and lowers steady noise', () async {
    final x = whiteNoise(kRate * 4, 0.05);
    final out = await run(ListeningMode.city, x);
    final inRms = rms(x, x.length - kRate, kRate);
    expect(db(rms(out, 0, kRate) / inRms), lessThan(-8));
  });
}
