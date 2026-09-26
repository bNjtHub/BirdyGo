/// Tunable values of the species photos (fork/PLAN.md J6b, DESIGN.md Photos).
library;

/// iNaturalist API, asked for one taxon when its sheet opens.
const String kInatApiBase = 'https://api.inaturalist.org/v1';

/// Page of one iNaturalist photo, followed by its id.
const String kInatPhotoPage = 'https://www.inaturalist.org/photos/';

/// Page of one Macaulay Library asset, followed by its number.
const String kMacaulayAssetPage = 'https://macaulaylibrary.org/asset/';

/// Licenses an online photo may carry. Same list as
/// tools/fork_species_photos.py: no "nd", the photo is cropped to 3:2.
const Set<String> kOpenPhotoLicenses = {
  'cc0',
  'cc-by',
  'cc-by-sa',
  'cc-by-nc',
  'cc-by-nc-sa',
  'pd',
};

/// Width over height below which a photo is skipped: a portrait photo
/// cropped to 3:2 would lose the bird. Same value as the bundle script.
const double kPhotoMinAspectRatio = 1.3;

/// Aspect ratio of the species photo frame (the bundled photos are 480×320).
const double kSpeciesPhotoAspectRatio = 3 / 2;

/// iNaturalist size of the online photo: 1024 px on the long side.
const String kOnlinePhotoSize = 'large';

/// Largest photo file accepted, in bytes.
const int kOnlinePhotoMaxBytes = 4 * 1024 * 1024;

/// Disk cache of online photos; the least recently shown go first.
const int kPhotoCacheMaxBytes = 50 * 1024 * 1024;

/// Folder of the cache, inside the app's cache directory.
const String kPhotoCacheDirName = 'fork_species_photos';

/// After this age, the chosen photo is asked again (it may have changed).
const Duration kPhotoInfoMaxAge = Duration(days: 30);

/// Time limits of the API request and of the photo download.
const Duration kPhotoApiTimeout = Duration(seconds: 10);
const Duration kPhotoDownloadTimeout = Duration(seconds: 20);

/// Settings key of the "large photos (online)" switch, off by default.
const String kOnlinePhotosPref = 'fork_allow_online_photos';
