/// Rules and numbers of the game (J6e, SPEC.md 7): statuses, badges and the
/// forgiving streak. Every threshold of the game lives here.
library;

import 'package:flutter/painting.dart';

/// One of the 8 statuses, reached with [from] verified species.
class StatusDef {
  const StatusDef({
    required this.rank,
    required this.from,
    required this.color,
    required this.glyph,
  });

  /// 1 to 8.
  final int rank;
  final int from;
  final Color color;

  /// Line drawing on a 24 grid (SPEC.md 4.3), in ink on [color].
  final Glyph glyph;
}

/// Stroked paths and circles of a 24 × 24 line glyph; [filled] paths are
/// painted solid.
class Glyph {
  const Glyph({
    this.paths = const [],
    this.circles = const [],
    this.filled = const [],
  });

  final List<String> paths;

  /// (cx, cy, r).
  final List<(double, double, double)> circles;
  final List<String> filled;
}

enum BadgeKind {
  /// 10 verified species in one listening started before 8 h.
  dawnChorus,

  /// A listening started before sunrise.
  earlyBird,

  /// Verified night species (owls, nightjar).
  nightOwl,

  /// Detections sorted in the quick review (every answer counts).
  reviewer,

  /// Verified migratory species.
  migrant,

  /// Best série, in days.
  streak,

  /// Verified tit species.
  tits,
}

abstract final class GameConfig {
  /// SPEC.md 7.2 and 2.6.
  static const List<StatusDef> statuses = [
    StatusDef(
      rank: 1,
      from: 1,
      color: Color(0xFFF2B98B),
      glyph: Glyph(
        paths: [
          'M12 3.5c3.3 0 6 4.9 6 9.3a6 6 0 0 1-12 0c0-4.4 2.7-9.3 6-9.3z',
          'M7 12.6l2.4 1.5 2.6-2.1 2.6 2.1 2.4-1.5',
        ],
      ),
    ),
    StatusDef(
      rank: 2,
      from: 5,
      color: Color(0xFFE9836B),
      glyph: Glyph(
        paths: [
          'M5.5 20.5 16 10',
          'M19.5 3.5C12 3.5 7 7.5 7 15l2 2c7.5 0 11.5-5.5 10.5-13.5z',
        ],
      ),
    ),
    StatusDef(
      rank: 3,
      from: 10,
      color: Color(0xFF9DB46A),
      glyph: Glyph(
        paths: [
          'M2.5 9.5c2.8-2.3 6-2.3 9.5 1.2 3.5-3.5 6.7-3.5 9.5-1.2',
          'M7.5 15.5c1.5-1.1 3-1.1 4.5.5 1.5-1.6 3-1.6 4.5-.5',
        ],
      ),
    ),
    StatusDef(
      rank: 4,
      from: 20,
      color: Color(0xFF5DA46A),
      glyph: Glyph(
        paths: [
          'M3 13.5S6.5 8 12 8s9 5.5 9 5.5-3.5 5.5-9 5.5-9-5.5-9-5.5z',
          'M12 2.5v2.5M6.5 4.5l1.3 2M17.5 4.5l-1.3 2',
        ],
        circles: [(12, 13.5, 2.5)],
      ),
    ),
    StatusDef(
      rank: 5,
      from: 35,
      color: Color(0xFFC28A55),
      glyph: Glyph(
        paths: [
          'M5 4l3.2 3.4M19 4l-3.2 3.4',
          'M5 4c-.7 2.2-1 4.6-1 7a8 8 0 0 0 16 0c0-2.4-.3-4.8-1-7',
          'M11 15.8l1 1.4 1-1.4',
        ],
        circles: [(9, 11.5, 2.4), (15, 11.5, 2.4)],
      ),
    ),
    StatusDef(rank: 6, from: 50, color: Color(0xFF5A9BE0), glyph: migrantGlyph),
    StatusDef(
      rank: 7,
      from: 75,
      color: Color(0xFFF4C542),
      glyph: Glyph(
        paths: [
          'M4.5 21 14 11.5',
          'M17.5 5.5C11 5.5 7 9 7 15.5l1.8 1.8c6.5 0 10-4.3 8.7-11.8z',
        ],
        filled: [
          'M19.5 1.8c.3 1.6.9 2.2 2.5 2.5-1.6.3-2.2.9-2.5 2.5-.3-1.6-.9-2.2-2.5-2.5 1.6-.3 2.2-.9 2.5-2.5z',
        ],
      ),
    ),
    StatusDef(
      rank: 8,
      from: 100,
      color: Color(0xFF19A7B3),
      glyph: Glyph(paths: ['M5 10v4M8.5 7v10M12 4.5v15M15.5 8v8M19 10.5v3']),
    ),
  ];

  /// Glyph `migrateur` (status 6, Migrateur badge).
  static const Glyph migrantGlyph = Glyph(
    paths: [
      'M2.5 6.5 4.3 8l1.8-1.5M6.8 10.5l1.8 1.5 1.8-1.5M11.1 14.5l1.8 1.5 1.8-1.5M13.6 10.5l1.8 1.5 1.8-1.5M17.9 6.5 19.7 8l1.8-1.5',
    ],
  );

  /// Badge tiers (1, 2, 3 plumes), SPEC.md 7.3.
  static const Map<BadgeKind, List<int>> badgeTiers = {
    BadgeKind.dawnChorus: [1, 5, 20],
    BadgeKind.earlyBird: [1, 5, 20],
    BadgeKind.nightOwl: [1, 3, 6],
    BadgeKind.reviewer: [10, 50, 200],
    BadgeKind.migrant: [3, 6, 12],
    BadgeKind.streak: [7, 30, 100],
    BadgeKind.tits: [2, 4, 6],
  };

  /// Badge circle fill and glyph color: locked, then 1, 2, 3 plumes
  /// (SPEC.md 2.7).
  static const List<(Color, Color)> badgeTierColors = [
    (Color(0xFFE6E9E4), Color(0xFF9AA39A)),
    (Color(0xFFEADFD1), Color(0xFF6B5847)),
    (Color(0xFFE3EBD2), Color(0xFF4B6023)),
    (Color(0xFFFBEFC8), Color(0xFF7A5A00)),
  ];

  /// « Chœur de l'aube »: verified species in one listening…
  static const int dawnChorusSpecies = 10;

  /// …started before this local hour.
  static const int dawnChorusBeforeHour = 8;

  /// A day counts in the série with this much listening.
  static const Duration streakMinListening = Duration(minutes: 5);

  /// One rest day allowed per this many days (SPEC.md 7.4).
  static const int streakRestEvery = 7;

  /// Night birds (Noctambule): owls and nightjars, by genus.
  static const Set<String> nightGenera = {
    'Aegolius',
    'Asio',
    'Athene',
    'Bubo',
    'Caprimulgus',
    'Glaucidium',
    'Otus',
    'Strix',
    'Surnia',
    'Tyto',
  };

  /// Tits (Les mésanges), by genus.
  static const Set<String> titGenera = {
    'Aegithalos',
    'Cyanistes',
    'Lophophanes',
    'Parus',
    'Periparus',
    'Poecile',
  };

  /// Migrant (Migrateur): at the user's place, the geo-model's weekly
  /// score reaches [migrantPresentScore] in some weeks and stays under
  /// [migrantAbsentScore] in others.
  static const double migrantPresentScore = 0.05;
  static const double migrantAbsentScore = 0.01;
}

/// Genus of a scientific name.
String genusOf(String scientificName) => scientificName.split(' ').first;
