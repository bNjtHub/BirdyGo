import 'package:birdnet_live/fork/map/hex_grid.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  test('Mercator projection round-trips', () {
    for (final p in [
      const LatLng(47.2101, -1.5502),
      const LatLng(-33.9, 151.2),
      const LatLng(0, 0),
    ]) {
      final m = toMercator(p.latitude, p.longitude);
      final back = fromMercator(m.x, m.y);
      expect(back.latitude, closeTo(p.latitude, 1e-9));
      expect(back.longitude, closeTo(p.longitude, 1e-9));
    }
  });

  test('a hexagon center falls in its own hexagon, corners around it', () {
    final grid = HexGrid(zoom: 10, radiusPx: 26);
    final key = grid.keyOf(const LatLng(47.2101, -1.5502));
    final center = grid.center(key);
    expect(grid.keyOf(center), key);
    final corners = grid.corners(key);
    expect(corners, hasLength(6));
    // Points slightly inside each corner stay in the hexagon.
    for (final c in corners) {
      final inside = LatLng(
        center.latitude + (c.latitude - center.latitude) * 0.9,
        center.longitude + (c.longitude - center.longitude) * 0.9,
      );
      expect(grid.keyOf(inside), key);
    }
  });

  test('close points share a hexagon, distant ones do not', () {
    final grid = HexGrid(zoom: 17, radiusPx: 22);
    final center = grid.center(grid.keyOf(const LatLng(47.2101, -1.5502)));
    final a = grid.keyOf(center);
    // ~3 m and ~1 km from the center.
    final b = grid.keyOf(LatLng(center.latitude + 3e-5, center.longitude));
    final c = grid.keyOf(LatLng(center.latitude + 0.01, center.longitude));
    expect(a, b);
    expect(a, isNot(c));
  });

  test('hexagons at a lower zoom are larger', () {
    final far = HexGrid(zoom: 8, radiusPx: 26);
    final near = HexGrid(zoom: 14, radiusPx: 26);
    final p = far.center(far.keyOf(const LatLng(47.2101, -1.5502)));
    // ~5 km away: same 10 km hexagon at zoom 8, not at zoom 14.
    final q = LatLng(p.latitude + 0.045, p.longitude);
    expect(far.keyOf(p), far.keyOf(q));
    expect(near.keyOf(p), isNot(near.keyOf(q)));
  });
}
