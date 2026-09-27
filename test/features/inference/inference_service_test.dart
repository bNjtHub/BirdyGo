import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:birdnet_live/features/inference/classifier_model.dart';
import 'package:birdnet_live/features/inference/inference_service.dart';
import 'package:birdnet_live/features/inference/model_config.dart';
import 'package:birdnet_live/features/inference/models/detection.dart';
import 'package:birdnet_live/features/inference/species_filter.dart';
import 'package:flutter_test/flutter_test.dart';

const _name = 'Turdus merula';
const _labels =
    'idx;id;sci_name;com_name;class;order\n'
    '0;1;Turdus merula;Eurasian Blackbird;Aves;Passeriformes\n';
final _start = DateTime.utc(2026, 9, 27, 8);
final _audio = Float32List(0);

/// Feed controlled model outputs through the production inference service,
/// including its real pooling, support gate, timestamps, and score metadata.
class _ScriptedModel extends ClassifierModel {
  _ScriptedModel(List<double> scores) : _scores = scores.iterator;

  final Iterator<double> _scores;

  @override
  bool get isLoaded => true;

  @override
  Future<void> loadModelFromFile(
    String modelPath, {
    String inputName = 'input',
    String predictionsName = 'predictions',
    String? embeddingsName = 'embeddings',
    int? intraOpNumThreads,
  }) async {}

  @override
  Future<ModelOutput> predict(
    Float32List audioSamples, {
    required int windowSamples,
  }) async {
    if (!_scores.moveNext()) throw StateError('No scripted output left');
    return ModelOutput(predictions: [_scores.current]);
  }

  @override
  Future<List<ModelOutput>> predictBatch(
    List<Float32List> audioWindows, {
    required int windowSamples,
  }) async => [
    for (final audio in audioWindows)
      await predict(audio, windowSamples: windowSamples),
  ];

  @override
  Future<void> dispose() async {}
}

Future<InferenceService> _service(
  List<double> scores, {
  double? multiplier,
}) async {
  final json =
      jsonDecode(File('assets/models/model_config.json').readAsStringSync())
          as Map<String, dynamic>;
  final service = InferenceService(model: _ScriptedModel(scores));
  await service.initialize(
    modelFilePath: 'scripted.onnx',
    labelsCsv: _labels,
    config: ModelConfig.fromJson(json['audioModel'] as Map<String, dynamic>),
    scoreBlacklistJson:
        multiplier == null
            ? null
            : jsonEncode({'Eurasian Blackbird': multiplier}),
  );
  addTearDown(service.dispose);
  return service;
}

Future<List<Detection>> _step(
  InferenceService service,
  int second, {
  double? threshold,
}) => service.infer(
  _audio,
  timestamp: _start.add(Duration(seconds: second)),
  confidenceThreshold: threshold,
);

void main() {
  test(
    'a lower threshold cannot revive old support in a silent window',
    () async {
      final service = await _service([0.90, 0.75, 0.01]);
      expect(await _step(service, 0, threshold: 0.95), isEmpty);
      expect(await _step(service, 1, threshold: 0.95), isEmpty);

      expect(await _step(service, 2), isEmpty);
    },
  );

  test('penalized raw peaks cannot bypass repeated confirmation', () async {
    final service = await _service([0.99, 0.99], multiplier: 0.5);
    expect(await _step(service, 0), isEmpty);

    final detection = (await _step(service, 1)).single;
    expect(detection.confidence, closeTo(0.495, 1e-9));
    expect(detection.effectiveDecisionConfidence, closeTo(0.495, 1e-9));
  });

  test('support and contact start use the same penalized scores', () async {
    final service = await _service([0.45, 0.85, 0.90], multiplier: 0.5);
    expect(await _step(service, 0), isEmpty);
    expect(await _step(service, 1), isEmpty);

    final detection = (await _step(service, 2)).single;
    expect(detection.timestamp, _start.add(const Duration(seconds: 1)));
    expect(detection.confidence, closeTo(0.45, 1e-9));
    expect(service.lastWindowScores!.single, closeTo(0.45, 1e-9));
  });

  test(
    'brief supported calls and configured very high calls still pass',
    () async {
      final repeated = await _service([0.90, 0.75]);
      expect(await _step(repeated, 0), isEmpty);
      expect(await _step(repeated, 1), hasLength(1));

      final immediate = await _service([0.99]);
      expect(await _step(immediate, 0), hasLength(1));
    },
  );

  test(
    'recent peak stays separate from geographic decision evidence',
    () async {
      final service = await _service([0.01, 0.01, 0.97, 0.26, 0.01]);
      for (var i = 0; i < 4; i++) {
        await _step(service, i);
      }
      final detection = (await _step(service, 4)).single;
      expect(detection.confidence, 0.97);
      expect(
        detection.effectiveDecisionConfidence,
        inExclusiveRange(0.65, 0.67),
      );
      expect(detection.timestamp, _start.add(const Duration(seconds: 2)));
      expect(service.lastWindowScores!.single, 0.01);

      expect(
        SpeciesFilter.apply(
          detections: [detection],
          mode: SpeciesFilterMode.geoAdaptive,
          confidenceThreshold: 0.35,
          geoScores: const {_name: 0, 'Plausible species': 0.2},
        ),
        isEmpty,
      );
      expect(
        SpeciesFilter.apply(
          detections: [detection],
          mode: SpeciesFilterMode.geoMerge,
          confidenceThreshold: 0.35,
          geoScores: const {_name: 0.4},
        ),
        isEmpty,
      );
    },
  );

  test(
    'batch and streaming calls apply identical support and decision rules',
    () async {
      final scores = [0.45, 0.85, 0.90, 0.01, 0.01];
      final streaming = await _service(scores, multiplier: 0.5);
      final batch = await _service(scores, multiplier: 0.5);
      final expected = [
        for (var i = 0; i < scores.length; i++) await _step(streaming, i),
      ];
      final actual = await batch.inferBatch(
        [for (final _ in scores) _audio],
        timestamps: [
          for (var i = 0; i < scores.length; i++)
            _start.add(Duration(seconds: i)),
        ],
      );

      expect(actual, expected);
      expect(
        [
          for (final cycle in actual)
            for (final d in cycle) d.timestamp,
        ],
        [
          for (final cycle in expected)
            for (final d in cycle) d.timestamp,
        ],
      );
    },
  );

  test('turning pooling off retains direct single-window behavior', () async {
    final service = await _service([0.90, 0.01]);
    service.setPoolingMode('off');
    final detection = (await _step(service, 0)).single;
    expect(detection.confidence, 0.90);
    expect(detection.effectiveDecisionConfidence, 0.90);
    expect(await _step(service, 1), isEmpty);
  });
}
