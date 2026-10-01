/// Bottom bar of BirdyGo (J6j): Accueil, Carnet, « Écouter », Carte, Profil.
///
/// « Écouter » is a round disc in the middle that overhangs the bar's top
/// edge by [BirdySizes.listenDiscLift]. Material's `NavigationBar` cannot
/// host a slot taller than its own height, so the bar is drawn here, with the
/// four tabs looking like `NavigationBar` under the theme (indicator pill,
/// label and icon styles come from `NavigationBarTheme`, no animation).
///
/// The bar's box is taller than its surface: the surface and its top line
/// cover only the bottom [BirdySizes.navBar] (plus the safe inset), and the
/// strip above them takes no touch except on the disc, so the page behind
/// stays usable there.
library;

import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/live/live_controller.dart';
import '../../features/live/live_providers.dart';
import '../../shared/utils/app_icons.dart';
import '../design/birdy_motion.dart';
import '../design/birdy_tokens.dart';
import '../design/birdy_typography.dart';
import '../design/widgets/birdy_wing_icon.dart';
import '../design/widgets/pressable.dart';
import 'fork_shell.dart';

class ForkNavBar extends StatelessWidget {
  const ForkNavBar({
    super.key,
    required this.selected,
    required this.onSelect,
    required this.onListen,
  });

  final ForkTab selected;
  final ValueChanged<ForkTab> onSelect;

  /// Tap on the « Écouter » disc; it never changes the selected tab.
  final VoidCallback onListen;

  /// Height of the bar's box without the safe inset: the surface and the
  /// disc's overhang.
  static const double boxHeight = BirdySizes.navBar + BirdySizes.listenDiscLift;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
    final inset = MediaQuery.paddingOf(context).bottom;
    Widget tab(ForkTab t, IconData icon, String label) => Expanded(
      child: _NavTab(
        icon: icon,
        label: label,
        selected: selected == t,
        onTap: () => onSelect(t),
      ),
    );
    return SizedBox(
      height: boxHeight + inset,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: BirdySizes.navBar + inset,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: c.surface1,
                border: Border(top: BorderSide(color: c.line)),
              ),
            ),
          ),
          Positioned.fill(
            bottom: inset,
            child: Semantics(
              container: true,
              label: l10n.forkNavLabel,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  tab(ForkTab.home, AppIcons.home, l10n.forkNavHome),
                  tab(
                    ForkTab.notebook,
                    AppIcons.menuBook,
                    l10n.forkNavNotebook,
                  ),
                  Expanded(child: _ListenSlot(onTap: onListen)),
                  tab(ForkTab.map, AppIcons.mapSheet, l10n.forkMap),
                  tab(
                    ForkTab.profile,
                    AppIcons.personOutline,
                    l10n.forkNavProfile,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One of the four tabs, drawn like a `NavigationDestination`.
class _NavTab extends StatelessWidget {
  const _NavTab({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  /// Indicator pill of a selected tab.
  static const Size _pill = Size(64, 32);

  @override
  Widget build(BuildContext context) {
    final theme = NavigationBarTheme.of(context);
    final states = {if (selected) WidgetState.selected};
    final iconTheme = theme.iconTheme?.resolve(states);
    final labelStyle = theme.labelTextStyle?.resolve(states);
    return Semantics(
      container: true,
      selected: selected,
      button: true,
      label: label,
      onTap: onTap,
      child: ExcludeSemantics(
        // Only the bar's own part takes the touch, not the strip above it.
        child: Padding(
          padding: const EdgeInsets.only(top: BirdySizes.listenDiscLift),
          // A press scale like the listen disc, no ink: an ink splash over
          // the whole tab drew a grey oval across the pill and the label.
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: Pressable(
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: BirdySizes.target),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox.fromSize(
                      size: _pill,
                      child: DecoratedBox(
                        decoration: ShapeDecoration(
                          color: selected ? theme.indicatorColor : null,
                          shape: const StadiumBorder(),
                        ),
                        child: Icon(
                          icon,
                          color: iconTheme?.color,
                          size: iconTheme?.size,
                        ),
                      ),
                    ),
                    const SizedBox(height: BirdySpace.xs),
                    Text(
                      label,
                      style: labelStyle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The disc and its label. Only the disc and the label take the touch; the
/// strip beside the disc, above the bar, lets it through.
class _ListenSlot extends ConsumerWidget {
  const _ListenSlot({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
    final tabLabel = NavigationBarTheme.of(
      context,
    ).labelTextStyle?.resolve({WidgetState.selected});
    final listening = ref.watch(
      liveStateProvider.select(
        (s) => s == LiveState.active || s == LiveState.paused,
      ),
    );
    return Semantics(
      container: true,
      button: true,
      label: l10n.forkListen,
      onTap: onTap,
      child: ExcludeSemantics(
        child: GestureDetector(
          onTap: onTap,
          child: Pressable(
            scale: BirdyMotion.listenDiscPressScale,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: c.accent,
                      border: Border.all(
                        color: c.surface1,
                        width: BirdySizes.listenDiscRim,
                      ),
                      boxShadow: c.listenGlow,
                    ),
                    child: SizedBox.square(
                      dimension: BirdySizes.listenDisc,
                      child: Center(
                        child: BirdyWingIcon(
                          size: BirdyGlyph.x6l,
                          animated: true,
                          listening: listening,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: BirdySpace.xs),
                // Transparent but hit-testable: the label's row is part of
                // the touch target.
                ColoredBox(
                  color: Colors.transparent,
                  child: Text(
                    l10n.forkListen,
                    // The tabs' label size and line height, so the baselines
                    // line up across the bar.
                    style: BirdyText.labelCompact.copyWith(
                      color: c.accentText,
                      fontSize: tabLabel?.fontSize,
                      height: tabLabel?.height,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
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
