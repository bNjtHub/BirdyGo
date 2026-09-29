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
import '../design/widgets/birdy_switch.dart';
import '../design/widgets/pressable.dart';
import 'onboarding_pages.dart';
import 'onboarding_permissions.dart';

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
                icon: AppIcons.micRounded,
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
                icon: AppIcons.locationOnRounded,
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
                extra: const _MapSwitchRow(),
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
    this.extra,
  });

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
  final Widget? extra;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
    final stateWidget = switch (state) {
      OnboardingPermState.granted => Semantics(
        liveRegion: true,
        child: Row(
          children: [
            Icon(
              AppIcons.checkCircleRounded,
              size: BirdyGlyph.x5l,
              fill: 1,
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
                icon: const Icon(AppIcons.tuneRounded),
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
          if (extra != null) ...[const SizedBox(height: BirdySpace.s), extra!],
        ],
      ),
    );
  }
}

/// « Afficher la carte en ligne »: upstream's map-tiles consent
/// (`privacyAllowMapProvider`), off until the person turns it on.
class _MapSwitchRow extends ConsumerWidget {
  const _MapSwitchRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
    final on = ref.watch(privacyAllowMapProvider);
    void toggle(bool v) => ref.read(privacyAllowMapProvider.notifier).set(v);
    return Semantics(
      toggled: on,
      label: l10n.forkOnbMapSwitch,
      excludeSemantics: true,
      onTap: () => toggle(!on),
      child: InkWell(
        key: const ValueKey('onb-map-switch'),
        borderRadius: BorderRadius.circular(BirdyRadii.thumb),
        onTap: () => toggle(!on),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: BirdySizes.target),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  l10n.forkOnbMapSwitch,
                  style: BirdyText.label.copyWith(color: c.text1),
                ),
              ),
              const SizedBox(width: BirdySpace.m),
              IgnorePointer(
                child: BirdySwitch(value: on, onChanged: toggle),
              ),
            ],
          ),
        ),
      ),
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
