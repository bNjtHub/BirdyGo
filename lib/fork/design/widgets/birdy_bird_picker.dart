/// « Choisis ton oiseau » (J6i): the 2 × 2 grid of bird cards and the
/// « Ton icône sur le téléphone » box under it. Shared by the onboarding's
/// step 2 and the Settings « Mon oiseau » screen, which only differ by what
/// surrounds it.
///
/// A card is a white block with the bird's tonal disc and logo, its name and
/// three colour dots; the chosen one gets a 3 dp ring of its accent and a
/// check. The picker holds no state: the caller passes [selected] and saves
/// the choice in [onPick] (both screens set `birdyBirdProvider`, so the whole
/// app previews the bird at once).
library;

import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

import '../../../shared/utils/app_icons.dart';
import '../../game/quiz_fx.dart' show QuizPop;
import '../../home/birdygo_logo.dart';
import '../birdy_motion.dart';
import '../birdy_theme_choice.dart';
import '../birdy_tokens.dart';
import '../birdy_typography.dart';
import 'birdy_block.dart';
import 'pressable.dart';
import 'singing_theme_logo.dart';

/// Localized texts of a bird theme.
extension BirdyBirdLabels on BirdyBird {
  String label(AppLocalizations l10n) => switch (this) {
    BirdyBird.loriot => l10n.forkThemeLoriot,
    BirdyBird.martin => l10n.forkThemeMartin,
    BirdyBird.flamant => l10n.forkThemeFlamant,
    BirdyBird.etourneau => l10n.forkThemeEtourneau,
  };

  /// Plural, lower case: « chez les loriots ».
  String plural(AppLocalizations l10n) => switch (this) {
    BirdyBird.loriot => l10n.forkThemeLoriotPlural,
    BirdyBird.martin => l10n.forkThemeMartinPlural,
    BirdyBird.flamant => l10n.forkThemeFlamantPlural,
    BirdyBird.etourneau => l10n.forkThemeEtourneauPlural,
  };

  String fact(AppLocalizations l10n) => switch (this) {
    BirdyBird.loriot => l10n.forkThemeFactLoriot,
    BirdyBird.martin => l10n.forkThemeFactMartin,
    BirdyBird.flamant => l10n.forkThemeFactFlamant,
    BirdyBird.etourneau => l10n.forkThemeFactEtourneau,
  };
}

class BirdyBirdPicker extends StatelessWidget {
  const BirdyBirdPicker({
    super.key,
    required this.selected,
    required this.onPick,
  });

  final BirdyBird selected;
  final ValueChanged<BirdyBird> onPick;

  static const List<BirdyBird> _order = BirdyBird.values;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var row = 0; row < _order.length; row += 2) ...[
          if (row > 0) const SizedBox(height: BirdySpace.m),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = row; i < row + 2 && i < _order.length; i++) ...[
                  if (i > row) const SizedBox(width: BirdySpace.m),
                  Expanded(
                    child: BirdyBirdCard(
                      bird: _order[i],
                      selected: _order[i] == selected,
                      onTap: () => onPick(_order[i]),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
        const SizedBox(height: BirdySpace.l),
        BirdyIconPreview(bird: selected),
      ],
    );
  }
}

class BirdyBirdCard extends StatelessWidget {
  const BirdyBirdCard({
    super.key,
    required this.bird,
    required this.selected,
    required this.onTap,
  });

