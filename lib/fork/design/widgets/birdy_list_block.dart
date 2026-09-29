/// A white block holding [BirdyListRow]s under a title (J6h): the title is a
/// [BirdyText.heading] with an optional trailing widget on its baseline, the
/// rows are separated by 1 px `line` dividers.
library;

import 'package:flutter/material.dart';

import '../birdy_tokens.dart';
import '../birdy_typography.dart';
import 'birdy_block.dart';

class BirdyListBlock extends StatelessWidget {
  const BirdyListBlock({
    super.key,
    this.title,
    this.trailing,
    this.color,
    required this.children,
  });

  final String? title;

  /// Right end of the title line (a count, a « Tout voir » link).
  final Widget? trailing;

  /// Fill of the block (Brume for the Plus sheet); white when null.
  final Color? color;

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final c = BirdyColors.of(context);
    return BirdyBlock(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                BirdySpace.l,
                BirdySpace.l,
                BirdySpace.l,
                BirdySpace.s,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Expanded(
                    child: Text(
                      title!,
                      style: BirdyText.heading.copyWith(color: c.text1),
                    ),
                  ),
                  if (trailing != null) trailing!,
                ],
              ),
            ),
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) Divider(height: 1, thickness: 1, color: c.line),
            children[i],
          ],
        ],
      ),
    );
  }
}
