/// BirdyGo themes (J6a): light ("carnet") and dark ("écoute").
///
/// Built on upstream's [AppTheme.fromColorScheme] so every structural choice
/// of upstream (touch targets, list tile padding, sheet width) stays, then
/// the BirdyGo palette, fonts and component shapes are laid over it. The
/// brand roles follow the chosen bird ([BirdyBird], J6i).
///
/// Material roles: `primary` is the bird's `accentText`, which stays AA as
/// text on the theme's surfaces (Loriot: #0B6E77 on light, #4FC3CC on dark);
/// the bright `accent` fill with Encre text is used through
/// [BirdyButtonStyles].
library;

import 'package:flutter/material.dart';

import '../../core/theme/app_semantic_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/score_colors.dart';
import 'birdy_page_transitions.dart';
import 'birdy_theme_choice.dart';
import 'birdy_tokens.dart';
import 'birdy_typography.dart';

abstract final class BirdyTheme {
  static final Map<(BirdyBird, Brightness), ThemeData> _cache = {};

  /// Light theme: Brume background, white cards. [bird] sets the brand
  /// colors (J6i); Loriot is the original look.
  static ThemeData light({BirdyBird bird = BirdyBird.loriot}) =>
      _cache[(bird, Brightness.light)] ??= _build(
        BirdyColors.forBird(bird, Brightness.light),
        BirdyBrandColors(bird, Brightness.light),
      );

  /// Dark theme: Encre de nuit background, used by listening by default.
  static ThemeData dark({BirdyBird bird = BirdyBird.loriot}) =>
      _cache[(bird, Brightness.dark)] ??= _build(
        BirdyColors.forBird(bird, Brightness.dark),
        BirdyBrandColors(bird, Brightness.dark),
      );

  /// Material color scheme mapped on the BirdyGo tokens.
  static ColorScheme colorScheme(
    BirdyColors c, {
    BirdyBird bird = BirdyBird.loriot,
  }) {
    final isDark = c.isDark;
    Color solid(Color color) => Color.alphaBlend(color, c.background);
    final seed = ColorScheme.fromSeed(
      seedColor: c.accent,
      brightness: c.brightness,
    );
    return seed.copyWith(
      primary: c.accentText,
      onPrimary: isDark ? BirdyBrand.ink : const Color(0xFFFFFFFF),
      primaryContainer: solid(c.tonal),
      onPrimaryContainer: c.accentText,
      secondary: c.accentText,
      onSecondary: isDark ? BirdyBrand.ink : const Color(0xFFFFFFFF),
      secondaryContainer: solid(c.tonal),
      onSecondaryContainer: c.accentText,
      tertiary: c.orioleText,
      onTertiary: isDark ? BirdyBrand.ink : const Color(0xFFFFFFFF),
      tertiaryContainer: solid(c.orioleContainer),
      onTertiaryContainer: c.orioleText,
      surface: c.background,
      onSurface: c.text1,
      onSurfaceVariant: c.text2,
      surfaceDim: isDark ? c.backgroundDeep : c.lineOpaque,
      surfaceBright: isDark ? c.surface3 : c.surface1,
      surfaceContainerLowest: isDark ? c.backgroundDeep : c.surface1,
      surfaceContainerLow: c.surface1,
      surfaceContainer: c.surface1,
      surfaceContainerHigh: c.surface2,
      surfaceContainerHighest: isDark ? c.surface3 : c.lineOpaque,
      outline: c.borderOpaque,
      outlineVariant: c.lineOpaque,
      inverseSurface: isDark ? BirdyBrand.mist : BirdyBrand.ink,
      onInverseSurface: isDark ? BirdyBrand.ink : BirdyBrand.mist,
      inversePrimary:
          isDark
              ? BirdyBrandColors(bird, Brightness.light).accentText
              : BirdyBrandColors(bird, Brightness.dark).accentText,
    );
  }

