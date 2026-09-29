/// The three story pages of the BirdyGo onboarding (J6g-a), in the style of
/// the Profil and the quiz intro: a dark well with the bird and twinkles,
/// three tilted numbered cards, and the reliability levels as tinted blocks.
///
/// Every page scrolls as a last resort (130 % text on a 320 dp phone) and
/// stays in a column of at most [kOnboardingMaxWidth]. Reduced motion is
/// handled by the quiz motion widgets used here (no loops, nothing moves).
library;

import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

import '../../shared/utils/app_icons.dart';
import '../design/birdy_tokens.dart';
import '../design/birdy_typography.dart';
import '../design/widgets/birdy_block.dart';
import '../design/widgets/birdy_wing_icon.dart';
import '../game/fine_ear_quiz_widgets.dart' show QuizWell;
import '../game/quiz_decor.dart';
import '../game/quiz_fx.dart';
import '../home/birdygo_logo.dart';
import '../reliability/reliability_badge.dart';
import '../reliability/reliability_config.dart';

/// Widest column of an onboarding page (tablets, landscape).
const double kOnboardingMaxWidth = 520;

/// Shared frame: the column is centered, the content scrolls when it does not
/// fit.
class OnboardingPageFrame extends StatelessWidget {
  const OnboardingPageFrame({super.key, required this.builder});

  /// Builds the content for the available height (used to size the hero).
  final Widget Function(BuildContext context, double height) builder;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: kOnboardingMaxWidth),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                BirdySpace.page,
                BirdySpace.s,
                BirdySpace.page,
                BirdySpace.l,
              ),
              child: builder(context, constraints.maxHeight),
            ),
          ),
        );
      },
    );
  }
}

/// A page title: Fraunces, announced as a header.
class OnboardingTitle extends StatelessWidget {
  const OnboardingTitle(this.text, {super.key, this.style});

  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final c = BirdyColors.of(context);
    return Semantics(
      header: true,
      child: Text(
        text,
        style: (style ?? BirdyText.display).copyWith(color: c.text1),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Page 1: the bird
// ---------------------------------------------------------------------------

class OnboardingWelcomePage extends StatelessWidget {
  const OnboardingWelcomePage({super.key});

  static const double heroMax = 290;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
    return OnboardingPageFrame(
      builder: (context, height) {
        final hero = (height * 0.42).clamp(168.0, heroMax);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: hero, child: _WelcomeWell(height: hero)),
            const SizedBox(height: BirdySpace.xl),
            OnboardingTitle(
              l10n.forkOnbWelcomeTitle,
              style: BirdyText.title,
            ),
            const SizedBox(height: BirdySpace.s),
            Text(
              l10n.forkOnbWelcomeBody,
              style: BirdyText.body.copyWith(color: c.text2),
            ),
          ],
        );
      },
    );
  }
}

