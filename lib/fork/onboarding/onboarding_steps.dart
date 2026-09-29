/// The two steps of the child's onboarding (J6i): « Étape 1 sur 2 » the
/// first name, « Étape 2 sur 2 » « Choisis ton oiseau ». They replace the
/// old optional name page; the story pages and the permissions page stay.
///
/// Both steps carry their own header and their own 72 dp button, so the
/// screen hides its dots and « Passer » on them. The bird step is also the
/// Settings « Mon oiseau » screen (with a back arrow instead of the step
/// counter): a tap on a card sets `birdyBirdProvider` at once, so the whole
/// app previews the bird, and the disc sings a phrase.
library;

import 'dart:async';

import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/utils/app_icons.dart';
import '../design/birdy_motion.dart';
import '../design/birdy_theme_choice.dart';
import '../design/birdy_tokens.dart';
import '../design/birdy_typography.dart';
import '../design/widgets/birdy_bird_picker.dart';
import '../design/widgets/birdy_block.dart';
import '../design/widgets/birdy_buttons.dart';
import '../design/widgets/birdygo_wordmark.dart';
import '../design/widgets/pressable.dart';
import '../design/widgets/singing_theme_logo.dart';
import '../game/quiz_fx.dart' show QuizRise;
import '../settings/fork_prefs.dart';
import 'onboarding_pages.dart'
    show OnboardingPageFrame, kOnboardingMaxWidth;

/// Top line of a step: an optional back arrow, and the step counter at the
/// end.
class _StepHeader extends StatelessWidget {
  const _StepHeader({this.stepLabel, this.onBack});

  final String? stepLabel;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final c = BirdyColors.of(context);
    return SizedBox(
      height: BirdySizes.target,
      child: Row(
        children: [
          if (onBack != null)
            BirdyIconButton(
              key: const ValueKey('step-back'),
              icon: AppIcons.arrowBackRounded,
              semanticLabel: MaterialLocalizations.of(context).backButtonTooltip,
              onPressed: onBack,
            ),
          const Spacer(),
          if (stepLabel != null)
            Text(
              stepLabel!,
              key: const ValueKey('step-label'),
              style: BirdyText.caption.copyWith(
                fontWeight: FontWeight.w700,
                color: c.text2,
              ),
            ),
        ],
      ),
    );
  }
}

/// Centered display title, announced as a header.
class _StepTitle extends StatelessWidget {
  const _StepTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Semantics(
    header: true,
    child: Text(
      text,
      textAlign: TextAlign.center,
      style: BirdyText.display.copyWith(color: BirdyColors.of(context).text1),
    ),
  );
}

/// Page = pinned header, scrolling content, and the pinned 72 dp button (and
/// a text button). The header stays put so the back arrow is always there.
class _StepScaffold extends StatelessWidget {
  const _StepScaffold({
    required this.header,
    required this.content,
    required this.cta,
    this.secondary,
  });

  final Widget header;
  final Widget content;
  final Widget cta;
  final Widget? secondary;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: kOnboardingMaxWidth),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                BirdySpace.page,
                BirdySpace.s,
                BirdySpace.page,
                0,
              ),
              child: header,
            ),
          ),
        ),
        Expanded(child: OnboardingPageFrame(builder: (_, _) => content)),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: kOnboardingMaxWidth),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                BirdySpace.page,
                BirdySpace.s,
                BirdySpace.page,
                BirdySpace.l,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [cta, if (secondary != null) secondary!],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The 72 dp button of a step, with the theme's glow; grey when disabled.
class _StepButton extends StatelessWidget {
  const _StepButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final c = BirdyColors.of(context);
    final enabled = onPressed != null;
    return Pressable(
      enabled: enabled,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(BirdyRadii.pill),
          boxShadow: enabled ? c.ctaGlow : null,
        ),
        child: FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: c.accent,
            foregroundColor: c.onAccent,
            disabledBackgroundColor: c.line,
            disabledForegroundColor: c.text2,
            minimumSize: const Size(64, BirdySizes.listen),
            shape: const StadiumBorder(),
            textStyle: BirdyText.labelLarge,
            iconSize: BirdySizes.ctaIcon,
          ),
          iconAlignment: IconAlignment.end,
          onPressed: onPressed,
          icon: Icon(icon),
          label: Text(label, textAlign: TextAlign.center),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Step 1: first name
// ---------------------------------------------------------------------------

/// « Bienvenue ! » → « Enchanté, {prénom} ! » while typing. The screen owns
/// the [controller] and saves it through `firstNameProvider` in [onContinue];
/// [onLater] leaves without saving.
class OnboardingNameStep extends StatelessWidget {
  const OnboardingNameStep({
    super.key,
    required this.controller,
    required this.onContinue,
    required this.onLater,
    required this.total,
  });