  final BirdyBird bird;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
    final brightness = Theme.of(context).brightness;
    final brand = BirdyBrandColors(bird, brightness);
    final reduced = BirdyMotion.reduced(context);
    return Semantics(
      button: true,
      selected: selected,
      label: bird.label(l10n),
      excludeSemantics: true,
      onTap: onTap,
      child: Pressable(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: AnimatedContainer(
            duration: reduced ? Duration.zero : BirdyMotion.enter,
            curve: BirdyMotion.standard,
            padding: const EdgeInsets.all(BirdySpace.m),
            decoration: BoxDecoration(
              color: c.surface1,
              borderRadius: BorderRadius.circular(BirdyRadii.card),
              border: Border.all(
                color: selected ? brand.accent : Colors.transparent,
                width: BirdySizes.themeRing,
              ),
            ),
            child: Stack(
              children: [
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SingingThemeLogo(
                        bird: bird,
                        size: BirdySizes.themeCardDisc,
                        markWidth: BirdySizes.themeCardMark,
                        halo: false,
                        sings: false,
                      ),
                      const SizedBox(height: BirdySpace.s),
                      Text(
                        bird.label(l10n),
                        textAlign: TextAlign.center,
                        style: BirdyText.heading.copyWith(
                          fontSize: 17,
                          color: c.text1,
                        ),
                      ),
                      const SizedBox(height: BirdySpace.s),
                      _Dots(brand: brand),
                    ],
                  ),
                ),
                PositionedDirectional(
                  top: 0,
                  end: 0,
                  child: AnimatedOpacity(
                    duration: reduced ? Duration.zero : BirdyMotion.exit,
                    opacity: selected ? 1 : 0,
                    child: Container(
                      key: ValueKey('bird-check-${bird.name}'),
                      width: BirdySizes.themeCheck,
                      height: BirdySizes.themeCheck,
                      decoration: BoxDecoration(
                        color: brand.accent,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        AppIcons.check,
                        size: 16,
                        weight: 700,
                        color: BirdyBrand.ink,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The bird's three colours: accent, highlight and tonal.
class _Dots extends StatelessWidget {
  const _Dots({required this.brand});

  final BirdyBrandColors brand;

  @override
  Widget build(BuildContext context) {
    final c = BirdyColors.of(context);
    Widget dot(Color color, {bool outlined = false}) => Container(
      width: BirdySizes.themeDot,
      height: BirdySizes.themeDot,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: outlined ? Border.all(color: c.line) : null,
      ),
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: BirdySpace.xs,
      children: [
        dot(brand.accent),
        dot(brand.highlight),
        dot(brand.tonal, outlined: true),
      ],
    );
  }
}

/// « Ton icône sur le téléphone »: the launcher icon of [bird] (its logo on
/// the tonal → white gradient, the same as the icon of PR 4) and the bird's
/// fun fact.
class BirdyIconPreview extends StatelessWidget {
  const BirdyIconPreview({super.key, required this.bird});

  final BirdyBird bird;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
    // The launcher icon does not follow the dark mode.
    final brand = BirdyBrandColors(bird, Brightness.light);
    return BirdyBlock(
      key: const ValueKey('bird-icon-preview'),
      padding: const EdgeInsets.symmetric(
        horizontal: BirdySpace.l,
        vertical: BirdySpace.m,
      ),
      child: Row(
        children: [
          QuizPop(
            key: ValueKey(bird),
            duration: BirdyMotion.enter,
            child: Container(
              width: BirdySizes.iconPreview,
              height: BirdySizes.iconPreview,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(
                  BirdySizes.iconPreviewRadius,
                ),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [brand.tonal, BirdyColors.light.surface1],
                ),
                border: Border.all(color: c.line),
              ),
              child: ExcludeSemantics(
                child: CustomPaint(
                  size: const Size.square(BirdySizes.iconPreviewMark),
                  painter: BirdyGoLogoPainter(
                    progress: kAlwaysCompleteAnimation,
                    brand: brand,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: BirdySpace.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.forkOnbIconLabel,
                  style: BirdyText.caption.copyWith(
                    fontWeight: FontWeight.w700,
                    color: c.text2,
                  ),
                ),
                const SizedBox(height: BirdySpace.xs),
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: bird.label(l10n),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      TextSpan(text: ' · ${bird.fact(l10n)}'),
                    ],
                  ),
                  style: BirdyText.bodyCompact.copyWith(color: c.text1),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
