/// Compact badges for reliability levels and "Inattendu ici" (J3).
///
/// Levels differ by icon shape and by lightness, not by hue alone.
library;

import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

import '../../shared/utils/app_icons.dart';
import 'reliability_config.dart';

/// Localized label of a level.
String reliabilityLabel(AppLocalizations l10n, ReliabilityLevel level) =>
    switch (level) {
      ReliabilityLevel.sure => l10n.forkLevelSure,
      ReliabilityLevel.probable => l10n.forkLevelProbable,
      ReliabilityLevel.toCheck => l10n.forkLevelToCheck,
    };

/// Level badge: icon plus short label.
class ReliabilityBadge extends StatelessWidget {
  const ReliabilityBadge({
    super.key,
    required this.level,
    this.unexpected = false,
    this.compact = false,
  });

  final ReliabilityLevel level;

  /// Adds the "Inattendu ici" mark.
  final bool unexpected;

  /// Icon only (label kept for screen readers and the tooltip).
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final (icon, fill, color) = switch (level) {
      ReliabilityLevel.sure => (AppIcons.checkCircle, 1.0, scheme.primary),
      ReliabilityLevel.probable => (
        AppIcons.checkCircleOutline,
        0.0,
        scheme.onSurfaceVariant,
      ),
      ReliabilityLevel.toCheck => (AppIcons.helpOutline, 0.0, scheme.tertiary),
    };
    final label = reliabilityLabel(l10n, level);
    final semantics = unexpected ? '$label, ${l10n.forkUnexpectedHere}' : label;
    return Tooltip(
      message: semantics,
      child: Semantics(
        label: semantics,
        excludeSemantics: true,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, fill: fill, color: color),
            if (!compact) ...[
              const SizedBox(width: 4),
              Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            if (unexpected) ...[
              const SizedBox(width: 4),
              Icon(
                AppIcons.warningAmberRounded,
                size: 18,
                color: scheme.tertiary,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
