/// Contacts prepared for the map: hexagon bins for small zooms, species
/// spots for large zooms, and per-area species tallies for the sheet
/// (fork/PLAN.md J5). Pure Dart, no Flutter.
library;

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:latlong2/latlong.dart';

import '../../features/live/live_session.dart';
import '../data/observation_index.dart';
import 'hex_grid.dart';
import 'map_config.dart';

/// Contacts grouped in the hexagons of one grid.
class HexBins {
  const HexBins(this.grid, this.cells, this.maxCount);

  final HexGrid grid;

  /// Point indices per hexagon.
  final Map<HexKey, List<int>> cells;

  /// Contacts in the busiest hexagon (at least 1).
  final int maxCount;
}

/// One species heard at one spot: a map marker.
class ContactSpot {
  const ContactSpot({
    required this.spot,
    required this.scientificName,
    required this.commonName,
    required this.position,
    required this.indices,
    required this.maxConfidence,
    required this.hasClip,
    required this.confirmed,
  });

  /// Spot hexagon (grid of [kMapSpotZoom]).
  final HexKey spot;
  final String scientificName;
  final String commonName;

  /// Mean position of the contacts.
  final LatLng position;
  final List<int> indices;
  final double maxConfidence;
  final bool hasClip;

  /// At least one contact confirmed in review.
  final bool confirmed;

  int get count => indices.length;
}

/// A species' contacts inside an area (hexagon or spot).
class SpeciesInArea {
  const SpeciesInArea({
    required this.scientificName,
    required this.commonName,
    required this.contacts,
    required this.bestClip,
  });

  final String scientificName;
  final String commonName;
  final int contacts;

  /// Best-scored contact that has a clip, if any.
  final IndexedDetection? bestClip;
}

/// Opacity of a hexagon holding [count] contacts, on a log scale so that
/// a garden with 400 contacts does not wash out a wood with 6, in
/// [kMapHexOpacitySteps] levels.
double hexOpacity(int count, int maxCount) {
  if (maxCount <= 1) return kMapHexMaxOpacity;
  final t =
      (math.log(1 + count) / math.log(1 + maxCount) * kMapHexOpacitySteps)
          .round() /
      kMapHexOpacitySteps;
  return kMapHexMinOpacity + (kMapHexMaxOpacity - kMapHexMinOpacity) * t;
}

/// Positioned contacts, with their bins computed lazily and cached.
class ContactMapData {
  ContactMapData(List<IndexedDetection> detections)
    : points = [
        for (final d in detections)
          if (d.latitude != null && d.longitude != null) d,
      ] {
    _mx = Float64List(points.length);
    _my = Float64List(points.length);
    for (var i = 0; i < points.length; i++) {
      final m = toMercator(points[i].latitude!, points[i].longitude!);
      _mx[i] = m.x;
      _my[i] = m.y;
    }
  }

  final List<IndexedDetection> points;
  late final Float64List _mx;
  late final Float64List _my;
  final Map<int, HexBins> _bins = {};

  bool get isEmpty => points.isEmpty;

  /// Positions of every contact, for fitting the camera.
  List<LatLng> get positions => [
    for (final p in points) LatLng(p.latitude!, p.longitude!),
  ];

  /// Hexagon bins for the map at [zoom] (binned at its integer part).
  HexBins hexBins(int zoom) =>
      _bins[zoom] ??= _bin(HexGrid(zoom: zoom, radiusPx: kMapHexRadiusPx));

  HexBins _bin(HexGrid grid) {
    final cells = <HexKey, List<int>>{};
    var maxCount = 1;
    for (var i = 0; i < points.length; i++) {
      final list = cells.putIfAbsent(
        grid.keyOfMercator(_mx[i], _my[i]),
        () => <int>[],
      );
      list.add(i);
      if (list.length > maxCount) maxCount = list.length;
    }
    return HexBins(grid, cells, maxCount);
  }

  /// The spot grid shared by markers and marker taps.
  final HexGrid spotGrid = HexGrid(
    zoom: kMapSpotZoom,
    radiusPx: kMapSpotRadiusPx,
  );

  /// One marker per species per spot, busiest first.
  late final List<ContactSpot> spots = _buildSpots();

  List<ContactSpot> _buildSpots() {
    final groups = <(HexKey, String), List<int>>{};
    for (var i = 0; i < points.length; i++) {
      final spot = spotGrid.keyOfMercator(_mx[i], _my[i]);
      groups
          .putIfAbsent((spot, points[i].scientificName), () => <int>[])
          .add(i);
    }
    final result = <ContactSpot>[];
    for (final entry in groups.entries) {
      final indices = entry.value;
      var x = 0.0;
      var y = 0.0;
      var maxConfidence = 0.0;
      var hasClip = false;
      var confirmed = false;
      for (final i in indices) {
        x += _mx[i];
        y += _my[i];
        final p = points[i];
        maxConfidence = math.max(maxConfidence, p.confidence);
        hasClip = hasClip || p.clipPath != null;
        confirmed = confirmed || p.reviewStatus == ReviewStatus.confirmed;
      }
      result.add(
        ContactSpot(
          spot: entry.key.$1,
          scientificName: entry.key.$2,
          commonName: points[indices.first].commonName,
          position: fromMercator(x / indices.length, y / indices.length),
          indices: indices,
          maxConfidence: maxConfidence,
          hasClip: hasClip,
          confirmed: confirmed,
        ),
      );
    }
    result.sort((a, b) => b.count.compareTo(a.count));
    return result;
  }

  /// Point indices of every species at [spot].
  List<int> indicesAtSpot(HexKey spot) => [
    for (final s in spots)
      if (s.spot == spot) ...s.indices,
  ];

  /// Species among the contacts [indices], most contacts first.
  List<SpeciesInArea> speciesIn(Iterable<int> indices) {
    final byName = <String, List<IndexedDetection>>{};
    for (final i in indices) {
      byName.putIfAbsent(points[i].scientificName, () => []).add(points[i]);
    }
    final result = [
      for (final entry in byName.entries)
        SpeciesInArea(
          scientificName: entry.key,
          commonName: entry.value.first.commonName,
          contacts: entry.value.length,
          bestClip: _bestClip(entry.value),
        ),
    ];
    result.sort((a, b) {
      final byCount = b.contacts.compareTo(a.contacts);
      return byCount != 0 ? byCount : a.commonName.compareTo(b.commonName);
    });
    return result;
  }

  static IndexedDetection? _bestClip(List<IndexedDetection> contacts) {
    IndexedDetection? best;
    for (final c in contacts) {
      if (c.clipPath == null) continue;
      if (best == null || c.confidence > best.confidence) best = c;
    }
    return best;
  }
}
