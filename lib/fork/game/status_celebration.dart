/// « Nouveau statut » (J6e, SPEC.md 9.7, fork/DESIGN.md): the emblem fades
/// in (scale 0.97 → 1, 300 ms), the text follows 60 ms later, one light
/// vibration, and one confetti burst leaves the emblem once it is in
/// (J6f, `BirdyConfetti`, none with reduced motion). Plays once per status,
/// in the Bilan or on the home screen, never while listening.
library;

import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/live/live_providers.dart';
import '../../features/live/live_controller.dart';
import '../../shared/providers/app_providers.dart';
import '../design/birdy_motion.dart';
import '../design/birdy_theme.dart';
import '../design/birdy_theme_choice.dart';
import '../design/birdy_tokens.dart';
import '../design/birdy_typography.dart';
import '../design/widgets/birdy_buttons.dart';
import '../design/widgets/birdy_confetti.dart';
import 'game_config.dart';
import 'game_progress.dart';
import 'game_text.dart';
import 'game_widgets.dart';
import 'moment_appear.dart';

const String kStatusCelebratedPref = 'fork_status_celebrated';

/// Rank of the last status celebrated.
class StatusCelebrationStore {
  StatusCelebrationStore(this._prefs);

  final SharedPreferences _prefs;

  int? read() => _prefs.getInt(kStatusCelebratedPref);

  Future<void> write(int rank) => _prefs.setInt(kStatusCelebratedPref, rank);
}

final statusCelebrationStoreProvider = Provider<StatusCelebrationStore>(
  (ref) => StatusCelebrationStore(ref.watch(sharedPreferencesProvider)),
);

/// Shows [NewStatusScreen] if [progress] reached a status never celebrated,
/// when [context]'s route is on top and no listening runs. The first time
/// ever, the current status is recorded silently (statuses reached before
/// the game existed are not new).
Future<void> maybeCelebrateStatus(
  BuildContext context,
  WidgetRef ref,
  GameProgress progress,
) async {
  final store = ref.read(statusCelebrationStoreProvider);
  final rank = progress.status?.rank ?? 0;
  final celebrated = store.read();
  if (celebrated == null) {
    await store.write(rank);
    return;
  }
  if (rank <= celebrated) return;
  final live = ref.read(liveStateProvider);
  if (live == LiveState.active || live == LiveState.paused) return;
  if (!context.mounted || !(ModalRoute.of(context)?.isCurrent ?? true)) return;
  await store.write(rank);
  if (!context.mounted) return;
  await Navigator.of(context).push(
    PageRouteBuilder<void>(
      opaque: true,
      transitionDuration: BirdyMotion.enter,
      reverseTransitionDuration: BirdyMotion.exit,
      pageBuilder: (_, _, _) => NewStatusScreen(progress: progress),
      transitionsBuilder:
          (_, animation, _, child) =>
              FadeTransition(opacity: animation, child: child),
    ),
  );
}

class NewStatusScreen extends StatefulWidget {
  const NewStatusScreen({super.key, required this.progress});

  final GameProgress progress;

  @override
  State<NewStatusScreen> createState() => _NewStatusScreenState();
}

class _NewStatusScreenState extends State<NewStatusScreen> {
  @override
  void initState() {
    super.initState();
    BirdyHaptics.light();
  }

  @override
  Widget build(BuildContext context) {
    final progress = widget.progress;
    final status = progress.status ?? GameConfig.statuses.first;
    final next = progress.next;
    return Theme(
      data: BirdyTheme.dark(bird: BirdyBrandColors.of(context).bird),
      child: Builder(
        builder: (context) {
          final l10n = AppLocalizations.of(context)!;
          final c = BirdyColors.of(context);
          final name = statusName(l10n, status);
          return Scaffold(
            backgroundColor: c.background,
            body: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.32),
                  radius: 0.9,
                  colors: [
                    status.color.withValues(alpha: BirdyMotion.tintMaxOpacity),
                    status.color.withValues(alpha: 0),
                  ],
                ),
              ),
              child: SafeArea(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 600),
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(
                        BirdySpace.xl,
                        BirdySpace.xxxl * BirdySpace.xxs,
                        BirdySpace.xl,
                        BirdySpace.xxl,
                      ),
                      children: [
                        Center(
                          child: Stack(
                            alignment: Alignment.center,
                            clipBehavior: Clip.none,
                            children: [
                              MomentAppear(
                                child: StatusEmblem(status: status, size: BirdyGlyph.disc136),
                              ),
                              BirdyConfetti.burst(
                                colors: [
                                  status.color,
                                  ...BirdyConfettiColors.burstOf(context),
                                ],
                                delay: BirdyMotion.newStatus,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: BirdySpace.xl),
                        MomentAppear(
                          delay: BirdyMotion.newStatusTextDelay,
                          child: Column(
                            children: [
                              Semantics(
                                header: true,
                                child: Text(
                                  l10n.forkStatusBecome(name),
                                  textAlign: TextAlign.center,
                                  style: BirdyText.display.copyWith(
                                    color: c.text1,
                                  ),
                                ),
                              ),
                              const SizedBox(height: BirdySpace.m),
                              Text(
                                l10n.forkStatusReached(
                                  progress.verified,
                                  statusLine(l10n, status),
                                ),
                                textAlign: TextAlign.center,
                                style: BirdyText.body.copyWith(color: c.text2),
                              ),
                              if (next != null) ...[
                                const SizedBox(height: BirdySpace.xl),
                                _NextCard(progress: progress, next: next),
                              ],
                              const SizedBox(height: BirdySpace.xl),
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton(
                                  style: BirdyButtonStyles.primary(context),
                                  onPressed: () => Navigator.of(context).pop(),
                                  child: Text(l10n.forkStatusContinue),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _NextCard extends StatelessWidget {
  const _NextCard({required this.progress, required this.next});

  final GameProgress progress;
  final StatusDef next;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.surface1,
        borderRadius: BorderRadius.circular(BirdyRadii.card),
      ),
      child: Padding(
        padding: const EdgeInsets.all(BirdySpace.l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.forkStatusNextTitle,
              style: BirdyText.caption.copyWith(color: c.text2),
            ),
            const SizedBox(height: BirdySpace.s),
            Row(
              children: [
                StatusEmblem(status: next, size: BirdyGlyph.disc40, reached: false),
                const SizedBox(width: BirdySpace.m),
                Expanded(
                  child: Text(
                    l10n.forkStatusNextAt(statusName(l10n, next), next.from),
                    style: BirdyText.species.copyWith(color: c.text1),
                  ),
                ),
              ],
            ),
            const SizedBox(height: BirdySpace.s),
            Text(
              l10n.forkStatusNext(progress.remaining, statusName(l10n, next)),
              style: BirdyText.caption.copyWith(color: c.text2),
            ),
          ],
        ),
      ),
    );
  }
}
