/// The themed BirdyGo mark in a tonal disc (J6i): the bird of the chosen
/// theme, drawn by [BirdyGoSingingPainter], in a disc filled with the
/// theme's tonal color and a white halo.
///
/// Shared by the onboarding (steps 1 and 2, 132 dp), the bird picker's cards
/// (72 dp, still) and the Settings row (a small still disc), so the emblem is
/// the same everywhere.
///
/// It sings one phrase on arrival and on a tap, and again whenever
/// [singSignal] changes (the picker bumps it when a card is tapped). Never a
/// loop. Reduced motion: the settled mark, nothing moves.
library;

import 'package:flutter/material.dart';

import '../../home/singing_logo.dart' show SingingLogo;
import '../../splash/birdygo_splash_painter.dart';
import '../birdy_motion.dart';
import '../birdy_theme_choice.dart';
import '../birdy_tokens.dart';

class SingingThemeLogo extends StatefulWidget {
  const SingingThemeLogo({
    super.key,
    this.bird,
    this.size = BirdySizes.themeLogoDisc,
    this.markWidth = BirdySizes.themeLogoMark,
    this.halo = true,
    this.sings = true,
    this.singSignal = 0,
  });

  /// The bird to draw; the theme's own bird (`BirdyBrandColors.of`) when
  /// null, so the disc follows the app as it is previewed.
  final BirdyBird? bird;

  /// Diameter of the disc.
  final double size;

  /// Width of the logo inside the disc.
  final double markWidth;

  /// White halo around the disc (the big onboarding disc only).
  final bool halo;

  /// False: a still mark (cards, Settings row), no tap, no arrival phrase.
  final bool sings;

  /// A change of this value makes the bird sing one phrase.
  final int singSignal;

  @override
  State<SingingThemeLogo> createState() => _SingingThemeLogoState();
}

class _SingingThemeLogoState extends State<SingingThemeLogo>
    with SingleTickerProviderStateMixin {
  /// Clock of the settled mark: the first phrase and its notes are over.
  static const double _settled =
      BirdyGoSingingPainter.firstPhrase + BirdyGoSingingPainter.phraseLength;

  /// Start of a later phrase (no entrance replayed).
  static const double _again =
      BirdyGoSingingPainter.firstPhrase + BirdyGoSingingPainter.phrasePeriod;

  late final AnimationController _controller = AnimationController(vsync: this)
    ..addListener(_tick);
  final ValueNotifier<double> _clock = ValueNotifier(_settled);
  double _from = 0;
  double _to = 0;
  bool _reduced = false;
  bool _arrived = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = BirdyMotion.reduced(context);
    if (!_arrived) {
      _arrived = true;
      if (widget.sings && !_reduced) _play(0, _settled);
    }
    if (_reduced && _controller.isAnimating) {
      _controller.stop();
      _clock.value = _settled;
    }
  }

  @override
  void didUpdateWidget(SingingThemeLogo old) {
    super.didUpdateWidget(old);
    if (widget.singSignal != old.singSignal) _sing();
  }

  void _play(double from, double to) {
    _from = from;
    _to = to;
    _controller.duration = Duration(milliseconds: (to - from).round());
    _controller.forward(from: 0);
  }

  void _tick() => _clock.value = _from + (_to - _from) * _controller.value;

  void _sing() {
    if (!widget.sings || _reduced || _controller.isAnimating) return;
    _play(_again, _again + BirdyGoSingingPainter.phraseLength);
  }

  @override
  void dispose() {
    _controller.dispose();
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = BirdyColors.of(context);
    final brand =
        widget.bird == null
            ? BirdyBrandColors.of(context)
            : BirdyBrandColors(
              widget.bird!,
              Theme.of(context).brightness,
            );
    final scale = widget.markWidth / SingingLogo.markRect.width;
    final board = BirdyGoSingingPainter.viewBox * scale;
    final shift =
        (SingingLogo.markRect.topLeft - SingingLogo.boardOrigin) * scale;
    final markSize = Size(
      widget.markWidth,
      SingingLogo.markRect.height * scale,
    );
    Widget disc = AnimatedContainer(
      duration: _reduced ? Duration.zero : BirdyMotion.enter,
      width: widget.size,
      height: widget.size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: brand.tonal,
        shape: BoxShape.circle,
        boxShadow:
            widget.halo
                ? [
                  BoxShadow(
                    color: c.surface1.withValues(alpha: BirdyAlpha.themeHalo),
                    spreadRadius: BirdySizes.themeLogoHalo,
                  ),
                ]
                : null,
      ),
      child: SizedBox(
        width: markSize.width,
        height: markSize.height,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: -shift.dx,
              top: -shift.dy,
              width: board.width,
              height: board.height,
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: BirdyGoSingingPainter(
                    clock: _clock,
                    still: _reduced || !widget.sings,
                    brand: brand,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    if (widget.sings) {
      disc = GestureDetector(
        behavior: HitTestBehavior.opaque,
        // A small pleasure, not a control: nothing to announce.
        excludeFromSemantics: true,
        onTap: _sing,
        child: disc,
      );
    }
    return ExcludeSemantics(child: disc);
  }
}
