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

/// Online photos added after the bundled one in the species page carousel.
const int kCarouselExtraPhotos = 4;

/// Carousel page dots (DESIGN.md Photos).
const double kCarouselDotSize = 6;
const double kCarouselDotGap = 6;

/// "More photos are coming" spinner after the dots: size, stroke, and the
/// fixed progress shown instead of the spin with reduced motion.
const double kCarouselLoaderSize = 11;
const double kCarouselLoaderStroke = 1.5;
const double kCarouselLoaderStaticProgress = 0.3;

/// Opacity of the inactive dots and of the spinner.
const double kCarouselDimAlpha = 0.5;

/// Height of the top scrim of the header photo below the status bar.
const double kPhotoTopScrimExtra = 56;

/// Full-screen photo viewer: pinch limit, double-tap zoom, drag-to-close.
const double kViewerMaxScale = 4;
const double kViewerDoubleTapScale = 2;

/// Below this scale the photo counts as not zoomed (pages swipe, drag closes).
const double kViewerZoomedAbove = 1.02;
const Duration kViewerZoomDuration = Duration(milliseconds: 220);

/// A drag down past this fraction of the screen height, or this fling
/// speed (dp/s), closes the viewer.
const double kViewerDismissFraction = 0.15;
const double kViewerDismissVelocity = 700;

/// Photo shrinks at most to this scale while dragged away.
const double kViewerDismissMinScale = 0.85;

/// Observations of a taxon, for photos labelled by life stage and sex.
/// API v2 with `fields`: ~25 KB instead of ~8 MB with v1.
const String kInatApiBaseV2 = 'https://api.inaturalist.org/v2';
const int kObservationsPerPage = 30;
const String kObservationFields =
    'annotations.controlled_attribute_id,annotations.controlled_value_id,'
    'annotations.vote_score,photos.id,photos.url,photos.license_code,'
    'photos.attribution,photos.original_dimensions.width,'
    'photos.original_dimensions.height';

/// iNaturalist controlled terms (checked against /v1/controlled_terms):
/// 1 = Life Stage, 9 = Sex.
const int kInatTermLifeStage = 1;
const int kInatValueAdult = 2;
const int kInatValueJuvenile = 8;
const int kInatValueEgg = 7;
const int kInatTermSex = 9;
const int kInatValueFemale = 10;
const int kInatValueMale = 11;

/// An annotation counts unless the community voted it down.
const int kInatMinAnnotationScore = 0;
