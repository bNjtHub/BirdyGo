/// Disc logo of the « Qui chante ? » quiz entry row (J6f Profil mockup): a
/// dark Kingfisher-ringed well holding the BirdyGo silhouette, a Loriot
/// question mark and five equalizer bars. Decorative only (excluded from
/// semantics by its caller), so it is drawn once as a static SVG picture
/// rather than rebuilt from primitives.
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../design/birdy_tokens.dart';

/// Hex literals below mirror design tokens (`BirdyQuizColors.bar1`..`bar4`,
/// `BirdyBrand.oriole`) but stay literal: they feed a raw SVG string, which
/// cannot reference a [Color] value directly.
const String _bar1 = '52C0C9';
const String _bar2 = '79D0D7';
const String _bar3 = 'A8E2E6';
const String _bar4 = 'DDF4F5';
const String _oriole = 'F4C542';

String _svg() => '''
<svg viewBox="0 0 64 64" xmlns="http://www.w3.org/2000/svg">
<g transform="translate(8 1) scale(.75)">
<g fill="#$_bar1" opacity=".55">
<path d="M45.55 22.68A3.05 3.05 0 0 0 49.68 22.44L53 19A2.69 2.69 0 0 1 57.31 22.14L53.13 30.06A11.71 11.71 0 0 0 51.78 35.66Z"/>
<path d="M18.24 18.63L6.33 20.11L14.76 24.58Z" stroke="#$_bar1" stroke-width="1.5" stroke-linejoin="round"/>
<path d="M14.76 25.83L8.06 27.81L17.5 30.04Z" stroke="#$_bar1" stroke-width="1.5" stroke-linejoin="round"/>
<path d="M16.64 31.44A11.95 11.95 0 1 1 35.09 16.48A6.79 6.79 0 0 0 39.04 19.34A17.1 17.1 0 1 1 17.65 34.26A3.51 3.51 0 0 0 16.64 31.44Z"/>
</g>
<path d="M29.5 31.5a4.5 4.5 0 1 1 6.2 4.2c-1.4.6-2.2 1.6-2.2 3.2v.8" fill="none" stroke="#$_oriole" stroke-width="3.6" stroke-linecap="round" stroke-linejoin="round"/>
<circle cx="33.5" cy="45.2" r="2.2" fill="#$_oriole"/>
</g>
<rect x="19.5" y="47.5" width="3" height="5" rx="1.5" fill="#$_bar4"/>
<rect x="25" y="45.3" width="3" height="9.4" rx="1.5" fill="#$_oriole"/>
<rect x="30.5" y="46.4" width="3" height="7.2" rx="1.5" fill="#$_bar3"/>
<rect x="36" y="47.9" width="3" height="4.3" rx="1.5" fill="#$_bar2"/>
<rect x="41.5" y="48.9" width="3" height="2.2" rx="1.5" fill="#$_bar1"/>
</svg>
''';

/// The quiz entry's logo disc, [size] wide (56 dp on the Profil row).
class QuizLogo extends StatelessWidget {
  const QuizLogo({super.key, this.size = BirdySizes.quizLogo});

  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [BirdyBrand.wellTop, BirdyBrand.wellBottom],
      ),
      // The ring follows the bird theme picked on the Profil.
      border: Border.all(
        color: BirdyColors.of(context).accent,
        width: BirdyStroke.regular,
      ),
    ),
    child: SvgPicture.string(_svg(), width: size, height: size),
  );
}
