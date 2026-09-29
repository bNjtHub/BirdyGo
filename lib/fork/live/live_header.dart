/// Header of the listening screen (J6c, SPEC.md 9.2; J6f): the BirdyGo logo,
/// status (always with the listening mode, coloured with its icon) and
/// place, the « Options d'écoute » button (modes, levels, help, settings),
/// then three stat tiles (duration, species, contacts).
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
import '../design/widgets/birdy_listening_logo.dart';
import '../listening_mode/listening_mode.dart';
import 'listening_options.dart';
import 'live_control_bar.dart';
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
    required this.phase,
    required this.stats,
    required this.elapsed,
    required this.expanded,
    this.showTiles = true,
    this.place,
    this.listeningMode = ListeningMode.normal,
    required this.onOptions,
    required this.onBack,
  });

  /// « En écoute », « En pause », « Chargement du modèle… ».
  final String statusText;

  /// Drives the logo (J6f): only its wing bars move, and only while
  /// [LiveControlPhase.active] — frozen mid-length while
  /// [LiveControlPhase.paused], full and still otherwise.
  final LiveControlPhase phase;

  final LiveStats stats;

  /// Listening time, pauses excluded; read every second.
  final Duration Function() elapsed;

  /// The spectrogram is enlarged: the tiles give way to a one-line summary.
  final bool expanded;

  /// False in landscape: the summary line replaces the tiles to leave the
  /// height to the spectrogram.
  final bool showTiles;

  /// Where the phone listens (« Le jardin · Beaulieu »), under the status.
  final String? place;

  /// Active listening mode; null when the Settings sliders were moved by
  /// hand (« Personnalisé »). Always shown in the status, coloured with its
  /// icon (« En écoute · Vent »), and given to the options button.
  final ListeningMode? listeningMode;

  /// Opens the « Options d'écoute » sheet: modes, levels, help, settings.
  final VoidCallback onOptions;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
    final reduced = BirdyMotion.reduced(context);
    final tiles = showTiles && !expanded;
    final running = phase == LiveControlPhase.active;
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
                          BirdyListeningLogo(
                            size: BirdySizes.liveLogo,
                            running: phase == LiveControlPhase.active,
                            frozen: phase == LiveControlPhase.paused,
                          ),
                          const SizedBox(width: BirdySpace.s),
                          Expanded(
                            child: _StatusText(
                              status: statusText,
                              mode: listeningMode,
                              style: BirdyText.label.copyWith(color: c.text1),
                            ),
                          ),
                        ],
                      ),
                      if (place != null)
                        Text(
                          place!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          softWrap: false,
                          style: BirdyText.caption.copyWith(color: c.text2),
                        ),
                      if (!tiles)
                        Text(
                          l10n.forkLiveSummary(stats.species, stats.contacts),
                          style: BirdyText.caption.copyWith(color: c.text2),
                        ),
                    ],
                  ),
                ),
                // The enlarge chevron moved onto the spectrogram (J6c-bis-c).
                // J6f: one options button (modes, levels, help, settings)
                // leaves the width to the status and the place.
                const SizedBox(width: BirdySpace.s),
                ListeningOptionsButton(
                  mode: listeningMode,
                  onPressed: onOptions,
                ),
              ],
            ),
            if (tiles) ...[
              const SizedBox(height: BirdySpace.m),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: StatTile(
                      value: _ElapsedText(elapsed: elapsed, running: running),
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

/// Listening time, refreshed every second in this widget only, so the rest
/// of the screen does not rebuild with the clock.
/// Status on one line; a new text fades in over the old one, the height
/// stays that of one line whatever the text (room for « Analyse… »). The
/// listening mode always follows, its word and icon in the mode's color
/// (J6f); « Personnalisé » stays neutral.
class _StatusText extends StatelessWidget {
  const _StatusText({
    required this.status,
    required this.mode,
    required this.style,
  });

  final String status;
  final ListeningMode? mode;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
    final modeWord = listeningModeLabel(l10n, mode);
    final modeColor = listeningModeColor(c, mode);
    return AnimatedSwitcher(
      duration: BirdyMotion.enter,
      reverseDuration: BirdyMotion.exit,
      switchInCurve: BirdyMotion.standard,
      switchOutCurve: BirdyMotion.standard,
      layoutBuilder:
          (current, previous) => Stack(
            alignment: AlignmentDirectional.centerStart,
            children: [...previous, if (current != null) current],
          ),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(text: status, style: style),
            TextSpan(text: ' · ', style: style),
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Icon(
                listeningModeIcon(mode),
                size: BirdySizes.statusModeIcon,
                color: modeColor,
              ),
            ),
            TextSpan(
              text: ' $modeWord',
              style: style.copyWith(color: modeColor),
            ),
          ],
        ),
        key: ValueKey('$status·${mode?.name}'),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        softWrap: false,
        semanticsLabel: l10n.forkLiveStatusWithMode(status, modeWord),
      ),
    );
  }
}

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
  Widget build(BuildContext context) => Text(
    formatListeningTime(widget.elapsed()),
    style: BirdyText.numberL,
    maxLines: 1,
    softWrap: false,
  );
}
