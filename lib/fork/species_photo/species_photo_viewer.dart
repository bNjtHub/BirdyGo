/// Full-screen species photo: pinch and double-tap zoom, swipe between the
/// photos of the carousel, drag down to close (J7).
library;

import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../shared/services/link_launcher.dart';
import '../../shared/utils/app_icons.dart';
import '../design/birdy_motion.dart';
import '../design/birdy_tokens.dart';
import '../design/birdy_typography.dart';
import 'photo_credit.dart';
import 'photo_credit_sheet.dart';
import 'species_photo_config.dart';
import 'species_photo_page_dots.dart';

/// One page of the viewer: the image already loaded by the carousel and its
/// credit.
class ViewerPhoto {
  const ViewerPhoto(this.image, this.credit);

  final ImageProvider image;
  final PhotoCredit credit;
}

/// Opens the viewer on [initialPage]; completes with the page on screen when
/// it closes, so the carousel can follow.
Future<int?> showSpeciesPhotoViewer(
  BuildContext context, {
  required List<ViewerPhoto> photos,
  required int initialPage,
  required Object heroTag,
}) {
  final reduced = BirdyMotion.reduced(context);
  return Navigator.of(context).push<int>(
    PageRouteBuilder<int>(
      opaque: false,
      transitionDuration: reduced ? Duration.zero : BirdyMotion.enter,
      reverseTransitionDuration: reduced ? Duration.zero : BirdyMotion.exit,
      pageBuilder:
          (_, _, _) => SpeciesPhotoViewer(
            photos: photos,
            initialPage: initialPage,
            heroTag: heroTag,
          ),
      transitionsBuilder:
          (_, animation, _, child) =>
              FadeTransition(opacity: animation, child: child),
    ),
  );
}

class SpeciesPhotoViewer extends StatefulWidget {
  const SpeciesPhotoViewer({
    super.key,
    required this.photos,
    required this.initialPage,
    required this.heroTag,
  });

  final List<ViewerPhoto> photos;
  final int initialPage;
  final Object heroTag;

  @override
  State<SpeciesPhotoViewer> createState() => _SpeciesPhotoViewerState();
}

class _SpeciesPhotoViewerState extends State<SpeciesPhotoViewer> {
  late final PageController _pages = PageController(
    initialPage: widget.initialPage,
  );
  late int _page = widget.initialPage;
  bool _zoomed = false;

  /// Vertical offset of the photo while dragged to close.
  double _drag = 0;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _close() => Navigator.of(context).pop(_page);

  void _onZoom(bool zoomed) {
    if (zoomed != _zoomed) setState(() => _zoomed = zoomed);
  }

