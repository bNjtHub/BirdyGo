/// Small, still map of a species' contacts on the species page (J6c).
/// Same base layer and tile cache as the contact map; a tap opens it.
library;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../design/birdy_tokens.dart';
import 'species_page_config.dart';
import 'species_page_model.dart';

class SpeciesMiniMap extends StatelessWidget {
  const SpeciesMiniMap({
    super.key,
    required this.spots,
    required this.tileLayer,
    required this.semanticLabel,
    required this.onTap,
  });

  /// At least one place.
  final List<MapSpot> spots;

  /// The user's base layer, or null (tests, no network needed).
  final Widget? tileLayer;
  final String semanticLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = BirdyColors.of(context);
    final points = [for (final s in spots) LatLng(s.latitude, s.longitude)];
    final single = points.every((p) => p == points.first);
    return Semantics(
      button: true,
      label: semanticLabel,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(BirdyRadii.inset),
        child: DecoratedBox(
          position: DecorationPosition.foreground,
          decoration: BoxDecoration(
            border: Border.all(color: c.line),
            borderRadius: BorderRadius.circular(BirdyRadii.inset),
          ),
          child: ColoredBox(
            color: c.surface2,
            child: Stack(
              fit: StackFit.expand,
              children: [
                IgnorePointer(
                  child: FlutterMap(
                    options: MapOptions(
                      initialCenter: points.first,
                      initialZoom: SpeciesPageConfig.miniMapSingleZoom,
                      initialCameraFit:
                          single
                              ? null
                              : CameraFit.coordinates(
                                coordinates: points,
                                padding: const EdgeInsets.all(16),
                                maxZoom: SpeciesPageConfig.miniMapSingleZoom,
                              ),
                      interactionOptions: const InteractionOptions(
                        flags: InteractiveFlag.none,
                      ),
                    ),
                    children: [
                      if (tileLayer != null) tileLayer!,
                      CircleLayer(
                        circles: [
                          for (final p in points)
                            CircleMarker(
                              point: p,
                              radius: 5,
                              color: BirdyBrand.kingfisher,
                              borderColor: Colors.white,
                              borderStrokeWidth: 1.5,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                Material(
                  type: MaterialType.transparency,
                  child: InkWell(onTap: onTap),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
