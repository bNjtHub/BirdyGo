/// The answer cards of « Qui chante ? » (J6e, Quiz v2): a 2 × 2 grid of big
/// cards, the bird's icon on its halo and its name. After the answer, the
/// right card turns Lichen with a check (a pop and « +1 Oreille fine »
/// flying away when the player found it), a wrong pick sways and takes a
/// cross, the others fade to 40 %.
library;

import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

import '../../shared/utils/app_icons.dart';
import '../design/birdy_motion.dart';
import '../design/birdy_tokens.dart';
import '../design/birdy_typography.dart';
import '../design/widgets/pressable.dart';
import 'fine_ear_quiz_widgets.dart';
import 'game_config.dart';
import 'game_text.dart';
import 'quiz_fx.dart';

enum QuizChoiceState { open, right, wrong, other }

class QuizChoiceCard extends StatelessWidget {
  const QuizChoiceCard({
    super.key,
    required this.bird,
    required this.state,
    this.onTap,
    this.height = defaultHeight,
    this.found = false,
  });

  static const double defaultHeight = 136;
  static const double radius = 24;

  static const double padH = 12;
  static const double padV = 10;
  static const double gap = 8;
  static const double minIcon = 28;
  static const double maxIcon = 76;
  static const int maxNameLines = 3;

  /// Height of [name] on a card whose content is [width] wide.
  static double nameHeight(BuildContext context, String name, double width) {
    final painter = TextPainter(
      text: TextSpan(text: name, style: BirdyText.species),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      textAlign: TextAlign.center,
      maxLines: maxNameLines,
    )..layout(maxWidth: width < 1 ? 1 : width);
    final height = painter.height;
    painter.dispose();
    return height;
  }

  /// Smallest card, [cardWidth] wide, that shows [name] with the smallest
  /// icon.
  static double minHeightFor(
    BuildContext context,
    String name,
    double cardWidth,
  ) {
    const border = 2 * 2.5;
    return 2 * padV +
        border +
        minIcon +
        gap +
        nameHeight(context, name, cardWidth - 2 * padH - border);
  }

  final QuizBird bird;
  final QuizChoiceState state;
  final VoidCallback? onTap;
  final double height;

  /// The player picked this right card: pop and « +1 Oreille fine ».
  final bool found;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
    final open = state == QuizChoiceState.open;
    final tint = bird.tint;
    final (background, foreground, border, width) = switch (state) {
      QuizChoiceState.open => (
        tint.cardBackground(c.brightness),
        c.text1,
        tint.accent.withValues(alpha: 0.4),
        1.5,
      ),
      QuizChoiceState.right => (
        c.sure.background,
        c.sure.foreground,
        c.sure.foreground,
        2.5,
      ),
      QuizChoiceState.wrong => (c.surface1, c.text1, c.border, 1.5),
      QuizChoiceState.other => (c.surface1, c.text2, c.lineOpaque, 1.5),
    };
    final value = switch (state) {
      QuizChoiceState.right => l10n.forkQuizChoiceRight,
      QuizChoiceState.wrong => l10n.forkQuizChoiceWrong,
      _ => null,
    };

