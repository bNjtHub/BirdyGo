/// Live table (J6c, fork/DESIGN.md « Live »): one row per species of the
/// outing, fed as detections arrive.
///
/// - a new species comes in on top ([BirdyEntrance] from 8 px above, light
///   haptic);
/// - a species heard again goes back to the top in 250 ms ([FlipMove]) and
///   its counter ×N bumps ([AnimatedCount]);
/// - the table never empties while listening.
library;

import 'dart:async';

import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

import '../design/birdy_motion.dart';
import '../design/birdy_tokens.dart';
import '../design/species_accents.dart';
import '../../shared/utils/app_icons.dart';
import '../design/widgets/animated_count.dart';
import '../design/widgets/birdy_cross_fade.dart';
import '../design/widgets/birdy_pill.dart';
import '../design/widgets/expanded_hit_area.dart';
import '../reliability/reliability_config.dart';
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
    this.levelFor,
    this.onBadgeTap,
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

  /// Level of a row (J7, best contact of the outing): a row that goes from
  /// another level to « Sûr » shows « Confirmé » once.
  final ReliabilityLevel Function(LiveTableEntry entry)? levelFor;

  /// The level badge of a row was tapped.
  final void Function(LiveTableEntry entry)? onBadgeTap;

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

  /// Last level seen per species (J7).
  final Map<String, ReliabilityLevel> _levels = {};

  /// Species already confirmed during this outing, and those showing
  /// « Confirmé » now.
  final Set<String> _confirmedOnce = {};
  final Set<String> _confirmedNow = {};
  final Map<String, Timer> _timers = {};

  @override
  void dispose() {
    for (final timer in _timers.values) {
      timer.cancel();
    }
    super.dispose();
  }

  void _trackLevels() {
    final levelFor = widget.levelFor;
    if (levelFor == null) return;
    if (widget.entries.isEmpty) {
      _levels.clear();
      _confirmedOnce.clear();
      _confirmedNow.clear();
      for (final timer in _timers.values) {
        timer.cancel();
      }
      _timers.clear();
      return;
    }
    for (final entry in widget.entries) {
      final name = entry.scientificName;
      final level = levelFor(entry);
      final before = _levels[name];
      _levels[name] = level;
      if (before == null ||
          before == ReliabilityLevel.sure ||
          level != ReliabilityLevel.sure ||
          !_confirmedOnce.add(name)) {
        continue;
      }
      _confirmedNow.add(name);
      _timers[name]?.cancel();
      _timers[name] = Timer(BirdyMotion.confirmedShown, () {
        _timers.remove(name);
        if (!mounted) return;
        setState(() => _confirmedNow.remove(name));
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _known = {for (final e in widget.entries) e.scientificName};
    _trackLevels();
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
    _trackLevels();
  }

  static const Key _emptyKey = ValueKey('live-table-empty');
  static const Key _rowsKey = ValueKey('live-table-rows');

  @override
  Widget build(BuildContext context) {
    final empty = widget.empty;
    if (empty == null) return _rows();
    // J6f: the empty state fades out (exit) as the first row comes in; the
    // row plays its own entrance, so the rows themselves do not fade.
    return AnimatedSwitcher(
      duration: BirdyMotion.reduced(context) ? Duration.zero : BirdyMotion.exit,
      switchInCurve: BirdyMotion.standard,
      switchOutCurve: BirdyMotion.standard,
      layoutBuilder:
          (current, previous) => Stack(
            fit: StackFit.expand,
            children: [...previous, if (current != null) current],
          ),
      transitionBuilder:
          (child, animation) =>
              child.key == _emptyKey
                  ? FadeTransition(opacity: animation, child: child)
                  : child,
      child:
          widget.entries.isEmpty
              ? KeyedSubtree(
                key: _emptyKey,
                child: Padding(padding: widget.padding, child: empty),
              )
              : KeyedSubtree(key: _rowsKey, child: _rows()),
    );
  }

  Widget _rows() {
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
                        confirmed: _confirmedNow.contains(entry.scientificName),
                        onBadgeTap:
                            widget.onBadgeTap == null
                                ? null
                                : () => widget.onBadgeTap!(entry),
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
    this.confirmed = false,
    this.onBadgeTap,
    this.action,
    this.onTap,
  });

  final LiveTableEntry entry;
  final bool compact;
  final ImageProvider? image;
  final Widget? badge;

  /// The species just became « Sûr » (J7): a brief « Confirmé » takes the
  /// place of the badge. With reduced motion only the badge changes, and a
  /// screen reader announces it.
  final bool confirmed;

  /// Tap on the level badge (opens the levels sheet).
  final VoidCallback? onBadgeTap;
  final Widget? action;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
    final tint = SpeciesAccents.tintOf(entry.scientificName);
    final tile = SpeciesTile(
      name: entry.commonName,
      compact: compact,
      onTap: onTap,
      // The species color, as on its marks under the spectrogram
      // (J6c-bis-c): a dot on the photo.
      avatar: SpeciesColorDot(
        color: tint.accent,
        ring: c.background,
        child: SpeciesAvatar(image: image, tint: tint, size: compact ? 40 : 48),
      ),
      meta: Wrap(
        spacing: BirdySpace.s,
        runSpacing: BirdySpace.xs,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SingingIndicator(
            singing: entry.singingVisual,
            color: tint.accent,
            // The bars follow the score of the current window (J7).
            level: entry.record.confidence,
          ),
          if (badge != null) _badgeSlot(context, badge!),
        ],
      ),
      count: AnimatedCount(
        value: entry.sessionCount,
        format: (n) => '×$n',
        semanticsLabel: l10n.forkLiveSessionCount(entry.sessionCount),
      ),
      action: action,
    );
    // J7: the badge gets a 48 dp target without growing the row.
    return onBadgeTap == null ? tile : ExpandedHitRegion(child: tile);
  }
}

