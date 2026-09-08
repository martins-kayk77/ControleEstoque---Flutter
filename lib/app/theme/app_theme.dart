import 'package:flutter/material.dart';

class AppTheme {
  const AppTheme._();

  static const primaryBlue = Color(0xFF075BD8);
  static const deepBlue = Color(0xFF071E63);
  static const aqua = Color(0xFF00A7E8);
  static const warning = Color(0xFFE49B0F);
  static const success = Color(0xFF0F8A5F);

  static ThemeData light() {
    const colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: primaryBlue,
      onPrimary: Colors.white,
      primaryContainer: Color(0xFFDCE8FF),
      onPrimaryContainer: Color(0xFF06235F),
      secondary: aqua,
      onSecondary: Colors.white,
      secondaryContainer: Color(0xFFDDF6FF),
      onSecondaryContainer: Color(0xFF003544),
      tertiary: warning,
      onTertiary: Color(0xFF231A00),
      tertiaryContainer: Color(0xFFFFF2CC),
      onTertiaryContainer: Color(0xFF3F2E00),
      error: Color(0xFFBA1A1A),
      onError: Colors.white,
      errorContainer: Color(0xFFFFDAD6),
      onErrorContainer: Color(0xFF410002),
      surface: Color(0xFFF7F9FC),
      onSurface: Color(0xFF172033),
      surfaceContainerLowest: Colors.white,
      surfaceContainerLow: Color(0xFFF1F5FA),
      surfaceContainer: Color(0xFFEAF0F8),
      surfaceContainerHigh: Color(0xFFE2E9F3),
      surfaceContainerHighest: Color(0xFFD9E2EF),
      onSurfaceVariant: Color(0xFF58657A),
      outline: Color(0xFF8C98AA),
      outlineVariant: Color(0xFFD5DDE8),
      shadow: Colors.black,
      scrim: Colors.black,
      inverseSurface: Color(0xFF2C3140),
      onInverseSurface: Color(0xFFF1F3F8),
      inversePrimary: Color(0xFFB6C7FF),
    );

    return _buildTheme(colorScheme);
  }

  static ThemeData dark() {
    const colorScheme = ColorScheme(
      brightness: Brightness.dark,
      primary: Color(0xFFB6C7FF),
      onPrimary: Color(0xFF002B78),
      primaryContainer: Color(0xFF0B46B8),
      onPrimaryContainer: Color(0xFFDCE8FF),
      secondary: Color(0xFF77D7FF),
      onSecondary: Color(0xFF003544),
      secondaryContainer: Color(0xFF00516A),
      onSecondaryContainer: Color(0xFFDDF6FF),
      tertiary: Color(0xFFFFCC66),
      onTertiary: Color(0xFF3F2E00),
      tertiaryContainer: Color(0xFF5C4300),
      onTertiaryContainer: Color(0xFFFFF2CC),
      error: Color(0xFFFFB4AB),
      onError: Color(0xFF690005),
      errorContainer: Color(0xFF93000A),
      onErrorContainer: Color(0xFFFFDAD6),
      surface: Color(0xFF101521),
      onSurface: Color(0xFFE7EAF2),
      surfaceContainerLowest: Color(0xFF0A0F18),
      surfaceContainerLow: Color(0xFF171C29),
      surfaceContainer: Color(0xFF1C2331),
      surfaceContainerHigh: Color(0xFF273041),
      surfaceContainerHighest: Color(0xFF323B4D),
      onSurfaceVariant: Color(0xFFC2CAD8),
      outline: Color(0xFF8C98AA),
      outlineVariant: Color(0xFF3E4858),
      shadow: Colors.black,
      scrim: Colors.black,
      inverseSurface: Color(0xFFE7EAF2),
      onInverseSurface: Color(0xFF2C3140),
      inversePrimary: primaryBlue,
    );

    return _buildTheme(colorScheme);
  }

  static ThemeData _buildTheme(ColorScheme colorScheme) {
    final textTheme = Typography.material2021().black.apply(
      bodyColor: colorScheme.onSurface,
      displayColor: colorScheme.onSurface,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.surface,
      visualDensity: VisualDensity.standard,
      textTheme: textTheme.copyWith(
        headlineLarge: textTheme.headlineLarge?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
        ),
        headlineMedium: textTheme.headlineMedium?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
        ),
        headlineSmall: textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
        ),
        titleLarge: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
        ),
        titleMedium: textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
        ),
        labelLarge: textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
        ),
      ),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: colorScheme.onSurface,
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: colorScheme.surfaceContainerLowest,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        side: BorderSide(color: colorScheme.outlineVariant),
        labelStyle: TextStyle(
          color: colorScheme.onSurface,
          fontWeight: FontWeight.w700,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          minimumSize: const Size(44, 44),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          minimumSize: const Size(44, 44),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerLowest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
      ),
      navigationDrawerTheme: NavigationDrawerThemeData(
        backgroundColor: colorScheme.surfaceContainerLowest,
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant,
        thickness: 1,
        space: 1,
      ),
    );
  }
}
