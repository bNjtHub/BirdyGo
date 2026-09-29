/// The block shared by every media volume alert (J6h): the live banner and
/// the prompt before a playback. Oriole disc with the volume icon, title,
/// caption, and a tonal « Monter le son » pill on the right.
library;

import 'dart:ui' show ImageFilter;

import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

import '../../shared/utils/app_icons.dart';
import '../design/birdy_tokens.dart';
import '../design/birdy_typography.dart';
import '../design/widgets/birdy_buttons.dart';
import '../design/widgets/pressable.dart';
import 'media_volume_state.dart';

class VolumeAlertBlock extends StatelessWidget {
  const VolumeAlertBlock({
    super.key,
    required this.state,
    required this.onRaise,
    this.floating = false,
  });

  final MediaVolumeState state;
  final VoidCallback onRaise;

  /// True for the toast over other content: opaque fill (the tint composited
  /// over surface1), blurred backdrop and the float shadow.
  final bool floating;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
    final muted = state == MediaVolumeState.muted;
    final radius = BorderRadius.circular(BirdyRadii.card);
    // The tint is translucent in the dark theme: over other content it must
    // be opaque, so nothing shows through the text.
    final fill =
        floating
            ? Color.alphaBlend(c.orioleContainer, c.surface1)
            : c.orioleContainer;
    Widget block = DecoratedBox(
      decoration: BoxDecoration(
        color: fill,
        borderRadius: radius,
        boxShadow: floating ? c.floatShadow : null,
      ),
      child: Padding(
        padding: const EdgeInsets.all(BirdySpace.m),
        child: Row(
          children: [
            ExcludeSemantics(
              child: Container(
                width: BirdySizes.alertDisc,
                height: BirdySizes.alertDisc,
                decoration: BoxDecoration(
                  color: c.oriole,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  muted ? AppIcons.volumeOffRounded : AppIcons.volumeDown,
                  size: BirdySizes.alertDiscIcon,
                  color: c.onOriole,
                ),
              ),
            ),
            const SizedBox(width: BirdySpace.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    muted ? l10n.forkVolumeMuted : l10n.forkVolumeLow,
                    style: BirdyText.label.copyWith(color: c.text1),
                  ),
                  Text(
                    l10n.forkVolumeCaption,
                    style: BirdyText.caption.copyWith(color: c.text2),
                  ),
                ],
              ),
            ),
            const SizedBox(width: BirdySpace.s),
            Pressable(
              child: FilledButton(
                // The tonal pill turns oriole on the oriole tint (AA in both themes).
                style: BirdyButtonStyles.tonal(context).copyWith(
                  backgroundColor: WidgetStatePropertyAll(c.oriole),
                  foregroundColor: WidgetStatePropertyAll(c.onOriole),
                ),
                onPressed: onRaise,
                child: Text(l10n.forkVolumeRaise),
              ),
            ),
          ],
        ),
      ),
    );
    if (floating) {
      block = ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: BirdySizes.alertBlurSigma,
            sigmaY: BirdySizes.alertBlurSigma,
          ),
          child: block,
        ),
      );
    }
    return Semantics(container: true, liveRegion: true, child: block);
  }
}
