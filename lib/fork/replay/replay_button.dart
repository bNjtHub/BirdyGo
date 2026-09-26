/// Replay button shown at the end of a live detection row (fork/PLAN.md J2).
library;

import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/live/live_controller.dart';
import '../../features/live/live_session.dart';
import '../../shared/providers/app_providers.dart';
import '../design/widgets/clip_play_button.dart';

/// SharedPreferences key: the replay notice was shown once.
const String kReplayNoticeShown = 'fork_replay_notice_shown';

/// Newest clip per species from session records (newest first).
Map<String, String> latestClipBySpecies(List<DetectionRecord> records) {
  final clips = <String, String>{};
  for (final record in records) {
    final path = record.audioClipPath;
    if (path != null) clips.putIfAbsent(record.scientificName, () => path);
  }
  return clips;
}

/// Trailing widget for a live row: a replay button when a clip exists, a
/// "clip being saved" hint while the species sings and clips are recorded,
/// otherwise null (the row keeps its chevron).
Widget? buildReplayTrailing({
  required LiveController controller,
  required String? clipPath,
  required bool clipPending,
  Widget? badge,
}) {
  final Widget? action =
      clipPath != null
          ? ReplayButton(controller: controller, clipPath: clipPath)
          : clipPending
          ? const _ClipPendingIndicator()
          : null;
  if (badge == null) return action;
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Padding(
        padding: EdgeInsets.only(right: action == null ? 12 : 0),
        child: badge,
      ),
      if (action != null) action,
    ],
  );
}

/// Plays or stops a detection clip without stopping the session.
class ReplayButton extends ConsumerWidget {
  const ReplayButton({
    super.key,
    required this.controller,
    required this.clipPath,
  });

  final LiveController controller;
  final String clipPath;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    return ValueListenableBuilder<String?>(
      valueListenable: controller.replayingClip,
      builder: (context, playing, _) {
        final isPlaying = playing == clipPath;
        return ClipPlayButton(
          state: isPlaying ? ClipPlayState.playing : ClipPlayState.idle,
          semanticLabel: isPlaying ? l10n.forkReplayStop : l10n.forkReplay,
          onPressed: () {
            if (isPlaying) {
              controller.stopReplay();
              return;
            }
            _showNoticeOnce(context, ref, l10n);
            controller.replayClip(clipPath);
          },
        );
      },
    );
  }

  void _showNoticeOnce(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
  ) {
    final prefs = ref.read(sharedPreferencesProvider);
    if (prefs.getBool(kReplayNoticeShown) ?? false) return;
    prefs.setBool(kReplayNoticeShown, true);
    ScaffoldMessenger.maybeOf(
      context,
    )?.showSnackBar(SnackBar(content: Text(l10n.forkReplayNotice)));
  }
}

class _ClipPendingIndicator extends StatelessWidget {
  const _ClipPendingIndicator();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ClipPlayButton(
      state: ClipPlayState.pending,
      semanticLabel: l10n.forkReplayPending,
    );
  }
}
