/// Tunable values of the contact map (fork/PLAN.md J5).
library;

/// Below this zoom the map shows the hexagon grid; from it, bird markers.
const double kMapMarkersFromZoom = 13;

/// Hexagon radius on screen, in logical pixels, at the zoom it was binned at.
const double kMapHexRadiusPx = 26;

/// Contacts closer than one hexagon of this zoom's grid share a marker
/// ("a spot"): about 25 m around the point in France.
const int kMapSpotZoom = 17;

/// Radius of the spot grid, in pixels at [kMapSpotZoom].
const double kMapSpotRadiusPx = 22;

/// Hexagon opacity range: the emptiest cell to the busiest one.
const double kMapHexMinOpacity = 0.18;
const double kMapHexMaxOpacity = 0.8;

/// Number of opacity levels: few levels let the map batch hexagons of the
/// same color into one draw call.
const int kMapHexOpacitySteps = 8;

/// Zoom used when the map has a single point to show.
const double kMapSinglePointZoom = 15;

/// Highest zoom the IGN Géoplateforme tiles are served at (PM matrix set).
const int kIgnMaxNativeZoom = 19;

/// Size of the grid sensitive species' positions snap to in exports, in
/// degrees (0.1° is about 11 km north–south).
const double kSensitiveBlurDegrees = 0.1;
