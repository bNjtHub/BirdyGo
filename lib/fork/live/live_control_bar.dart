/// Bottom bar of the live screen (J6c): « Écouter » before the session,
/// then « Arrêter » and « Pause » / « Reprendre », with a notice above them
/// while a clip is replayed (SPEC.md 5.12).
library;

import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../shared/utils/app_icons.dart';
import '../design/birdy_tokens.dart';
import '../design/birdy_typography.dart';
import '../design/widgets/birdy_buttons.dart';
import '../design/widgets/entrance.dart';
import '../design/widgets/pressable.dart';

enum LiveBarState { idle, starting, active, paused }

class LiveControlBar extends StatelessWidget {
  const LiveControlBar({
    super.key,
    required this.state,
    required this.onStart,
    required this.onStop,
    required this.onPauseToggle,
    required this.replaying,
  });

  final LiveBarState state;
  final VoidCallback onStart;
  final VoidCallback onStop;
  final VoidCallback onPauseToggle;

  /// Clip being replayed, null otherwise.
  final ValueListenable<String?> replaying;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
    final running =
        state == LiveBarState.active || state == LiveBarState.paused;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.backgroundDeep,
        border: Border(top: BorderSide(color: c.line)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            BirdySpace.l,
            BirdySpace.m,
            BirdySpace.l,
            BirdySpace.l,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ValueListenableBuilder<String?>(
                valueListenable: replaying,
                builder:
                    (context, clip, _) =>
                        clip == null || !running
                            ? const SizedBox.shrink()
                            : Padding(
                              padding: const EdgeInsets.only(
                                bottom: BirdySpace.m,
                              ),
                              child: BirdyEntrance(
                                key: ValueKey(clip),
                                child: _ReplayNotice(
                                  text: l10n.forkLiveReplayToast,
                                ),
                              ),
                            ),
              ),
              if (!running)
                ListenButton(
                  onPressed: state == LiveBarState.idle ? onStart : null,
                )
              else
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Pressable(
                        child: FilledButton.icon(
                          style: BirdyButtonStyles.stop(context),
                          onPressed: onStop,
                          icon: const Icon(AppIcons.stop),
                          label: Text(l10n.forkStop),
                        ),
                      ),
                    ),
                    const SizedBox(width: BirdySpace.m),
                    Expanded(
                      flex: 2,
                      child: Pressable(
                        child: OutlinedButton.icon(
                          style: BirdyButtonStyles.pause(context),
                          onPressed: onPauseToggle,
                          icon: Icon(
                            state == LiveBarState.paused
                                ? AppIcons.playArrow
                                : AppIcons.pause,
                          ),
                          label: Text(
                            state == LiveBarState.paused
                                ? l10n.forkResume
                                : l10n.forkPause,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReplayNotice extends StatelessWidget {
  const _ReplayNotice({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final c = BirdyColors.of(context);
    return Semantics(
      liveRegion: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: c.surface3,
          borderRadius: BorderRadius.circular(BirdyRadii.card),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: BirdySpace.l,
            vertical: BirdySpace.m,
          ),
          child: Row(
            children: [
              Icon(AppIcons.volumeDown, size: 20, color: c.accentText),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  text,
                  style: BirdyText.body.copyWith(color: c.text1, fontSize: 15),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
