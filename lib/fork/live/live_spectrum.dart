/// Live spectrogram band (J6c): normal (120 px) or enlarged (about 60 % of
/// the screen) with one tap, with the species marks drawn under each
/// detected passage.
library;

import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../shared/utils/app_icons.dart';
import '../design/birdy_motion.dart';
import '../design/birdy_tokens.dart';
import '../design/widgets/birdy_buttons.dart';
import 'spectrum_marks.dart';

/// Share of the screen body given to the enlarged spectrogram.
const double kSpectrumExpandedShare = 0.6;

class LiveSpectrum extends StatefulWidget {
  const LiveSpectrum({
    super.key,
    required this.spectrogram,
    required this.height,
    required this.expanded,
    required this.onToggle,
    required this.isCapturing,
    required this.displaySeconds,
    required this.marks,
    this.now = DateTime.now,
  });

  /// The upstream spectrogram, kept as is.
  final Widget spectrogram;

  final double height;
  final bool expanded;
  final VoidCallback onToggle;

  /// The spectrogram scrolls only while capturing; the marks follow it.
  final bool isCapturing;

  /// Seconds across the whole width (the spectrogram's own setting).
  final double displaySeconds;

  final List<SpectrumMark> marks;

  /// Clock, replaceable in tests.
  final DateTime Function() now;

  @override
  State<LiveSpectrum> createState() => _LiveSpectrumState();
}

class _LiveSpectrumState extends State<LiveSpectrum>
    with SingleTickerProviderStateMixin {
  SpectrumClock? _clock;
  late final Ticker _ticker = createTicker((_) => _frame.value++);
  final ValueNotifier<int> _frame = ValueNotifier(0);

  @override
  void initState() {
    super.initState();
    if (widget.isCapturing) _clock = SpectrumClock(widget.now());
    _syncTicker();
  }

  @override
  void didUpdateWidget(LiveSpectrum old) {
    super.didUpdateWidget(old);
    if (widget.isCapturing != old.isCapturing) {
      final t = widget.now();
      final clock = _clock;
      if (clock == null) {
        if (widget.isCapturing) _clock = SpectrumClock(t);
      } else if (widget.isCapturing) {
        clock.resume(t);
      } else {
        clock.pause(t);
      }
    }
    _syncTicker();
  }

  /// Marks move only while the spectrogram scrolls and some are drawn.
  void _syncTicker() {
    final run = widget.isCapturing && widget.marks.isNotEmpty;
    if (run && !_ticker.isActive) {
      _ticker.start();
    } else if (!run && _ticker.isActive) {
      _ticker.stop();
      _frame.value++;
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _frame.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final clock = _clock;
    final label =
        widget.expanded
            ? l10n.forkLiveSpectrumShrink
            : l10n.forkLiveSpectrumExpand;
    final reduced = BirdyMotion.reduced(context);
    return AnimatedContainer(
      duration: reduced ? Duration.zero : BirdyMotion.reorder,
      curve: BirdyMotion.move,
      height: widget.height,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [BirdyBrand.wellTop, BirdyBrand.wellBottom],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Semantics(
            button: true,
            label: label,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: widget.onToggle,
              child: RepaintBoundary(child: widget.spectrogram),
            ),
          ),
          if (clock != null)
            IgnorePointer(
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: SpectrumMarksPainter(
                    marks: widget.marks,
                    clock: clock,
                    displaySeconds: widget.displaySeconds,
                    now: widget.now,
                    repaint: _frame,
                  ),
                ),
              ),
            ),
          PositionedDirectional(
            top: BirdySpace.xs,
            end: BirdySpace.xs,
            child: ExcludeSemantics(
              child: BirdyIconButton(
                icon:
                    widget.expanded ? AppIcons.unfoldLess : AppIcons.unfoldMore,
                semanticLabel: label,
                onPressed: widget.onToggle,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
