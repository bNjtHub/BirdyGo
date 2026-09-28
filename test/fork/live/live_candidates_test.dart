import 'dart:convert';
import 'dart:io';

import 'package:birdnet_live/features/inference/model_config.dart';
import 'package:birdnet_live/features/inference/models/detection.dart';
import 'package:birdnet_live/features/inference/models/species.dart';
import 'package:birdnet_live/features/inference/post_processor.dart';
import 'package:birdnet_live/features/inference/species_filter.dart';
import 'package:birdnet_live/features/live/live_session.dart';
import 'package:birdnet_live/fork/design/birdy_theme.dart';
import 'package:birdnet_live/fork/live/live_candidates.dart';
import 'package:birdnet_live/fork/live/live_control_bar.dart';
import 'package:birdnet_live/fork/live/live_header.dart';
import 'package:birdnet_live/fork/live/live_table.dart';
import 'package:birdnet_live/fork/live/live_table_model.dart';
import 'package:birdnet_live/fork/reliability/reliability_config.dart';
import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _bird = Species(
  index: 0,
  id: 0,
  scientificName: 'Turdus merula',
  commonName: 'Eurasian Blackbird',
  className: 'Aves',
  order: 'Passeriformes',
);
const _insect = Species(
  index: 1,
  id: 1,
  scientificName: 'Gryllus campestris',
  commonName: 'Field Cricket',
  className: 'Insecta',
  order: 'Orthoptera',
);
const _other = Species(
  index: 2,
  id: 2,
  scientificName: 'Parus major',
  commonName: 'Great Tit',
  className: 'Aves',
  order: 'Passeriformes',
);
const _labels = [_bird, _insect, _other];

final _t0 = DateTime(2026, 9, 26, 6, 30);
const _window = Duration(seconds: 3);

/// Temporal pooling of the bundled model config: the support threshold comes
/// from the pipeline, never from a copied constant.
final TemporalPoolingConfig _pooling =
    ModelConfig.fromJson(
      (jsonDecode(File('assets/models/model_config.json').readAsStringSync())
              as Map<String, dynamic>)['audioModel']
          as Map<String, dynamic>,
    ).inference.temporalPooling;

/// The post-processing of `InferenceService` on window scores (LME pooling,
/// temporal support gate, threshold), without the model.
class _Pipeline {
  _Pipeline(this.threshold);

  final double threshold;
  final List<List<double>> _recent = [];
  Set<int> _confirmed = {};

  double get support => _pooling.supportThresholdFor(threshold);

  List<Detection> step(List<double> window, DateTime start) {
    _recent.add(window);
    if (_recent.length > _pooling.maxWindows) _recent.removeAt(0);
    final pooled = PostProcessor.logMeanExp(_recent, alpha: _pooling.alpha);
    final gated = PostProcessor.applyTemporalSupportGate(
      scores: pooled,
      windowScores: _recent,
      confirmedIndexes: _confirmed,
      confidenceThreshold: threshold,
      supportThreshold: support,
      minSupportWindows: _pooling.minSupportWindows,
      veryHighImmediateThreshold: _pooling.veryHighImmediateThreshold,
    );
    final detections = PostProcessor.topK(
      scores: gated,
      labels: _labels,
      threshold: threshold,
      timestamp: start,
    );
    _confirmed = {for (final d in detections) d.species.index};
    return detections;
  }
}

/// One cycle of the live screen: results, session records, signal.
class _Cycle {
  _Cycle(this.confirmed, this.records, this.signal);
  final List<Detection> confirmed;
  final List<DetectionRecord> records;
  final LiveCycleSignal signal;
}

