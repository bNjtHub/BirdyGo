/// Bottom bar of the listening screen (J6c, SPEC.md 9.2): « Arrêter » and
/// « Pause » / « Reprendre » while listening, « Écouter » before; a toast
/// above the buttons while a clip is replayed (SPEC.md 5.12).
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

enum LiveControlPhase {
  /// No session: « Écouter ».
  idle,

  /// The model loads or the session starts: « Écouter », busy.
  starting,

  active,
  paused,
}

class LiveControlBar extends StatelessWidget {
  const LiveControlBar({
    super.key,
    required this.phase,
    required this.onStart,
    required this.onStop,
    required this.onTogglePause,
    this.replaying,
  });

  final LiveControlPhase phase;
  final VoidCallback onStart;
  final VoidCallback onStop;
  final VoidCallback onTogglePause;

  /// Clip being replayed (null when none): shows the toast.
  final ValueListenable<String?>? replaying;

  @override
  Widget build(BuildContext context) {
    final c = BirdyColors.of(context);
    final bottom = MediaQuery.paddingOf(context).bottom;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.backgroundDeep,
        border: Border(top: BorderSide(color: c.line)),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          BirdySpace.l,
          BirdySpace.m,
          BirdySpace.l,
          BirdySpace.l + bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (replaying != null)
              ValueListenableBuilder<String?>(
                valueListenable: replaying!,
                builder:
                    (context, clip, _) =>
                        clip == null ||
                                !(phase == LiveControlPhase.active ||
                                    phase == LiveControlPhase.paused)
                            ? const SizedBox.shrink()
                            : const Padding(
                              padding: EdgeInsets.only(bottom: 10),
                              child: BirdyEntrance(child: _ReplayToast()),
                            ),
              ),
            switch (phase) {
              LiveControlPhase.idle ||
              LiveControlPhase.starting => _StartButton(
                busy: phase == LiveControlPhase.starting,
                onPressed: onStart,
              ),
              LiveControlPhase.active ||
              LiveControlPhase.paused => _SessionButtons(
                paused: phase == LiveControlPhase.paused,
                onStop: onStop,
                onTogglePause: onTogglePause,
              ),
            },
          ],
        ),
      ),
    );
  }
}

class _StartButton extends StatelessWidget {
  const _StartButton({required this.busy, required this.onPressed});

  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
    return Pressable(
      enabled: !busy,
      child: FilledButton.icon(
        onPressed: busy ? null : onPressed,
        style: BirdyButtonStyles.primary(context).copyWith(
          minimumSize: const WidgetStatePropertyAll(
            Size.fromHeight(BirdySizes.liveControl),
          ),
        ),
        icon:
            busy
                ? SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: c.text2,
                  ),
                )
                : const Icon(AppIcons.graphicEq),
        label: Text(l10n.forkListen),
      ),
    );
  }
}

class _SessionButtons extends StatelessWidget {
  const _SessionButtons({
    required this.paused,
    required this.onStop,
    required this.onTogglePause,
  });

  final bool paused;
  final VoidCallback onStop;
  final VoidCallback onTogglePause;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Row(
      children: [
        Expanded(
          child: Pressable(
            child: FilledButton.icon(
              onPressed: onStop,
              style: BirdyButtonStyles.stop(context),
              icon: const Icon(AppIcons.stopRounded),
              label: Text(l10n.forkStop),
            ),
          ),
        ),
        const SizedBox(width: BirdySpace.m),
        Expanded(
          child: Pressable(
            child: OutlinedButton.icon(
              onPressed: onTogglePause,
              style: BirdyButtonStyles.pause(context),
              icon: Icon(
                paused ? AppIcons.playArrowRounded : AppIcons.pauseRounded,
              ),
              label: Text(paused ? l10n.forkResume : l10n.forkPause),
            ),
          ),
        ),
      ],
    );
  }
}

class _ReplayToast extends StatelessWidget {
  const _ReplayToast();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
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
                  l10n.forkLiveReplayToast,
                  style: BirdyText.bodyCompact.copyWith(color: c.text1),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
