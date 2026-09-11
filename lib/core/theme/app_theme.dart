import 'package:flutter/material.dart';

class AppThemeConstants {
  static const double spacing4 = 4.0;
  static const double spacing8 = 8.0;
  static const double spacing12 = 12.0;
  static const double spacing16 = 16.0;
  static const double spacing24 = 24.0;
  static const double spacing32 = 32.0;

  static const double radiusButton = 8.0;
  static const double radiusCard = 12.0;
  static const double radiusDialog = 16.0;
  static const double radiusInput = 8.0;

  static const EdgeInsets defaultPadding = EdgeInsets.all(spacing16);
  static const EdgeInsets cardPadding = EdgeInsets.all(spacing16);
  static const EdgeInsets buttonPadding = EdgeInsets.symmetric(horizontal: spacing24, vertical: spacing12);
}

class AppTheme {
  // We use Teal as the primary business color
  static const Color _primaryTeal = Color(0xFF009688); // Teal
  static const Color _secondaryAccent = Color(0xFFFFB300); // Amber/Gold

  // Semantic Colors
  static const Color _successGreen = Color(0xFF4CAF50);
  static const Color _warningOrange = Color(0xFFFF9800);
  static const Color _errorRed = Color(0xFFF44336);

  // Dark Theme Background Colors
  static const Color _darkBackground = Color(0xFF121212);
  static const Color _darkSurface = Color(0xFF1E1E1E);
  static const Color _darkElevatedSurface = Color(0xFF2C2C2C);
  
  static const Color _lightBackground = Color(0xFFF5F7F8);
  static const Color _lightSurface = Color(0xFFFFFFFF);

  // Reusable Typography Scale
  static const TextTheme _textTheme = TextTheme(
    headlineLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
    headlineMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
    headlineSmall: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
    titleLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
    titleMedium: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
    titleSmall: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
    bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.normal),
    bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.normal),
    bodySmall: TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
    labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, letterSpacing: 1.1), // Buttons
    labelMedium: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
    labelSmall: TextStyle(fontSize: 10, fontWeight: FontWeight.w500),
  );

  static final ThemeData lightTheme = _buildTheme(
    brightness: Brightness.light,
    backgroundColor: _lightBackground,
    surfaceColor: _lightSurface,
  );

  static final ThemeData darkTheme = _buildTheme(
    brightness: Brightness.dark,
    backgroundColor: _darkBackground,
    surfaceColor: _darkSurface,
  );

  static ThemeData _buildTheme({
    required Brightness brightness,
    required Color backgroundColor,
    required Color surfaceColor,
  }) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _primaryTeal,
      secondary: _secondaryAccent,
      brightness: brightness,
      surface: surfaceColor,
      error: _errorRed,
    );

    final isDark = brightness == Brightness.dark;
    
    // Slight border for dark mode cards to differentiate them
    final cardBorder = isDark 
        ? BorderSide(color: Colors.white.withValues(alpha: 0.1), width: 1)
        : BorderSide.none;

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: backgroundColor,
      textTheme: _textTheme,
      
      // Components
      appBarTheme: AppBarTheme(
        backgroundColor: backgroundColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      
      cardTheme: CardThemeData(
        color: surfaceColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppThemeConstants.radiusCard),
          side: cardBorder,
        ),
        margin: const EdgeInsets.symmetric(vertical: AppThemeConstants.spacing8),
      ),
      
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(64, 48),
          padding: AppThemeConstants.buttonPadding,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppThemeConstants.radiusButton),
          ),
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
        ),
      ),
      
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 48),
          padding: AppThemeConstants.buttonPadding,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppThemeConstants.radiusButton),
          ),
          side: BorderSide(color: colorScheme.primary),
        ),
      ),
      
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(64, 48),
          padding: AppThemeConstants.buttonPadding,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppThemeConstants.radiusButton),
          ),
        ),
      ),
      
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? _darkElevatedSurface : Colors.grey.shade100,
        contentPadding: const EdgeInsets.symmetric(horizontal: AppThemeConstants.spacing16, vertical: AppThemeConstants.spacing12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppThemeConstants.radiusInput),
          borderSide: BorderSide(color: colorScheme.outline.withValues(alpha: 0.5)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppThemeConstants.radiusInput),
          borderSide: BorderSide(color: colorScheme.outline.withValues(alpha: 0.5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppThemeConstants.radiusInput),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppThemeConstants.radiusInput),
          borderSide: BorderSide(color: colorScheme.error),
        ),
      ),
      
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surfaceColor,
        indicatorColor: colorScheme.primary.withValues(alpha: 0.2),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
      
      dialogTheme: DialogThemeData(
        backgroundColor: isDark ? _darkElevatedSurface : _lightSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppThemeConstants.radiusDialog),
        ),
        elevation: 8,
      ),
      
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: isDark ? _darkElevatedSurface : _lightSurface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppThemeConstants.radiusDialog)),
        ),
        elevation: 8,
      ),
    );
  }

  // Extensions or getters for semantic colors if needed
  static Color get successColor => _successGreen;
  static Color get warningColor => _warningOrange;
  static Color get errorColor => _errorRed;
}
