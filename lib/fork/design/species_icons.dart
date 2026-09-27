/// Drawn species icons (fork/maquette/icons.json, J6e quiz): SVG assets in
/// assets/fork/species_icons, named after the scientific name. Species
/// without an icon keep their photo avatar.
library;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'birdy_tokens.dart';

abstract final class SpeciesIcons {
  static const String _dir = 'assets/fork/species_icons';

  /// The mystery bird: a grey silhouette with a question mark.
  static const String mystery = '$_dir/mystere.svg';

  /// Species with a drawn icon.
  static const Set<String> _known = {
    'Erithacus rubecula',
    'Cyanistes caeruleus',
    'Parus major',
    'Turdus merula',
    'Dendrocopos major',
    'Fringilla coelebs',
    'Pica pica',
    'Troglodytes troglodytes',
    'Passer domesticus',
    'Phylloscopus collybita',
    'Strix aluco',
    'Upupa epops',
    'Alcedo atthis',
    'Oriolus oriolus',
  };

  /// Asset of [scientificName]'s icon, or null.
  static String? assetOf(String scientificName) =>
      _known.contains(scientificName)
          ? '$_dir/${scientificName.toLowerCase().replaceAll(' ', '_')}.svg'
          : null;
}

/// The mystery silhouette, brightened like the mockup's CSS
/// `filter: brightness(2.2)` so it reads on the dark well.
class MysterySilhouette extends StatelessWidget {
  const MysterySilhouette({super.key, required this.size});

  final double size;

  static const double _k = BirdyQuizColors.mysteryBrightness;

  /// CSS brightness(k): each channel times k, alpha kept.
  static const ColorFilter _brighten = ColorFilter.matrix([
    _k, 0, 0, 0, 0, //
    0, _k, 0, 0, 0, //
    0, 0, _k, 0, 0, //
    0, 0, 0, 1, 0, //
  ]);

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: ColorFiltered(
      colorFilter: _brighten,
      child: SvgPicture.asset(SpeciesIcons.mystery, width: size, height: size),
    ),
  );
}
