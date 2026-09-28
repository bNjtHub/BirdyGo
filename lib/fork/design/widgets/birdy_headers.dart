/// Headers of the J6f layout (« App finale » boards).
///
/// - Tabs (Accueil, Carnet, Carte, Profil): big title in display 34, a
///   caption under it, round white buttons on the right ([BirdyTabHeader]).
/// - Screens opened on top (Fiche, Palmarès, Bilan, Revue): back button and
///   a heading 20 title ([BirdyOverlayHeader]).
library;

import 'package:flutter/material.dart';

import '../../../shared/utils/app_icons.dart';
import '../birdy_tokens.dart';
import '../birdy_typography.dart';
import 'birdy_buttons.dart';

/// Big title of a tab, its caption and its round buttons.
class BirdyTabHeader extends StatelessWidget {
  const BirdyTabHeader({
    super.key,
    required this.title,
    this.caption,
    this.actions = const [],
  });

  final String title;

  /// One line under the title (« 24 espèces découvertes »).
  final String? caption;

  /// Round white buttons ([BirdyIconButton]), top right.
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final c = BirdyColors.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                header: true,
                child: Text(
                  title,
                  style: BirdyText.display.copyWith(color: c.text1),
                ),
              ),
              if (caption case final caption?) ...[
                const SizedBox(height: BirdySpace.xs),
                Text(
                  caption,
                  style: BirdyText.caption.copyWith(color: c.text2),
                ),
              ],
            ],
          ),
        ),
        for (final action in actions) ...[
          const SizedBox(width: BirdySpace.s),
          action,
        ],
      ],
    );
  }
}

/// Back button, heading 20 title and optional round buttons of a screen
/// opened on top of a tab.
class BirdyOverlayHeader extends StatelessWidget {
  const BirdyOverlayHeader({
    super.key,
    required this.title,
    this.onBack,
    this.closing = false,
    this.enabled = true,
    this.actions = const [],
  });

  final String title;

  /// Defaults to popping the route.
  final VoidCallback? onBack;

  /// A cross (« Fermer ») instead of the back arrow: screens that end a
  /// flow (Bilan, Revue rapide).
  final bool closing;

  /// False greys the button out (a save in progress); it never pops then.
  final bool enabled;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final c = BirdyColors.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: BirdySizes.target),
      child: Row(
        children: [
          BirdyIconButton(
            icon: closing ? AppIcons.closeRounded : AppIcons.arrowBackRounded,
            semanticLabel:
                closing
                    ? MaterialLocalizations.of(context).closeButtonTooltip
                    : MaterialLocalizations.of(context).backButtonTooltip,
            onPressed:
                enabled
                    ? onBack ?? () => Navigator.of(context).maybePop()
                    : null,
          ),
          const SizedBox(width: BirdySpace.m),
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                title,
                style: BirdyText.heading.copyWith(color: c.text1),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          for (final action in actions) ...[
            const SizedBox(width: BirdySpace.s),
            action,
          ],
        ],
      ),
    );
  }
}
