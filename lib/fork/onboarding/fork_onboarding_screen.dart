/// The BirdyGo first-launch experience (J6g-a): three short story pages and
/// the permissions page, swipeable, with dots and a « Passer » link. It
/// replaces upstream's `OnboardingScreen` in `_AppGate` (one `// FORK` line
/// in `lib/app.dart`); the upstream screen file is untouched.
///
/// Finishing sets the same flags as upstream (`termsAcceptedProvider`, then
/// `onboardingCompleteProvider`), so the gate then shows the home
/// (`ForkShell`). The consent line above the button carries the upstream
/// acceptable-use and privacy links, so tapping the button is the acceptance.
library;

import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/providers/app_providers.dart';
import '../design/birdy_motion.dart';
import '../design/birdy_tokens.dart';
import '../design/birdy_typography.dart';
import '../design/widgets/birdy_buttons.dart';
import '../design/widgets/birdy_step_dots.dart';
import '../design/widgets/pressable.dart';
import '../settings/fork_prefs.dart';
import 'onboarding_pages.dart';
import 'onboarding_permissions.dart';
import 'onboarding_permissions_page.dart';
import 'onboarding_steps.dart';
import '../design/birdy_icons.dart';

/// Steps counted in « Étape n sur N » (first name, bird), and the dots of the
/// other pages (three story pages and the permissions page).
const int _stepCount = 2;
const int _dotCount = 4;

class ForkOnboardingScreen extends ConsumerStatefulWidget {
  const ForkOnboardingScreen({super.key});

  /// Story pages, step 1 (first name), step 2 (bird), then the permissions
  /// page. FORK J6i: the bird step was added.
  static const int pageCount = 6;
  static const int namePage = 3;
  static const int birdPage = 4;
  static const int permissionsPage = 5;

  /// Pages with their own header and button (the two steps).
  static bool isStep(int page) => page == namePage || page == birdPage;

  @override
  ConsumerState<ForkOnboardingScreen> createState() =>
      _ForkOnboardingScreenState();
}

