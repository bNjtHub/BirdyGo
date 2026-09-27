import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/app_localizations.dart';
import '../design/birdy_tokens.dart';
import '../design/birdy_typography.dart';
import '../home/birdygo_logo.dart';

/// The same mark as Home, with one 480 ms wing drawing and a quiet dawn sky.
/// Supplying [onRetry] replaces the loading status with a recoverable error.
class BirdyGoSplash extends StatelessWidget {
  const BirdyGoSplash({super.key, this.onRetry});

  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarContrastEnforced: false,
      ),
      child: Scaffold(
        backgroundColor: BirdyBrand.ink,
        body: Stack(
          fit: StackFit.expand,
          children: [
            const RepaintBoundary(
              child: CustomPaint(painter: _DawnBackground()),
            ),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxHeight < 480;
                  return SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 28,
                            vertical: compact ? 20 : 40,
                          ),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 480),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ExcludeSemantics(
                                  child: BirdyGoLogo(size: compact ? 100 : 168),
                                ),
                                SizedBox(height: compact ? 8 : 18),
                                Text(
                                  l10n.appTitle,
                                  style: BirdyText.display.copyWith(
                                    color: BirdyBrand.mist,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 14),
                                Text(
                                  l10n.forkSplashTagline,
                                  style: BirdyText.body.copyWith(
                                    color: BirdyBrand.mist.withValues(
                                      alpha: .8,
                                    ),
                                    height: 1.5,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                SizedBox(height: compact ? 24 : 42),
                                if (onRetry == null)
                                  Semantics(
                                    liveRegion: true,
                                    label: l10n.forkSplashLoading,
                                    child: ExcludeSemantics(
                                      child: Column(
                                        children: [
                                          const _LoadingMark(),
                                          const SizedBox(height: 14),
                                          Text(
                                            l10n.forkSplashLoading,
                                            style: BirdyText.caption.copyWith(
                                              color: BirdyBrand.mist.withValues(
                                                alpha: .65,
                                              ),
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                else ...[
                                  Semantics(
                                    liveRegion: true,
                                    child: Text(
                                      l10n.forkSplashError,
                                      style: BirdyText.bodyCompact.copyWith(
                                        color: BirdyBrand.mist,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  FilledButton(
                                    onPressed: onRetry,
                                    child: Text(l10n.retry),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Static after the logo animation, including during a slow startup.
class _LoadingMark extends StatelessWidget {
  const _LoadingMark();

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (final height in [4.0, 10.0, 16.0, 8.0, 4.0])
        Container(
          width: 3,
          height: height,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(
            color: BirdyBrand.kingfisher.withValues(alpha: .75),
            borderRadius: BorderRadius.circular(3),
          ),
        ),
    ],
  );
}

class _DawnBackground extends CustomPainter {
  const _DawnBackground();

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    canvas.drawRect(bounds, Paint()..color = BirdyBrand.ink);
    for (final (center, color, radius) in [
      (const Alignment(.9, -.8), BirdyBrand.kingfisher, 1.1),
      (const Alignment(-1, .9), BirdyBrand.oriole, .9),
    ]) {
      canvas.drawRect(
        bounds,
        Paint()
          ..shader = RadialGradient(
            center: center,
            radius: radius,
            colors: [color.withValues(alpha: .13), color.withValues(alpha: 0)],
          ).createShader(bounds),
      );
    }

    // A few stationary listening contours; no particles or continuous work.
    final center = Offset(size.width * .52, size.height * .42);
    final unit = size.shortestSide;
    for (final radius in [.58, .82, 1.08]) {
      canvas.drawCircle(
        center,
        unit * radius,
        Paint()
          ..color = BirdyBrand.mist.withValues(alpha: .035)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    }
  }

  @override
  bool shouldRepaint(_DawnBackground oldDelegate) => false;
}
