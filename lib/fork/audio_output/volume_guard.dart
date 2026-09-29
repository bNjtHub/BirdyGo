/// One guard for every place that plays a sound (J6h): call [ensureAudible]
/// right before a playback starts. When the media volume is muted or low, a
/// prompt slides in at the top of the screen (same block as the live
/// banner) with « Monter le son ». It never blocks the playback, and shows
/// at most once per [MediaVolumeConfig.promptCooldown].
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design/birdy_motion.dart';
import '../design/birdy_tokens.dart';
import '../design/widgets/tip_card.dart';
import 'media_volume.dart';
import 'media_volume_config.dart';
import 'media_volume_state.dart';
import 'volume_alert_block.dart';

/// Remembers when the prompt last showed.
class VolumePromptThrottle {
  VolumePromptThrottle({DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;
  DateTime? _last;

  bool get ready {
    final last = _last;
    return last == null ||
        _clock().difference(last) >= MediaVolumeConfig.promptCooldown;
  }

  /// True (and starts the cooldown) when a prompt may show now.
  bool take() {
    if (!ready) return false;
    _last = _clock();
    return true;
  }
}

final volumePromptThrottleProvider = Provider<VolumePromptThrottle>(
  (ref) => VolumePromptThrottle(),
);

/// Fire and forget: checks the volume and prompts if needed. Call it just
/// before starting a playback, do not wait for it.
void ensureAudible(BuildContext context, WidgetRef ref) {
  unawaited(checkAudible(context, ref));
}

/// [ensureAudible], awaitable. Returns true when the prompt was shown.
Future<bool> checkAudible(BuildContext context, WidgetRef ref) async {
  final throttle = ref.read(volumePromptThrottleProvider);
  final volume = ref.read(mediaVolumeProvider);
  if (!throttle.ready) return false;
  final state = MediaVolumeState.of(await volume.level());
  if (state == null || !context.mounted) return false;
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null || !throttle.take()) return false;
  _VolumePrompt.show(
    overlay,
    state,
    () => volume.setLevel(MediaVolumeConfig.comfortable),
  );
  return true;
}

class _VolumePrompt extends StatefulWidget {
  const _VolumePrompt({
    required this.state,
    required this.onRaise,
    required this.onDone,
  });

  final MediaVolumeState state;
  final VoidCallback onRaise;
  final VoidCallback onDone;

  /// Only one prompt at a time.
  static OverlayEntry? _current;

  static void show(
    OverlayState overlay,
    MediaVolumeState state,
    VoidCallback onRaise,
  ) {
    _current?.remove();
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder:
          (_) => _VolumePrompt(
            state: state,
            onRaise: onRaise,
            onDone: () {
              if (entry.mounted) entry.remove();
              if (identical(_current, entry)) _current = null;
            },
          ),
    );
    _current = entry;
    overlay.insert(entry);
  }

  @override
  State<_VolumePrompt> createState() => _VolumePromptState();
}

class _VolumePromptState extends State<_VolumePrompt>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this);
  Timer? _timer;
  bool _leaving = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller.isAnimating || _controller.value > 0) return;
    final reduced = BirdyMotion.reduced(context);
    _controller.duration = reduced ? Duration.zero : BirdyMotion.enter;
    _controller.reverseDuration = reduced ? Duration.zero : BirdyMotion.exit;
    _controller.forward();
    _timer = Timer(MediaVolumeConfig.promptDuration, _leave);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _leave() async {
    if (_leaving) return;
    _leaving = true;
    _timer?.cancel();
    await _controller.reverse();
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(
      parent: _controller,
      curve: BirdyMotion.standard,
    );
    return Positioned(
      top: MediaQuery.paddingOf(context).top + BirdySpace.page,
      left: BirdySpace.page,
      right: BirdySpace.page,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: BirdyTipCard.maxWidth),
          child: FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, -0.15),
                end: Offset.zero,
              ).animate(curved),
              child: Material(
                type: MaterialType.transparency,
                child: VolumeAlertBlock(
                  state: widget.state,
                  floating: true,
                  onRaise: () {
                    widget.onRaise();
                    _leave();
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
