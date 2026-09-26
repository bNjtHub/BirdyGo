/// Species photo (J6b): the bundled 480x320 photo at once, offline, and the
/// large version fading in over it once downloaded or read from the cache.
///
/// The frame has a fixed size (an aspect ratio, or the parent's
/// constraints) and both layers fill it with the same centred crop, so the
/// large photo never moves the layout. A tap opens the credit and licence.
/// Without photo: a sober silhouette on the species color.
library;

import 'dart:io';
import 'dart:math' as math;

import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/utils/app_icons.dart';
import '../design/birdy_motion.dart';
import '../design/birdy_tokens.dart';
import '../design/species_accents.dart';
import '../design/species_tint.dart';
import 'photo_credit.dart';
import 'photo_manifest.dart';
import 'species_photo_cache.dart';

class SpeciesPhoto extends ConsumerStatefulWidget {
  const SpeciesPhoto({
    super.key,
    required this.scientificName,
    this.aspectRatio = 3 / 2,
    this.borderRadius = BorderRadius.zero,
    this.loadLarge = true,
    this.overlays = const [],
  });

  final String scientificName;

  /// Width / height of the frame. Null fills the parent's (bounded)
  /// constraints, for a header of a given height.
  final double? aspectRatio;

  final BorderRadius borderRadius;

  /// Fetch the large version (species sheet). Lists keep the bundled one.
  final bool loadLarge;

  /// Drawn over the photo, under the credit button (e.g. a [Positioned]
  /// badge).
  final List<Widget> overlays;

  @override
  ConsumerState<SpeciesPhoto> createState() => _SpeciesPhotoState();
}

class _SpeciesPhotoState extends ConsumerState<SpeciesPhoto> {
  ProviderSubscription<AsyncValue<SpeciesPhotoInfo?>>? _subscription;
  String? _requested;
  File? _large;

  @override
  void initState() {
    super.initState();
    _listen();
  }

  @override
  void didUpdateWidget(SpeciesPhoto oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scientificName != widget.scientificName ||
        oldWidget.loadLarge != widget.loadLarge) {
      _subscription?.close();
      _requested = null;
      _large = null;
      _listen();
    }
  }

  void _listen() {
    _subscription = ref.listenManual(
      speciesPhotoProvider(widget.scientificName),
      (_, next) {
        final info = next.value;
        if (info != null) _fetchLarge(info);
      },
      fireImmediately: true,
    );
  }

  Future<void> _fetchLarge(SpeciesPhotoInfo info) async {
    if (!widget.loadLarge || !info.hasLarge || _requested == info.photoId) {
      return;
    }
    final id = _requested = info.photoId!;
    final file = await ref
        .read(speciesPhotoCacheProvider)
        .file(id, info.largeUrl!);
    if (!mounted || file == null || _requested != id) return;
    setState(() => _large = file);
  }

  @override
  Widget build(BuildContext context) {
    final photo = ref.watch(speciesPhotoProvider(widget.scientificName));
    final info = photo.value;
    final tint = SpeciesAccents.tintOf(widget.scientificName);
    final brightness = Theme.of(context).brightness;
    final large = _large;

    Widget frame = LayoutBuilder(
      builder: (context, constraints) {
        final width =
            constraints.hasBoundedWidth
                ? (constraints.maxWidth *
                        MediaQuery.devicePixelRatioOf(context))
                    .round()
                : null;
        final silhouette = _Silhouette(
          tint: tint,
          size: _shortestSide(constraints),
        );
        return Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: tint.cardBackground(brightness)),
            if (info == null && !photo.isLoading) silhouette,
            if (info != null)
              Image.asset(
                info.assetPath,
                fit: BoxFit.cover,
                gaplessPlayback: true,
                excludeFromSemantics: true,
                errorBuilder: (_, _, _) => silhouette,
              ),
            if (large != null)
              Image(
                key: ValueKey(large.path),
                image: ResizeImage.resizeIfNeeded(
                  width,
                  null,
                  FileImage(large),
                ),
                fit: BoxFit.cover,
                excludeFromSemantics: true,
                frameBuilder: photoFadeIn,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ...widget.overlays,
            if (info != null && info.hasCredit)
              Positioned(
                right: 0,
                bottom: 0,
                child: _CreditButton(
                  onTap: () => showPhotoCredit(context, info),
                ),
              ),
          ],
        );
      },
    );

    final ratio = widget.aspectRatio;
    if (ratio != null) frame = AspectRatio(aspectRatio: ratio, child: frame);
    frame = ClipRRect(borderRadius: widget.borderRadius, child: frame);
    if (info == null || !info.hasCredit) return frame;
    return GestureDetector(
      excludeFromSemantics: true,
      onTap: () => showPhotoCredit(context, info),
      child: frame,
    );
  }

  static double _shortestSide(BoxConstraints c) {
    final side = math.min(c.maxWidth, c.maxHeight);
    return side.isFinite ? side : 96;
  }
}

/// Fades a network or file photo in over what lies under it, with the
/// enter duration; kept with reduced motion (fades only, DESIGN.md).
Widget photoFadeIn(
  BuildContext context,
  Widget child,
  int? frame,
  bool wasSynchronouslyLoaded,
) {
  if (wasSynchronouslyLoaded) return child;
  return AnimatedOpacity(
    opacity: frame == null ? 0 : 1,
    duration: BirdyMotion.enter,
    curve: BirdyMotion.standard,
    child: child,
  );
}

class _Silhouette extends StatelessWidget {
  const _Silhouette({required this.tint, required this.size});

  final SpeciesTint tint;
  final double size;

  @override
  Widget build(BuildContext context) => Center(
    child: Icon(AppIcons.bird, size: size * 0.4, color: tint.deep, fill: 1),
  );
}

/// "©" in the corner of the photo: 28 px on a dark scrim, 48 px to tap.
class _CreditButton extends StatelessWidget {
  const _CreditButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Semantics(
      button: true,
      label: l10n.forkPhotoCreditOpen,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox.square(
          dimension: BirdySizes.target,
          child: Center(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: BirdyBrand.ink.withValues(alpha: 0.55),
                shape: BoxShape.circle,
              ),
              child: const SizedBox.square(
                dimension: 28,
                child: Center(
                  child: Text(
                    '©',
                    style: TextStyle(
                      color: BirdyBrand.mist,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      height: 1,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
