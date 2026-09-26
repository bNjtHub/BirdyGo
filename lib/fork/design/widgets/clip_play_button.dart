/// Clip player button (J6a, SPEC.md 5.1 « Réécouter »): visual only, the
/// caller owns playback (and the inference pause during a replay).
library;

import 'package:flutter/material.dart';

import '../../../shared/utils/app_icons.dart';
import '../birdy_tokens.dart';
import 'pressable.dart';

enum ClipPlayState {
  /// Teal outline and play icon.
  idle,

  /// The clip is still being saved: small spinner, not tappable.
  pending,

  /// Teal fill and stop icon, optional progress ring.
  playing,
}

class ClipPlayButton extends StatelessWidget {
  const ClipPlayButton({
    super.key,
    required this.state,
    required this.semanticLabel,
    this.onPressed,
    this.progress,
  });

  final ClipPlayState state;

  /// Read by screen readers and shown as tooltip (« Réécouter », « Arrêter »).
  final String semanticLabel;

  final VoidCallback? onPressed;

  /// Playback progress from 0 to 1, drawn as a ring while [state] is
  /// [ClipPlayState.playing]. Null draws no ring.
  final double? progress;

  @override
  Widget build(BuildContext context) {
    final c = BirdyColors.of(context);
    const size = BirdySizes.target;

    if (state == ClipPlayState.pending) {
      return Tooltip(
        message: semanticLabel,
        child: Semantics(
          label: semanticLabel,
          child: SizedBox.square(
            dimension: size,
            child: Center(
              child: SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: c.accentText,
                ),
              ),
            ),
          ),
        ),
      );
    }

    final playing = state == ClipPlayState.playing;
    final shape = CircleBorder(
      side:
          playing ? BorderSide.none : BorderSide(color: c.accentText, width: 2),
    );
    Widget button = Material(
      color: playing ? c.accent : Colors.transparent,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        customBorder: shape,
        child: SizedBox.square(
          dimension: size,
          child: Icon(
            playing ? AppIcons.stop : AppIcons.playArrow,
            size: 24,
            fill: 1,
            color: playing ? c.onAccent : c.accentText,
          ),
        ),
      ),
    );
    final ring = progress;
    if (playing && ring != null) {
      button = Stack(
        alignment: Alignment.center,
        children: [
          button,
          IgnorePointer(
            child: SizedBox.square(
              dimension: size - 4,
              child: CircularProgressIndicator(
                value: ring.clamp(0, 1).toDouble(),
                strokeWidth: 2.5,
                color: c.onAccent,
                backgroundColor: Colors.transparent,
              ),
            ),
          ),
        ],
      );
    }
    return Tooltip(
      message: semanticLabel,
      child: Semantics(
        button: true,
        enabled: onPressed != null,
        label: semanticLabel,
        excludeSemantics: true,
        onTap: onPressed,
        child: Pressable(enabled: onPressed != null, child: button),
      ),
    );
  }
}
