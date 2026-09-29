/// Thresholds for the media volume alerts (J6h): the live banner and the
/// prompt before any playback. A muted or low media volume means the user
/// hears nothing.
library;

abstract final class MediaVolumeConfig {
  /// Below this share of the maximum, the volume counts as low.
  static const double lowBelow = 0.25;

  /// Level set by « Monter le son », as a share of the maximum.
  static const double comfortable = 0.4;

  /// How often the level is read while the banner is mounted.
  static const Duration pollInterval = Duration(seconds: 1);

  /// Minimum time between two prompts before a playback, so a user who
  /// chose to keep the volume low is not nagged.
  static const Duration promptCooldown = Duration(seconds: 45);

  /// How long the prompt stays on screen when nobody taps it.
  static const Duration promptDuration = Duration(seconds: 6);
}
