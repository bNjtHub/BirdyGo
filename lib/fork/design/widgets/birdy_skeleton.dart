/// Loading skeletons (fix/j6f-b-notebook-loading): placeholders that reserve
/// exactly the size the real content will take, so a screen's layout never
/// shifts once data arrives. DESIGN.md forbids animation loops (no shimmer
/// sweep, no repeating pulse), so a skeleton is a plain static fill; it does
/// not need a reduced-motion branch because it never animates.
library;

import 'package:flutter/material.dart';

import '../birdy_tokens.dart';

abstract final class BirdySkeleton {
  /// A muted bar the height and alphabetic baseline of [style]'s text, so it
  /// drops into a `CrossAxisAlignment.baseline` [Row] exactly like the real
  /// text would (it *is* a [Text], just with invisible glyphs and a filled
  /// background instead of readable content).
  ///
  /// [placeholder] should be the real string the final text will show (its
  /// characters never show, but its length decides how many lines this
  /// wraps to, so pass the localized sentence, not a generic filler, or a
  /// caption that wraps in the real state would come out shorter here and
  /// the block would still resize once the real text replaces it).
  /// [maxLines] null lets it wrap like the real text; `1` (the default) is
  /// for a line that never wraps (a number, a static label).
  static Widget text(
    TextStyle style, {
    Key? key,
    String placeholder = '00000000000000000000',
    int? maxLines = 1,
  }) => _SkeletonText(
    key: key,
    style: style,
    placeholder: placeholder,
    maxLines: maxLines,
  );

  /// A muted rounded box of exactly [width] × [height] (a card, a visual).
  static Widget box({
    Key? key,
    required double width,
    required double height,
    double radius = BirdyRadii.thumb,
  }) => _SkeletonBox(key: key, width: width, height: height, radius: radius);
}

class _SkeletonText extends StatelessWidget {
  const _SkeletonText({
    super.key,
    required this.style,
    required this.placeholder,
    required this.maxLines,
  });

  final TextStyle style;
  final String placeholder;
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    final c = BirdyColors.of(context);
    return ExcludeSemantics(
      child: Text(
        placeholder,
        maxLines: maxLines,
        softWrap: maxLines != 1,
        overflow: maxLines == 1 ? TextOverflow.clip : TextOverflow.visible,
        style: style.copyWith(
          color: Colors.transparent,
          backgroundColor: c.skeleton,
        ),
      ),
    );
  }
}

class _SkeletonBox extends StatelessWidget {
  const _SkeletonBox({
    super.key,
    required this.width,
    required this.height,
    required this.radius,
  });

  final double width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final c = BirdyColors.of(context);
    return ExcludeSemantics(
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: c.skeleton,
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }
}
