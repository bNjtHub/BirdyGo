/// Region rules of the contact map: default view and IGN availability
/// (English version prep). Pure functions, easy to test.
library;

import 'package:latlong2/latlong.dart';

import 'base_layers.dart';
import 'map_config.dart';

/// Camera of an empty map (no contact to fit).
typedef MapDefaultView = ({LatLng center, double zoom});

/// Last known position when there is one, else a neutral world view.
MapDefaultView emptyMapView(LatLng? knownPosition) =>
    knownPosition != null
        ? (center: knownPosition, zoom: kMapKnownPositionZoom)
        : (
          center: const LatLng(kMapWorldCenterLat, kMapWorldCenterLng),
          zoom: kMapWorldZoom,
        );

/// IGN maps only cover France: offered when the device region is France or
/// the UI is in French.
bool ignLayersAvailable({String? regionCode, String? languageCode}) =>
    regionCode?.toUpperCase() == kMapIgnRegionCode ||
    languageCode?.toLowerCase() == kMapIgnLanguageCode;

/// Base maps shown in the picker.
List<MapBaseLayer> availableBaseLayers({
  String? regionCode,
  String? languageCode,
}) =>
    ignLayersAvailable(regionCode: regionCode, languageCode: languageCode)
        ? MapBaseLayer.values
        : const [MapBaseLayer.osm];

/// [selected] if it is offered, else OpenStreetMap.
MapBaseLayer effectiveBaseLayer(
  MapBaseLayer selected, {
  String? regionCode,
  String? languageCode,
}) =>
    availableBaseLayers(
          regionCode: regionCode,
          languageCode: languageCode,
        ).contains(selected)
        ? selected
        : MapBaseLayer.osm;
