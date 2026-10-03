import 'package:birdnet_live/fork/species_photo/inat_photo_service.dart';
import 'package:birdnet_live/fork/species_photo/photo_label.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _ann(int attr, int value, [num score = 1]) => {
  'controlled_attribute_id': attr,
  'controlled_value_id': value,
  'vote_score': score,
};

Map<String, dynamic> _obs(
  int id,
  List<Map<String, dynamic>> annotations, {
  int width = 2000,
  String license = 'cc-by',
}) => {
  'annotations': annotations,
  'photos': [
    {
      'id': id,
      'license_code': license,
      'attribution': '(c) Author $id, some rights reserved (CC BY)',
      'url': 'https://photos.example/$id/square.jpg',
      'original_dimensions': {'width': width, 'height': 1000},
    },
  ],
};

List<int> _ids(List<InatPhotoChoice> choices) => [
  for (final c in choices) int.parse(c.credit.pageUrl!.split('/').last),
];

void main() {
  group('PhotoLabel.fromAnnotations', () {
    test('life stage and sex', () {
      final label = PhotoLabel.fromAnnotations([_ann(1, 2), _ann(9, 11)]);
      expect(label!.stage, PhotoLifeStage.adult);
      expect(label.sex, PhotoSex.male);
      expect(
        PhotoLabel.fromAnnotations([_ann(1, 8)])!.stage,
        PhotoLifeStage.juvenile,
      );
      expect(PhotoLabel.fromAnnotations([_ann(9, 10)])!.sex, PhotoSex.female);
    });

    test('voted down, unknown values and other terms are ignored', () {
      expect(PhotoLabel.fromAnnotations([_ann(1, 2, -1)]), isNull);
      expect(PhotoLabel.fromAnnotations([_ann(1, 5), _ann(9, 20)]), isNull);
      expect(PhotoLabel.fromAnnotations([_ann(17, 18)]), isNull);
      expect(PhotoLabel.fromAnnotations(null), isNull);
    });
  });

  group('pickFromObservations', () {
    test('adults first, other sex second, juvenile last, max 4', () {
      final picked = InatPhotoChoice.pickFromObservations([
        _obs(1, [_ann(1, 8)]),
        _obs(2, [_ann(1, 2), _ann(9, 11)]),
        _obs(3, [_ann(1, 2), _ann(9, 11)]),
        _obs(4, [_ann(1, 2), _ann(9, 10)]),
        _obs(5, [_ann(1, 2)]),
        _obs(6, [_ann(1, 8)]),
      ]);
      expect(_ids(picked), [2, 4, 3, 1]);
      expect(picked.last.label!.stage, PhotoLifeStage.juvenile);
    });

    test('skips unknown stage, bad licence, portrait, excluded page', () {
      final picked = InatPhotoChoice.pickFromObservations(
        [
          _obs(1, []),
          _obs(2, [_ann(1, 2)], license: 'cc-by-nd'),
          _obs(3, [_ann(1, 2)], width: 800),
          _obs(4, [_ann(1, 2)]),
          _obs(5, [_ann(1, 2)]),
        ],
        exclude: {'https://www.inaturalist.org/photos/4'},
      );
      expect(_ids(picked), [5]);
    });
  });
}
