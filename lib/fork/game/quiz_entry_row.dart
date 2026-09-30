/// « Qui chante ? » entry row (J6h): the same row as the Profil's quiz entry
/// (`_QuizEntry` in profile_screen.dart), shared so other screens (the
/// species page) can show it with their own subtitle.
library;

import 'package:birdnet_live/l10n/app_localizations.dart';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../shared/utils/app_icons.dart';
import '../design/birdy_motion.dart';
import '../design/birdy_tokens.dart';
import '../design/birdy_typography.dart';
import '../design/widgets/pressable.dart';
import 'fine_ear_quiz_screen.dart';
import 'game_progress.dart';
import 'quiz_fx.dart';
import 'quiz_intro.dart' show QuizTitleMark;
import 'quiz_logo.dart';

class QuizEntryRow extends StatelessWidget {
  const QuizEntryRow({
    super.key,
    this.subtitle,
    this.onTap,
    this.bordered = false,
    this.progress,
  });

  /// Defaults to the Profil's line.
  final String? subtitle;

  /// Defaults to opening the quiz.
  final VoidCallback? onTap;

  /// A hairline outline (the Profil's look, on its background).
  final bool bordered;

  /// The Oreille fine badge progress: the hook replaces the subtitle and a
  /// segmented bar shows the way to the next plume (the Accueil block).
  final BadgeProgress? progress;

  /// Segments filled on the bar: the share of the way from the previous tier
  /// to the next one, rounded down; all of them once the last tier is won.
  static int filledSegments(BadgeProgress progress) {
    const total = BirdySizes.quizEntrySegments;
    final next = progress.nextTarget;
    if (next == null) return total;
    final tier = progress.tier;
    final from = tier == 0 ? 0 : progress.tiers[tier - 1];
    final share = (progress.value - from) / (next - from);
    return (share * total).floor().clamp(0, total);
  }

  static String _hook(AppLocalizations l10n, BadgeProgress progress) =>
      switch (progress.tier) {
        0 => l10n.forkQuizEntryHook(progress.nextTarget! - progress.value),
        1 => l10n.forkQuizEntryHookNext,
        2 => l10n.forkQuizEntryHookTier('two'),
        _ => l10n.forkQuizEntryHookTier('all'),
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
    final progress = this.progress;
    final line =
        progress != null
            ? _hook(l10n, progress)
            : subtitle ?? l10n.forkQuizEntrySubtitle;
    return Semantics(
      label: '${l10n.forkQuizTitle}. $line',
      button: true,
      excludeSemantics: true,
      child: Pressable(
        child: Material(
          color: c.surface1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(BirdyRadii.card),
            side: bordered ? BorderSide(color: c.line) : BorderSide.none,
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap:
                onTap ??
                () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const FineEarQuizScreen(),
                  ),
                ),
            child: Padding(
              padding: const EdgeInsets.all(BirdySpace.l),
              child: Row(
                children: [
                  const ExcludeSemantics(child: _LogoBounceOnce()),
                  const SizedBox(width: BirdySpace.l),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // The intro's title: the word and the oriole « ? ».
                        Text.rich(
                          TextSpan(
                            style: BirdyText.heading.copyWith(color: c.text1),
                            children: [
                              TextSpan(text: l10n.forkQuizTitleWord),
                              const WidgetSpan(
                                alignment: PlaceholderAlignment.middle,
                                child: SizedBox(width: BirdySpace.xxs),
                              ),
                              const WidgetSpan(
                                alignment: PlaceholderAlignment.middle,
                                baseline: TextBaseline.alphabetic,
                                child: QuizTitleMark(
                                  size: BirdySizes.quizEntryMark,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: BirdySpace.xs),
                        Text(
                          line,
                          style: (progress != null
                                  ? BirdyText.caption
                                  : BirdyText.bodyCompact)
                              .copyWith(color: c.text2),
                        ),
                        if (progress != null) ...[
                          const SizedBox(height: BirdySpace.snug),
                          _SegmentBar(filled: filledSegments(progress)),
                        ],
                      ],
                    ),
                  ),
                  Icon(AppIcons.chevronRight, color: c.text2),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SegmentBar extends StatelessWidget {
  const _SegmentBar({required this.filled});

  final int filled;

  @override
  Widget build(BuildContext context) {
    final c = BirdyColors.of(context);
    return ExcludeSemantics(
      child: Row(
        children: [
          for (var i = 0; i < BirdySizes.quizEntrySegments; i++) ...[
            if (i > 0) const SizedBox(width: BirdySpace.thin),
            Expanded(
              child: Container(
                key: ValueKey(
                  i < filled ? 'quiz-segment-on' : 'quiz-segment-off',
                ),
                height: BirdySizes.quizEntrySegmentHeight,
                decoration: BoxDecoration(
                  color: i < filled ? c.accent : c.line,
                  borderRadius: BorderRadius.circular(BirdyRadii.pill),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The logo with the intro's bob and tilt (qz-bounce), played once as the row
/// appears, never in a loop; still under reduced motion.
class _LogoBounceOnce extends StatefulWidget {
  const _LogoBounceOnce();

  @override
  State<_LogoBounceOnce> createState() => _LogoBounceOnceState();
}

class _LogoBounceOnceState extends State<_LogoBounceOnce>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: QuizMotion.bounce,
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started && !BirdyMotion.reduced(context)) {
      _started = true;
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: AnimatedBuilder(
      animation: _controller,
      child: const QuizLogo(),
      builder: (context, child) {
        final t = _controller.value;
        final dy = quizKeyframes(
          t,
          const [0, 0.5, 1],
          const [0, -8, 0],
          QuizMotion.bounceEase,
        );
        final deg = quizKeyframes(
          t,
          const [0, 0.5, 1],
          const [0, 3, 0],
          QuizMotion.bounceEase,
        );
        return Transform.translate(
          offset: Offset(0, dy),
          child: Transform.rotate(angle: deg * math.pi / 180, child: child),
        );
      },
    ),
  );
}
