import 'package:birdnet_live/features/inference/models/detection.dart';
import 'package:birdnet_live/features/inference/models/species.dart';
import 'package:flutter_test/flutter_test.dart';

const _species = Species(
  index: 0,
  id: 1,
  scientificName: 'Parus major',
  commonName: 'Great Tit',
  className: 'Aves',
  order: 'Passeriformes',
);

void main() {
  test('ordinary detections use their reported score for decisions', () {
    const detection = Detection(species: _species, confidence: 0.8);

    expect(detection.decisionConfidence, isNull);
    expect(detection.effectiveDecisionConfidence, 0.8);
  });

  test('reported peak and decision evidence remain separate', () {
    const detection = Detection(
      species: _species,
      confidence: 0.95,
      decisionConfidence: 0.6,
    );

    expect(detection.effectiveDecisionConfidence, 0.6);
    expect(detection.confidencePercent, '95.0 %');
  });

  test('equality includes effective decision evidence', () {
    const implicit = Detection(species: _species, confidence: 0.8);
    const explicit = Detection(
      species: _species,
      confidence: 0.8,
      decisionConfidence: 0.8,
    );
    const weaker = Detection(
      species: _species,
      confidence: 0.8,
      decisionConfidence: 0.5,
    );

    expect(implicit, explicit);
    expect(implicit.hashCode, explicit.hashCode);
    expect(implicit, isNot(weaker));
    expect({implicit, explicit, weaker}, hasLength(2));
  });
}