extension on LiveTableRow {
  /// The level badge (tappable), or « Confirmé » for a moment (J7).
  Widget _badgeSlot(BuildContext context, Widget badge) {
    final l10n = AppLocalizations.of(context)!;
    final reduced = BirdyMotion.reduced(context);
    final showPill = confirmed && !reduced;
    final Widget tappable =
        onBadgeTap == null
            ? badge
            : Semantics(
              button: true,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onBadgeTap,
                child: badge,
              ),
            );
    final Widget inner =
        reduced
            ? tappable
            : BirdyCrossFade(
              child: KeyedSubtree(
                key: ValueKey(showPill ? 'confirmed' : 'level'),
                child: showPill ? const ConfirmedPill() : tappable,
              ),
            );
    // A 48 dp touch target around the badge, outside the layout: the row
    // keeps its height (the tap must land inside the row).
    final Widget slot =
        onBadgeTap == null
            ? inner
            : ExpandedHitArea(
              key: const ValueKey('live-badge-hit'),
              minSize: BirdySizes.target,
              child: inner,
            );
    if (!confirmed) return slot;
    return Semantics(
      liveRegion: true,
      label: l10n.forkLiveConfirmedAnnounce(entry.commonName),
      child: slot,
    );
  }
}

/// « Confirmé » with a check, in the « Sûr » colors (J7).
class ConfirmedPill extends StatelessWidget {
  const ConfirmedPill({super.key});

  @override
  Widget build(BuildContext context) {
    final c = BirdyColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    return BirdyPill(
      key: const ValueKey('live-confirmed'),
      label: l10n.forkLiveConfirmed,
      foreground: c.sure.foreground,
      background: c.sure.background,
      leading: Icon(
        AppIcons.checkRounded,
        size: BirdyGlyph.s,
        color: c.sure.foreground,
      ),
    );
  }
}

