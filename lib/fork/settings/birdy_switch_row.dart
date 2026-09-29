/// A settings row with a [BirdySwitch] (J6g-c): title, optional hint, the
/// whole row one 48 dp target announced as a toggle.
library;

import 'package:flutter/material.dart';

import '../design/birdy_tokens.dart';
import '../design/birdy_typography.dart';
import '../design/widgets/birdy_switch.dart';

class BirdySwitchRow extends StatelessWidget {
  const BirdySwitchRow({
    super.key,
    required this.title,
    this.hint,
    this.icon,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String? hint;

  /// Icon of a leading tinted disc (J6h); none keeps the plain row.
  final IconData? icon;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = BirdyColors.of(context);
    return Semantics(
      container: true,
      toggled: value,
      label: title,
      hint: hint,
      onTap: () => onChanged(!value),
      excludeSemantics: true,
      child: InkWell(
        onTap: () => onChanged(!value),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: BirdySizes.row),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: BirdySpace.l,
              vertical: BirdySpace.s,
            ),
            child: Row(
              children: [
                if (icon != null) ...[
                  Container(
                    width: BirdySizes.rowDisc,
                    height: BirdySizes.rowDisc,
                    decoration: BoxDecoration(
                      color: c.tonal,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, size: 22, color: c.accentText, fill: 1),
                  ),
                  const SizedBox(width: BirdySpace.m),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: BirdyText.body.copyWith(
                          color: c.text1,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (hint != null)
                        Text(
                          hint!,
                          style: BirdyText.caption.copyWith(color: c.text2),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: BirdySpace.m),
                // The row is the target; the switch only shows the state.
                IgnorePointer(
                  child: BirdySwitch(value: value, onChanged: onChanged),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