class _WelcomeWell extends StatelessWidget {
  const _WelcomeWell({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final bird = (height * 0.62).clamp(96.0, 190.0);
    return QuizWell(
      highlightRadius: 240,
      child: Stack(
        children: [
          const Positioned.fill(child: QuizSparkField(maxRadius: 130)),
          const Positioned.fill(child: QuizTwinkleField(count: 7, seed: 11)),
          Center(
            child: Semantics(
              label: l10n.forkOnbBirdLabel,
              image: true,
              excludeSemantics: true,
              child: QuizFloat(
                period: QuizMotion.floatIntro,
                child: BirdyGoLogo(size: bird),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Page 2: listen, discover, collect
// ---------------------------------------------------------------------------

class OnboardingHowPage extends StatelessWidget {
  const OnboardingHowPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
    final steps = [
      (
        title: l10n.forkOnbStepListenTitle,
        body: l10n.forkOnbStepListenBody,
        icon: const BirdyWingIcon(size: 26), // the Listen emblem
        bg: c.tonal,
        ink: c.accentText,
        tilt: -0.02,
      ),
      (
        title: l10n.forkOnbStepDiscoverTitle,
        body: l10n.forkOnbStepDiscoverBody,
        icon: Icon(AppIcons.menuBook, size: 26, color: c.orioleText),
        bg: c.orioleContainer,
        ink: c.orioleText,
        tilt: 0.017,
      ),
      (
        title: l10n.forkOnbStepCollectTitle,
        body: l10n.forkOnbStepCollectBody,
        icon: Icon(AppIcons.quizSpark, size: 26, color: c.sure.foreground),
        bg: c.sure.background,
        ink: c.sure.foreground,
        tilt: -0.012,
      ),
    ];
    return OnboardingPageFrame(
      builder:
          (context, height) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              OnboardingTitle(l10n.forkOnbHowTitle),
              const SizedBox(height: BirdySpace.xl),
              for (var i = 0; i < steps.length; i++) ...[
                if (i > 0) const SizedBox(height: BirdySpace.l),
                Semantics(
                  container: true,
                  label:
                      '${l10n.forkOnbStepNumber(i + 1)}. ${steps[i].title}. '
                      '${steps[i].body}',
                  excludeSemantics: true,
                  child: QuizPop(
                    duration: const Duration(milliseconds: 380),
                    delay: Duration(milliseconds: 120 + i * 100),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Transform.rotate(
                        angle: steps[i].tilt,
                        child: _StepCard(
                          number: i + 1,
                          title: steps[i].title,
                          body: steps[i].body,
                          icon: steps[i].icon,
                          background: steps[i].bg,
                          ink: steps[i].ink,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
    );
  }
}

class _StepCard extends StatelessWidget {
  const _StepCard({
    required this.number,
    required this.title,
    required this.body,
    required this.icon,
    required this.background,
    required this.ink,
  });

  final int number;
  final String title;
  final String body;
  final Widget icon;
  final Color background;
  final Color ink;

  @override
  Widget build(BuildContext context) {
    final c = BirdyColors.of(context);
    return Container(
      padding: const EdgeInsets.all(BirdySpace.l),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(BirdyRadii.card),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: BirdyBrand.ink,
                ),
                child: Text(
                  '$number',
                  style: BirdyText.badge.copyWith(
                    color: BirdyBrand.mist,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: BirdySpace.s),
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: c.surface1,
                  shape: BoxShape.circle,
                ),
                child: icon,
              ),
            ],
          ),
          const SizedBox(width: BirdySpace.m),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: BirdyText.heading.copyWith(color: c.text1),
                  ),
                  const SizedBox(height: BirdySpace.xs),
                  Text(
                    body,
                    style: BirdyText.bodyCompact.copyWith(color: c.text1),
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

// ---------------------------------------------------------------------------
// Page 3: reliability levels
// ---------------------------------------------------------------------------

class OnboardingLevelsPage extends StatelessWidget {
  const OnboardingLevelsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
    final rows = [
      (
        level: ReliabilityLevel.sure,
        tone: BirdyBlockTone.sure,
        text: l10n.forkLevelsInfoSure,
      ),
      (
        level: ReliabilityLevel.probable,
        tone: BirdyBlockTone.tonal,
        text: l10n.forkLevelsInfoProbable,
      ),
      (
        level: ReliabilityLevel.toCheck,
        tone: BirdyBlockTone.toCheck,
        text: l10n.forkLevelsInfoToCheck,
      ),
    ];
    return OnboardingPageFrame(
      builder:
          (context, height) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              OnboardingTitle(l10n.forkOnbLevelsTitle),
              const SizedBox(height: BirdySpace.s),
              Text(
                l10n.forkOnbLevelsIntro,
                style: BirdyText.body.copyWith(color: c.text2),
              ),
              const SizedBox(height: BirdySpace.xl),
              for (var i = 0; i < rows.length; i++) ...[
                if (i > 0) const SizedBox(height: BirdySpace.block),
                QuizRise(
                  duration: QuizMotion.rise,
                  delay: Duration(milliseconds: 80 + i * 100),
                  distance: 8,
                  child: BirdyBlock(
                    tone: rows[i].tone,
                    padding: const EdgeInsets.all(BirdySpace.l),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ReliabilityBadge(level: rows[i].level),
                        const SizedBox(height: BirdySpace.s),
                        Text(
                          rows[i].text,
                          style: BirdyText.body.copyWith(color: c.text1),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
    );
  }
}
