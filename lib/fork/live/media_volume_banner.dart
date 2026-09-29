/// Discreet banner under the listening screen's header when the phone's
/// media volume is muted or low: replayed clips would not be heard (J6h).
/// Hidden when the volume is fine or unknown (iOS, errors).
library;

import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/utils/app_icons.dart';
import '../audio_output/media_volume.dart';
import '../audio_output/media_volume_config.dart';
import '../design/birdy_tokens.dart';
import '../design/birdy_typography.dart';
import '../design/widgets/pressable.dart';

/// What the banner says for a level, null when nothing is wrong.
enum MediaVolumeState {
  muted,
  low;

  static MediaVolumeState? of(double? level) {
    if (level == null) return null;
    if (level <= 0) return muted;
    if (level < MediaVolumeConfig.lowBelow) return low;
    return null;
  }
}

class MediaVolumeBanner extends ConsumerWidget {
  const MediaVolumeBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = MediaVolumeState.of(ref.watch(mediaVolumeLevelProvider).value);
    if (state == null) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
    final title =
        state == MediaVolumeState.muted
            ? l10n.forkVolumeMuted
            : l10n.forkVolumeLow;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: BirdySpace.gutterLive,
        vertical: BirdySpace.xs,
      ),
      child: Container(
        constraints: const BoxConstraints(minHeight: BirdySizes.target),
        padding: const EdgeInsets.only(
          left: BirdySpace.m,
          right: BirdySpace.xs,
        ),
        decoration: BoxDecoration(
          color: c.orioleContainer,
          borderRadius: BorderRadius.circular(BirdyRadii.inset),
        ),
        child: Row(
          children: [
            Icon(
              state == MediaVolumeState.muted
                  ? AppIcons.volumeOffRounded
                  : AppIcons.volumeDown,
              size: 20,
              color: c.orioleText,
            ),
            const SizedBox(width: BirdySpace.s),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: BirdySpace.s),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: BirdyText.label.copyWith(color: c.orioleText),
                    ),
                    Text(
                      l10n.forkVolumeCaption,
                      style: BirdyText.caption.copyWith(color: c.orioleText),
                    ),
                  ],
                ),
              ),
            ),
            Pressable(
              child: Semantics(
                button: true,
                label: l10n.forkVolumeRaise,
                excludeSemantics: true,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap:
                      () => ref
                          .read(mediaVolumeProvider)
                          .setLevel(MediaVolumeConfig.comfortable),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      minHeight: BirdySizes.target,
                      minWidth: BirdySizes.target,
                    ),
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: BirdySpace.m,
                        ),
                        child: Text(
                          l10n.forkVolumeRaise,
                          style: BirdyText.label.copyWith(
                            color: c.orioleText,
                            decoration: TextDecoration.underline,
                            decorationColor: c.orioleText,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
