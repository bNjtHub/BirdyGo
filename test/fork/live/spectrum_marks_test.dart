import 'dart:ui';

import 'package:birdnet_live/features/live/live_session.dart';
import 'package:birdnet_live/fork/design/species_accents.dart';
import 'package:birdnet_live/fork/live/spectrum_marks.dart';
import 'package:flutter_test/flutter_test.dart';

final _t0 = DateTime(2026, 9, 26, 7);
DateTime _at(double s) => _t0.add(Duration(milliseconds: (s * 1000).round()));

void main() {
  group('SpectrumClock', () {
    test('counts wall time while nothing is paused', () {
      final clock = SpectrumClock(_t0);
      expect(clock.audioSecondsBetween(_at(2), _at(12)), 10);
      expect(clock.audioSecondsBetween(_at(12), _at(2)), 0);
    });

    test('pauses do not scroll the spectrogram', () {
      final clock =
          SpectrumClock(_t0)
            ..pause(_at(10))
            ..resume(_at(40));
      // 5 s before the pause, 5 s after it.
      expect(clock.audioSecondsBetween(_at(5), _at(45)), 10);
      // A mark drawn during a running pause stands still.
      clock.pause(_at(50));
      final a = clock.audioSecondsBetween(_at(45), _at(60));
      final b = clock.audioSecondsBetween(_at(45), _at(90));
      expect(a, 5);
      expect(b, 5);
    });
  });

  group('spectrumMarkRect', () {
    const size = Size(300, 120);

    test('right edge is now, width spans the display time', () {
      final rect =
          spectrumMarkRect(
            size: size,
            displaySeconds: 10,
            startAge: 5,
            endAge: 2,
          )!;
      expect(rect.left, closeTo(150, 1e-9));
      expect(rect.right, closeTo(240, 1e-9));
    });

    test('a bar along the bottom edge, never a box around a sound', () {
      final rect =
          spectrumMarkRect(
            size: size,
            displaySeconds: 10,
            startAge: 9,
            endAge: 0,
          )!;
      expect(rect.height, kSpectrumMarkHeight);
      expect(rect.bottom, size.height - kSpectrumMarkInset);
    });

    test('clipped at the edges, dropped when off screen', () {
      final partial =
          spectrumMarkRect(
            size: size,
            displaySeconds: 10,
            startAge: 14,
            endAge: 8,
          )!;
      expect(partial.left, 0);
      expect(
        spectrumMarkRect(
          size: size,
          displaySeconds: 10,
          startAge: 30,
          endAge: 12,
        ),
        isNull,
      );
    });

    test('a short call stays visible', () {
      final rect =
          spectrumMarkRect(
            size: size,
            displaySeconds: 10,
            startAge: 1.001,
            endAge: 1,
          )!;
      expect(rect.width, kSpectrumMarkMinWidth);
    });
  });

  test('buildSpectrumMarks: open episodes run to now while singing', () {
    DetectionRecord rec(String name, double start, [double? end]) =>
        DetectionRecord(
          scientificName: name,
          commonName: name,
          confidence: 0.9,
          timestamp: _at(start),
          endTimestamp: end == null ? null : _at(end),
        );
    final marks = buildSpectrumMarks(
      records: [rec('Erithacus rubecula', 0, 6), rec('A', 2), rec('B', 4)],
      currentSpecies: {'A'},
      window: const Duration(seconds: 3),
      colorOf: speciesAccentFor,
    );
    expect(marks[0].end, _at(6));
    expect(marks[0].color, const Color(0xFFEC7A3C));
    expect(marks[1].end, isNull);
    expect(marks[2].end, _at(7));
  });
}