class _ForkOnboardingScreenState extends ConsumerState<ForkOnboardingScreen>
    with WidgetsBindingObserver {
  final PageController _controller = PageController();
  final TextEditingController _name = TextEditingController();
  int _page = 0;

  OnboardingPermState _mic = OnboardingPermState.unknown;
  OnboardingPermState _location = OnboardingPermState.unknown;
  bool _busyMic = false;
  bool _busyLocation = false;
  bool _finishing = false;

  OnboardingPermissions get _permissions =>
      ref.read(onboardingPermissionsProvider);

  bool get _last => _page == ForkOnboardingScreen.permissionsPage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    _name.dispose();
    super.dispose();
  }

  /// Back from the phone's settings: read the states again, silently.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    final mic = await _permissions.microphoneState();
    final location = await _permissions.locationState();
    if (!mounted) return;
    setState(() {
      // Never go back from « refused » to « not asked » on a silent read.
      if (mic != OnboardingPermState.unknown ||
          _mic != OnboardingPermState.refused) {
        _mic = mic;
      }
      if (location != OnboardingPermState.unknown ||
          _location != OnboardingPermState.refused) {
        _location = location;
      }
    });
  }

  Future<void> _allowMic() async {
    if (_busyMic) return;
    setState(() => _busyMic = true);
    final state = await _permissions.requestMicrophone();
    if (!mounted) return;
    setState(() {
      _mic = state;
      _busyMic = false;
    });
  }

  Future<void> _allowLocation() async {
    if (_busyLocation) return;
    setState(() => _busyLocation = true);
    final state = await _permissions.requestLocation();
    if (!mounted) return;
    setState(() {
      _location = state;
      _busyLocation = false;
    });
  }

  void _goTo(int page) {
    if (BirdyMotion.reduced(context)) {
      _controller.jumpToPage(page);
    } else {
      _controller.animateToPage(
        page,
        duration: BirdyMotion.reorder,
        curve: BirdyMotion.move,
      );
    }
  }

  void _next() => _goTo((_page + 1).clamp(0, ForkOnboardingScreen.pageCount));

  bool get _onStep => ForkOnboardingScreen.isStep(_page);

  /// « Continuer » on step 1: same preference as the Settings block.
  void _saveName() {
    FocusManager.instance.primaryFocus?.unfocus();
    ref.read(firstNameProvider.notifier).set(_name.text);
    _next();
  }

  /// « Plus tard » on step 1: nothing saved.
  void _skipName() {
    FocusManager.instance.primaryFocus?.unfocus();
    _next();
  }

  /// The button of the last page. With the microphone not asked yet it asks
  /// first, and stays here if the answer is no (the card says why the
  /// microphone is needed); the next tap finishes anyway, so nobody is stuck.
  Future<void> _finish() async {
    if (_finishing) return;
    if (_mic == OnboardingPermState.unknown) {
      await _allowMic();
      if (!mounted || _mic != OnboardingPermState.granted) return;
    }
    setState(() => _finishing = true);
    HapticFeedback.lightImpact();
    await ref.read(termsAcceptedProvider.notifier).accept();
    await ref.read(onboardingCompleteProvider.notifier).complete();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        child: Column(
          children: [
            // « Passer »: keeps its room on the last page, so nothing jumps.
            SizedBox(
              height: BirdySizes.topBar,
              child: Align(
                alignment: AlignmentDirectional.centerEnd,
                child: Padding(
                  padding: const EdgeInsetsDirectional.only(end: BirdySpace.s),
                  child: Visibility(
                    visible: !_last && !_onStep,
                    maintainSize: true,
                    maintainAnimation: true,
                    maintainState: true,
                    child: TextButton(
                      key: const ValueKey('onb-skip'),
                      style: TextButton.styleFrom(
                        foregroundColor: c.accentText,
                        minimumSize: const Size(
                          BirdySizes.target,
                          BirdySizes.target,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: BirdySpace.l,
                        ),
                        textStyle: BirdyText.label,
                      ),
                      onPressed: () => _goTo(ForkOnboardingScreen.namePage),
                      child: Text(l10n.skip),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: PageView(
                key: const ValueKey('onb-pages'),
                controller: _controller,
                // The steps are left by their own buttons only.
                physics:
                    _onStep ? const NeverScrollableScrollPhysics() : null,
                onPageChanged: (i) {
                  setState(() => _page = i);
                  if (i == ForkOnboardingScreen.permissionsPage) _refresh();
                },
                children: [
                  const OnboardingWelcomePage(),
                  const OnboardingHowPage(),
                  const OnboardingLevelsPage(),
                  OnboardingNameStep(
                    controller: _name,
                    onContinue: _saveName,
                    onLater: _skipName,
                    total: _stepCount,
                  ),
                  BirdyBirdStep(
                    stepLabel: l10n.forkOnbStep(2, _stepCount),
                    confirmation: true,
                    onDone: _next,
                  ),
                  OnboardingPermissionsPage(
                    mic: _mic,
                    location: _location,
                    busyMic: _busyMic,
                    busyLocation: _busyLocation,
                    onAllowMic: _allowMic,
                    onAllowLocation: _allowLocation,
                    onOpenSettings: _permissions.openSettings,
                  ),
                ],
              ),
            ),
            if (!_onStep)
              _BottomBar(
                page: _page,
                last: _last,
                finishing: _finishing,
                onNext: _next,
                onFinish: _finish,
              ),
          ],
        ),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.page,
    required this.last,
    required this.finishing,
    required this.onNext,
    required this.onFinish,
  });

  final int page;
  final bool last;
  final bool finishing;
  final VoidCallback onNext;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        BirdySpace.page,
        BirdySpace.s,
        BirdySpace.page,
        BirdySpace.l,
      ),
      child: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: kOnboardingMaxWidth),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Dots for the story pages and the permissions page; the two
              // steps have their own counter.
              _Dots(
                page: last ? _dotCount - 1 : page,
                count: _dotCount,
              ),
              const SizedBox(height: BirdySpace.l),
              if (last)
                _FinishButton(
                  label: l10n.forkOnbFirstBird,
                  onPressed: finishing ? null : onFinish,
                )
              else
                Pressable(
                  child: FilledButton(
                    key: const ValueKey('onb-next'),
                    style: BirdyButtonStyles.primary(context),
                    onPressed: onNext,
                    child: Text(l10n.next, textAlign: TextAlign.center),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Page dots: the current one is a longer pill of the action color.
class _Dots extends StatelessWidget {
  const _Dots({required this.page, required this.count});

  final int page;
  final int count;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
    return BirdyStepDots(
      count: count,
      current: page,
      activeColor: c.accentText,
      inactiveColor: c.progressTrack,
      semanticLabel: l10n.forkOnbPageOf(page + 1, count),
    );
  }
}

/// « Écouter mon premier oiseau »: 72 dp, Martin-pêcheur, with its glow
/// (same look as the quiz's « C'est parti ! »).
class _FinishButton extends StatelessWidget {
  const _FinishButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final c = BirdyColors.of(context);
    return Pressable(
      enabled: onPressed != null,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(BirdyRadii.pill),
          boxShadow: c.ctaGlow,
        ),
        child: FilledButton.icon(
          key: const ValueKey('onb-finish'),
          style: FilledButton.styleFrom(
            backgroundColor: c.accent,
            foregroundColor: c.onAccent,
            minimumSize: const Size(64, BirdySizes.listen),
            shape: const StadiumBorder(),
            textStyle: BirdyText.labelLarge,
            iconSize: BirdyGlyph.x7l,
          ),
          onPressed: onPressed,
          icon: const BirdyIcon(BirdyIcons.play),
          label: Text(label, textAlign: TextAlign.center),
        ),
      ),
    );
  }
}
