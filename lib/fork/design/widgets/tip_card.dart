/// « Le saviez-vous ? » cards of BirdyGo (DESIGN.md « Astuces »).
///
/// One component for every tip or fact shown while the user waits: a card
/// with the tip icon in a Loriot disc (played once as it appears), a small « Le saviez-vous ? » caption,
/// the title and one or two sentences. [BirdyTipCarousel] cycles through a
/// list: tap for the next one, auto-advance otherwise, dots show the place.
library;

import 'dart:async';
import 'dart:math';

import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

import '../../../shared/utils/app_icons.dart';
import '../birdy_motion.dart';
import '../birdy_tokens.dart';
import '../birdy_typography.dart';
import 'birdy_animated_icon.dart';
import 'birdy_step_dots.dart';
import 'entrance.dart';
import 'pressable.dart';

/// One tip: icon and how it moves, short title, one or two sentences.
class BirdyTip {
  const BirdyTip({
    required this.icon,
    required this.title,
    required this.body,
    this.motion = BirdyIconMotion.fill,
  });

  final IconData icon;
  final String title;
  final String body;
  final BirdyIconMotion motion;
}

class BirdyTipCard extends StatelessWidget {
  const BirdyTipCard({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.motion = BirdyIconMotion.fill,
    this.active = true,
    this.footer,
    this.fill = false,
  });

  final IconData icon;
  final String title;
  final String body;

  /// How the icon plays each time the card becomes [active].
  final BirdyIconMotion motion;
  final bool active;

  /// Under the texts, e.g. the carousel dots.
  final Widget? footer;

  /// Fills the height it is given, [footer] pinned to the bottom: every
  /// card of a carousel then has its dots at the same place.
  final bool fill;

  static const double disc = 48;
  static const double discIcon = 24;
  static const double maxWidth = 460;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: maxWidth),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: c.surface1,
          borderRadius: BorderRadius.circular(BirdyRadii.card),
          border: Border.all(color: c.border),
        ),
        child: Padding(
          padding: const EdgeInsets.all(BirdySpace.l),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ExcludeSemantics(
                    child: Container(
                      width: disc,
                      height: disc,
                      decoration: BoxDecoration(
                        color: c.orioleContainer,
                        shape: BoxShape.circle,
                      ),
                      child: BirdyAnimatedIcon(
                        icon: icon,
                        motion: motion,
                        active: active,
                        size: discIcon,
                        color: c.orioleText,
                      ),
                    ),
                  ),
                  const SizedBox(width: BirdySpace.m),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              AppIcons.lightbulbOutline,
                              size: BirdyGlyph.m,
                              color: c.orioleText,
                            ),
                            const SizedBox(width: BirdySpace.xs),
                            Flexible(
                              child: Text(
                                l10n.forkTipHeader,
                                style: BirdyText.caption.copyWith(
                                  color: c.orioleText,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: BirdySpace.xs),
                        Text(
                          title,
                          style: BirdyText.label.copyWith(color: c.text1),
                        ),
                        const SizedBox(height: BirdySpace.xs),
                        Text(
                          body,
                          style: BirdyText.bodyCompact.copyWith(color: c.text2),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              // Centered on the whole card, pinned to the bottom with [fill].
              if (footer != null) ...[
                const SizedBox(height: BirdySpace.m),
                if (fill) const Spacer(),
                Center(child: footer),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Rotating [BirdyTipCard]. Starts on a random tip, advances every
/// [interval] (not with a screen reader), tap for the next one. Every card
/// takes the height of the longest tip, dots at the bottom: nothing moves
/// around it, and the dots stay in place from one tip to the next.
class BirdyTipCarousel extends StatefulWidget {
  const BirdyTipCarousel({
    super.key,
    required this.tips,
    this.interval = const Duration(seconds: 15),
    this.random,
  });

  final List<BirdyTip> tips;
  final Duration interval;

  /// For tests: a seeded start.
  final Random? random;

  @override
  State<BirdyTipCarousel> createState() => _BirdyTipCarouselState();
}

class _BirdyTipCarouselState extends State<BirdyTipCarousel> {
  late int _index;
  Timer? _timer;
  bool _autoRotate = false;

  @override
  void initState() {
    super.initState();
    _index = (widget.random ?? Random()).nextInt(1 << 16);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auto = !MediaQuery.accessibleNavigationOf(context);
    if (auto == _autoRotate) return;
    _autoRotate = auto;
    _restartTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _restartTimer() {
    _timer?.cancel();
    if (!_autoRotate) return;
    _timer = Timer.periodic(widget.interval, (_) {
      if (mounted) setState(() => _index++);
    });
  }

  void _next() {
    setState(() => _index++);
    _restartTimer();
  }

  @override
  Widget build(BuildContext context) {
    final tips = widget.tips;
    if (tips.isEmpty) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context)!;
    final current = _index % tips.length;
    final duration =
        BirdyMotion.reduced(context) ? Duration.zero : BirdyMotion.enter;
    final dots = _Dots(count: tips.length, current: current);

    // Every tip is laid out, only the current one shows: the stack takes
    // the height of the longest, and the switch is a cross-fade.
    return BirdyEntrance(
      child: Semantics(
        button: true,
        onTapHint: l10n.forkTipNext,
        child: Pressable(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _next,
            // Intrinsic height: the stack measures the longest tip, then
            // every card is stretched to it.
            child: IntrinsicHeight(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  for (final (i, tip) in tips.indexed)
                    IgnorePointer(
                      ignoring: i != current,
                      child: ExcludeSemantics(
                        excluding: i != current,
                        child: AnimatedOpacity(
                          opacity: i == current ? 1 : 0,
                          duration: duration,
                          curve: BirdyMotion.standard,
                          child: BirdyTipCard(
                            icon: tip.icon,
                            title: tip.title,
                            body: tip.body,
                            motion: tip.motion,
                            active: i == current,
                            footer: dots,
                            fill: true,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Place in the carousel. Many tips: the dots stay small and wrap,
/// centered.
class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.current});

  final int count;
  final int current;

  @override
  Widget build(BuildContext context) {
    final c = BirdyColors.of(context);
    return BirdyStepDots(
      count: count,
      current: current,
      activeColor: c.orioleText,
      inactiveColor: c.progressTrack,
      height: BirdySpace.tight,
      activeWidth: 14,
      gap: 5,
    );
  }
}
