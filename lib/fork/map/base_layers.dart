/// Base maps of the contact map: OpenStreetMap with the app's shared tile
/// settings, plus IGN Plan and aerial photos from the Géoplateforme
/// (fork/PLAN.md J5).
///
/// IGN tiles come from the public WMTS of data.geopf.fr (PM matrix set,
/// Web Mercator), open data under Licence Ouverte Etalab 2.0; the source
/// must be credited on the map (« © IGN – Géoplateforme »). They share the
/// app's on-disk tile cache; nothing is prefetched.
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:http/retry.dart';

import '../../core/constants/app_constants.dart';
import '../../shared/widgets/open_street_map_tile_layer.dart';
import 'map_config.dart';

/// Base maps offered by the contact map.
enum MapBaseLayer {
  osm,
  ignPlan,
  ignPhoto;

  static MapBaseLayer fromName(String? name) => MapBaseLayer.values.firstWhere(
    (l) => l.name == name,
    orElse: () => MapBaseLayer.osm,
  );
}

/// SharedPreferences key of the chosen base map.
const String kMapBaseLayerPref = 'fork_map_base_layer';

const String _geopfWmts =
    'https://data.geopf.fr/wmts?SERVICE=WMTS&REQUEST=GetTile&VERSION=1.0.0'
    '&TILEMATRIXSET=PM&TILEMATRIX={z}&TILEROW={y}&TILECOL={x}&STYLE=normal';

/// WMTS URL of the IGN Plan (Plan IGN v2).
const String kIgnPlanUrlTemplate =
    '$_geopfWmts&LAYER=GEOGRAPHICALGRIDSYSTEMS.PLANIGNV2&FORMAT=image/png';

/// WMTS URL of the IGN aerial photos (BD ORTHO).
const String kIgnPhotoUrlTemplate =
    '$_geopfWmts&LAYER=ORTHOIMAGERY.ORTHOPHOTOS&FORMAT=image/jpeg';

/// Mandatory source credit of [layer].
List<String> baseLayerAttributions(MapBaseLayer layer) => switch (layer) {
  MapBaseLayer.osm => const ['OpenStreetMap contributors'],
  MapBaseLayer.ignPlan => const ['Plan IGN © IGN – Géoplateforme'],
  MapBaseLayer.ignPhoto => const [
    'Photographies aériennes © IGN – Géoplateforme',
  ],
};

http.Client? _ignClient;

/// Tile layer of [layer]. Build it once per layer change, not per frame.
TileLayer buildBaseTileLayer(MapBaseLayer layer) {
  if (layer == MapBaseLayer.osm) return buildOpenStreetMapTileLayer();
  return TileLayer(
    key: ValueKey(layer),
    urlTemplate:
        layer == MapBaseLayer.ignPlan
            ? kIgnPlanUrlTemplate
            : kIgnPhotoUrlTemplate,
    userAgentPackageName: AppConstants.packageName,
    maxNativeZoom: kIgnMaxNativeZoom,
    tileProvider: NetworkTileProvider(
      headers: const {'User-Agent': AppConstants.networkUserAgent},
      // Shared across rebuilds: NetworkTileProvider only closes clients it
      // created itself (see open_street_map_tile_layer.dart).
      httpClient: _ignClient ??= RetryClient(http.Client()),
      cachingProvider: osmTileCachingProvider(),
      silenceExceptions: true,
    ),
    evictErrorTileStrategy: EvictErrorTileStrategy.notVisible,
  );
}
