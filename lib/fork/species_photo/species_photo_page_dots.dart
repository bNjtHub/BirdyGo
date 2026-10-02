/// Page dots on a small scrim, so they read on any photo (carousel and
/// full-screen viewer).
library;

import 'package:flutter/material.dart';

import '../design/birdy_tokens.dart';
import 'species_photo_config.dart';

class PhotoPageDots extends StatelessWidget {
  const PhotoPageDots({super.key, required this.count, required this.current});

  final int count;
  final int current;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: IgnorePointer(
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
                                : BirdyBrand.white.withValues(alpha: 0.5),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
