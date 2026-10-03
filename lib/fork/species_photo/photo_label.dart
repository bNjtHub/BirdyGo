/// What a species photo shows: life stage and sex, from iNaturalist
/// annotations (J7). Unknown parts are simply absent.
library;

import 'package:birdnet_live/l10n/app_localizations.dart';

import 'species_photo_config.dart';

enum PhotoLifeStage { adult, juvenile, egg }

enum PhotoSex { female, male }

class PhotoLabel {
  const PhotoLabel({this.stage, this.sex});

  final PhotoLifeStage? stage;
  final PhotoSex? sex;

  bool get isEmpty => stage == null && sex == null;

  /// Reads the `annotations` of an observation. Annotations voted down are
  /// ignored. Null when neither life stage nor sex is known.
  static PhotoLabel? fromAnnotations(Object? annotations) {
    PhotoLifeStage? stage;
    PhotoSex? sex;
    for (final a in (annotations as List? ?? const []).whereType<Map>()) {
      final score = a['vote_score'];
      if (score is num && score < kInatMinAnnotationScore) continue;
      final value = a['controlled_value_id'];
      switch (a['controlled_attribute_id']) {
        case kInatTermLifeStage:
          stage ??= switch (value) {
            kInatValueAdult => PhotoLifeStage.adult,
            kInatValueJuvenile => PhotoLifeStage.juvenile,
            kInatValueEgg => PhotoLifeStage.egg,
            _ => null,
          };
        case kInatTermSex:
          sex ??= switch (value) {
            kInatValueFemale => PhotoSex.female,
            kInatValueMale => PhotoSex.male,
            _ => null,
          };
      }
    }
    final label = PhotoLabel(stage: stage, sex: sex);
    return label.isEmpty ? null : label;
  }

  /// "Adulte · mâle", "Juvénile", "Femelle"; null without a label.
  static String? text(AppLocalizations l10n, PhotoLabel? label) {
    if (label == null || label.isEmpty) return null;
    final stage = switch (label.stage) {
      PhotoLifeStage.adult => l10n.forkPhotoAdult,
      PhotoLifeStage.juvenile => l10n.forkPhotoJuvenile,
      PhotoLifeStage.egg => l10n.forkPhotoEgg,
      null => null,
    };
    final sex = switch (label.sex) {
      PhotoSex.female => l10n.forkPhotoFemale,
      PhotoSex.male => l10n.forkPhotoMale,
      null => null,
    };
    // The sex follows the stage in lower case, alone it opens the label.
    return stage == null
        ? sex
        : (sex == null ? stage : '$stage · ${sex.toLowerCase()}');
  }

  /// "Photo 2 sur 5", followed by what the photo shows when known.
  static String position(
    AppLocalizations l10n,
    int position,
    int total,
    PhotoLabel? label,
  ) {
    final shown = PhotoLabel.text(l10n, label);
    final base = l10n.forkPhotoPosition(position, total);
    return shown == null
        ? base
        : l10n.forkPhotoWithLabel(base, shown.toLowerCase());
  }
}
