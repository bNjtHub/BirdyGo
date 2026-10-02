/// The species photo: bundled, then larger online, credit one tap away
/// (fork/PLAN.md J6b, DESIGN.md Photos).
library;

import 'dart:io';

import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/models/taxonomy_species.dart';
import '../../shared/utils/app_icons.dart';
import '../design/birdy_motion.dart';
import '../design/birdy_tokens.dart';
import '../design/birdy_typography.dart';
import 'photo_credit.dart';
import 'photo_label.dart';
import 'inat_photo_service.dart';
import 'photo_credit_sheet.dart';
import 'species_photo_viewer.dart';
import 'species_photo_page_dots.dart';
import 'species_photo_providers.dart';

const _placeholder = 'assets/images/dummy_species.png';

/// Fills its parent, which sets the frame: wrap it in an [AspectRatio] of
/// `kSpeciesPhotoAspectRatio`. The online photo fades in over the bundled
/// one inside the same frame, so nothing moves.
///
/// With online photos allowed, up to 4 more photos follow as a swipeable
/// carousel (J7): a page exists only once its image is downloaded. With
/// them off, it is the single bundled photo, no dots, no request.
class SpeciesPhoto extends ConsumerStatefulWidget {
  const SpeciesPhoto({super.key, required this.species});

  /// Null while the taxonomy loads: the placeholder shows.
  final TaxonomySpecies? species;

  @override
  ConsumerState<SpeciesPhoto> createState() => _SpeciesPhotoState();
}

class _SpeciesPhotoState extends ConsumerState<SpeciesPhoto> {
  int _page = 0;
  final _pages = PageController();

  /// Tag of the photo on screen, shared with the full-screen viewer.
  final Object _heroTag = Object();

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  /// Only the page on screen flies to the viewer (one hero per tag).
  Widget _heroIf(bool on, Widget child) =>
      on ? Hero(tag: _heroTag, child: child) : child;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final species = widget.species;
    final inatId = species?.inatId;
    final online =
        inatId == null
            ? null
            : ref.watch(onlineSpeciesPhotoProvider(inatId)).value;
    final bundledCredit =
        online?.credit ??
        (species == null
            ? const PhotoCredit()
            : PhotoCredit.fromSpecies(species));
    final galleryState =
        inatId == null
            ? null
            : ref
                .watch(
                  speciesGalleryProvider((
                    inatId: inatId,
                    bundledPage: PhotoCredit.fromSpecies(species!).pageUrl,
                  )),
                )
                .value;
    final gallery = galleryState?.photos ?? const <GalleryPhoto>[];
    final loading =
        inatId != null &&
        ref.watch(onlinePhotosAllowedProvider) &&
        (galleryState?.loading ?? true);
    final extras = [
      for (final photo in gallery)
        if (photo.credit.pageUrl == null ||
            photo.credit.pageUrl != online?.credit.pageUrl)
          photo,
    ];
    final total = 1 + extras.length;
    final page = _page.clamp(0, total - 1);
    // The credit follows the page on screen.
    void showCredit() => showPhotoCreditSheet(
      context,
      page == 0 ? bundledCredit : extras[page - 1].credit,
    );