    final border2 = 2 * width;
    final card = Pressable(
      enabled: open,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: open ? onTap : null,
          borderRadius: BorderRadius.circular(radius),
          child: LayoutBuilder(
            builder: (context, constraints) {
              // The icon takes what the name leaves: 76 px on the mockup,
              // smaller on short cards or with large text.
              final inner = constraints.maxWidth - 2 * padH - border2;
              final text = nameHeight(context, bird.name, inner);
              final icon = (height - 2 * padV - border2 - gap - text).clamp(
                minIcon,
                maxIcon,
              );
              return AnimatedContainer(
                duration: QuizMotion.fade,
                curve: QuizMotion.out,
                constraints: BoxConstraints(minHeight: height),
                padding: const EdgeInsets.symmetric(
                  horizontal: padH,
                  vertical: padV,
                ),
                decoration: BoxDecoration(
                  color: background,
                  borderRadius: BorderRadius.circular(radius),
                  border: Border.all(color: border, width: width),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    QuizBirdArt(
                      bird: bird,
                      size: icon,
                      iconSize: icon * 66 / 76,
                      // Open: a white halo on the tinted card. Answered:
                      // each state's own halo (grey out, bird tint, ...).
                      background: open ? c.surface1 : null,
                    ),
                    const SizedBox(height: gap),
                    QuizBalancedText(
                      TextSpan(
                        text: bird.name,
                        style: BirdyText.species.copyWith(color: foreground),
                      ),
                      maxLines: maxNameLines,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );

    Widget body = Stack(
      clipBehavior: Clip.none,
      fit: StackFit.passthrough,
      children: [
        card,
        if (state == QuizChoiceState.right)
          Positioned(
            top: BirdySpace.s,
            right: BirdySpace.s,
            child: QuizPop(
              duration: QuizMotion.pill,
              child: _Mark(
                icon: AppIcons.quizCheck,
                color: c.sure.foreground,
                iconSize: 20,
              ),
            ),
          ),
        if (state == QuizChoiceState.wrong)
          Positioned(
            top: BirdySpace.s,
            right: BirdySpace.s,
            child: _Mark(
              icon: AppIcons.quizClose,
              color: c.text2,
              iconSize: 18,
            ),
          ),
        if (found)
          Positioned(
            top: BirdySpace.xs,
            left: -BirdySpace.l,
            right: -BirdySpace.l,
            child: IgnorePointer(
              child: Center(
                child: QuizFlyUp(
                  child: _PlusOne(
                    label: l10n.forkQuizPlusOne(
                      badgeName(l10n, BadgeKind.fineEar),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
    body = switch (state) {
      QuizChoiceState.right when found => QuizPop(
        key: const ValueKey('pop'),
        child: body,
      ),
      QuizChoiceState.wrong => QuizWobble(
        key: const ValueKey('wobble'),
        child: body,
      ),
      _ => body,
    };

    return Semantics(
      button: open,
      enabled: open,
      label: bird.name,
      value: value,
      excludeSemantics: true,
      child: AnimatedOpacity(
        opacity: state == QuizChoiceState.other ? 0.4 : 1,
        duration: BirdyMotion.exit,
        curve: QuizMotion.out,
        child: body,
      ),
    );
  }
}

/// Round mark at the top right of an answered card.
class _Mark extends StatelessWidget {
  const _Mark({
    required this.icon,
    required this.color,
    required this.iconSize,
  });

  final IconData icon;
  final Color color;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final c = BirdyColors.of(context);
    return Container(
      width: BirdyGlyph.x5l,
      height: BirdyGlyph.x5l,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: Icon(icon, size: iconSize, weight: 600, color: c.surface1),
    );
  }
}

/// « +1 Oreille fine », Loriot pill.
class _PlusOne extends StatelessWidget {
  const _PlusOne({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final c = BirdyColors.of(context);
    return Container(
      constraints: const BoxConstraints(minHeight: 28),
      padding: const EdgeInsets.symmetric(
        horizontal: BirdySpace.m,
        vertical: BirdySpace.tight,
      ),
      decoration: BoxDecoration(
        color: c.oriole,
        borderRadius: BorderRadius.circular(BirdyRadii.pill),
      ),
      child: Text(
        label,
        maxLines: 1,
        softWrap: false,
        style: BirdyText.labelCompact.copyWith(
          fontWeight: FontWeight.w800,
          color: c.onOriole,
        ),
      ),
    );
  }
}

/// Answer cards two by two, 10 px apart.
class QuizChoiceGrid extends StatelessWidget {
  const QuizChoiceGrid({super.key, required this.children});

  static const double gap = 10;

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i += 2) {
      if (i > 0) rows.add(const SizedBox(height: gap));
      rows.add(
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: children[i]),
            const SizedBox(width: gap),
            Expanded(
              child:
                  i + 1 < children.length
                      ? children[i + 1]
                      : const SizedBox.shrink(),
            ),
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: rows,
    );
  }
}
