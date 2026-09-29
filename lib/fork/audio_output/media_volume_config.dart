/// Thresholds for the media volume warning on the listening screen (J6h).
/// Replayed clips play on the media stream: a muted or low volume means
/// the user hears nothing.
library;

abstract final class MediaVolumeConfig {
  /// Below this share of the maximum, the volume counts as low.
  static const double lowBelow = 0.25;

  /// Level set by « Monter le son », as a share of the maximum.
  static const double comfortable = 0.6;

  /// How often the level is read while the banner is mounted.
  static const Duration pollInterval = Duration(seconds: 1);
}