    // A tap on the photo opens it full screen, on the page tapped.
    Future<void> openViewer() async {
      final photos = [
        ViewerPhoto(
          // The bundled photo at full resolution, or the larger online one.
          online != null
              ? FileImage(online.file)
              : AssetImage(species?.assetImagePath ?? _placeholder),
          bundledCredit,
        ),
        for (final photo in extras)
          ViewerPhoto(MemoryImage(photo.bytes), photo.credit, photo.label),
      ];
      final closedOn = await showSpeciesPhotoViewer(
        context,
        photos: photos,
        initialPage: page,
        heroTag: _heroTag,
      );
      // The carousel follows the page the viewer closed on.
      if (closedOn != null && closedOn != page && _pages.hasClients) {
        _pages.jumpToPage(closedOn);
      }
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final cacheWidth =
            width.isFinite
                ? (width * MediaQuery.devicePixelRatioOf(context)).round()
                : null;
        final bundledLayers = <Widget>[
          _heroIf(
            page == 0,
            Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  species?.assetImagePath ?? _placeholder,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                  // Decoded at display size, never upscaled.
                  cacheWidth: cacheWidth,
                  errorBuilder:
                      (_, _, _) =>
                          Image.asset(_placeholder, fit: BoxFit.contain),
                ),
                if (online != null)
                  _FadeInPhoto(
                    key: ValueKey(online.file.path),
                    file: online.file,
                    cacheWidth: cacheWidth,
                  ),
              ],
            ),
          ),
          ExcludeSemantics(
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(onTap: openViewer),
            ),
          ),
        ];
        final creditButton = Positioned(
          right: BirdySpace.xs,
          bottom: BirdySpace.xs,
          child: IconButton(
            onPressed: showCredit,
            tooltip: l10n.forkPhotoCredit,
            iconSize: BirdySizes.blockIcon,
            icon: const Icon(AppIcons.infoOutline),
            style: IconButton.styleFrom(
              backgroundColor: BirdyBrand.black.withValues(
                alpha: BirdyAlpha.photoButtonScrim,
              ),
              foregroundColor: BirdyBrand.white,
            ),
          ),
        );
        if (extras.isEmpty) {
          return Stack(
            fit: StackFit.expand,
            children: [
              ...bundledLayers,
              _PageDots(count: 1, current: 0, loading: loading),
              creditButton,
            ],
          );
        }
        return Stack(
          fit: StackFit.expand,
          children: [
            PageView.builder(
              controller: _pages,
              itemCount: total,
              onPageChanged: (i) => setState(() => _page = i),
              itemBuilder:
                  (context, i) => Semantics(
                    label: PhotoLabel.position(
                      l10n,
                      i + 1,
                      total,
                      i == 0 ? null : extras[i - 1].label,
                    ),
                    image: true,
                    child: Stack(
                      fit: StackFit.expand,
                      children:
                          i == 0
                              ? bundledLayers
                              : [
                                _heroIf(
                                  i == page,
                                  Image.memory(
                                    extras[i - 1].bytes,
                                    fit: BoxFit.cover,
                                    gaplessPlayback: true,
                                    cacheWidth: cacheWidth,
                                    excludeFromSemantics: true,
                                    errorBuilder:
                                        (_, _, _) => const SizedBox.shrink(),
                                  ),
                                ),
                                ExcludeSemantics(
                                  child: Material(
                                    type: MaterialType.transparency,
                                    child: InkWell(onTap: openViewer),
                                  ),
                                ),
                                _LabelChip(label: extras[i - 1].label),
                              ],
                    ),
                  ),
            ),
            _PageDots(count: total, current: page, loading: loading),
            creditButton,
          ],
        );
      },
    );
  }
}

/// What the photo shows (life stage, sex), bottom left on a small scrim.
/// Nothing when unknown. Read through the page's semantics label instead.
class _LabelChip extends StatelessWidget {
  const _LabelChip({required this.label});

  final PhotoLabel? label;

  @override
  Widget build(BuildContext context) {
    final text = PhotoLabel.text(AppLocalizations.of(context)!, label);
    if (text == null) return const SizedBox.shrink();
    return Positioned(
      left: BirdySpace.xs,
      bottom: BirdySpace.xs,
      child: ExcludeSemantics(
        child: IgnorePointer(
          child: DecoratedBox(
            key: const ValueKey('photo-label'),
            decoration: BoxDecoration(
              color: BirdyBrand.black.withValues(
                alpha: BirdyAlpha.photoButtonScrim,
              ),
              borderRadius: BorderRadius.circular(BirdyRadii.hero),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: BirdySpace.s,
                vertical: BirdySpace.xs,
              ),
              child: Text(
                text,
                style: BirdyText.labelCompact.copyWith(color: BirdyBrand.white),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The carousel dots, at the bottom of the photo.
class _PageDots extends StatelessWidget {
  const _PageDots({
    required this.count,
    required this.current,
    required this.loading,
  });

  final int count;
  final int current;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: BirdySpace.m,
      child: AnimatedSwitcher(
        duration: BirdyMotion.exit,
        child:
            count > 1 || loading
                ? PhotoPageDots(
                  key: const ValueKey('photo-dots'),
                  count: count,
                  current: current,
                  loading: loading,
                )
                : const SizedBox.shrink(key: ValueKey('photo-dots-none')),
      ),
    );
  }
}

/// The online photo, transparent until its first frame is decoded.
/// A fade is kept even with reduced motion (DESIGN.md Animations).
class _FadeInPhoto extends StatelessWidget {
  const _FadeInPhoto({super.key, required this.file, this.cacheWidth});

  final File file;
  final int? cacheWidth;

  @override
  Widget build(BuildContext context) {
    return Image(
      image: ResizeImage.resizeIfNeeded(cacheWidth, null, FileImage(file)),
      fit: BoxFit.cover,
      gaplessPlayback: true,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded) return child;
        return AnimatedOpacity(
          opacity: frame == null ? 0 : 1,
          duration: BirdyMotion.enter,
          curve: BirdyMotion.standard,
          child: child,
        );
      },
      errorBuilder: (_, _, _) => const SizedBox.shrink(),
    );
  }
}
