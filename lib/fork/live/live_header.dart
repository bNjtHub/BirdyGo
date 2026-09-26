/// Header of the listening screen (J6c, SPEC.md 9.2): status, spectrogram
/// size, menu, then three stat tiles (duration, species, contacts).
library;

import 'dart:async';

import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

import '../../shared/utils/app_icons.dart';
import '../design/birdy_motion.dart';
import '../design/birdy_tokens.dart';
import '../design/birdy_typography.dart';
import '../design/widgets/animated_count.dart';
import '../design/widgets/birdy_buttons.dart';
import 'live_table_model.dart';

/// « 12:47 », or « 1:02:47 » after an hour.
String formatListeningTime(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return h > 0 ? '$h:$m:$s' : '$m:$s';
}

class LiveHeader extends StatelessWidget {
  const LiveHeader({
    super.key,
    required this.statusText,
    required this.live,
    required this.stats,
    required this.elapsed,
    required this.expanded,
    this.showTiles = true,
    required this.onToggleSpectrum,
    required this.onBack,
    required this.onSettings,
    required this.onHelp,
  });

  /// « En écoute », « En pause », « Chargement du modèle… ».
  final String statusText;

  /// Listening now: the dot glows.
  final bool live;

  final LiveStats stats;

  /// Listening time, pauses excluded; read every second.
  final Duration Function() elapsed;

  /// The spectrogram is enlarged: the tiles give way to a one-line summary.
  final bool expanded;

  /// False in landscape: the summary line replaces the tiles to leave the
  /// height to the spectrogram.
  final bool showTiles;

  final VoidCallback onToggleSpectrum;
  final VoidCallback onBack;
  final VoidCallback onSettings;
  final VoidCallback onHelp;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
    final reduced = BirdyMotion.reduced(context);
    final tiles = showTiles && !expanded;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        BirdySpace.gutterDark,
        BirdySpace.s,
        BirdySpace.gutterDark,
        BirdySpace.m,
      ),
      child: AnimatedSize(
        duration: reduced ? Duration.zero : BirdyMotion.reorder,
        curve: BirdyMotion.move,
        alignment: Alignment.topCenter,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                BirdyIconButton(
                  icon: AppIcons.arrowBackRounded,
                  semanticLabel: l10n.tooltipBack,
                  onPressed: onBack,
                ),
                const SizedBox(width: BirdySpace.m),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _LiveDot(live: live),
                          const SizedBox(width: BirdySpace.s),
                          Flexible(
                            child: Text(
                              statusText,
                              style: BirdyText.label.copyWith(color: c.text1),
                            ),
                          ),
                        ],
                      ),
                      if (!tiles)
                        Text(
                          l10n.forkLiveSummary(stats.species, stats.contacts),
                          style: BirdyText.caption.copyWith(color: c.text2),
                        ),
                    ],
                  ),
                ),
                BirdyIconButton(
                  icon: expanded ? AppIcons.expandLess : AppIcons.expandMore,
                  semanticLabel:
                      expanded
                          ? l10n.forkLiveCollapseSpectrum
                          : l10n.forkLiveExpandSpectrum,
                  onPressed: onToggleSpectrum,
                ),
                const SizedBox(width: BirdySpace.xs),
                _Menu(onSettings: onSettings, onHelp: onHelp),
              ],
            ),
            if (tiles) ...[
              const SizedBox(height: BirdySpace.m),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: StatTile(
                      value: _ElapsedText(elapsed: elapsed, running: live),
                      label: l10n.forkLiveDuration,
                    ),
                  ),
                  const SizedBox(width: BirdySpace.s),
                  Expanded(
                    child: StatTile(
                      value: AnimatedCount(
                        value: stats.species,
                        style: BirdyText.numberL,
                      ),
                      label: l10n.forkLiveSpeciesStat(stats.species),
                    ),
                  ),
                  const SizedBox(width: BirdySpace.s),
                  Expanded(
                    child: StatTile(
                      value: AnimatedCount(
                        value: stats.contacts,
                        style: BirdyText.numberL,
                      ),
                      label: l10n.forkLiveContactsStat(stats.contacts),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LiveDot extends StatelessWidget {
  const _LiveDot({required this.live});

  final bool live;

  @override
  Widget build(BuildContext context) {
    final c = BirdyColors.of(context);
    final color = live ? c.accentText : c.text2;
    return SizedBox.square(
      dimension: 8,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow:
              live
                  ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.6),
                      blurRadius: 6,
                    ),
                  ]
                  : null,
        ),
      ),
    );
  }
}

class _Menu extends StatelessWidget {
  const _Menu({required this.onSettings, required this.onHelp});

  final VoidCallback onSettings;
  final VoidCallback onHelp;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
    return PopupMenuButton<VoidCallback>(
      tooltip: MaterialLocalizations.of(context).showMenuTooltip,
      icon: const Icon(AppIcons.moreVert),
      style: IconButton.styleFrom(
        fixedSize: const Size.square(BirdySizes.target),
        backgroundColor: c.line,
        foregroundColor: c.text1,
        side: BorderSide(color: c.border),
      ),
      onSelected: (action) => action(),
      itemBuilder:
          (context) => [
            PopupMenuItem(
              value: onSettings,
              child: ListTile(
                leading: const Icon(AppIcons.tuneRounded),
                title: Text(l10n.settings),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            PopupMenuItem(
              value: onHelp,
              child: ListTile(
                leading: const Icon(AppIcons.helpOutlineRounded),
                title: Text(l10n.liveScreenHelpTitle),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
    );
  }
}

/// Listening time, refreshed every second in this widget only, so the rest
/// of the screen does not rebuild with the clock.
class _ElapsedText extends StatefulWidget {
  const _ElapsedText({required this.elapsed, required this.running});

  final Duration Function() elapsed;
  final bool running;

  @override
  State<_ElapsedText> createState() => _ElapsedTextState();
}

class _ElapsedTextState extends State<_ElapsedText> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(_ElapsedText old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    if (widget.running && _timer == null) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    } else if (!widget.running) {
      _timer?.cancel();
      _timer = null;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      Text(formatListeningTime(widget.elapsed()), style: BirdyText.numberL);
}
