/// Live table (J6c, fork/DESIGN.md « Live »): one row per species of the
/// outing, fed as detections arrive.
///
/// - a new species comes in on top ([BirdyEntrance] from 8 px above, light
///   haptic);
/// - a species heard again goes back to the top in 250 ms ([FlipMove]) and
///   its counter ×N bumps ([AnimatedCount]);
/// - the table never empties while listening.
library;

import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

import '../design/birdy_motion.dart';
import '../design/birdy_tokens.dart';
import '../design/birdy_typography.dart';
import '../design/species_accents.dart';
import '../design/widgets/animated_count.dart';
import '../design/widgets/entrance.dart';
import '../design/widgets/species_avatar.dart';
import '../design/widgets/species_tile.dart';
import 'flip_move.dart';
import 'live_table_model.dart';

class LiveTable extends StatefulWidget {
  const LiveTable({
    super.key,
    required this.entries,
    this.compact = false,
    this.imageFor,
    this.badgeFor,
    this.actionFor,
    this.onOpen,
    this.empty,
    this.padding = const EdgeInsets.fromLTRB(
      BirdySpace.gutterLive,
      BirdySpace.m,
      BirdySpace.gutterLive,
      BirdySpace.m,
    ),
  });

  /// Rows, species heard last first (see [buildLiveTable]).
  final List<LiveTableEntry> entries;

  /// 60 px rows, under the enlarged spectrogram.
  final bool compact;

  /// Photo of a species, when the bundle has one.
  final ImageProvider? Function(String scientificName)? imageFor;

  /// Reliability badge of a row.
  final Widget Function(LiveTableEntry entry, {required bool compact})?
  badgeFor;

  /// Trailing action of a row (replay button).
  final Widget? Function(LiveTableEntry entry)? actionFor;

  /// Opens the species sheet.
  final void Function(LiveTableEntry entry)? onOpen;

  /// Shown while no species has been heard yet.
  final Widget? empty;

  final EdgeInsets padding;

  @override
  State<LiveTable> createState() => _LiveTableState();
}

class _LiveTableState extends State<LiveTable> {
  /// Species already shown: only later ones play the entrance.
  Set<String> _known = const {};

  /// Species that entered during this screen's life.
  final Set<String> _arrived = {};

  @override
  void initState() {
    super.initState();
    _known = {for (final e in widget.entries) e.scientificName};
  }

  @override
  void didUpdateWidget(LiveTable old) {
    super.didUpdateWidget(old);
    final names = {for (final e in widget.entries) e.scientificName};
    final fresh = names.difference(_known);
    if (names.isEmpty) {
      _arrived.clear();
    } else if (fresh.isNotEmpty) {
      _arrived.addAll(fresh);
      BirdyHaptics.light();
    }
    _known = names;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.entries.isEmpty && widget.empty != null) {
      return Padding(padding: widget.padding, child: widget.empty);
    }
    final gap = widget.compact ? 6.0 : BirdySpace.s;
    // Moves repaint the table only, not the header or the spectrogram.
    return RepaintBoundary(
      child: SingleChildScrollView(
        padding: widget.padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final entry in widget.entries)
              FlipMove(
                key: ValueKey(entry.scientificName),
                child: Padding(
                  // Same gap under every row: a moved row keeps its inner layout.
                  padding: EdgeInsets.only(bottom: gap),
                  child: _maybeEnter(
                    entry,
                    RepaintBoundary(
                      child: LiveTableRow(
                        entry: entry,
                        compact: widget.compact,
                        image: widget.imageFor?.call(entry.scientificName),
                        badge: widget.badgeFor?.call(
                          entry,
                          compact: widget.compact,
                        ),
                        action: widget.actionFor?.call(entry),
                        onTap:
                            widget.onOpen == null
                                ? null
                                : () => widget.onOpen!(entry),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _maybeEnter(LiveTableEntry entry, Widget row) {
    if (!_arrived.contains(entry.scientificName)) return row;
    return BirdyEntrance(
      duration: BirdyMotion.newSpecies,
      offset: const Offset(0, -BirdyMotion.maxOffset),
      child: row,
    );
  }
}

/// One row of the live table (SPEC.md 5.5): species halo, name, « chante »
/// bars while it sings, reliability, all-time total, ×N and replay.
class LiveTableRow extends StatelessWidget {
  const LiveTableRow({
    super.key,
    required this.entry,
    this.compact = false,
    this.image,
    this.badge,
    this.action,
    this.onTap,
  });

  final LiveTableEntry entry;
  final bool compact;
  final ImageProvider? image;
  final Widget? badge;
  final Widget? action;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
    final tint = SpeciesAccents.tintOf(entry.scientificName);
    return SpeciesTile(
      name: entry.commonName,
      compact: compact,
      onTap: onTap,
      avatar: SpeciesAvatar(image: image, tint: tint, size: compact ? 40 : 48),
      meta: Wrap(
        spacing: BirdySpace.s,
        runSpacing: BirdySpace.xs,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (entry.singing) SingingBars(color: c.accentText),
          if (badge != null) badge!,
          if (!compact)
            Text(
              l10n.forkLiveTotal(entry.total),
              style: BirdyText.caption.copyWith(
                color: c.text2,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
        ],
      ),
      count: AnimatedCount(
        value: entry.sessionCount,
        format: (n) => '×$n',
        semanticsLabel: l10n.forkLiveSessionCount(entry.sessionCount),
      ),
      action: action,
    );
  }
}

/// Three small bars that rise and fall while a species sings (SPEC.md 5.5
/// « chante »). Still with reduced motion.
class SingingBars extends StatefulWidget {
  const SingingBars({super.key, required this.color});

  final Color color;

  @override
  State<SingingBars> createState() => _SingingBarsState();
}

class _SingingBarsState extends State<SingingBars>
    with SingleTickerProviderStateMixin {
  static const Duration _period = Duration(milliseconds: 900);
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _period,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (BirdyMotion.reduced(context)) {
      _controller.stop();
      _controller.value = 0.5;
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: RepaintBoundary(
      child: CustomPaint(
        size: const Size(13, 12),
        painter: _BarsPainter(animation: _controller, color: widget.color),
      ),
    ),
  );
}

class _BarsPainter extends CustomPainter {
  _BarsPainter({required this.animation, required this.color})
    : super(repaint: animation);

  final Animation<double> animation;
  final Color color;

  /// Phase of each bar, as a fraction of the period (0, 150, 300 ms).
  static const _phases = [0.0, 1 / 6, 1 / 3];

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    for (final (i, phase) in _phases.indexed) {
      final t = (animation.value + phase) % 1;
      // Up and down once per period, between 35 % and 100 % of the height.
      final wave = 1 - (2 * t - 1).abs();
      final h = size.height * (0.35 + 0.65 * Curves.easeInOut.transform(wave));
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(i * 5.0, size.height - h, 3, h),
          const Radius.circular(2),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_BarsPainter old) =>
      old.color != color || old.animation != animation;
}