  void _dragEnd(DragEndDetails details) {
    final height = MediaQuery.sizeOf(context).height;
    final fling = details.velocity.pixelsPerSecond.dy;
    if (_drag > height * kViewerDismissFraction ||
        fling > kViewerDismissVelocity) {
      _close();
    } else if (_drag != 0) {
      setState(() => _drag = 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final reduced = BirdyMotion.reduced(context);
    final height = MediaQuery.sizeOf(context).height;
    final progress = (_drag / (height * 0.5)).clamp(0.0, 1.0);
    // Reduced motion: the photo does not follow the finger, it only closes.
    final visual = reduced ? 0.0 : progress;
    final padding = MediaQuery.paddingOf(context);
    final total = widget.photos.length;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: BirdyBrand.clear,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: BirdyBrand.black,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: BirdyBrand.black.withValues(alpha: 1 - visual),
        body: Stack(
          fit: StackFit.expand,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onVerticalDragUpdate:
                  _zoomed
                      ? null
                      : (d) => setState(
                        () =>
                            _drag = (_drag + d.delta.dy).clamp(
                              0.0,
                              double.infinity,
                            ),
                      ),
              onVerticalDragEnd: _zoomed ? null : _dragEnd,
              onVerticalDragCancel: () {
                if (_drag != 0) setState(() => _drag = 0);
              },
              child: Transform.translate(
                offset: Offset(0, reduced ? 0 : _drag),
                child: Transform.scale(
                  scale: 1 - (1 - kViewerDismissMinScale) * visual,
                  child: PageView.builder(
                    controller: _pages,
                    itemCount: total,
                    physics:
                        _zoomed
                            ? const NeverScrollableScrollPhysics()
                            : const PageScrollPhysics(),
                    onPageChanged:
                        (i) => setState(() {
                          _page = i;
                          _zoomed = false;
                        }),
                    itemBuilder:
                        (context, i) => Semantics(
                          label: l10n.forkPhotoPosition(i + 1, total),
                          image: true,
                          child: _ZoomablePhoto(
                            key: ValueKey('viewer-photo-$i'),
                            image: widget.photos[i].image,
                            heroTag: i == _page ? widget.heroTag : null,
                            onZoomChanged: _onZoom,
                          ),
                        ),
                  ),
                ),
              ),
            ),
            // Fades with the drag, like the background.
            Opacity(
              opacity: 1 - visual,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: _CreditBar(
                      credit: widget.photos[_page].credit,
                      count: total,
                      current: _page,
                      bottomInset: padding.bottom,
                    ),
                  ),
                  Positioned(
                    top: padding.top + BirdySpace.xs,
                    left: BirdySpace.xs,
                    child: IconButton(
                      key: const ValueKey('viewer-close'),
                      onPressed: _close,
                      tooltip:
                          MaterialLocalizations.of(context).closeButtonTooltip,
                      iconSize: BirdySizes.blockIcon,
                      constraints: const BoxConstraints.tightFor(
                        width: kMinInteractiveDimension,
                        height: kMinInteractiveDimension,
                      ),
                      icon: const Icon(AppIcons.close),
                      style: IconButton.styleFrom(
                        backgroundColor: BirdyBrand.black.withValues(
                          alpha: BirdyAlpha.photoButtonScrim,
                        ),
                        foregroundColor: BirdyBrand.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One photo in an [InteractiveViewer]: pinch, pan when zoomed, double-tap
/// toggles a 2x zoom around the tap.
class _ZoomablePhoto extends StatefulWidget {
  const _ZoomablePhoto({
    super.key,
    required this.image,
    required this.onZoomChanged,
    this.heroTag,
  });

  final ImageProvider image;
  final Object? heroTag;
  final ValueChanged<bool> onZoomChanged;

  @override
  State<_ZoomablePhoto> createState() => _ZoomablePhotoState();
}

class _ZoomablePhotoState extends State<_ZoomablePhoto>
    with SingleTickerProviderStateMixin {
  final _controller = TransformationController();
  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: kViewerZoomDuration,
  );
  Offset _tap = Offset.zero;
  bool _zoomed = false;
  Animation<Matrix4>? _zoomAnim;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTransform);
  }

  @override
  void dispose() {
    _anim.dispose();
    _controller
      ..removeListener(_onTransform)
      ..dispose();
    super.dispose();
  }

  void _onTransform() {
    final zoomed = _controller.value.getMaxScaleOnAxis() > kViewerZoomedAbove;
    if (zoomed == _zoomed) return;
    _zoomed = zoomed;
    widget.onZoomChanged(zoomed);
  }

  void _setFromAnimation() => _controller.value = _zoomAnim!.value;

  void _toggleZoom() {
    final Matrix4 to;
    if (_zoomed) {
      to = Matrix4.identity();
    } else {
      const s = kViewerDoubleTapScale;
      // The tapped point stays under the finger.
      to =
          Matrix4.identity()
            ..translateByDouble(-_tap.dx * (s - 1), -_tap.dy * (s - 1), 0, 1)
            ..scaleByDouble(s, s, 1, 1);
    }
    if (BirdyMotion.reduced(context)) {
      _controller.value = to;
      return;
    }
    _anim.removeListener(_setFromAnimation);
    _zoomAnim = Matrix4Tween(
      begin: _controller.value,
      end: to,
    ).animate(CurvedAnimation(parent: _anim, curve: BirdyMotion.standard));
    _anim
      ..addListener(_setFromAnimation)
      ..forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    Widget image = Image(
      image: widget.image,
      // Fills the screen whatever its size; the photo is contained in it.
      width: double.infinity,
      height: double.infinity,
      fit: BoxFit.contain,
      gaplessPlayback: true,
      excludeFromSemantics: true,
      errorBuilder: (_, _, _) => const SizedBox.shrink(),
    );
    if (widget.heroTag != null) {
      image = Hero(tag: widget.heroTag!, child: image);
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onDoubleTapDown: (d) => _tap = d.localPosition,
      onDoubleTap: _toggleZoom,
      child: InteractiveViewer(
        transformationController: _controller,
        maxScale: kViewerMaxScale,
        minScale: 1,
        clipBehavior: Clip.none,
        child: SizedBox.expand(child: image),
      ),
    );
  }
}

/// Credit of the photo on screen on a bottom scrim, with the page dots.
/// Author, licence and source on one line; a tap opens the photo's page, or
/// the credit sheet when it has none.
class _CreditBar extends StatelessWidget {
  const _CreditBar({
    required this.credit,
    required this.count,
    required this.current,
    required this.bottomInset,
  });

  final PhotoCredit credit;
  final int count;
  final int current;
  final double bottomInset;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final license = credit.parsedLicense;
    final parts = [
      if (credit.author != null) credit.author!,
      if (license != null) photoLicenseText(l10n, license),
      if (credit.source != null) credit.source!,
    ];
    final text = parts.isEmpty ? l10n.forkPhotoNoCredit : parts.join(' · ');
    final pageUrl = credit.pageUrl;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            BirdyBrand.black.withValues(alpha: BirdyAlpha.photoViewerScrim),
            BirdyBrand.clear,
          ],
        ),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          BirdySpace.gutter,
          BirdySpace.xl,
          BirdySpace.gutter,
          BirdySpace.s + bottomInset,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (count > 1) ...[
              PhotoPageDots(count: count, current: current),
              const SizedBox(height: BirdySpace.s),
            ],
            Semantics(
              button: true,
              child: InkWell(
                key: const ValueKey('viewer-credit'),
                onTap:
                    () =>
                        pageUrl != null
                            ? openExternalUrl(context, pageUrl)
                            : showPhotoCreditSheet(context, credit),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minHeight: kMinInteractiveDimension,
                    minWidth: double.infinity,
                  ),
                  child: Center(
                    child: Text(
                      text,
                      textAlign: TextAlign.center,
                      style: BirdyText.labelCompact.copyWith(
                        color: BirdyBrand.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
