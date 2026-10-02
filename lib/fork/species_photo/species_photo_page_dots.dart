/// Page dots on a small scrim, so they read on any photo (carousel and
/// full-screen viewer). In the carousel, while more photos are being
/// fetched, the same pill holds pulsing "pending" dots; they cross-fade to
/// the page dots when the photos are revealed. The pill height never changes.
library;

import 'dart:math' as math;

import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

import '../design/birdy_motion.dart';
import '../design/birdy_tokens.dart';
import 'species_photo_config.dart';

/// Height of the pill, pending or not.
const double kPhotoPillHeight =
    kCarouselDotSize + 2 * (BirdySpace.xs + BirdySpace.xxs);

class PhotoPageDots extends StatelessWidget {
  const PhotoPageDots({
    super.key,
    required this.count,
    required this.current,
    this.pending = false,
  });

  final int count;
  final int current;

  /// More photos are being fetched: the pulsing dots stand in for the page
  /// dots.
  final bool pending;

  @override
  Widget build(BuildContext context) {
    final reduced = BirdyMotion.reduced(context);
    final content = SizedBox(
      key: const ValueKey('photo-pill'),
      height: kPhotoPillHeight,
      child: AnimatedSwitcher(
        duration: BirdyMotion.enter,
        switchInCurve: BirdyMotion.standard,
        layoutBuilder:
            (currentChild, previous) => Stack(
              alignment: Alignment.center,
              children: [
                // The outgoing content must not size the pill.
                for (final old in previous)
                  Positioned.fill(
                    child: OverflowBox(maxWidth: double.infinity, child: old),
                  ),
                if (currentChild != null) currentChild,
              ],
            ),
        child:
            pending
                ? const _PendingDots(key: ValueKey('photo-loader'))
                : _Dots(
                  key: const ValueKey('photo-dots-row'),
                  count: count,
                  current: current,
                ),
      ),
    );
    return IgnorePointer(
      child: Center(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: BirdyBrand.black.withValues(
              alpha: BirdyAlpha.photoButtonScrim,
            ),
            borderRadius: BorderRadius.circular(BirdyRadii.hero),
          ),
          // The width follows the content; the height is fixed. With reduced
          // motion the width snaps (AnimatedSize rejects a zero duration) and
          // only the fade stays.
          child:
              reduced
                  ? content
                  : AnimatedSize(
                    duration: BirdyMotion.enter,
                    curve: BirdyMotion.standard,
                    child: content,
                  ),
        ),
      ),
    );
  }
}

class _PillContent extends StatelessWidget {
  const _PillContent({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: BirdySpace.s),
    child: Center(
      widthFactor: 1,
      child: Row(mainAxisSize: MainAxisSize.min, children: children),
    ),
  );
}

class _Dots extends StatelessWidget {
  const _Dots({super.key, required this.count, required this.current});

  final int count;
  final int current;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: _PillContent(
        children: [
          for (var i = 0; i < count; i++)
            _Dot(
              key: ValueKey('photo-dot-$i'),
              gapBefore: i == 0 ? 0 : kCarouselDotGap,
              alpha: i == current ? 1 : kCarouselDimAlpha,
            ),
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({super.key, required this.gapBefore, required this.alpha});

  final double gapBefore;
  final double alpha;

  @override
  Widget build(BuildContext context) => Container(
    width: kCarouselDotSize,
    height: kCarouselDotSize,
    margin: EdgeInsets.only(left: gapBefore),
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: BirdyBrand.white.withValues(alpha: alpha),
    ),
  );
}

/// Dots pulsing in sequence. Static at rest opacity with reduced motion.
class _PendingDots extends StatefulWidget {
  const _PendingDots({super.key});

  @override
  State<_PendingDots> createState() => _PendingDotsState();
}

class _PendingDotsState extends State<_PendingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: kCarouselPendingPeriod,
  );
  bool _running = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduced = BirdyMotion.reduced(context);
    if (reduced && _running) {
      _clock.stop();
      _running = false;
    } else if (!reduced && !_running) {
      _clock.repeat();
      _running = true;
    }
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  /// Opacity of dot `i`: a smooth bump from the rest opacity to full and back
  /// once per cycle, each dot a little later than the previous one.
  double _alpha(int i) {
    if (!_running) return kCarouselDimAlpha;
    final phase = (_clock.value - i * kCarouselPendingStagger) % 1.0;
    final bump = math.sin(math.pi * phase);
    return kCarouselDimAlpha + (1 - kCarouselDimAlpha) * bump;
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: AppLocalizations.of(context)!.forkPhotoLoading,
      child: ExcludeSemantics(
        child: AnimatedBuilder(
          animation: _clock,
          builder:
              (context, _) => _PillContent(
                children: [
                  for (var i = 0; i < kCarouselPendingDots; i++)
                    _Dot(
                      key: ValueKey('photo-pending-dot-$i'),
                      gapBefore: i == 0 ? 0 : kCarouselDotGap,
                      alpha: _alpha(i),
                    ),
                ],
              ),
        ),
      ),
    );
  }
}
