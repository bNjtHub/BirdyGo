/// Tunable values of the notification images (J6h).
library;

/// Longest side of the expanded photo, in pixels.
const int kNotificationBigPictureMaxPx = 512;

/// Side of the round large icon, in pixels.
const int kNotificationLargeIconPx = 192;

/// How long a notification waits for its images. Past it, the notification
/// is posted without image: it must never be late because of a photo.
const Duration kNotificationImageTimeout = Duration(milliseconds: 800);

/// Bundled placeholder used when a species has no photo of its own.
const String kNotificationPlaceholderAsset = 'assets/images/dummy_species.png';
