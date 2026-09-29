/// The block shared by every media volume alert (J6h): the live banner and
/// the prompt before a playback. Oriole disc with the volume icon, title,
/// caption, and a tonal « Monter le son » pill on the right.
library;

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
  });

  final MediaVolumeState state;
  final VoidCallback onRaise;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
    final muted = state == MediaVolumeState.muted;
    return Semantics(
      container: true,
      liveRegion: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: c.surface1,
          borderRadius: BorderRadius.circular(BirdyRadii.card),
          border: Border.all(color: c.border),
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
                    color: c.orioleContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    muted ? AppIcons.volumeOffRounded : AppIcons.volumeDown,
                    size: BirdySizes.alertDiscIcon,
                    color: c.orioleText,
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
                  style: BirdyButtonStyles.tonal(context),
                  onPressed: onRaise,
                  child: Text(l10n.forkVolumeRaise),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
