/// Round species visual (J6a): photo, icon on a colored halo, or a sober
/// silhouette when there is neither.
library;

import 'package:flutter/material.dart';

import '../../../shared/utils/app_icons.dart';
import '../../species_icons/species_icon.dart';
import '../species_tint.dart';

class SpeciesAvatar extends StatelessWidget {
  const SpeciesAvatar({
    super.key,
    this.image,
    this.icon,
    this.scientificName,
    this.preferIcon = false,
    this.tint,
    this.size = 42,
    this.muted = false,
    this.heroTag,
  });

  /// Photo, drawn as a circle. Wins at large sizes unless [preferIcon] is set.
  final ImageProvider? image;

  /// Species icon (J6d), drawn on the halo of [tint].
  final Widget? icon;

  /// Scientific name used to resolve the generated J6d SVG.
  final String? scientificName;

  /// Use the SVG at 48 dp too (Live); smaller avatars prefer it by default.
  final bool preferIcon;

  /// Species colors; [SpeciesTint.neutral] when unknown.
  final SpeciesTint? tint;

  final double size;

  /// "Heard but not confirmed": grey and faded.
  final bool muted;

  /// Hero tag shared with the species sheet photo.
  final Object? heroTag;

  static const ColorFilter _greyscale = ColorFilter.matrix(<double>[
    0.2126, 0.7152, 0.0722, 0, 0, //
    0.2126, 0.7152, 0.0722, 0, 0, //
    0.2126, 0.7152, 0.0722, 0, 0, //
    0, 0, 0, 1, 0,
  ]);

  @override
  Widget build(BuildContext context) {
    final t = tint ?? SpeciesTint.neutral;
    Widget visual;
    final photo = image;
    final generated =
        icon ??
        (scientificName == null
            ? null
            : SpeciesIcon(scientificName: scientificName!, size: size * 0.9));
    final useIcon = generated != null && (preferIcon || size < 48);
    if (useIcon) {
      visual = _halo(t, generated);
    } else if (photo != null) {
      final pixels = (size * MediaQuery.devicePixelRatioOf(context)).round();
      visual = ClipOval(
        child: Image(
          image: ResizeImage.resizeIfNeeded(pixels, null, photo),
          width: size,
          height: size,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          excludeFromSemantics: true,
          errorBuilder:
              (context, error, stack) => _halo(t, generated ?? _silhouette(t)),
        ),
      );
    } else {
      visual = _halo(t, generated ?? _silhouette(t));
    }
    if (muted) {
      visual = Opacity(
        opacity: 0.45,
        child: ColorFiltered(colorFilter: _greyscale, child: visual),
      );
    }
    final box = SizedBox.square(dimension: size, child: visual);
    return heroTag == null ? box : Hero(tag: heroTag!, child: box);
  }

  Widget _halo(SpeciesTint t, Widget child) => DecoratedBox(
    decoration: BoxDecoration(color: t.halo, shape: BoxShape.circle),
    child: Center(child: child),
  );

  Widget _silhouette(SpeciesTint t) =>
      Icon(AppIcons.bird, size: size * 0.6, color: t.deep, fill: 1);
}
