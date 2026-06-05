// This is free and unencumbered software released into the public domain.
// For more information, please refer to <https://unlicense.org>.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Defines the Material Design 3 theme for the Gallium application.
///
/// Provides both light and dark theme configurations that adhere to the
/// Material Design 3 specification, including dynamic color schemes,
/// Roboto typography, and MD3 shape tokens.
abstract final class AppTheme {
  /// The light theme configuration.
  static ThemeData lightTheme = _buildTheme(Brightness.light);

  /// The dark theme configuration.
  static ThemeData darkTheme = _buildTheme(Brightness.dark);

  static ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    // Define colors according to Google's Material 3 standard palettes:
    final ColorScheme colorScheme;
    if (isDark) {
      colorScheme =
          ColorScheme.fromSeed(
            seedColor: const Color(0xFF4285F4),
            brightness: Brightness.dark,
          ).copyWith(
            surface: const Color(
              0xFF111318,
            ), // Google dark base canvas background
            surfaceContainerLow: const Color(
              0xFF191C20,
            ), // Navigation rail canvas background
            surfaceContainerLowest: const Color(
              0xFF0F1115,
            ), // Workspace nested sheet background
            surfaceContainer: const Color(0xFF1A1C22),
            surfaceContainerHigh: const Color(0xFF24262A),
            surfaceContainerHighest: const Color(0xFF2E3035),
            primary: const Color(0xFFA8C7FA), // Google soft pastel blue
            onPrimary: const Color(0xFF062E6F),
            primaryContainer: const Color(0xFF0842A0),
            onPrimaryContainer: const Color(0xFFD3E3FD),
            secondary: const Color(0xFFC2E7FF), // Google secondary cyan
            onSecondary: const Color(0xFF003354),
            secondaryContainer: const Color(
              0xFF004B75,
            ), // Sidebar active capsule background
            onSecondaryContainer: const Color(0xFFC2E7FF),
            outline: const Color(0xFF8E918F),
            outlineVariant: const Color(0xFF444746), // Splitting border lines
          );
    } else {
      colorScheme = ColorScheme.fromSeed(seedColor: const Color(0xFF4285F4))
          .copyWith(
            surface: const Color(
              0xFFF8F9FA,
            ), // Google light base canvas background
            surfaceContainerLow: const Color(
              0xFFF1F3F4,
            ), // Navigation rail background
            surfaceContainerLowest: const Color(
              0xFFFFFFFF,
            ), // Workspace nested sheet background
            surfaceContainer: const Color(0xFFE8EAED),
            surfaceContainerHigh: const Color(0xFFE0E2E5),
            surfaceContainerHighest: const Color(0xFFDADCE0),
            primary: const Color(0xFF0B57D0), // Google classic blue
            onPrimary: const Color(0xFFFFFFFF),
            primaryContainer: const Color(0xFFD3E3FD),
            onPrimaryContainer: const Color(0xFF041E42),
            secondary: const Color(0xFF00639B),
            onSecondary: const Color(0xFFFFFFFF),
            secondaryContainer: const Color(
              0xFFC2E7FF,
            ), // Sidebar active capsule background
            onSecondaryContainer: const Color(0xFF001D35),
            outline: const Color(0xFF747775),
            outlineVariant: const Color(0xFFC4C7C5), // Splitting border lines
          );
    }

    final textTheme = GoogleFonts.robotoTextTheme(
      isDark ? ThemeData.dark().textTheme : ThemeData.light().textTheme,
    );

    final monospaceTextTheme = GoogleFonts.robotoMonoTextTheme(textTheme);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: colorScheme.surface,
      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant,
        thickness: 1,
        space: 1,
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: colorScheme.surfaceContainerLow,
        indicatorColor: colorScheme.secondaryContainer,
        minWidth: 80,
        minExtendedWidth: 256,
        labelType: NavigationRailLabelType.all,
        selectedIconTheme: IconThemeData(
          color: colorScheme.onSecondaryContainer,
          size: 24,
        ),
        unselectedIconTheme: IconThemeData(
          color: colorScheme.onSurfaceVariant,
          size: 24,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colorScheme.surfaceContainer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cornerExtraLarge), // 28dp
        ),
        titleTextStyle: textTheme.headlineSmall?.copyWith(
          color: colorScheme.onSurface,
          fontWeight: FontWeight.w600,
        ),
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(
                cornerFull,
              ), // Full pill shape
            ),
          ),
        ),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: colorScheme.primary,
        inactiveTrackColor: colorScheme.primaryContainer,
        thumbColor: colorScheme.primary,
        overlayColor: colorScheme.primary.withValues(alpha: 0.12),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        menuStyle: MenuStyle(
          backgroundColor: WidgetStateProperty.all(
            colorScheme.surfaceContainer,
          ),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(cornerMedium), // 12dp
            ),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerHigh,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(cornerSmall), // 8dp
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(cornerSmall),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(cornerSmall),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        hintStyle: monospaceTextTheme.bodyLarge?.copyWith(
          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
        ),
      ),
    );
  }

  /// Returns the monospace text style for the editor area.
  ///
  /// Uses Roboto Mono, the MD3-specified monospace companion to Roboto.
  static TextStyle editorTextStyle(BuildContext context) {
    return GoogleFonts.robotoMono(
      textStyle: Theme.of(context).textTheme.bodyLarge,
      height: 1.5,
    );
  }

  /// MD3 spacing tokens (4dp grid).
  static const double space4 = 4.0;
  static const double space8 = 8.0;
  static const double space12 = 12.0;
  static const double space16 = 16.0;
  static const double space24 = 24.0;
  static const double space32 = 32.0;
  static const double space48 = 48.0;

  /// MD3 shape corner tokens.
  static const double cornerNone = 0.0;
  static const double cornerExtraSmall = 4.0;
  static const double cornerSmall = 8.0;
  static const double cornerMedium = 12.0;
  static const double cornerLarge = 16.0;
  static const double cornerLargeIncreased = 20.0;
  static const double cornerExtraLarge = 28.0;
  static const double cornerExtraLargeIncreased = 32.0;
  static const double cornerExtraExtraLarge = 48.0;
  static const double cornerFull = 999.0;

  /// Window corner radius (28dp — MD3 extra large token).
  static const double windowCornerRadius = cornerExtraLarge;
}
