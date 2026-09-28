/// Words and icons of the game (J6e).
library;

import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:flutter/widgets.dart';

import '../../shared/utils/app_icons.dart';
import 'game_config.dart';

String statusName(AppLocalizations l10n, StatusDef status) => switch (status
    .rank) {
  1 => l10n.forkStatus1,
  2 => l10n.forkStatus2,
  3 => l10n.forkStatus3,
  4 => l10n.forkStatus4,
  5 => l10n.forkStatus5,
  6 => l10n.forkStatus6,
  7 => l10n.forkStatus7,
  _ => l10n.forkStatus8,
};

/// The line shown when [status] is reached (informational, never a
/// command); [status] null: before the first species.
String statusLine(AppLocalizations l10n, StatusDef? status) => switch (status
    ?.rank) {
  null => l10n.forkStatusLine0,
  1 => l10n.forkStatusLine1,
  2 => l10n.forkStatusLine2,
  3 => l10n.forkStatusLine3,
  4 => l10n.forkStatusLine4,
  5 => l10n.forkStatusLine5,
  6 => l10n.forkStatusLine6,
  7 => l10n.forkStatusLine7,
  _ => l10n.forkStatusLine8,
};

String badgeName(AppLocalizations l10n, BadgeKind kind) => switch (kind) {
  BadgeKind.dawnChorus => l10n.forkBadgeDawnChorus,
  BadgeKind.earlyBird => l10n.forkBadgeEarlyBird,
  BadgeKind.nightOwl => l10n.forkBadgeNightOwl,
  BadgeKind.reviewer => l10n.forkBadgeReviewer,
  BadgeKind.migrant => l10n.forkBadgeMigrant,
  BadgeKind.streak => l10n.forkBadgeStreak,
  BadgeKind.tits => l10n.forkBadgeTits,
  BadgeKind.fineEar => l10n.forkBadgeFineEar,
};

String badgeRule(AppLocalizations l10n, BadgeKind kind) => switch (kind) {
  BadgeKind.dawnChorus => l10n.forkBadgeDawnChorusRule,
  BadgeKind.earlyBird => l10n.forkBadgeEarlyBirdRule,
  BadgeKind.nightOwl => l10n.forkBadgeNightOwlRule,
  BadgeKind.reviewer => l10n.forkBadgeReviewerRule,
  BadgeKind.migrant => l10n.forkBadgeMigrantRule,
  BadgeKind.streak => l10n.forkBadgeStreakRule,
  BadgeKind.tits => l10n.forkBadgeTitsRule,
  BadgeKind.fineEar => l10n.forkBadgeFineEarRule,
};

/// UI icon of a badge; null when it uses a glyph ([badgeGlyph]).
IconData? badgeIcon(BadgeKind kind) => switch (kind) {
  BadgeKind.dawnChorus => AppIcons.wbTwilightRounded,
  BadgeKind.earlyBird => AppIcons.schedule,
  BadgeKind.nightOwl => AppIcons.darkMode,
  BadgeKind.reviewer => AppIcons.check,
  BadgeKind.migrant => null,
  BadgeKind.streak => AppIcons.calendarToday,
  // Until the species icons of J6d.
  BadgeKind.tits => AppIcons.bird,
  BadgeKind.fineEar => AppIcons.headphones,
};

Glyph? badgeGlyph(BadgeKind kind) =>
    kind == BadgeKind.migrant ? GameConfig.migrantGlyph : null;