  static ThemeData _build(BirdyColors c, BirdyBrandColors brand) {
    final scheme = colorScheme(c, bird: brand.bird);
    final base = AppTheme.fromColorScheme(scheme);
    const stadium = StadiumBorder();
    final textTheme = base.textTheme.merge(BirdyText.textTheme);

    return base.copyWith(
      scaffoldBackgroundColor: c.background,
      canvasColor: c.background,
      pageTransitionsTheme: BirdyPageTransitionsBuilder.theme,
      textTheme: textTheme,
      primaryTextTheme: base.primaryTextTheme.merge(BirdyText.textTheme),
      extensions: <ThemeExtension<dynamic>>[
        c.isDark ? ScoreColors.dark : ScoreColors.light,
        c.isDark ? AppSemanticColors.dark(scheme) : AppSemanticColors.light,
        c,
        brand,
      ],
      appBarTheme: base.appBarTheme.copyWith(
        backgroundColor: c.background,
        foregroundColor: c.text1,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        toolbarHeight: BirdySizes.topBar,
        titleTextStyle: BirdyText.heading.copyWith(color: c.text1),
      ),
      cardTheme: base.cardTheme.copyWith(
        color: c.surface1,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(BirdyRadii.card)),
        ),
      ),
      bottomSheetTheme: base.bottomSheetTheme.copyWith(
        backgroundColor: c.surface1,
        modalBackgroundColor: c.surface1,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        modalElevation: 0,
        dragHandleColor: c.border,
        dragHandleSize: const Size(36, 4),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(BirdyRadii.hero),
          ),
        ),
      ),
      dialogTheme: base.dialogTheme.copyWith(
        backgroundColor: c.surface1,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: BirdyText.heading.copyWith(color: c.text1),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(BirdyRadii.hero)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, BirdySizes.target),
          padding: const EdgeInsets.symmetric(horizontal: BirdySpace.xl),
          shape: stadium,
          textStyle: BirdyText.labelCompact,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          shape: stadium,
          textStyle: BirdyText.labelCompact,
        ).merge(base.elevatedButtonTheme.style),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: c.text1,
          minimumSize: const Size(64, BirdySizes.target),
          padding: const EdgeInsets.symmetric(horizontal: BirdySpace.xl),
          shape: stadium,
          side: BorderSide(color: c.borderStrong, width: 1.5),
          textStyle: BirdyText.labelCompact,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: stadium,
          textStyle: BirdyText.labelCompact,
        ).merge(base.textButtonTheme.style),
      ),
      chipTheme: base.chipTheme.copyWith(
        shape: const StadiumBorder(),
        side: BorderSide(color: c.borderOpaque),
      ),
      navigationBarTheme: base.navigationBarTheme.copyWith(
        height: BirdySizes.navBar,
        backgroundColor: c.surface1,
        surfaceTintColor: Colors.transparent,
        indicatorColor: c.navIndicator,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected)
                  ? BirdyText.badge.copyWith(color: c.accentText, height: 1.2)
                  : BirdyText.caption.copyWith(color: c.text2, height: 1.2),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color:
                states.contains(WidgetState.selected) ? c.accentText : c.text2,
          ),
        ),
      ),
      snackBarTheme: base.snackBarTheme.copyWith(
        backgroundColor: c.isDark ? c.surface3 : BirdyBrand.ink,
        contentTextStyle: BirdyText.bodyCompact.copyWith(
          color: BirdyBrand.mist,
        ),
        actionTextColor: BirdyBrandColors(brand.bird, Brightness.dark).accentText,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(BirdyRadii.card)),
        ),
      ),
      dividerTheme: base.dividerTheme.copyWith(color: c.lineOpaque),
      // FORK: upstream's off-state switch (colorScheme.outline on
      // surfaceContainerHighest) only reached ~1.3:1 to 1.5:1 on our
      // surfaces, effectively invisible (J6f-b feedback). text2 keeps the
      // selected state as upstream drew it and gives the off thumb/outline
      // WCAG 1.4.11's 3:1 non-text contrast (measured >=5.9:1 both themes,
      // see test/fork/design/switch_contrast_test.dart).
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected)
                  ? base.switchTheme.thumbColor?.resolve(states)
                  : c.text2,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected)
                  ? base.switchTheme.trackColor?.resolve(states)
                  : c.surface2,
        ),
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected)
                  ? Colors.transparent
                  : c.text2,
        ),
      ),
    );
  }
}

/// Forces the theme below it: listening opens dark by default
/// (fork/DESIGN.md), or light when [light] is set (J6h « Écran clair »).
/// Keeps an already matching theme, and the upstream high-contrast palette
/// when the user chose it.
class ListeningTheme extends StatelessWidget {
  const ListeningTheme({
    super.key,
    required this.child,
    this.light = false,
    this.follow = false,
  });

  final Widget child;

  /// J7: keep the theme of the app (light or dark, chosen bird included);
  /// nothing is forced. Off when the user asked for the listening screen
  /// always dark.
  final bool follow;

  /// The user chose the light listening screen (`liveThemeProvider`).
  final bool light;

  @override
  Widget build(BuildContext context) {
    if (follow) return child;
    final current = Theme.of(context);
    final wanted = light ? Brightness.light : Brightness.dark;
    if (current.brightness == wanted) return child;
    final highContrast = AppTheme.isHighContrastTheme(current);
    final bird = BirdyBrandColors.fromTheme(current).bird;
    final data =
        light
            ? (highContrast
                ? AppTheme.highContrastLight()
                : BirdyTheme.light(bird: bird))
            : (highContrast
                ? AppTheme.highContrastDark()
                : BirdyTheme.dark(bird: bird));
    return Theme(data: data, child: child);
  }
}
