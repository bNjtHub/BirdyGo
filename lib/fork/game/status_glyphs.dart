/// The eight status drawings and the migrant one (J6k), on a 24 grid, from
/// the « Mélange 2 » sheet: solid shapes with a Loriot detail, a few lines.
library;

import 'package:flutter/painting.dart';

import 'glyph.dart';

const _m = GlyphTone.main;
const _a = GlyphTone.accent;
const _d = GlyphTone.deep;

// A bird of the migrant V, on its own origin (placed with dx, dy and scale).
const _vBird =
    'M-3.4-.9c1.3-.3 2.6.4 3.4 1.7.8-1.3 2.1-2 3.4-1.7-1.4.7-2.6 2-3.4 3.4-.8-1.4-2-2.7-3.4-3.4z';

// A four-point sparkle of radius 1, on its own origin.
const _spark =
    'M0-1c.13.66.34.87 1 1-.66.13-.87.34-1 1-.13-.66-.34-.87-1-1 .66-.13.87-.34 1-1z';

abstract final class StatusGlyphs {
  /// 1 Oisillon: a chick hatching, Loriot head between the shell halves.
  static const Glyph chick = Glyph([
    GlyphLayer.fill('M8 14.4c-2-.1-3.6-1.3-4.1-3.1 1.8-.4 3.7.3 4.9 1.8z', _a),
    GlyphLayer.dot(12, 12, 5, _a),
    GlyphLayer.dot(13.7, 11, 1.05, _d),
    GlyphLayer.dot(14.05, 10.65, .35, _m),
    GlyphLayer.fill(
      'M16.7 11.8l2.6.9-2.6 1z',
      _d,
      real: Color(0xFFF28C28),
      outline: 1,
    ),
    GlyphLayer.fill(
      'M4.6 14c0 4.8 3.3 8 7.4 8s7.4-3.2 7.4-8l-2.5 1.6-2.5-1.9-2.4 1.9-2.4-1.9-2.5 1.9z',
      _m,
    ),
    GlyphLayer.fill(
      'M7.4 7.6c.4-3 2.3-5 4.6-5s4.2 2 4.6 5l-1.8-1-1.4 1-1.4-1-1.4 1-1.4-1z',
      _m,
      rotate: -8,
    ),
  ]);

  /// 2 Jeune plume: a soft feather, a notch cut in the vane, down at the base.
  static const Glyph youngFeather = Glyph([
    GlyphLayer.fill(
      'M20 3C11.6 3.2 6.6 8.2 6.8 15.8l1.6 1.6c7.6.2 12.6-4.8 11.6-14.4z',
      _m,
      cut: 'M16.9 16.3L18.9 14.3 15.4 13.6z',
    ),
    GlyphLayer.line('M4.2 19.8L14.6 9.4', 2.1, _d),
    GlyphLayer.line('M4.2 19.8l1.4-1.4', 2.6, _a),
  ]);

  /// 3 Premier envol: a young bird taking off, wings up.
  static const Glyph firstFlight = Glyph([
    GlyphLayer.fill(
      'M11.2 12.6C13 9 15.8 6.4 20.4 5.4c-.2 3.4-2.2 6.2-5.6 7.8z',
      _m,
      opacity: .55,
    ),
    GlyphLayer.fill('M16.6 14.4l4.6-1.6c.7-.2 1.1.7.5 1.1l-4 2.8z', _m),
    GlyphLayer.fill('M4.8 15.4a6.6 4.6 0 1 0 13.2 0a6.6 4.6 0 1 0-13.2 0z', _m),
    GlyphLayer.dot(6.6, 12.8, 3.6, _m),
    GlyphLayer.fill('M3.4 12L.8 13.1l2.6.9z', _d),
    GlyphLayer.dot(5.8, 12.2, 1, _d),
    GlyphLayer.fill(
      'M7.8 13.6C8.6 8.8 11.2 5 15.6 2.8c1 3.8-.4 7.8-3.6 10.8z',
      _a,
    ),
    GlyphLayer.line('M4.6 21.8h3.2M10.2 21.8h2', 1.6, _m, opacity: .6),
  ]);

  /// 4 Sentinelle des haies: the watching eye above a hedge line.
  static const Glyph sentinel = Glyph([
    GlyphLayer.fill(
      'M2.4 13.4S6.3 7.6 12 7.6s9.6 5.8 9.6 5.8-3.9 5.8-9.6 5.8-9.6-5.8-9.6-5.8z',
      _m,
    ),
    GlyphLayer.dot(12, 13.4, 3.7, _d),
    GlyphLayer.dot(13.3, 12.1, 1.1, _m),
    GlyphLayer.line('M12 2.4v2.4M6.2 4.2l1.3 2.1M17.8 4.2l-1.3 2.1', 2.2, _a),
  ]);

