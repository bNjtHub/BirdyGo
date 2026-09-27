import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../../l10n/app_localizations.dart';
import '../design/birdy_motion.dart';
import '../design/birdy_tokens.dart';
import '../design/birdy_typography.dart';
import 'birdygo_splash_painter.dart';
import 'birdygo_warm_up.dart';

/// The startup screen of the Claude Design board « BirdyGo Splash »: the mark
/// sings, the wordmark and the tagline follow. The app loads alongside; the
/// bar and the caption show the real [progress], and the bird keeps singing
/// for as long as loading takes.
class BirdyGoSplash extends StatefulWidget {
  const BirdyGoSplash({
    super.key,
    required this.progress,
    this.onRetry,
    this.onIntroComplete,
  });

  final ValueListenable<BirdyGoLoadState> progress;

  /// Shortest time the splash stays up on a normal launch, however fast the
  /// app initializes: one whole sung phrase, up to the blink and the last
  /// note fading out, until the bird is about to sing again.
  static const minimumDisplay = Duration(milliseconds: 4400);

  final VoidCallback? onRetry;

  /// Called once, when [minimumDisplay] has elapsed.
  final VoidCallback? onIntroComplete;

  @override
  State<BirdyGoSplash> createState() => _BirdyGoSplashState();
}

class _BirdyGoSplashState extends State<BirdyGoSplash>
    with SingleTickerProviderStateMixin {
  /// Milliseconds since the splash appeared.
  final _clock = ValueNotifier<double>(0);

  /// Filled share of the loading bar: follows the real progress, eased.
  final _bar = ValueNotifier<double>(0);
  late final Ticker _ticker = createTicker(_onTick);
  bool _reported = false;
  bool _reduced = false;

  void _onTick(Duration elapsed) {
    final now = elapsed.inMicroseconds / 1000;
    final dt = now - _clock.value;
    _clock.value = now;
    final target = widget.progress.value.fraction;
    _bar.value =
        (target - _bar.value).abs() < .002
            ? target
            : _bar.value +
                (target - _bar.value) *
                    (1 - math.exp(-dt / BirdyGoSplashTimeline.barEase));
    if (elapsed >= BirdyGoSplash.minimumDisplay) _reportIntroComplete();
  }

  /// Without the ticker (reduced motion), the bar jumps to the progress.
  void _onProgress() {
    if (!_ticker.isActive) _bar.value = widget.progress.value.fraction;
  }

  // Frame statistics, logged when the splash leaves, to measure smoothness
  // on a device (debug builds are much slower than release ones).
  int _frames = 0;
  int _slowFrames = 0;
  Duration _worstBuild = Duration.zero;
  Duration _worstRaster = Duration.zero;

  void _onTimings(List<FrameTiming> timings) {
    for (final timing in timings) {
      _frames++;
      if (timing.buildDuration > _frameBudget ||
          timing.rasterDuration > _frameBudget) {
        _slowFrames++;
      }
      if (timing.buildDuration > _worstBuild) {
        _worstBuild = timing.buildDuration;
      }
      if (timing.rasterDuration > _worstRaster) {
        _worstRaster = timing.rasterDuration;
      }
    }
  }

  static const _frameBudget = Duration(microseconds: 16667);

  @override
  void initState() {
    super.initState();
    widget.progress.addListener(_onProgress);
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
  }

  @override
  void didUpdateWidget(BirdyGoSplash oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.progress != widget.progress) {
      oldWidget.progress.removeListener(_onProgress);
      widget.progress.addListener(_onProgress);
    }
  }

  void _reportIntroComplete() {
    if (_reported) return;
    _reported = true;
    widget.onIntroComplete?.call();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = BirdyMotion.reduced(context);
    if (_reduced) {
      _ticker.stop();
      _bar.value = widget.progress.value.fraction;
      // Reduced motion adds no wait. Reported after the frame: this runs
      // during build.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _reportIntroComplete();
      });
    } else if (!_ticker.isActive) {
      _ticker.start();
    }
  }

  @override
  void dispose() {
    SchedulerBinding.instance.removeTimingsCallback(_onTimings);
    debugPrint(
      '[BirdyGoSplash] $_frames frames, $_slowFrames over 16.7 ms, '
      'worst build ${_worstBuild.inMilliseconds} ms, '
      'worst raster ${_worstRaster.inMilliseconds} ms',
    );
    widget.progress.removeListener(_onProgress);
    _ticker.dispose();
    _clock.dispose();
    _bar.dispose();
    super.dispose();
  }

  Widget _entrance({required double at, required Widget child}) =>
      ValueListenableBuilder<double>(
        valueListenable: _clock,
        child: child,
        builder: (context, clock, child) {
          final t =
              _reduced
                  ? 1.0
                  : BirdyGoSplashTimeline.easeOut(
                    (clock - at) / BirdyGoSplashTimeline.textEnter,
                  );
          return Opacity(
            opacity: t,
            // A screen reader gets the text at once, not beat by beat.
            alwaysIncludeSemantics: true,
            child: Transform.translate(
              offset: Offset(0, BirdyMotion.maxOffset * (1 - t)),
              child: child,
            ),
          );
        },
      );

  /// « Birdy », an Oriole dot, « Go » (variant « Point Loriot » of the board).
  /// The brand name is never translated.
  Widget _wordmark(BuildContext context, AppLocalizations l10n) {
    final scaler = MediaQuery.textScalerOf(context);
    return Semantics(
      label: l10n.appTitle,
      child: ExcludeSemantics(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: 'Birdy',
                  style: BirdyText.display.copyWith(
                    fontSize: 44,
                    letterSpacing: -.8,
                    fontVariations: const [
                      FontVariation('SOFT', 100),
                      FontVariation('opsz', 44),
                    ],
                  ),
                ),
                // The dot floats at mid-height of the lowercase letters.
                WidgetSpan(
                  alignment: PlaceholderAlignment.baseline,
                  baseline: TextBaseline.alphabetic,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(5, 0, 5, scaler.scale(5)),
                    child: SizedBox.square(
                      dimension: scaler.scale(9),
                      child: const DecoratedBox(
                        decoration: ShapeDecoration(
                          color: BirdyBrand.oriole,
                          shape: CircleBorder(),
                        ),
                      ),
                    ),
                  ),
                ),
                TextSpan(
                  text: 'Go',
                  style: BirdyText.label.copyWith(
                    fontSize: 42,
                    height: 1.1,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1,
                  ),
                ),
              ],
            ),
            style: const TextStyle(color: BirdyBrand.ink),
            softWrap: false,
          ),
        ),
      ),
    );
  }

  /// The tagline enters in two beats; a screen reader hears one sentence.
  Widget _tagline(AppLocalizations l10n) {
    final style = BirdyText.body.copyWith(color: BirdyBrand.bark);
    return Semantics(
      label: '${l10n.forkSplashTaglineFirst} ${l10n.forkSplashTaglineSecond}',
      child: ExcludeSemantics(
        child: Wrap(
          alignment: WrapAlignment.center,
          spacing: 6,
          children: [
            _entrance(
              at: BirdyGoSplashTimeline.taglineFirst,
              child: Text(l10n.forkSplashTaglineFirst, style: style),
            ),
            _entrance(
              at: BirdyGoSplashTimeline.taglineSecond,
              child: Text(l10n.forkSplashTaglineSecond, style: style),
            ),
          ],
        ),
      ),
    );
  }

  Widget _error(AppLocalizations l10n) => Column(
    children: [
      Semantics(
        liveRegion: true,
        child: Text(
          l10n.forkSplashError,
          style: BirdyText.bodyCompact.copyWith(color: BirdyBrand.ink),
          textAlign: TextAlign.center,
        ),
      ),
      const SizedBox(height: 12),
      FilledButton(onPressed: widget.onRetry, child: Text(l10n.retry)),
    ],
  );

  /// What is loading right now, as the caption under the bar says it.
  static String _stepCaption(AppLocalizations l10n, BirdyGoLoadStep? step) =>
      switch (step) {
        BirdyGoLoadStep.start => l10n.forkSplashLoading,
        BirdyGoLoadStep.audioModel => l10n.forkSplashStepAudioModel,
        BirdyGoLoadStep.geoModel => l10n.forkSplashStepGeoModel,
        BirdyGoLoadStep.species => l10n.forkSplashStepSpecies,
        BirdyGoLoadStep.observations => l10n.forkSplashStepObservations,
        null => l10n.forkSplashReady,
      };

  Widget _loading(AppLocalizations l10n, {required bool compact}) => _entrance(
    at: BirdyGoSplashTimeline.footer,
    child: ValueListenableBuilder<BirdyGoLoadState>(
      valueListenable: widget.progress,
      builder: (context, state, _) {
        final caption = _stepCaption(l10n, state.current);
        return Semantics(
          liveRegion: true,
          label: caption,
          value: '${(state.fraction * 100).round()} %',
          child: ExcludeSemantics(
            child: Column(
              children: [
                RepaintBoundary(
                  child: CustomPaint(
                    size: const Size(180, 4),
                    painter: BirdyGoLoadingPainter(fraction: _bar),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  caption,
                  style: BirdyText.caption.copyWith(
                    fontSize: 14,
                    color: BirdyBrand.bark,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: compact ? 8 : 24),
                Text(
                  l10n.forkPoweredByBirdnet,
                  style: BirdyText.caption.copyWith(color: BirdyBrand.bark),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      },
    ),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarContrastEnforced: false,
      ),
      child: Scaffold(
        backgroundColor: BirdyBrand.mist,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxHeight < 480;
              final logoWidth =
                  compact ? 168.0 : math.min(310.0, constraints.maxWidth - 56);
              final padding = compact ? 16.0 : 40.0;
              // The mark sits in the middle of the room left above the
              // footer; a screen too short for both scrolls.
              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minWidth: constraints.maxWidth,
                    minHeight: constraints.maxHeight,
                  ),
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(28, 16, 28, padding),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const SizedBox.shrink(),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 480),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ExcludeSemantics(
                                child: RepaintBoundary(
                                  child: CustomPaint(
                                    size: Size(
                                      logoWidth,
                                      logoWidth *
                                          BirdyGoSingingPainter.viewBox.height /
                                          BirdyGoSingingPainter.viewBox.width,
                                    ),
                                    painter: BirdyGoSingingPainter(
                                      clock: _clock,
                                      // A startup error is no time to sing on.
                                      loop: widget.onRetry == null,
                                      still: _reduced,
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(height: compact ? 10 : 20),
                              _entrance(
                                at: BirdyGoSplashTimeline.wordmark,
                                child: _wordmark(context, l10n),
                              ),
                              SizedBox(height: compact ? 10 : 20),
                              _tagline(l10n),
                            ],
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.only(top: compact ? 16 : 32),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 480),
                            child:
                                widget.onRetry != null
                                    ? _error(l10n)
                                    : _loading(l10n, compact: compact),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
