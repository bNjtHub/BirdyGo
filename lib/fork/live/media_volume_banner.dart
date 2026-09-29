/// Banner under the listening screen's header when the phone's media volume
/// is muted or low: replayed clips would not be heard (J6h). Hidden when the
/// volume is fine or unknown (iOS, errors). It grows and fades in, and
/// folds away, so the list below never jumps.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../audio_output/media_volume.dart';
import '../audio_output/media_volume_config.dart';
import '../audio_output/media_volume_state.dart';
import '../audio_output/volume_alert_block.dart';
import '../design/birdy_motion.dart';
import '../design/birdy_tokens.dart';

class MediaVolumeBanner extends ConsumerStatefulWidget {
  const MediaVolumeBanner({super.key});

  @override
  ConsumerState<MediaVolumeBanner> createState() => _MediaVolumeBannerState();
}

class _MediaVolumeBannerState extends ConsumerState<MediaVolumeBanner> {
  /// Kept while the banner folds away, so it does not empty as it leaves.
  MediaVolumeState? _shown;

  @override
  Widget build(BuildContext context) {
    final state = MediaVolumeState.of(ref.watch(mediaVolumeLevelProvider).value);
    if (state != null) _shown = state;
    final visible = state != null;
    final duration =
        BirdyMotion.reduced(context)
            ? Duration.zero
            : visible
            ? BirdyMotion.enter
            : BirdyMotion.exit;
    final shown = _shown;
    final body = shown == null ? null : _Body(state: shown);
    return AnimatedSize(
      duration: duration,
      curve: BirdyMotion.standard,
      alignment: Alignment.topCenter,
      child:
          body == null
              ? const SizedBox(width: double.infinity)
              : AnimatedOpacity(
                opacity: visible ? 1 : 0,
                duration: duration,
                curve: BirdyMotion.standard,
                child: visible ? body : IgnorePointer(child: body),
              ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.state});

  final MediaVolumeState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: BirdySpace.gutterLive,
        vertical: BirdySpace.xs,
      ),
      child: VolumeAlertBlock(
        state: state,
        onRaise:
            () => ref
                .read(mediaVolumeProvider)
                .setLevel(MediaVolumeConfig.comfortable),
      ),
    );
  }
}
