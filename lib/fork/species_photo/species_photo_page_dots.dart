/// Page dots on a small scrim, so they read on any photo (carousel and
/// full-screen viewer). In the carousel, a tiny spinner follows the dots
/// while more photos are being fetched.
library;

import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

import '../design/birdy_motion.dart';
import '../design/birdy_tokens.dart';
import 'species_photo_config.dart';

class PhotoPageDots extends StatelessWidget {
  const PhotoPageDots({
    super.key,
    required this.count,
    required this.current,
    this.loading = false,
  });

  final int count;
  final int current;

  /// More photos are being fetched: the spinner follows the dots (or stands
  /// alone while the bundled photo is the only one).
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Center(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: BirdyBrand.black.withValues(
              alpha: BirdyAlpha.photoButtonScrim,
            ),
            borderRadius: BorderRadius.circular(BirdyRadii.hero),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: BirdySpace.s,
              vertical: BirdySpace.xs + BirdySpace.xxs,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (count > 1)
                  ExcludeSemantics(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (var i = 0; i < count; i++)
                          Container(
                            key: ValueKey('photo-dot-$i'),
                            width: kCarouselDotSize,
                            height: kCarouselDotSize,
                            margin: EdgeInsets.only(
                              left: i == 0 ? 0 : kCarouselDotGap,
                            ),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color:
                                  i == current
                                      ? BirdyBrand.white
                                      : BirdyBrand.white.withValues(
                                        alpha: kCarouselDimAlpha,
                                      ),
                            ),
                          ),
                      ],
                    ),
                  ),
                if (loading) _Loader(hasDots: count > 1),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Loader extends StatelessWidget {
  const _Loader({required this.hasDots});

  final bool hasDots;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Semantics(
      label: l10n.forkPhotoLoading,
      child: Padding(
        key: const ValueKey('photo-loader'),
        padding: EdgeInsets.only(left: hasDots ? kCarouselDotGap : 0),
        child: SizedBox.square(
          dimension: kCarouselLoaderSize,
          child: CircularProgressIndicator(
            strokeWidth: kCarouselLoaderStroke,
            color: BirdyBrand.white.withValues(alpha: kCarouselDimAlpha),
            // Static ring with reduced motion.
            value:
                BirdyMotion.reduced(context)
                    ? kCarouselLoaderStaticProgress
                    : null,
          ),
        ),
      ),
    );
  }
}
