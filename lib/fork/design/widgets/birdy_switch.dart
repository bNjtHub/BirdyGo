/// Track-and-knob switch (44 × 28 dp track, 22 dp knob), the same look as
/// the quiz's "Avec son" switch (`QuizSoundSwitch`, `quiz_intro.dart`) but
/// without its icon and label, so any screen can pair it with its own text
/// (fork/PLAN.md J6f-f, `AppPalmares` mockup).
library;

import 'package:flutter/material.dart';

import '../birdy_motion.dart';
import '../birdy_tokens.dart';

/// A single on/off track. Callers add the row, the label and the
/// [Semantics] that describe what it toggles.
class BirdySwitch extends StatelessWidget {
  const BirdySwitch({super.key, required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = BirdyColors.of(context);
    final reduced = BirdyMotion.reduced(context);
    final duration = reduced ? Duration.zero : BirdyMotion.enter;
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: duration,
        curve: BirdyMotion.standard,
        width: BirdyGlyph.disc44,
        height: BirdyGlyph.x5l,
        padding: const EdgeInsets.all(BirdySpace.thin),
        decoration: BoxDecoration(
          color: value ? c.accent : c.border,
          borderRadius: BorderRadius.circular(BirdyRadii.pill),
        ),
        child: AnimatedAlign(
          duration: duration,
          curve: BirdyMotion.standard,
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: const DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: BirdyQuizColors.knob,
              boxShadow: [
                BoxShadow(
                  color: BirdyQuizColors.knobShadow,
                  offset: Offset(0, 1),
                  blurRadius: BirdyBlur.s,
                ),
              ],
            ),
            child: SizedBox(width: BirdySizes.switchKnob, height: BirdySizes.switchKnob),
          ),
        ),
      ),
    );
  }
}