/// Runs [windows] (scores per label) through the pipeline and the tracker,
/// opening a record when a species enters the results.
List<_Cycle> _run(
  List<List<double>> windows, {
  double threshold = 0.4,
  SpeciesFilterMode mode = SpeciesFilterMode.off,
  Map<String, double>? geoScores,
  Set<String>? geoNames,
}) {
  final pipeline = _Pipeline(threshold);
  final tracker = LiveCycleTracker();
  final records = <DetectionRecord>[];
  var previous = <String>{};
  final cycles = <_Cycle>[];
  for (var i = 0; i < windows.length; i++) {
    final start = _t0.add(Duration(seconds: i));
    final confirmed = liveSpeciesFilter(
      pipeline.step(windows[i], start),
      mode: mode,
      threshold: threshold,
      geoScores: geoScores,
      geoNames: geoNames,
    );
    for (final d in confirmed) {
      if (!previous.contains(d.species.scientificName)) {
        records.add(DetectionRecord.fromDetection(d));
      }
    }
    previous = {for (final d in confirmed) d.species.scientificName};
    final signal = tracker.update(
      windowScores: windows[i],
      labels: _labels,
      poolingMode: 'adaptive_lme_peak',
      supportThreshold: pipeline.support,
      confirmed: confirmed,
      records: records,
      filterMode: mode,
      geoScores: geoScores,
      geoNames: geoNames,
      windowEnd: start.add(_window),
      window: _window,
      expectedHop: const Duration(seconds: 1),
      processedAt: start.add(_window),
    );
    cycles.add(_Cycle(confirmed, List.of(records), signal));
  }
  return cycles;
}

Set<String> _names(List<Detection> detections) => {
  for (final d in detections) d.species.scientificName,
};

