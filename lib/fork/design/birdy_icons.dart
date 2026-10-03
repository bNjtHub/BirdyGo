/// Icon roles of BirdyGo: one meaning, one glyph, everywhere.
///
/// [AppIcons] stays the source of the glyphs (Material Symbols Rounded, weight
/// 400); [BirdyIcons] is the source of the meaning. Fork code asks for a
/// role, never for a glyph. Fill rule (fork/DESIGN.md): outline at rest, filled
/// when active / selected / in progress / confirmed; play, pause and stop are
/// always filled; the favorite star is filled only for a favorite.
library;

import 'package:flutter/widgets.dart';

import '../../shared/utils/app_icons.dart';

/// Role dictionary. Two roles are not [IconData] and keep their widget:
/// "listen" is [BirdyWingIcon] (the logo's wing) and "species" is
/// [BirdyGoSilhouetteIcon].
abstract final class BirdyIcons {
  /// "Heard": a species or sound that was heard.
  static const IconData heard = AppIcons.hearing;

  /// A song, a clip, a sound.
  static const IconData song = AppIcons.graphicEq;

  /// Recording one's own voice (voice memo): still a microphone.
  static const IconData voiceMemo = AppIcons.mic;

  /// A reference document (licenses, fonts, citations): not the notebook.
  static const IconData document = AppIcons.menuBook;

  /// The "Oreille fine" (fine ear) game and badge.
  static const IconData fineEar = AppIcons.headphones;

  /// A real map.
  static const IconData map = AppIcons.mapSheet;

  /// A place, a pin.
  static const IconData place = AppIcons.locationOn;

  /// The user's current position.
  static const IconData myPosition = AppIcons.myLocation;

  /// The world, worldwide scope.
  static const IconData world = AppIcons.public;

  /// The notebook (Carnet).
  static const IconData notebook = AppIcons.menuBook;

  /// A list of detections.
  static const IconData detections = AppIcons.detections;

  /// A note the user writes.
  static const IconData note = AppIcons.editNote;

  /// "How does it work": help.
  static const IconData help = AppIcons.helpOutline;

  /// A piece of information.
  static const IconData info = AppIcons.infoOutline;

  /// A tip ("Le saviez-vous ?").
  static const IconData tip = AppIcons.lightbulbOutline;

  /// Settings and listening options.
  static const IconData settings = AppIcons.tune;

  /// "More" (three dots), also the "Plus" sheet.
  static const IconData more = AppIcons.moreHoriz;

  /// A menu.
  static const IconData menu = AppIcons.menu;

  /// Confirmed: filled only when the thing is confirmed (`active`).
  static const IconData confirmed = AppIcons.checkCircle;

  /// A check mark in a list or a choice.
  static const IconData tick = AppIcons.check;

  /// Close, leave a flow.
  static const IconData close = AppIcons.close;

  /// Back, without losing anything.
  static const IconData back = AppIcons.arrowBackRounded;

  /// Play (always filled).
  static const IconData play = AppIcons.playArrow;

  /// Pause (always filled).
  static const IconData pause = AppIcons.pause;

  /// Stop (always filled).
  static const IconData stop = AppIcons.stop;

  /// Favorite star (filled only when it is a favorite).
  static const IconData favorite = AppIcons.star;

  /// Roles that are filled whatever the state.
  static final Set<IconData> alwaysFilled = {

    play,
    pause,
    stop,
  };

  /// Fill axis (0 or 1) of [icon]: 1 when it is an always-filled role or
  /// [active] is true. The single place that applies the fill rule.
  static double fillOf(IconData icon, {bool active = false}) =>
      (active || alwaysFilled.contains(icon)) ? 1 : 0;
}

/// An [Icon] that applies the fill rule of [BirdyIcons] (and weight 400).
/// Pass [active] for selected / in progress / favorite states.
class BirdyIcon extends StatelessWidget {
  const BirdyIcon(
    this.icon, {
    super.key,
    this.size,
    this.color,
    this.active = false,
    this.semanticLabel,
  });

  final IconData icon;
  final double? size;
  final Color? color;

  /// Selected / in progress / favorite: draws the glyph filled.
  final bool active;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) => Icon(
    icon,
    size: size,
    color: color,
    fill: BirdyIcons.fillOf(icon, active: active),
    weight: 400,
    semanticLabel: semanticLabel,
  );
}
