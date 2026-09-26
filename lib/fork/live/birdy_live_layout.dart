/// BirdyGo live screen layout (J6c, fork/DESIGN.md « Live »): status bar,
/// counters, spectrogram (normal or enlarged), live table, control bar.
///
/// Layout only: the upstream screen keeps the session logic (start, stop,
/// lifecycle, warm-up, replay guard) and hands the pieces in.
library;

import 'package:flutter/material.dart';

import '../design/birdy_tokens.dart';
import 'live_board.dart';
import 'live_board_model.dart';
import 'live_spectrum.dart';
import 'live_stats.dart';
import 'spectrum_marks.dart';

class BirdyLiveLayout extends StatefulWidget {
  const BirdyLiveLayout({
    super.key,
    required this.statusBar,
    this.errorBanner,
    required this.spectrogram,
    required this.isCapturing,
    required this.displaySeconds,
    required this.marks,
    required this.sessionRunning,
    required this.elapsed,
    required this.entries,
    required this.contacts,
    required this.idleBody,
    required this.emptyBody,
    required this.controlBar,
    this.onTapSpecies,
    this.actionBuilder,
    this.imageOf,
  });

  final Widget statusBar;
  final Widget? errorBanner;
  final Widget spectrogram;
  final bool isCapturing;
  final double displaySeconds;
  final List<SpectrumMark> marks;

  /// A session is active or paused.
  final bool sessionRunning;
  final Duration Function() elapsed;

  final List<LiveBoardEntry> entries;
  final int contacts;

  /// Shown before the session starts (upstream tips).
  final Widget idleBody;

  /// Shown while listening, before the first bird.
  final Widget emptyBody;

  final Widget controlBar;
  final void Function(LiveBoardEntry entry)? onTapSpecies;
  final Widget? Function(LiveBoardEntry entry)? actionBuilder;
  final ImageProvider? Function(String scientificName)? imageOf;

  @override
  State<BirdyLiveLayout> createState() => _BirdyLiveLayoutState();
}

class _BirdyLiveLayoutState extends State<BirdyLiveLayout> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final running = widget.sessionRunning;
    final Widget body;
    if (!running) {
      body = widget.idleBody;
    } else if (widget.entries.isEmpty) {
      body = widget.emptyBody;
    } else {
      body = LiveBoard(
        entries: widget.entries,
        compact: _expanded,
        onTap: widget.onTapSpecies,
        actionBuilder: widget.actionBuilder,
        imageOf: widget.imageOf,
      );
    }

    return Column(
      children: [
        widget.statusBar,
        if (widget.errorBanner != null) widget.errorBanner!,
        if (running)
          LiveStats(
            elapsed: widget.elapsed,
            ticking: widget.isCapturing,
            species: widget.entries.length,
            contacts: widget.contacts,
            compact: _expanded,
          ),
        // Keyed so the spectrogram keeps its image when the rows above change.
        Expanded(
          key: const ValueKey('live-body'),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final height =
                  _expanded
                      ? constraints.maxHeight * kSpectrumExpandedShare
                      : BirdySizes.spectrumNormal;
              return Column(
                children: [
                  LiveSpectrum(
                    spectrogram: widget.spectrogram,
                    height: height,
                    expanded: _expanded,
                    onToggle: () => setState(() => _expanded = !_expanded),
                    isCapturing: widget.isCapturing,
                    displaySeconds: widget.displaySeconds,
                    marks: widget.marks,
                  ),
                  Expanded(child: body),
                ],
              );
            },
          ),
        ),
        widget.controlBar,
      ],
    );
  }
}

/// Calm line shown while listening, before the first bird.
class LiveEmptyState extends StatelessWidget {
  const LiveEmptyState({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final c = BirdyColors.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(BirdySpace.xxl),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(color: c.text2, fontSize: 15, height: 1.35),
        ),
      ),
    );
  }
}
