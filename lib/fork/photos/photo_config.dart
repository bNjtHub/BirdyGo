/// Settings of the species photos (J6b).
library;

abstract final class PhotoConfig {
  /// Credits and large URLs of the bundled photos, written on the PC by
  /// tools/fork_species_photos.py.
  static const String manifestAsset = 'assets/fork/species_photos.json';

  /// Bundled 480x320 photos, one `<birdnet_id>.webp` per species.
  static const String bundledImagesDir = 'assets/species_images/';

  /// Folder of the large photos, in the app cache directory.
  static const String cacheDirName = 'species_photos';

  /// Disk budget of the large photos (about 500 photos of 200 KB).
  static const int maxCacheBytes = 100 * 1024 * 1024;

  /// A large photo is about 200 KB: anything over this is not a photo.
  static const int maxPhotoBytes = 5 * 1024 * 1024;

  /// Past this delay the bundled photo simply stays.
  static const Duration downloadTimeout = Duration(seconds: 20);
}