void main() {
  test('the support threshold comes from the model config', () {
    expect(
      _Pipeline(0.4).support,
      _pooling.supportThresholdFor(0.4),
      reason: 'same formula as InferenceService',
    );
  });

  group('0.3 → 0.5 → 0.5', () {
    final cycles = _run([
      [0.3, 0, 0],
      [0.5, 0, 0],
      [0.5, 0, 0],
    ]);

    test('« Analyse… », then the row, never an empty or double cycle', () {
      expect(cycles[0].confirmed, isEmpty);
      expect(cycles[0].signal.candidates, {'Turdus merula'});
      expect(cycles[1].confirmed, isNotEmpty, reason: 'confirmed at 0.5');
      for (final c in cycles) {
        expect(
          c.signal.analysing || c.confirmed.isNotEmpty,
          isTrue,
          reason: 'never an empty cycle',
        );
        expect(
          c.signal.candidates.intersection(_names(c.confirmed)),
          isEmpty,
          reason: 'never a candidate and a row at once',
        );
      }
    });

    test('« Analyse… » stays one cycle after the confirmation', () {
      expect(cycles.map((c) => c.signal.analysing), [true, true, false]);
      expect(ReliabilityConfig.analysingHoldWindows, 1);
    });

    testWidgets('one vibration, the header fades to « Analyse… »', (
      tester,
    ) async {
      var vibrations = 0;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'HapticFeedback.vibrate') vibrations++;
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      Future<void> pump(List<LiveTableEntry> entries, bool analysing) =>
          tester.pumpWidget(
            MaterialApp(
              theme: BirdyTheme.dark(),
              locale: const Locale('fr'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: Builder(
                  builder: (context) {
                    final l10n = AppLocalizations.of(context)!;
                    return Column(
                      children: [
                        LiveHeader(
                          statusText:
                              analysing
                                  ? l10n.forkLiveAnalysing
                                  : l10n.forkLiveListening,
                          phase: LiveControlPhase.active,
                          stats: LiveStats.of(entries),
                          elapsed: () => Duration.zero,
                          expanded: false,
                          onOptions: () {},
                          onBack: () {},
                        ),
                        Expanded(child: LiveTable(entries: entries)),
                      ],
                    );
                  },
                ),
              ),
            ),
          );

      // The status line's `Text.rich` embeds the mode icon as a `WidgetSpan`
      // placeholder character (J6f): match its semantics label instead.
      Text statusText() => tester
          .widgetList<Text>(find.byType(Text))
          .firstWhere((t) => t.textSpan != null);

      await pump(const [], false);
      expect(statusText().semanticsLabel, 'En écoute · Normal');
      for (final c in cycles) {
        await pump(
          buildLiveTable(
            sessionDetections: c.records,
            currentDetections: [
              for (final d in c.confirmed) DetectionRecord.fromDetection(d),
            ],
            singingVisual: c.signal.singingVisual,
          ),
          c.signal.analysing,
        );
        await tester.pump(const Duration(milliseconds: 400));
        if (c == cycles.first) {
          expect(statusText().semanticsLabel, 'Analyse… · Normal');
          expect(find.text('Turdus merula'), findsNothing, reason: 'no name');
          expect(vibrations, 0, reason: '« Analyse… » never vibrates');
        }
      }
      expect(vibrations, 1);
      expect(statusText().semanticsLabel, 'En écoute · Normal');
    });
  });

  test('an isolated 0.6 held back by the gate gives « Analyse… »', () {
    final cycles = _run([
      [0.6, 0, 0],
    ], threshold: 0.5);
    expect(0.6, greaterThanOrEqualTo(0.5), reason: 'above the threshold');
    expect(cycles.single.confirmed, isEmpty, reason: 'one window of support');
    expect(cycles.single.signal.candidates, {'Turdus merula'});
    expect(cycles.single.signal.analysing, isTrue);
  });

  test('an insect is never a candidate', () {
    final cycles = _run([
      [0, 0.9, 0],
    ]);
    expect(cycles.single.signal.candidates, isEmpty);
    expect(cycles.single.signal.analysing, isFalse);
  });

  group('species filter', () {
    test('geoExclude: under the geo threshold, ignored', () {
      final cycles = _run(
        [
          [0.35, 0, 0.35],
        ],
        mode: SpeciesFilterMode.geoExclude,
        geoScores: {'Turdus merula': 0.01, 'Parus major': 0.5},
      );
      expect(cycles.single.signal.candidates, {'Parus major'});
    });

    test('outside the geo-model species, ignored', () {
      final cycles = _run(
        [
          [0.35, 0, 0.35],
        ],
        geoNames: {'Parus major'},
      );
      expect(cycles.single.signal.candidates, {'Parus major'});
    });
  });

  test('under the support threshold: no candidate', () {
    final support = _Pipeline(0.4).support;
    final cycles = _run([
      [support - 0.01, 0, 0],
    ]);
    expect(cycles.single.signal.candidates, isEmpty);
  });

  for (final mode in ['off', 'avg', 'average', 'max']) {
    test('pooling $mode: never a candidate', () {
      expect(
        liveCandidates(
          windowScores: const [0.9, 0, 0],
          labels: _labels,
          poolingMode: mode,
          supportThreshold: 0.25,
          confirmed: const {},
          filter: (d) => d,
        ),
        isEmpty,
      );
    });
  }

  test('a replayed window clears everything but the mark ends', () {
    final tracker = LiveCycleTracker();
    final record = DetectionRecord(
      scientificName: 'Turdus merula',
      commonName: 'Eurasian Blackbird',
      confidence: 0.9,
      timestamp: _t0,
    );
    final lit = tracker.update(
      windowScores: const [0.9, 0, 0.5],
      labels: _labels,
      poolingMode: 'adaptive_lme_peak',
      supportThreshold: 0.25,
      confirmed: [Detection(species: _bird, confidence: 0.9, timestamp: _t0)],
      records: [record],
      filterMode: SpeciesFilterMode.off,
      windowEnd: _t0.add(_window),
      window: _window,
      expectedHop: const Duration(seconds: 1),
      processedAt: _t0.add(_window),
    );
    expect(lit.analysing, isTrue);
    expect(lit.singingVisual, {'Turdus merula'});

    final replayed = tracker.update(
      windowScores: const [0.9, 0, 0.5],
      labels: _labels,
      poolingMode: 'adaptive_lme_peak',
      supportThreshold: 0.25,
      confirmed: [Detection(species: _bird, confidence: 0.9, timestamp: _t0)],
      records: [record],
      filterMode: SpeciesFilterMode.off,
      windowEnd: _t0.add(const Duration(seconds: 4)),
      window: _window,
      expectedHop: const Duration(seconds: 1),
      processedAt: _t0.add(const Duration(seconds: 4)),
      replayHeard: true,
    );
    expect(replayed.candidates, isEmpty);
    expect(replayed.analysing, isFalse);
    expect(replayed.singingVisual, isEmpty);
    expect(replayed.heardUntil, lit.heardUntil);
  });
}
