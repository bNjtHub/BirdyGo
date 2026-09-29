/// What the volume alerts say for a level (J6h).
library;

import 'media_volume_config.dart';

enum MediaVolumeState {
  muted,
  low;

  /// Null when nothing is wrong (or the level is unknown).
  static MediaVolumeState? of(double? level) {
    if (level == null) return null;
    if (level <= 0) return muted;
    if (level < MediaVolumeConfig.lowBelow) return low;
    return null;
  }
}
