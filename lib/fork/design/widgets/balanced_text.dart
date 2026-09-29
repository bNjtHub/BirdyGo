/// Text that wraps on balanced lines (J6h): flutter has no `text-wrap:
/// balance`, so this keeps the number of lines the full width gives and
/// narrows the box to the smallest width that still gives that number.
/// « Rouge-gorge / familier » rather than « Rouge-gorge familier » cut at
/// its last word. A single line is left alone.
library;

import 'package:flutter/widgets.dart';

class BalancedText extends StatelessWidget {
  const BalancedText(
    this.data, {
    super.key,
    this.style,
    this.textAlign = TextAlign.center,
  });

  final String data;
  final TextStyle? style;
  final TextAlign textAlign;

  /// Smallest width, at most [maxWidth], that keeps the number of lines
  /// [data] takes at [maxWidth].
  static double balancedWidth(
    String data, {
    required TextStyle style,
    required double maxWidth,
    TextScaler textScaler = TextScaler.noScaling,
    TextDirection textDirection = TextDirection.ltr,
    TextAlign textAlign = TextAlign.center,
  }) {
    int lines(double width) {
      final painter = TextPainter(
        text: TextSpan(text: data, style: style),
        textDirection: textDirection,
        textScaler: textScaler,
        textAlign: textAlign,
      )..layout(maxWidth: width);
      final count = painter.computeLineMetrics().length;
      painter.dispose();
      return count;
    }

    final target = lines(maxWidth);
    if (target <= 1) return maxWidth;
    var low = 0.0;
    var high = maxWidth;
    // Half a pixel is far below what the eye sees.
    while (high - low > 0.5) {
      final mid = (low + high) / 2;
      if (lines(mid) <= target) {
        high = mid;
      } else {
        low = mid;
      }
    }
    // One more pixel of margin against rounding in the real layout.
    return (high + 1).clamp(0, maxWidth).toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final resolved = DefaultTextStyle.of(context).style.merge(style);
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final text = Text(data, textAlign: textAlign, style: style);
        if (!constraints.hasBoundedWidth) return text;
        return SizedBox(
          width: balancedWidth(
            data,
            style: resolved,
            maxWidth: constraints.maxWidth,
            textScaler: scaler,
            textDirection: direction,
            textAlign: textAlign,
          ),
          child: text,
        );
      },
    );
  }
}
