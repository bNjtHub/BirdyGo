/// Last page of the BirdyGo onboarding (J6g-a): the microphone (needed) and
/// the location (optional), each with one plain sentence on why, a 56 dp
/// button and a state (allowed, or refused with « Ouvrir les réglages »).
/// Refusing the location never blocks; refusing the microphone says it is
/// needed to listen. The upstream consent line and links sit under the cards.
library;

import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../shared/providers/settings_providers.dart';
import '../../shared/services/link_launcher.dart';
import '../../shared/utils/app_icons.dart';
import '../design/birdy_tokens.dart';
import '../design/birdy_typography.dart';
import '../design/widgets/birdy_block.dart';
import '../design/widgets/birdy_buttons.dart';
import '../design/widgets/pressable.dart';
import 'onboarding_pages.dart';
import 'onboarding_permissions.dart';
import '../design/birdy_icons.dart';

class OnboardingPermissionsPage extends ConsumerWidget {
  const OnboardingPermissionsPage({
    super.key,
    required this.mic,
    required this.location,
    required this.busyMic,
    required this.busyLocation,
    required this.onAllowMic,
    required this.onAllowLocation,
    required this.onOpenSettings,
  });

  final OnboardingPermState mic;
  final OnboardingPermState location;
  final bool busyMic;
  final bool busyLocation;
  final VoidCallback onAllowMic;
  final VoidCallback onAllowLocation;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
    return OnboardingPageFrame(
      builder:
          (context, height) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              OnboardingTitle(l10n.forkOnbPermsTitle),
              const SizedBox(height: BirdySpace.xl),
              _PermissionCard(
                key: const ValueKey('onb-mic'),
                id: 'onb-mic',
                tone: BirdyBlockTone.tonal,
                icon: BirdyIcons.heard,
                name: l10n.forkOnbMicName,
                tag: l10n.forkOnbNeeded,
                why: l10n.forkOnbMicWhy,
                state: mic,
                busy: busyMic,
                allowLabel: l10n.forkOnbMicAllow,
                refusedText: l10n.forkOnbMicRefused,
                unavailableText: l10n.forkOnbMicRefused,
                onAllow: onAllowMic,
                onOpenSettings: onOpenSettings,
              ),
              const SizedBox(height: BirdySpace.block),
              _PermissionCard(
                key: const ValueKey('onb-location'),
                id: 'onb-location',
                tone: BirdyBlockTone.oriole,
                icon: BirdyIcons.place,
                name: l10n.forkOnbLocName,
                tag: l10n.forkOnbOptional,
                why: l10n.forkOnbLocWhy,
                state: location,
                busy: busyLocation,
                allowLabel: l10n.forkOnbLocAllow,
                refusedText: l10n.forkOnbLocRefused,
                unavailableText: l10n.forkOnbLocOff,
                onAllow: onAllowLocation,
                onOpenSettings: onOpenSettings,
              ),
              const SizedBox(height: BirdySpace.block),
              _PermissionCard.custom(
                key: const ValueKey('onb-map'),
                id: 'onb-map',
                tone: BirdyBlockTone.tonal,
                icon: BirdyIcons.map,
                name: l10n.forkOnbMapName,
                tag: l10n.forkOnbOptional,
                why: l10n.forkOnbMapWhy,
                action: const _MapChoice(),
              ),
              const SizedBox(height: BirdySpace.l),
              Text(
                l10n.forkOnbConsent,
                style: BirdyText.caption.copyWith(color: c.text2),
              ),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: Wrap(
                  children: [
                    _LinkButton(
                      label: l10n.onboardingTermsLink,
                      path: '/acceptable-use/',
                    ),
                    _LinkButton(
                      label: l10n.onboardingPrivacyLink,
                      path: '/privacy/',
                    ),
                  ],
                ),
              ),
            ],
          ),
    );
  }
}

class _PermissionCard extends StatelessWidget {
  const _PermissionCard({
    super.key,
    required this.id,
    required this.tone,
    required this.icon,
    required this.name,
    required this.tag,
    required this.why,
    required this.state,
    required this.busy,
    required this.allowLabel,
    required this.refusedText,
    required this.unavailableText,
    required this.onAllow,
    required this.onOpenSettings,
  }) : action = null;

  /// A card whose body is [action] instead of a permission button (the
  /// online map question: nothing to ask the system).
  const _PermissionCard.custom({
    super.key,
    required this.id,
    required this.tone,
    required this.icon,
    required this.name,
    required this.tag,
    required this.why,
    required Widget this.action,
  }) : state = OnboardingPermState.unknown,
       busy = false,
       allowLabel = '',
       refusedText = '',
       unavailableText = '',
       onAllow = _noop,
       onOpenSettings = _noop;