/// [child] with a small dot of [color] at its bottom right, circled with
/// [ring] (the background) so it reads on any photo.
class SpeciesColorDot extends StatelessWidget {
  const SpeciesColorDot({
    super.key,
    required this.color,
    required this.ring,
    required this.child,
  });

  /// Diameter of the dot, ring included.
  static const double size = 16;

  final Color color;
  final Color ring;
  final Widget child;

  @override
  Widget build(BuildContext context) => Stack(
    clipBehavior: Clip.none,
    children: [
      child,
      PositionedDirectional(
        end: -2,
        bottom: -2,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: ring, width: BirdyStroke.thick),
          ),
        ),
      ),
    ],
  );
}

/// [SingingBars] in a place kept for them: they fade in and out
/// ([BirdyMotion.enter], [BirdyMotion.exit]) and the row never moves. The
/// bars stop ticking once faded out.
class SingingIndicator extends StatefulWidget {
  const SingingIndicator({
    super.key,
    required this.singing,
    required this.color,
    this.level = 1,
  });

  final bool singing;
  final Color color;

  /// Score of the current window, 0 to 1: how tall the bars stand.
  final double level;

  @override
  State<SingingIndicator> createState() => _SingingIndicatorState();
}

class _SingingIndicatorState extends State<SingingIndicator> {
  /// True while shown or fading out.
  late bool _ticking = widget.singing;

  @override
  void didUpdateWidget(SingingIndicator old) {
    super.didUpdateWidget(old);
    if (widget.singing) _ticking = true;
  }

  @override
  Widget build(BuildContext context) => AnimatedOpacity(
    opacity: widget.singing ? 1 : 0,
    duration: widget.singing ? BirdyMotion.enter : BirdyMotion.exit,
    curve: BirdyMotion.standard,
    onEnd: () {
      if (!widget.singing && _ticking) setState(() => _ticking = false);
    },
    child: TickerMode(
      enabled: _ticking,
      child: SingingBars(color: widget.color, level: widget.level),
    ),
  );
}

/// Three small bars that rise and fall while a species sings (SPEC.md 5.5
/// « chante »). Still with reduced motion.
class SingingBars extends StatefulWidget {
  const SingingBars({super.key, required this.color, this.level = 1});

  final Color color;

  /// Score of the current window, 0 to 1 (J7): bars scale from
  /// [BirdyMotion.singingBarsMinScale] of their height up to all of it.
  final double level;

  @override
  State<SingingBars> createState() => _SingingBarsState();
}

class _SingingBarsState extends State<SingingBars>
    with SingleTickerProviderStateMixin {
  static const Duration _period = BirdyMotion.singingBars;
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
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: widget.level.clamp(0.0, 1.0)),
        duration:
            BirdyMotion.reduced(context) ? Duration.zero : BirdyMotion.enter,
        curve: BirdyMotion.standard,
        builder:
            (context, level, _) => CustomPaint(
              size: const Size(13, 12),
              painter: _BarsPainter(
                animation: _controller,
                color: widget.color,
                level: level,
              ),
            ),
      ),
    ),
  );
}

class _BarsPainter extends CustomPainter {
  _BarsPainter({
    required this.animation,
    required this.color,
    required this.level,
  }) : super(repaint: animation);

  final Animation<double> animation;
  final Color color;

  /// Bar height scale from the score of the current window.
  final double level;

  /// Phase of each bar, as a fraction of the period (0, 150, 300 ms).
  static const _phases = [0.0, 1 / 6, 1 / 3];

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    for (final (i, phase) in _phases.indexed) {
      final t = (animation.value + phase) % 1;
      // Up and down once per period, between 35 % and 100 % of the height.
      final wave = 1 - (2 * t - 1).abs();
      final scale =
          BirdyMotion.singingBarsMinScale +
          (1 - BirdyMotion.singingBarsMinScale) * level;
      final h =
          size.height *
          scale *
          (0.35 + 0.65 * Curves.easeInOut.transform(wave));
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
      old.color != color || old.animation != animation || old.level != level;
}
