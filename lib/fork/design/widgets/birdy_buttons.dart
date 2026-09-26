/// Buttons of BirdyGo (J6a, SPEC.md 5.1).
///
/// Material buttons take their shape and size from the theme; these styles
/// add the BirdyGo colors, which the theme cannot give without also
/// recoloring `FilledButton.tonal`. Wrap buttons in [Pressable] for the
/// 0.97 press feedback.
library;

import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

import '../../../shared/utils/app_icons.dart';
import '../birdy_tokens.dart';
import '../birdy_typography.dart';
import 'pressable.dart';

abstract final class BirdyButtonStyles {
  /// Main action: Martin-pêcheur fill, Encre text, 56 px.
  static ButtonStyle primary(BuildContext context) {
    final c = BirdyColors.of(context);
    return FilledButton.styleFrom(
      backgroundColor: c.accent,
      foregroundColor: c.onAccent,
      minimumSize: const Size(64, BirdySizes.mainAction),
      padding: const EdgeInsets.symmetric(horizontal: BirdySpace.xxl),
      shape: const StadiumBorder(),
      textStyle: BirdyText.label,
      iconSize: 22,
    );
  }

  /// Secondary action: white (light) or transparent (dark), outlined, 56 px.
  static ButtonStyle secondary(BuildContext context) {
    final c = BirdyColors.of(context);
    return OutlinedButton.styleFrom(
      backgroundColor: c.isDark ? Colors.transparent : c.surface1,
      foregroundColor: c.text1,
      minimumSize: const Size(64, BirdySizes.mainAction),
      padding: const EdgeInsets.symmetric(horizontal: 22),
      shape: const StadiumBorder(),
      side: BorderSide(color: c.borderStrong, width: 1.5),
      textStyle: BirdyText.label,
      iconSize: 22,
    );
  }

  /// Inline action (« Chant de référence »): tonal, 48 px.
  static ButtonStyle tonal(BuildContext context) {
    final c = BirdyColors.of(context);
    return FilledButton.styleFrom(
      backgroundColor: c.tonal,
      foregroundColor: c.accentText,
      minimumSize: const Size(64, BirdySizes.target),
      padding: const EdgeInsets.symmetric(horizontal: 18),
      shape: const StadiumBorder(),
      textStyle: BirdyText.labelCompact,
      iconSize: 20,
    );
  }

  /// « Arrêter » in the live control bar: Brume fill, Encre text, 64 px.
  static ButtonStyle stop(BuildContext context) => FilledButton.styleFrom(
    backgroundColor: BirdyBrand.mist,
    foregroundColor: BirdyBrand.ink,
    minimumSize: const Size(64, BirdySizes.liveControl),
    shape: const StadiumBorder(),
    textStyle: BirdyText.label,
    iconSize: 22,
  );

  /// « Pause » / « Reprendre » in the live control bar: outlined, 64 px.
  static ButtonStyle pause(BuildContext context) {
    final c = BirdyColors.of(context);
    return OutlinedButton.styleFrom(
      foregroundColor: c.text1,
      minimumSize: const Size(64, BirdySizes.liveControl),
      shape: const StadiumBorder(),
      side: BorderSide(color: c.borderStrong, width: 1.5),
      textStyle: BirdyText.label,
      iconSize: 22,
    );
  }
}

/// The big « Écouter » button of the home screen: 72 px, full width.
class ListenButton extends StatelessWidget {
  const ListenButton({super.key, required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
    return Pressable(
      enabled: onPressed != null,
      child: DecoratedBox(
        decoration: ShapeDecoration(
          shape: const StadiumBorder(),
          shadows: onPressed == null ? null : c.ctaGlow,
        ),
        child: FilledButton.icon(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: c.accent,
            foregroundColor: c.onAccent,
            minimumSize: const Size.fromHeight(BirdySizes.listen),
            shape: const StadiumBorder(),
            textStyle: BirdyText.label.copyWith(fontSize: 20),
            iconSize: 28,
          ),
          icon: const Icon(AppIcons.graphicEq),
          label: Text(l10n.forkListen),
        ),
      ),
    );
  }
}

/// Round 48 px icon button. The label is required: it is read by screen
/// readers and shown as tooltip.
class BirdyIconButton extends StatelessWidget {
  const BirdyIconButton({
    super.key,
    required this.icon,
    required this.semanticLabel,
    required this.onPressed,
  });

  final IconData icon;
  final String semanticLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final c = BirdyColors.of(context);
    return Pressable(
      enabled: onPressed != null,
      child: IconButton(
        onPressed: onPressed,
        tooltip: semanticLabel,
        icon: Icon(icon),
        style: IconButton.styleFrom(
          fixedSize: const Size.square(BirdySizes.target),
          backgroundColor: c.isDark ? c.line : c.surface1,
          foregroundColor: c.text1,
          side: BorderSide(color: c.isDark ? c.border : c.line),
        ),
      ),
    );
  }
}
