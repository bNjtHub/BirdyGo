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
import 'photo_credit.dart';
import 'photo_credit_sheet.dart';
import 'species_photo_providers.dart';

const _placeholder = 'assets/images/dummy_species.png';

/// Fills its parent, which sets the frame: wrap it in an [AspectRatio] of
/// `kSpeciesPhotoAspectRatio`. The online photo fades in over the bundled
/// one inside the same frame, so nothing moves.
class SpeciesPhoto extends ConsumerWidget {
  const SpeciesPhoto({super.key, required this.species});

  /// Null while the taxonomy loads: the placeholder shows.
  final TaxonomySpecies? species;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final species = this.species;
    final inatId = species?.inatId;
    final online =
        inatId == null
            ? null
            : ref.watch(onlineSpeciesPhotoProvider(inatId)).value;
    final credit =
        online?.credit ??
        (species == null
            ? const PhotoCredit()
            : PhotoCredit.fromSpecies(species));
    void showCredit() => showPhotoCreditSheet(context, credit);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final cacheWidth =
            width.isFinite
                ? (width * MediaQuery.devicePixelRatioOf(context)).round()
                : null;
        return Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              species?.assetImagePath ?? _placeholder,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              errorBuilder:
                  (_, _, _) => Image.asset(_placeholder, fit: BoxFit.contain),
            ),
            if (online != null)
              _FadeInPhoto(
                key: ValueKey(online.file.path),
                file: online.file,
                cacheWidth: cacheWidth,
              ),
            ExcludeSemantics(
              child: Material(
                type: MaterialType.transparency,
                child: InkWell(onTap: showCredit),
              ),
            ),
            Positioned(
              right: 4,
              bottom: 4,
              child: IconButton(
                onPressed: showCredit,
                tooltip: l10n.forkPhotoCredit,
                iconSize: 20,
                icon: const Icon(AppIcons.infoOutline),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black.withValues(alpha: 0.45),
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        );
      },
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
