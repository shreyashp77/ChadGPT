import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Brand Colors
  static const Color primaryLight = Color(0xFF6C63FF);
  static const Color primaryDark = Color(0xFF8B85FF); // Lighter for dark mode contrast
  static const Color accent = Color(0xFF00C853);
  
  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF6C63FF), Color(0xFF4834D4)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient darkCardGradient = LinearGradient(
    colors: [Color(0xFF1E1E1E), Color(0xFF252525)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Preset Colors
  static const List<Color> presetColors = [
      Color(0xFF6C63FF), // Default Purple
      Color(0xFF00C853), // Green
      Color(0xFF2962FF), // Blue
      Color(0xFFFF3D00), // Orange
      Color(0xFFFFD600), // Yellow
      Color(0xFFE91E63), // Pink
      Color(0xFF00BFA5), // Teal
      Color(0xFFD50000), // Red
      Color(0xFF304FFE), // Indigo
      Color(0xFF00B0FF), // Light Blue
      Color(0xFFFFAB00), // Amber
      Color(0xFF6200EA), // Deep Purple
      Color(0xFFAEEA00), // Lime
      Color(0xFF5D4037), // Brown
  ];

  // Dynamic Gradients
  static LinearGradient getPrimaryGradient(Color color) {
      return LinearGradient(
          colors: [color, HSLColor.fromColor(color).withLightness((HSLColor.fromColor(color).lightness - 0.1).clamp(0.0, 1.0)).toColor()],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
      );
  }

  static ThemeData getLightTheme(Color seedColor) {
      return ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF7F9FC),
        colorScheme: ColorScheme.fromSeed(
          seedColor: seedColor,
          brightness: Brightness.light,
          primary: seedColor, // Force vibrant
          secondary: seedColor,
          surface: const Color(0xFFF7F9FC),
          onSurface: const Color(0xFF1A1C1E),
        ),
        textTheme: GoogleFonts.outfitTextTheme(ThemeData.light().textTheme),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: false,
          scrolledUnderElevation: 0,
        ),
      );
  }

  static ThemeData getDarkTheme(Color seedColor) {
      return ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF000000), // True black
        colorScheme: ColorScheme.fromSeed(
          seedColor: seedColor,
          brightness: Brightness.dark,
          primary: seedColor, // Force vibrant
          secondary: seedColor,
          surface: const Color(0xFF141414),
          onSurface: const Color(0xFFEDEDED),
          surfaceContainer: const Color(0xFF1E1E1E), // For Cards/Sheets
        ),
        textTheme: GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: false,
          scrolledUnderElevation: 0,
        ),
      );
  }
  
  // Glassmorphism
  static BoxDecoration glassDecoration(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return BoxDecoration(
      color: (isDark ? Colors.black : Colors.white).withValues(alpha: 0.7),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(
        color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.1),
      ),
    );
  }
}
