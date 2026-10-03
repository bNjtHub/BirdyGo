/// Rules and numbers of the game (J6e, SPEC.md 7): statuses, badges and the
/// forgiving streak. Every threshold of the game lives here.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import '../design/birdy_tokens.dart';
import 'glyph.dart';
import 'status_glyphs.dart';

export 'glyph.dart';

/// One of the 8 statuses, reached with [from] verified species.
///
/// Colours (DESIGN.md « Jeu »): [color] is the disc, [deep] its rim and the
/// glyph's deep tone. The glyph is white with a Loriot detail ([glyphMain],
/// [glyphAccent]); [glyphInk] and [gauge] default to [deep] and [color].
class StatusDef {
  const StatusDef({
    required this.rank,
    required this.from,
    required this.color,
    required this.deep,
    required this.glyph,
    this.glyphMain = BirdyBrand.white,
    this.glyphAccent = BirdyBrand.oriole,
    Color? glyphInk,
    Color? gauge,
  }) : _glyphInk = glyphInk,
       _gauge = gauge;

  /// 1 to 8.
  final int rank;
  final int from;
  final Color color;
  final Color deep;

  /// Layered drawing on a 24 grid (SPEC.md 4.3).
  final Glyph glyph;
  final Color glyphMain;
  final Color glyphAccent;
  final Color? _glyphInk;
  final Color? _gauge;

  Color get glyphInk => _glyphInk ?? deep;

  /// Colour of the lit gauge segments.
  Color get gauge => _gauge ?? color;
}

/// Medal of an earned badge tier: a flat [base] disc with its [deep] rim,
/// the engraved face in [ink] (DESIGN.md « Jeu »).
@immutable
class MedalMetal {
  const MedalMetal({
    required this.base,
    required this.deep,
    required this.ink,
    required this.tone,
  });

  final Color base;
  final Color deep;
  final Color ink;

  /// Pale tone of the medal metal: background of an earned badge tile
  /// (J6f, Profil « À gagner ») and of the quiz result medal card.
  final Color tone;
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

  /// Right answers in the « Qui chante ? » quiz.
  fineEar,
}

/// Weekly challenges (SPEC.md 7.5), one per week in turn.
enum ChallengeKind {
  /// Mornings with a listening started before [GameConfig.dawnChorusBeforeHour].
  dawnMornings,

  /// Days with at least [GameConfig.streakMinListening] of listening.
  listeningDays,

  /// Distinct species verified (Sûr or confirmed) this week.
  weekSpecies,
}

abstract final class GameConfig {
  /// Challenges in turn, one per week, with their target.
  static const List<(ChallengeKind, int)> weeklyChallenges = [
    (ChallengeKind.dawnMornings, 3),
    (ChallengeKind.listeningDays, 5),
    (ChallengeKind.weekSpecies, 10),
  ];

  /// SPEC.md 7.2 and 2.6. Colours climb from earth to green, sky, indigo and
  /// turquoise; the last rank lights its whole gauge in Loriot.
  static const List<StatusDef> statuses = [
    StatusDef(
      rank: 1,
      from: 1,
      color: Color(0xFFB98E66),
      deep: Color(0xFF7A5638),
      glyph: StatusGlyphs.chick,
    ),
    StatusDef(
      rank: 2,
      from: 5,
      color: Color(0xFFC9694A),
      deep: Color(0xFF86402A),
      glyph: StatusGlyphs.youngFeather,
    ),
    StatusDef(
      rank: 3,
      from: 10,
      color: Color(0xFF7F9A45),
      deep: Color(0xFF4F6527),
      glyph: StatusGlyphs.firstFlight,
    ),
    StatusDef(
      rank: 4,
      from: 20,
      color: Color(0xFF3E8B57),
      deep: Color(0xFF235936),
      glyph: StatusGlyphs.sentinel,
    ),
    StatusDef(
      rank: 5,
      from: 35,
      color: Color(0xFF8E5E33),
      deep: Color(0xFF5A3818),
      glyph: StatusGlyphs.owl,
    ),
    StatusDef(
      rank: 6,
      from: 50,
      color: Color(0xFF2F76BF),
      deep: Color(0xFF1B4C80),
      glyph: migrantGlyph,
    ),
    StatusDef(
      rank: 7,
      from: 75,
      color: Color(0xFF3D3A7A),
      deep: Color(0xFF26234F),
      glyph: StatusGlyphs.goldFeather,
      glyphMain: BirdyBrand.oriole,
      glyphAccent: BirdyBrand.white,
      glyphInk: Color(0xFF1A1840),
    ),
    StatusDef(
      rank: 8,
      from: 100,
      color: Color(0xFF0E8D98),
      deep: Color(0xFF085F67),
      glyph: StatusGlyphs.kingfisher,
      gauge: BirdyBrand.oriole,
    ),
  ];

  /// Glyph `migrateur` (status 6, Migrateur badge): a V of birds.
  static const Glyph migrantGlyph = StatusGlyphs.migrant;

  /// Badge tiers (1, 2, 3 plumes), SPEC.md 7.3.
  static const Map<BadgeKind, List<int>> badgeTiers = {
    BadgeKind.dawnChorus: [1, 5, 20],
    BadgeKind.earlyBird: [1, 5, 20],
    BadgeKind.nightOwl: [1, 3, 6],
    BadgeKind.reviewer: [10, 50, 200],
    BadgeKind.migrant: [3, 6, 12],
    BadgeKind.streak: [7, 30, 100],
    BadgeKind.tits: [2, 4, 6],
    BadgeKind.fineEar: [10, 50, 150],
  };

  /// « Qui chante ? »: questions in one round, answers offered, and the
  /// verified species with a clip needed to play.
  static const int quizQuestions = 10;
  static const int quizChoices = 4;

  /// Stars at the end of a round (Quiz v2): share of right answers needed
  /// for one, two and three stars.
  static const List<double> quizStarShares = [0.4, 0.7, 1];

  /// Share of right answers that ends a round with a rain of confetti and
  /// the fanfare (Quiz v2: 5 out of 10).
  static const double quizPartyShare = 0.5;

  /// Medal of each earned tier: bronze, silver, gold for 1, 2, 3 plumes.
  /// The same in both themes, like real metal; a locked badge takes the
  /// locked disc colors instead (DESIGN.md « Jeu »).
  static const List<MedalMetal> badgeMedals = [
    MedalMetal(
      base: Color(0xFFC27F4A),
      deep: Color(0xFF8C542C),
      ink: Color(0xFF3F220C),
      tone: Color(0xFFF6EBE1),
    ),
    MedalMetal(
      base: Color(0xFFC9D0D7),
      deep: Color(0xFF8F99A4),
      ink: Color(0xFF2F3943),
      tone: Color(0xFFEBEFF3),
    ),
    MedalMetal(
      base: BirdyBrand.oriole,
      deep: Color(0xFFC49224),
      ink: Color(0xFF5A4000),
      tone: Color(0xFFFBEFC8),
    ),
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
