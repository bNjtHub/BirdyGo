/// Pills and badges of BirdyGo (J6a, SPEC.md 5.2 and 5.3): a generic pill,
/// the reliability glyph (three rising bars, like the logo's wing) and the
/// novelty and rarity pills.
library;

import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

import '../../../shared/utils/app_icons.dart';
import '../../reliability/reliability_config.dart';
import '../birdy_tokens.dart';
import '../birdy_typography.dart';
import 'dashed_border.dart';

/// Pill with an optional leading icon. Grows with the text scale.
class BirdyPill extends StatelessWidget {
  const BirdyPill({
    super.key,
    required this.label,
    required this.foreground,
    this.background,
    this.leading,
    this.outlined = false,
    this.dashed = false,
  });

  final String label;
  final Color foreground;
  final Color? background;
  final Widget? leading;

  /// 1.5 px solid outline in [foreground].
  final bool outlined;

  /// 1.5 px dashed outline in [foreground] (« À vérifier » only).
  final bool dashed;

  @override
  Widget build(BuildContext context) {
    // Loose Flexible in a min-size Row: wraps in narrow rows, and stays
    // legal in unbounded ones (live row trailing).
    final content = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: BirdySizes.pill),
      child: Padding(
        padding: EdgeInsetsDirectional.fromSTEB(
          leading == null ? 10 : 7,
          4,
          10,
          4,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (leading != null) ...[leading!, const SizedBox(width: 5)],
            Flexible(
              child: Text(
                label,
                style: BirdyText.badge.copyWith(color: foreground),
              ),
            ),
          ],
        ),
      ),
    );
    final shape = StadiumBorder(
      side:
          outlined && !dashed
              ? BorderSide(color: foreground, width: 1.5)
              : BorderSide.none,
    );
    final pill = DecoratedBox(
      decoration: ShapeDecoration(color: background, shape: shape),
      child: content,
    );
    if (!dashed) return pill;
    return CustomPaint(
      foregroundPainter: DashedBorderPainter(
        color: foreground,
        radius: BirdyRadii.pill,
      ),
      child: pill,
    );
  }
}

/// Three rising bars: 3 filled = Sûr, 2 = Probable, 1 = À vérifier.
class ReliabilityGlyph extends StatelessWidget {
  const ReliabilityGlyph({
    super.key,
    required this.level,
    required this.color,
    this.size = 12,
  });

  final ReliabilityLevel level;
  final Color color;
  final double size;

  int get filled => switch (level) {
    ReliabilityLevel.sure => 3,
    ReliabilityLevel.probable => 2,
    ReliabilityLevel.toCheck => 1,
  };

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size.square(size),
    painter: _BarsPainter(filled: filled, color: color),
  );
}

class _BarsPainter extends CustomPainter {
  const _BarsPainter({required this.filled, required this.color});

  final int filled;
  final Color color;

  // Geometry of the spec's 12 × 12 glyph: x, top, height of each bar.
  static const _bars = [(1.0, 6.5, 4.5), (4.8, 4.0, 7.0), (8.6, 1.0, 10.0)];

  @override
  void paint(Canvas canvas, Size size) {
    final unit = size.width / 12;
    for (var i = 0; i < _bars.length; i++) {
      final (x, top, height) = _bars[i];
      final paint =
          Paint()..color = i < filled ? color : color.withValues(alpha: 0.3);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x * unit, top * unit, 2.4 * unit, height * unit),
          Radius.circular(1.2 * unit),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_BarsPainter old) =>
      old.filled != filled || old.color != color;
}

/// Novelty and rarity pills.
enum NoveltyKind {
  /// First verified contact ever (Loriot fill).
  firstTime,

  /// First contact of the calendar year (Loriot outline).
  newThisYear,

  /// The geomodel says Rare or Exceptionnel here this week.
  unexpectedHere,

  /// Collection card not opened yet (Loriot fill).
  isNew,
}

class NoveltyPill extends StatelessWidget {
  const NoveltyPill({super.key, required this.kind});

  final NoveltyKind kind;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
    Widget icon(IconData data, Color color) =>
        Icon(data, size: 14, color: color, fill: 1);
    return switch (kind) {
      NoveltyKind.firstTime => BirdyPill(
        label: l10n.forkFirstTime,
        foreground: c.onOriole,
        background: c.oriole,
        leading: icon(AppIcons.sparkle, c.onOriole),
      ),
      NoveltyKind.isNew => BirdyPill(
        label: l10n.forkNew,
        foreground: c.onOriole,
        background: c.oriole,
        leading: icon(AppIcons.sparkle, c.onOriole),
      ),
      NoveltyKind.newThisYear => BirdyPill(
        label: l10n.forkNewThisYear,
        foreground: c.orioleText,
        outlined: true,
        leading: icon(AppIcons.sparkle, c.orioleText),
      ),
      NoveltyKind.unexpectedHere => BirdyPill(
        label: l10n.forkUnexpectedHere,
        foreground: c.orioleText,
        background: c.orioleContainer,
        leading: icon(AppIcons.diamond, c.orioleText),
      ),
    };
  }
}
