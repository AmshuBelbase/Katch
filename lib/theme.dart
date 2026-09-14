import 'package:flutter/material.dart';

class AppTheme {
  // Brand Colors
  static const Color primary = Color(0xFF6750A4); // Deep Purple
  static const Color secondary = Color(0xFF625B71); // Soft Muted Purple
  static const Color tertiary = Color(0xFF7D5260); // Warm Accent
  static const Color background = Color(0xFFFDFBF7); // Warm White
  static const Color surface = Color(0xFFFFFFFF);
  static const Color error = Color(0xFFB3261E);
  
  // Custom Semantic Colors
  static const Color success = Color(0xFF2E7D32); // Green for Income/Done
  static const Color warning = Color(0xFFED6C02); // Orange for Due Soon
  
  static Color successColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark ? Colors.greenAccent : success;
  }

  static Color errorColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark ? Colors.redAccent : error;
  }
  
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        secondary: secondary,
        tertiary: tertiary,
        background: background,
        surface: surface,
        error: error,
      ),
      scaffoldBackgroundColor: background,
      
      // Typography
      fontFamily: 'Roboto', // Modern system font
      
      // Card Theme for modern subtle elevation
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.black.withOpacity(0.05)),
        ),
        color: surface,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      
      // Inputs
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.black.withOpacity(0.03),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      
      // Navigation Bar
      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        backgroundColor: surface,
        indicatorColor: primary.withOpacity(0.15),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
      
      // Chips
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        backgroundColor: Colors.black.withOpacity(0.05),
        selectedColor: primary.withOpacity(0.15),
        labelStyle: const TextStyle(fontWeight: FontWeight.w500),
        side: BorderSide.none,
      ),
      
      // App Bar
      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        elevation: 0,
        centerTitle: false,
        scrolledUnderElevation: 0,
      ),
      
      // Floating Action Button
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        brightness: Brightness.dark,
        seedColor: background,
        primary: background,
        onPrimary: primary,
        secondary: background,
        tertiary: tertiary,
        background: primary,
        onBackground: background,
        surface: const Color(0xFF524082), // Slightly darker purple for surfaces
        onSurface: background,
        error: error,
      ),
      scaffoldBackgroundColor: primary,
      
      // Typography
      fontFamily: 'Roboto',
      
      // Card Theme
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: background.withOpacity(0.1)),
        ),
        color: const Color(0xFF524082),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      
      // Inputs
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withOpacity(0.1),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: background, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      
      // Navigation Bar
      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        backgroundColor: const Color(0xFF524082),
        indicatorColor: background.withOpacity(0.15),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
      
      // Chips
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        backgroundColor: Colors.white.withOpacity(0.1),
        selectedColor: background.withOpacity(0.2),
        labelStyle: const TextStyle(fontWeight: FontWeight.w500, color: background),
        secondaryLabelStyle: const TextStyle(color: primary),
        side: BorderSide.none,
      ),
      
      // App Bar
      appBarTheme: const AppBarTheme(
        backgroundColor: primary,
        foregroundColor: background,
        elevation: 0,
        centerTitle: false,
        scrolledUnderElevation: 0,
      ),
      
      // Floating Action Button
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: background,
        foregroundColor: primary,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}
