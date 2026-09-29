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
import '../../shared/utils/app_icons.dart';
import '../design/birdy_motion.dart';
import '../design/birdy_tokens.dart';
import '../design/birdy_typography.dart';
import '../design/widgets/birdy_buttons.dart';
import '../design/widgets/pressable.dart';
import '../settings/fork_prefs.dart';
import 'onboarding_pages.dart';
import 'onboarding_permissions.dart';
import 'onboarding_permissions_page.dart';

class ForkOnboardingScreen extends ConsumerStatefulWidget {
  const ForkOnboardingScreen({super.key});

  /// Story pages, the optional first-name page, then the permissions page.
  static const int pageCount = 5;
  static const int namePage = 3;
  static const int permissionsPage = 4;

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

  bool get _onName => _page == ForkOnboardingScreen.namePage;

  /// « Continuer » on the name page: same preference as the Settings block.
  void _saveName() {
    FocusManager.instance.primaryFocus?.unfocus();
    ref.read(firstNameProvider.notifier).set(_name.text);
    _next();
  }

  /// « Passer » on the name page: nothing saved.
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
                    visible: !_last && !_onName,
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
                      onPressed:
                          () => _goTo(ForkOnboardingScreen.permissionsPage),
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
                onPageChanged: (i) {
                  setState(() => _page = i);
                  if (i == ForkOnboardingScreen.permissionsPage) _refresh();
                },
                children: [
                  const OnboardingWelcomePage(),
                  const OnboardingHowPage(),
                  const OnboardingLevelsPage(),
                  OnboardingNamePage(
                    controller: _name,
                    onSubmitted: _saveName,
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
            _BottomBar(
              page: _page,
              last: _last,
              onName: _onName,
              finishing: _finishing,
              onNext: _onName ? _saveName : _next,
              onSkipName: _skipName,
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
    required this.onName,
    required this.finishing,
    required this.onNext,
    required this.onSkipName,
    required this.onFinish,
  });

  final int page;
  final bool last;
  final bool onName;
  final bool finishing;
  final VoidCallback onNext;
  final VoidCallback onSkipName;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
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
              _Dots(page: page, count: ForkOnboardingScreen.pageCount),
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
                    child: Text(
                      onName ? l10n.forkOnbNameContinue : l10n.next,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              if (onName && !last)
                TextButton(
                  key: const ValueKey('onb-name-skip'),
                  style: TextButton.styleFrom(
                    foregroundColor: c.accentText,
                    minimumSize: const Size.fromHeight(BirdySizes.target),
                    textStyle: BirdyText.label,
                  ),
                  onPressed: onSkipName,
                  child: Text(l10n.skip),
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
    final duration =
        BirdyMotion.reduced(context) ? Duration.zero : BirdyMotion.enter;
    return Semantics(
      label: l10n.forkOnbPageOf(page + 1, count),
      excludeSemantics: true,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < count; i++)
            AnimatedContainer(
              duration: duration,
              curve: BirdyMotion.standard,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: i == page ? 22 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: i == page ? c.accent : c.borderStrong,
                borderRadius: BorderRadius.circular(BirdyRadii.pill),
              ),
            ),
        ],
      ),
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
            textStyle: BirdyText.label.copyWith(fontSize: 20),
            iconSize: 32,
          ),
          onPressed: onPressed,
          icon: const Icon(AppIcons.playArrowRounded, fill: 1),
          label: Text(label, textAlign: TextAlign.center),
        ),
      ),
    );
  }
}
