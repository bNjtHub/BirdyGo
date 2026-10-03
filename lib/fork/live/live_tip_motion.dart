/// How each listening tip icon plays (DESIGN.md « Astuces »). The tips
/// themselves stay upstream (`buildLiveTips`); only the motion is ours.
library;

import 'package:flutter/widgets.dart';

import '../../shared/utils/app_icons.dart';
import '../design/birdy_icons.dart';
import '../design/widgets/birdy_animated_icon.dart';

/// Sound and scores pulse, wind and distance slide, a download comes down,
/// everything else fills in.
BirdyIconMotion liveTipMotion(IconData icon) {
  if (icon == BirdyIcons.song ||
      icon == AppIcons.volumeUpOutlined ||
      icon == AppIcons.bluetoothAudio ||
      icon == AppIcons.percent) {
    return BirdyIconMotion.pulse;
  }
  if (icon == AppIcons.air || icon == AppIcons.volumeDown) {
    return BirdyIconMotion.drift;
  }
  if (icon == AppIcons.saveAlt) return BirdyIconMotion.drop;
  return BirdyIconMotion.fill;
}