  final String id;
  final BirdyBlockTone tone;
  final IconData icon;
  final String name;
  final String tag;
  final String why;
  final OnboardingPermState state;
  final bool busy;
  final String allowLabel;
  final String refusedText;
  final String unavailableText;
  final VoidCallback onAllow;
  final VoidCallback onOpenSettings;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
    final stateWidget = action ?? switch (state) {
      OnboardingPermState.granted => Semantics(
        liveRegion: true,
        child: Row(
          children: [
            BirdyIcon(
              BirdyIcons.confirmed,
              active: true,
              size: BirdyGlyph.x5l,
              color: c.sure.foreground,
            ),
            const SizedBox(width: BirdySpace.s),
            Expanded(
              child: Text(
                l10n.forkOnbGranted,
                style: BirdyText.label.copyWith(color: c.sure.foreground),
              ),
            ),
          ],
        ),
      ),
      OnboardingPermState.unavailable => Semantics(
        liveRegion: true,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(AppIcons.locationOffRounded, size: BirdyGlyph.x3l),
            const SizedBox(width: BirdySpace.s),
            Expanded(
              child: Text(
                unavailableText,
                style: BirdyText.bodyCompact.copyWith(color: c.text1),
              ),
            ),
          ],
        ),
      ),
      OnboardingPermState.refused => Semantics(
        liveRegion: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              refusedText,
              style: BirdyText.bodyCompact.copyWith(
                color: c.text1,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: BirdySpace.m),
            Pressable(
              child: OutlinedButton.icon(
                key: ValueKey('$id-settings'),
                style: BirdyButtonStyles.secondary(context),
                onPressed: onOpenSettings,
                icon: const BirdyIcon(BirdyIcons.settings),
                label: Text(l10n.forkOnbOpenSettings),
              ),
            ),
          ],
        ),
      ),
      OnboardingPermState.unknown => Pressable(
        enabled: !busy,
        child: FilledButton(
          key: ValueKey('$id-allow'),
          style: BirdyButtonStyles.primary(context),
          onPressed: busy ? null : onAllow,
          child: Text(allowLabel, textAlign: TextAlign.center),
        ),
      ),
    };
    return BirdyBlock(
      tone: tone,
      padding: const EdgeInsets.all(BirdySpace.l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: BirdySizes.target,
                height: BirdySizes.target,
                decoration: BoxDecoration(
                  color: c.surface1,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: BirdyGlyph.x4l, color: c.accentText),
              ),
              const SizedBox(width: BirdySpace.m),
              Expanded(
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: BirdySpace.s,
                  children: [
                    Semantics(
                      header: true,
                      child: Text(
                        name,
                        style: BirdyText.heading.copyWith(color: c.text1),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: BirdySpace.s,
                        vertical: BirdySpace.xxs,
                      ),
                      decoration: BoxDecoration(
                        color: c.surface1,
                        borderRadius: BorderRadius.circular(BirdyRadii.pill),
                      ),
                      child: Text(
                        tag,
                        style: BirdyText.caption.copyWith(
                          color: c.text1,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: BirdySpace.m),
          Text(why, style: BirdyText.body.copyWith(color: c.text1)),
          const SizedBox(height: BirdySpace.m),
          stateWidget,
        ],
      ),
    );
  }
}

void _noop() {}

/// « Afficher la carte en ligne ? »: upstream's map-tiles consent
/// (`privacyAllowMapProvider`) as two plain buttons. Nothing is preselected;
/// « Non » is the default value of the setting, but the question is asked.
/// The choice can be changed until the page is left.
class _MapChoice extends ConsumerStatefulWidget {
  const _MapChoice();

  @override
  ConsumerState<_MapChoice> createState() => _MapChoiceState();
}

class _MapChoiceState extends ConsumerState<_MapChoice> {
  bool? _choice;

  @override
  void initState() {
    super.initState();
    if (ref.read(privacyAllowMapProvider)) _choice = true;
  }

  void _pick(bool allow) {
    setState(() => _choice = allow);
    ref.read(privacyAllowMapProvider.notifier).set(allow);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
    final yes = _choice == true;
    final no = _choice == false;
    const selectedIcon = BirdyIcon(BirdyIcons.tick);
    final fullWidth = WidgetStatePropertyAll(
      const Size.fromHeight(BirdySizes.target),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          button: true,
          selected: yes,
          excludeSemantics: true,
          label: l10n.forkOnbMapYes,
          onTap: () => _pick(true),
          child: Pressable(
            child: FilledButton.icon(
              key: const ValueKey('onb-map-yes'),
              style: BirdyButtonStyles.tonal(context).copyWith(
                minimumSize: fullWidth,
                backgroundColor: WidgetStatePropertyAll(
                  yes ? c.accent : c.tonal,
                ),
                foregroundColor: WidgetStatePropertyAll(
                  yes ? c.onAccent : c.accentText,
                ),
              ),
              onPressed: () => _pick(true),
              icon: yes ? selectedIcon : null,
              label: Text(l10n.forkOnbMapYes, textAlign: TextAlign.center),
            ),
          ),
        ),
        const SizedBox(height: BirdySpace.s),
        Semantics(
          button: true,
          selected: no,
          excludeSemantics: true,
          label: l10n.forkOnbMapNo,
          onTap: () => _pick(false),
          child: Pressable(
            child: TextButton.icon(
              key: const ValueKey('onb-map-no'),
              style: TextButton.styleFrom(
                foregroundColor: c.accentText,
                backgroundColor: no ? c.tonal : null,
                minimumSize: const Size.fromHeight(BirdySizes.target),
                shape: const StadiumBorder(),
                textStyle: BirdyText.labelCompact,
              ),
              onPressed: () => _pick(false),
              icon: no ? selectedIcon : null,
              label: Text(l10n.forkOnbMapNo, textAlign: TextAlign.center),
            ),
          ),
        ),
      ],
    );
  }
}

class _LinkButton extends StatelessWidget {
  const _LinkButton({required this.label, required this.path});

  final String label;
  final String path;

  @override
  Widget build(BuildContext context) {
    final c = BirdyColors.of(context);
    return TextButton(
      style: TextButton.styleFrom(
        foregroundColor: c.accentText,
        minimumSize: const Size(BirdySizes.target, BirdySizes.target),
        textStyle: BirdyText.labelCompact,
      ),
      onPressed: () {
        final code = Localizations.localeOf(context).languageCode;
        final base = AppConstants.policyDocsLocalePrefix(code);
        openExternalUrl(context, '${AppConstants.docsUrl}$base$path');
      },
      child: Text(label),
    );
  }
}
