/// BirdyGo themes (J6a): light ("carnet") and dark ("écoute").
///
/// Built on upstream's [AppTheme.fromColorScheme] so every structural choice
/// of upstream (touch targets, list tile padding, sheet width) stays, then
/// the BirdyGo palette, fonts and component shapes are laid over it.
///
/// Material roles: `primary` is the Martin-pêcheur that stays AA as text on
/// the theme's surfaces (#0B6E77 on light, #4FC3CC on dark); the bright
/// #19A7B3 fill with Encre text is used through [BirdyButtonStyles].
library;

import 'package:flutter/material.dart';

import '../../core/theme/app_semantic_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/score_colors.dart';
import 'birdy_tokens.dart';
import 'birdy_typography.dart';

abstract final class BirdyTheme {
  static ThemeData? _light;
  static ThemeData? _dark;

  /// Light theme: Brume background, white cards.
  static ThemeData light() => _light ??= _build(BirdyColors.light);

  /// Dark theme: Encre de nuit background, used by listening by default.
  static ThemeData dark() => _dark ??= _build(BirdyColors.dark);

  /// Material color scheme mapped on the BirdyGo tokens.
  static ColorScheme colorScheme(BirdyColors c) {
    final isDark = c.isDark;
    Color solid(Color color) => Color.alphaBlend(color, c.background);
    final seed = ColorScheme.fromSeed(
      seedColor: BirdyBrand.kingfisher,
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
          isDark ? BirdyColors.light.accentText : BirdyColors.dark.accentText,
    );
  }

  static ThemeData _build(BirdyColors c) {
    final scheme = colorScheme(c);
    final base = AppTheme.fromColorScheme(scheme);
    const stadium = StadiumBorder();
    final textTheme = base.textTheme.merge(BirdyText.textTheme);

    return base.copyWith(
      scaffoldBackgroundColor: c.background,
      canvasColor: c.background,
      textTheme: textTheme,
      primaryTextTheme: base.primaryTextTheme.merge(BirdyText.textTheme),
      extensions: <ThemeExtension<dynamic>>[
        c.isDark ? ScoreColors.dark : ScoreColors.light,
        c.isDark ? AppSemanticColors.dark(scheme) : AppSemanticColors.light,
        c,
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
        style: base.elevatedButtonTheme.style?.merge(
          ElevatedButton.styleFrom(
            elevation: 0,
            shape: stadium,
            textStyle: BirdyText.labelCompact,
          ),
        ),
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
        style: base.textButtonTheme.style?.merge(
          TextButton.styleFrom(
            shape: stadium,
            textStyle: BirdyText.labelCompact,
          ),
        ),
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
        actionTextColor: BirdyColors.dark.accentText,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(BirdyRadii.card)),
        ),
      ),
      dividerTheme: base.dividerTheme.copyWith(color: c.lineOpaque),
    );
  }
}

/// Forces the dark theme below it: listening opens dark by default
/// (fork/DESIGN.md). Keeps an already dark theme, and the upstream
/// high-contrast palette when the user chose it.
class ListeningTheme extends StatelessWidget {
  const ListeningTheme({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final current = Theme.of(context);
    if (current.brightness == Brightness.dark) return child;
    final data =
        AppTheme.isHighContrastTheme(current)
            ? AppTheme.highContrastDark()
            : BirdyTheme.dark();
    return Theme(data: data, child: child);
  }
}
