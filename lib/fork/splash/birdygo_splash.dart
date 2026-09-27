import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/app_localizations.dart';
import '../design/birdy_motion.dart';
import '../design/birdy_tokens.dart';
import '../design/birdy_typography.dart';
import 'birdygo_splash_painter.dart';

/// The supplied startup design, with three staggered musical notes.
/// Initialization and launch routing run alongside this one-shot introduction.
class BirdyGoSplash extends StatefulWidget {
  const BirdyGoSplash({super.key, this.onRetry, this.onIntroComplete});

  static const introDuration = Duration(milliseconds: 2400);

  final VoidCallback? onRetry;
  final VoidCallback? onIntroComplete;

  @override
  State<BirdyGoSplash> createState() => _BirdyGoSplashState();
}

class _BirdyGoSplashState extends State<BirdyGoSplash>
    with SingleTickerProviderStateMixin {
  late final _intro = AnimationController(
    vsync: this,
    duration: BirdyGoSplash.introDuration,
  )..addStatusListener(_onStatus);
  bool _started = false;
  bool _reported = false;
  bool _reduced = false;

  void _onStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || _reported) return;
    _reported = true;
    // Also safe when reduced motion completes during didChangeDependencies.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onIntroComplete?.call();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = BirdyMotion.reduced(context);
    if (_reduced) {
      _intro.value = 1;
    } else if (!_started) {
      _intro.forward();
    }
    _started = true;
  }

  @override
  void dispose() {
    _intro.dispose();
    super.dispose();
  }

  Widget _entrance({required Widget child, double delay = 0}) =>
      AnimatedBuilder(
        animation: _intro,
        child: child,
        builder: (context, child) {
          final elapsed =
              _intro.value * BirdyGoSplash.introDuration.inMilliseconds;
          final t = BirdyMotion.standard.transform(
            ((elapsed - delay) / 250).clamp(0.0, 1.0),
          );
          return Opacity(
            opacity: t,
            child: Transform.translate(
              offset: Offset(0, _reduced ? 0 : 8 * (1 - t)),
              child: child,
            ),
          );
        },
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
              final logoWidth = compact ? 168.0 : 270.0;
              final padding = compact ? 16.0 : 40.0;
              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minWidth: constraints.maxWidth,
                    minHeight: constraints.maxHeight,
                  ),
                  child: IntrinsicHeight(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(28, 16, 28, padding),
                      child: Column(
                        children: [
                          const Spacer(),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 480),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _entrance(
                                  child: ExcludeSemantics(
                                    child: RepaintBoundary(
                                      child: CustomPaint(
                                        size: Size(
                                          logoWidth,
                                          logoWidth * 368 / 530,
                                        ),
                                        painter: BirdyGoSplashPainter(
                                          progress: _intro,
                                          reducedMotion: _reduced,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(height: compact ? 10 : 20),
                                _entrance(
                                  delay: 60,
                                  child: Text(
                                    l10n.appTitle,
                                    style: BirdyText.display.copyWith(
                                      fontSize: 40,
                                      height: 1.1,
                                      letterSpacing: -.5,
                                      color: BirdyBrand.ink,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                SizedBox(height: compact ? 10 : 20),
                                _entrance(
                                  delay: 120,
                                  child: Text(
                                    l10n.forkSplashTagline,
                                    style: BirdyText.body.copyWith(
                                      color: BirdyBrand.bark,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          SizedBox(height: compact ? 16 : 32),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 480),
                            child:
                                widget.onRetry != null
                                    ? Column(
                                      children: [
                                        Semantics(
                                          liveRegion: true,
                                          child: Text(
                                            l10n.forkSplashError,
                                            style: BirdyText.bodyCompact
                                                .copyWith(
                                                  color: BirdyBrand.ink,
                                                ),
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        FilledButton(
                                          onPressed: widget.onRetry,
                                          child: Text(l10n.retry),
                                        ),
                                      ],
                                    )
                                    : _entrance(
                                      delay: 120,
                                      child: Semantics(
                                        liveRegion: true,
                                        label: l10n.forkSplashLoading,
                                        child: ExcludeSemantics(
                                          child: Column(
                                            children: [
                                              RepaintBoundary(
                                                child: CustomPaint(
                                                  size: const Size(180, 4),
                                                  painter:
                                                      BirdyGoLoadingPainter(
                                                        progress: _intro,
                                                      ),
                                                ),
                                              ),
                                              const SizedBox(height: 14),
                                              Text(
                                                l10n.forkSplashLoading,
                                                style: BirdyText.caption
                                                    .copyWith(
                                                      fontSize: 14,
                                                      color: BirdyBrand.bark,
                                                    ),
                                                textAlign: TextAlign.center,
                                              ),
                                              SizedBox(
                                                height: compact ? 8 : 24,
                                              ),
                                              Text(
                                                l10n.forkPoweredByBirdnet,
                                                style: BirdyText.caption
                                                    .copyWith(
                                                      color: BirdyBrand.bark,
                                                    ),
                                                textAlign: TextAlign.center,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                          ),
                        ],
                      ),
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