  /// 5 Oreille de chouette: owl face with tufts, big eyes, Loriot beak and
  /// a wave at each ear.
  static const Glyph owl = Glyph([
    GlyphLayer.fill(
      'M4.2 2.8l4.2 3.6h7.2l4.2-3.6c1 2.6 1.5 5.4 1.5 8.1a9.3 9.3 0 0 1-18.6 0c0-2.7.5-5.5 1.5-8.1z',
      _m,
    ),
    GlyphLayer.dot(8.7, 11.4, 3.1, _d),
    GlyphLayer.dot(15.3, 11.4, 3.1, _d),
    GlyphLayer.dot(9.7, 10.4, 1, _m),
    GlyphLayer.dot(16.3, 10.4, 1, _m),
    GlyphLayer.line(
      'M6 7.4c1.6-.9 3.6-.9 5 .4M18 7.4c-1.6-.9-3.6-.9-5 .4',
      1.2,
      _d,
      opacity: .7,
    ),
    GlyphLayer.fill('M10.7 15.2h2.6L12 17.5z', _a, outline: 1.2),
    GlyphLayer.line(
      'M21.8 3.4c.8.9.8 2.3 0 3.2M23.4 2.2c1.4 1.6 1.4 4 0 5.6M2.2 3.4c-.8.9-.8 2.3 0 3.2M.6 2.2c-1.4 1.6-1.4 4 0 5.6',
      1.2,
      _a,
    ),
  ]);

  /// 6 Grand migrateur (and the Migrateur badge): a V of birds, the lead one
  /// in Loriot.
  static const Glyph migrant = Glyph([
    GlyphLayer.fill(_vBird, _a, dx: 12, dy: 6, scale: 1.25),
    GlyphLayer.fill(_vBird, _m, dx: 7.6, dy: 10.4, scale: 1.05),
    GlyphLayer.fill(_vBird, _m, dx: 16.4, dy: 10.4, scale: 1.05),
    GlyphLayer.fill(_vBird, _m, dx: 3.6, dy: 14.8, scale: .9),
    GlyphLayer.fill(_vBird, _m, dx: 20.4, dy: 14.8, scale: .9),
  ]);

  /// 7 Plume d'or: the feather, golden, with two sparkles.
  static const Glyph goldFeather = Glyph([
    GlyphLayer.fill(
      'M18.6 5.4C11 5.6 6.8 10 7 16.8l1.6 1.6c6.8.2 11-4 10-13z',
      _m,
    ),
    GlyphLayer.line('M13.2 14l3-.1', 1.4, _d),
    GlyphLayer.line('M4.4 21.2L13.8 11.8', 2.1, _d),
    GlyphLayer.fill(_spark, _a, dx: 20, dy: 3.6, scale: 2.6),
    GlyphLayer.fill(_spark, _a, dx: 21.4, dy: 11.2, scale: 1.5),
  ]);

  /// 8 Martin-pêcheur: a kingfisher on its perch, dagger bill, Loriot
  /// breast; true colours once reached.
  static const Glyph kingfisher = Glyph([
    GlyphLayer.line(
      'M2 21.2Q12 19.6 22 20.6',
      1.9,
      _m,
      real: Color(0xFF8B5E3C),
      opacity: .7,
      realOpacity: 1,
    ),
    GlyphLayer.fill(
      'M6.6 6.2C7.6 3.8 10 2.8 12.4 3.2c2.8.5 4 2.8 3.8 5.4 1.6 2.4 2.8 5 3.2 7l2 4-2 .6-2.2-2.4c-1.6 1-3.8 1.2-5.6.4-2.6-1.2-3.8-3.8-3.6-6.4-1-1.4-1.6-3.4-1.4-5.6z',
      _m,
      real: Color(0xFF7FDBFF),
    ),
    GlyphLayer.fill(
      'M16.2 8.6c1.6 2.4 2.8 5 3.2 7l2 4-2 .6-2.2-2.4c-1.2-3.4-2.2-6.4-1-9.2z',
      _m,
      real: Color(0xFF2FA8E8),
      realOnly: true,
    ),
    GlyphLayer.fill(
      'M7.2 4.8C8.6 3.4 10.6 2.9 12.4 3.2c2 .3 3.2 1.5 3.6 3-2.8-1.2-5.8-1.6-8.8-1.4z',
      _m,
      real: Color(0xFF2FA8E8),
      realOnly: true,
    ),
    GlyphLayer.fill(
      'M8.2 11.6c-.2 2.8 1.2 5.2 3.6 6.3 1.8.8 3.8.5 5.2-.3-1.4-3-4.6-5.2-8.8-6z',
      _a,
      real: Color(0xFFF28C38),
    ),
    GlyphLayer.fill(
      'M11.6 8c1-.6 2.5-.6 3.5.2-.8 1-2.5 1.1-3.5-.2z',
      _a,
      real: Color(0xFFF28C38),
    ),
    GlyphLayer.fill(
      'M7.4 10.2c.9.9 2.1 1.3 3.2 1.1-.6.9-1.9 1.3-3 .7z',
      _m,
      real: Color(0xFFFFFFFF),
      realOnly: true,
    ),
    GlyphLayer.dot(15.6, 8.4, .9, _m, real: Color(0xFFFFFFFF), realOnly: true),
    GlyphLayer.fill('M7 6.6L.6 9.3 7.2 9.8z', _d, real: Color(0xFF1B1B26)),
    GlyphLayer.dot(10.4, 7, 1.1, _d, real: Color(0xFF1B1B26)),
    GlyphLayer.dot(10.8, 6.6, .38, _m, real: Color(0xFFFFFFFF)),
    GlyphLayer.line(
      'M12.6 18.8v1.6M15 18.4v1.8',
      1.2,
      _d,
      real: Color(0xFFE8553A),
    ),
  ]);
}
