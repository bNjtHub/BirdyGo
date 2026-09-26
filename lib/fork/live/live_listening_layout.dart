/// Portrait layout of the listening screen (J6c, fork/DESIGN.md « Live »):
/// header, spectrogram, live table, control bar. Dark by default: wrap it
/// in `ListeningTheme`.
///
/// Holds only the spectrogram size; the session itself stays in the
/// upstream `LiveScreen`, which passes data and callbacks in.
library;

import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../design/birdy_tokens.dart';
import 'detection_marks.dart';
import 'live_control_bar.dart';
import 'live_header.dart';
import 'live_spectrogram_panel.dart';
import 'live_table.dart';
import 'live_table_model.dart';

class LiveListeningLayout extends StatefulWidget {
  const LiveListeningLayout({
    super.key,
    required this.statusText,
    required this.live,
    required this.capturing,
    required this.elapsed,
    required this.entries,
    required this.spans,
    required this.displaySeconds,
    required this.spectrogramBuilder,
    required this.phase,
    required this.onStart,
    required this.onStop,
    required this.onTogglePause,
    required this.onBack,
    required this.onSettings,
    required this.onHelp,
    this.replaying,
    this.imageFor,
    this.badgeFor,
    this.actionFor,
    this.onOpen,
    this.empty,
    this.banner,
  });

  final String statusText;

  /// A session is listening (not paused).
  final bool live;

  /// The microphone runs: the spectrogram and its marks scroll.
  final bool capturing;

  final Duration Function() elapsed;
  final List<LiveTableEntry> entries;
  final List<MarkSpan> spans;
  final double displaySeconds;

  /// Builds the spectrogram; `expanded` asks for the kHz scale.
  final Widget Function(bool expanded) spectrogramBuilder;

  final LiveControlPhase phase;
  final VoidCallback onStart;
  final VoidCallback onStop;
  final VoidCallback onTogglePause;
  final VoidCallback onBack;
  final VoidCallback onSettings;
  final VoidCallback onHelp;
  final ValueListenable<String?>? replaying;

  final ImageProvider? Function(String scientificName)? imageFor;
  final Widget Function(LiveTableEntry entry, {required bool compact})?
  badgeFor;
  final Widget? Function(LiveTableEntry entry)? actionFor;
  final void Function(LiveTableEntry entry)? onOpen;

  /// Shown in the table before the first species.
  final Widget? empty;

  /// Error banner, under the header.
  final Widget? banner;

  @override
  State<LiveListeningLayout> createState() => _LiveListeningLayoutState();
}

class _LiveListeningLayoutState extends State<LiveListeningLayout> {
  /// Share of the screen body taken by the enlarged spectrogram.
  static const double _expandedShare = 0.6;

  bool _expanded = false;

  void _toggle() => setState(() => _expanded = !_expanded);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
    final stats = LiveStats.of(widget.entries);
    final toggleLabel =
        _expanded ? l10n.forkLiveCollapseSpectrum : l10n.forkLiveExpandSpectrum;
    final marked = <String>{
      for (final s in widget.spans.reversed.take(12)) s.label,
    };

    return ColoredBox(
      color: c.background,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SafeArea(
            bottom: false,
            child: LiveHeader(
              statusText: widget.statusText,
              live: widget.live,
              stats: stats,
              elapsed: widget.elapsed,
              expanded: _expanded,
              onToggleSpectrum: _toggle,
              onBack: widget.onBack,
              onSettings: widget.onSettings,
              onHelp: widget.onHelp,
            ),
          ),
          if (widget.banner != null) widget.banner!,
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final expandedHeight = (constraints.maxHeight * _expandedShare)
                    .clamp(
                      LiveSpectrogramPanel.normalHeight,
                      constraints.maxHeight,
                    );
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    LiveSpectrogramPanel(
                      expanded: _expanded,
                      expandedHeight: expandedHeight,
                      onToggle: _toggle,
                      toggleLabel: toggleLabel,
                      semanticLabel:
                          marked.isEmpty
                              ? l10n.forkLiveSpectrumLabel
                              : l10n.forkLiveSpectrumMarksLabel(
                                marked.join(', '),
                              ),
                      spectrogram: widget.spectrogramBuilder(_expanded),
                      marks: DetectionMarks(
                        spans: widget.spans,
                        displaySeconds: widget.displaySeconds,
                        running: widget.capturing,
                        showLabels: _expanded,
                      ),
                    ),
                    Expanded(
                      child: LiveTable(
                        entries: widget.entries,
                        compact: _expanded,
                        imageFor: widget.imageFor,
                        badgeFor: widget.badgeFor,
                        actionFor: widget.actionFor,
                        onOpen: widget.onOpen,
                        empty: widget.empty,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          LiveControlBar(
            phase: widget.phase,
            onStart: widget.onStart,
            onStop: widget.onStop,
            onTogglePause: widget.onTogglePause,
            replaying: widget.replaying,
          ),
        ],
      ),
    );
  }
}