  final TextEditingController controller;
  final VoidCallback onContinue;
  final VoidCallback onLater;
  final int total;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final name = controller.text.trim();
        return _StepScaffold(
          header: _StepHeader(stepLabel: l10n.forkOnbStep(1, total)),
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Center(child: SingingThemeLogo()),
              const SizedBox(height: BirdySpace.l),
              const Center(child: BirdyGoWordmark()),
              const SizedBox(height: BirdySpace.xl),
              QuizRise(
                distance: 8,
                child: Column(
                  children: [
                    _StepTitle(
                      name.isEmpty
                          ? l10n.forkOnbWelcome
                          : l10n.forkOnbHello(name),
                    ),
                    const SizedBox(height: BirdySpace.s),
                    Text(
                      l10n.forkOnbAskName,
                      textAlign: TextAlign.center,
                      style: BirdyText.body.copyWith(color: c.text1),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: BirdySpace.xl),
              BirdyBlock(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.forkOnbNameLabel,
                      style: BirdyText.caption.copyWith(
                        fontWeight: FontWeight.w700,
                        color: c.text2,
                      ),
                    ),
                    TextField(
                      key: const ValueKey('onb-name-field'),
                      controller: controller,
                      maxLength: kFirstNameMaxLength,
                      maxLengthEnforcement: MaxLengthEnforcement.enforced,
                      buildCounter:
                          (
                            _, {
                            required currentLength,
                            required isFocused,
                            maxLength,
                          }) => null,
                      autofillHints: const [AutofillHints.givenName],
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.done,
                      autocorrect: false,
                      style: BirdyText.inputLarge.copyWith(color: c.text1),
                      cursorColor: c.accentText,
                      decoration: InputDecoration(
                        hintText: l10n.forkOnbNamePlaceholder,
                        filled: false,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: BirdySpace.s,
                        ),
                        enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(
                            color: c.accent,
                            width: BirdySizes.themeRing - 1,
                          ),
                        ),
                        focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(
                            color: c.accent,
                            width: BirdySizes.themeRing - 1,
                          ),
                        ),
                      ),
                      onSubmitted: (_) {
                        if (name.isNotEmpty) onContinue();
                      },
                    ),
                    const SizedBox(height: BirdySpace.s),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: BirdySpace.xs / 4),
                          child: Icon(
                            AppIcons.lockOutline,
                            size: BirdySizes.inlineIcon,
                            color: c.text2,
                          ),
                        ),
                        const SizedBox(width: BirdySpace.s - 2),
                        Expanded(
                          child: Text(
                            l10n.forkOnbNamePrivacy,
                            style: BirdyText.caption.copyWith(color: c.text2),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          cta: _StepButton(
            key: const ValueKey('onb-name-continue'),
            label: l10n.forkOnbContinue,
            icon: AppIcons.arrowForwardRounded,
            onPressed: name.isEmpty ? null : onContinue,
          ),
          secondary: TextButton(
            key: const ValueKey('onb-name-later'),
            style: TextButton.styleFrom(
              foregroundColor: c.text2,
              minimumSize: const Size.fromHeight(BirdySizes.target),
              textStyle: BirdyText.labelCompact,
            ),
            onPressed: onLater,
            child: Text(l10n.forkOnbLater),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Step 2: pick a bird (also Settings > Mon oiseau)
// ---------------------------------------------------------------------------

/// « Choisis ton oiseau ». Tapping a card sets `birdyBirdProvider`; the
/// button then calls [onDone], after a short welcome when [confirmation] is
/// on (the onboarding), at once otherwise (Settings).
class BirdyBirdStep extends ConsumerStatefulWidget {
  const BirdyBirdStep({
    super.key,
    required this.onDone,
    this.stepLabel,
    this.onBack,
    this.confirmation = false,
  });

  final VoidCallback onDone;

  /// « Étape 2 sur 2 » in the onboarding.
  final String? stepLabel;

  /// Back arrow (Settings).
  final VoidCallback? onBack;

  /// Show « Bienvenue {prénom} chez les {oiseaux} ! » before [onDone].
  final bool confirmation;

  /// How long the welcome stays before the next page.
  static const Duration welcomeTime = Duration(milliseconds: 1500);

  @override
  ConsumerState<BirdyBirdStep> createState() => _BirdyBirdStepState();
}

class _BirdyBirdStepState extends ConsumerState<BirdyBirdStep> {
  int _sing = 0;
  bool _welcome = false;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _pick(BirdyBird bird) {
    if (_welcome) return;
    HapticFeedback.selectionClick();
    ref.read(birdyBirdProvider.notifier).set(bird);
    setState(() => _sing++);
  }

  void _confirm() {
    if (!widget.confirmation) {
      widget.onDone();
      return;
    }
    setState(() => _welcome = true);
    HapticFeedback.lightImpact();
    _timer = Timer(
      BirdyMotion.reduced(context) ? Duration.zero : BirdyBirdStep.welcomeTime,
      widget.onDone,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
    final bird = ref.watch(birdyBirdProvider);
    final name = ref.watch(firstNameProvider);
    final title =
        _welcome
            ? (name == null
                ? l10n.forkOnbWelcomeThemeAnon(bird.plural(l10n))
                : l10n.forkOnbWelcomeTheme(name, bird.plural(l10n)))
            : l10n.forkOnbPickTitle;
    return _StepScaffold(
      header: _StepHeader(stepLabel: widget.stepLabel, onBack: widget.onBack),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(child: SingingThemeLogo(singSignal: _sing)),
          const SizedBox(height: BirdySpace.l),
          _StepTitle(title),
          const SizedBox(height: BirdySpace.s),
          if (!_welcome)
            Text(
              l10n.forkOnbPickBody,
              textAlign: TextAlign.center,
              style: BirdyText.body.copyWith(color: c.text1),
            ),
          const SizedBox(height: BirdySpace.xl),
          IgnorePointer(
            ignoring: _welcome,
            child: BirdyBirdPicker(selected: bird, onPick: _pick),
          ),
        ],
      ),
      cta: _StepButton(
        key: const ValueKey('onb-bird-confirm'),
        label: l10n.forkOnbConfirm,
        icon: AppIcons.arrowForwardRounded,
        onPressed: _welcome ? null : _confirm,
      ),
    );
  }
}
