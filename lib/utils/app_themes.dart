import 'dart:ui';
import 'package:flutter/material.dart';

/// Theme types
enum AppThemeType {
  light,
  dark,
  liquidGlass,
}

/// App theme configurations
class AppThemes {
  // Dark Theme
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: Colors.black,
      primaryColor: Colors.amber,
      colorScheme: const ColorScheme.dark(
        primary: Colors.amber,
        secondary: Colors.amber,
        surface: Color(0xFF1A1A1A),
        background: Colors.black,
        error: Colors.red,
        onPrimary: Colors.black,
        onSecondary: Colors.black,
        onSurface: Colors.white,
        onBackground: Colors.white,
        onError: Colors.white,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.grey[900],
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.grey[800]!),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        contentTextStyle: TextStyle(
          color: Colors.grey[300],
          fontSize: 14,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.grey[900],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey[800]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey[800]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.amber, width: 2),
        ),
        labelStyle: TextStyle(color: Colors.grey[400]),
        hintStyle: TextStyle(color: Colors.grey[500]),
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(color: Colors.white),
        displayMedium: TextStyle(color: Colors.white),
        displaySmall: TextStyle(color: Colors.white),
        headlineLarge: TextStyle(color: Colors.white),
        headlineMedium: TextStyle(color: Colors.white),
        headlineSmall: TextStyle(color: Colors.white),
        titleLarge: TextStyle(color: Colors.white),
        titleMedium: TextStyle(color: Colors.white),
        titleSmall: TextStyle(color: Colors.white),
        bodyLarge: TextStyle(color: Colors.white),
        bodyMedium: TextStyle(color: Colors.white),
        bodySmall: TextStyle(color: Colors.white70),
        labelLarge: TextStyle(color: Colors.white),
        labelMedium: TextStyle(color: Colors.white),
        labelSmall: TextStyle(color: Colors.white70),
      ),
      visualDensity: VisualDensity.adaptivePlatformDensity,
    );
  }

  // Light Theme
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: const Color(0xFFFAFAFA), // Slightly off-white for better contrast
      primaryColor: Colors.amber,
      colorScheme: const ColorScheme.light(
        primary: Colors.amber,
        secondary: Colors.amber,
        surface: Color(0xFFF0F0F0), // Slightly darker for better card visibility
        background: Color(0xFFFAFAFA),
        error: Colors.red,
        onPrimary: Colors.black,
        onSecondary: Colors.black,
        onSurface: Color(0xFF1A1A1A), // Darker for better readability
        onBackground: Color(0xFF1A1A1A),
        onError: Colors.white,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: Color(0xFF1A1A1A)),
        titleTextStyle: TextStyle(
          color: Color(0xFF1A1A1A),
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.grey[200]!, width: 1),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        titleTextStyle: const TextStyle(
          color: Color(0xFF1A1A1A),
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        contentTextStyle: const TextStyle(
          color: Color(0xFF424242), // Darker for better readability
          fontSize: 14,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey[400]!, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey[300]!, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.amber, width: 2),
        ),
        labelStyle: const TextStyle(color: Color(0xFF424242)),
        hintStyle: TextStyle(color: Colors.grey[600]!),
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(color: Color(0xFF1A1A1A)),
        displayMedium: TextStyle(color: Color(0xFF1A1A1A)),
        displaySmall: TextStyle(color: Color(0xFF1A1A1A)),
        headlineLarge: TextStyle(color: Color(0xFF1A1A1A)),
        headlineMedium: TextStyle(color: Color(0xFF1A1A1A)),
        headlineSmall: TextStyle(color: Color(0xFF1A1A1A)),
        titleLarge: TextStyle(color: Color(0xFF1A1A1A)),
        titleMedium: TextStyle(color: Color(0xFF1A1A1A)),
        titleSmall: TextStyle(color: Color(0xFF1A1A1A)),
        bodyLarge: TextStyle(color: Color(0xFF1A1A1A)),
        bodyMedium: TextStyle(color: Color(0xFF1A1A1A)),
        bodySmall: TextStyle(color: Color(0xFF616161)), // Better contrast
        labelLarge: TextStyle(color: Color(0xFF1A1A1A)),
        labelMedium: TextStyle(color: Color(0xFF1A1A1A)),
        labelSmall: TextStyle(color: Color(0xFF616161)),
      ),
      visualDensity: VisualDensity.adaptivePlatformDensity,
    );
  }

  // Liquid Glass Theme (Apple-inspired)
  static ThemeData get liquidGlassTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF0A0A0A),
      primaryColor: Colors.amber,
      colorScheme: const ColorScheme.dark(
        primary: Colors.amber,
        secondary: Color(0xFF00D9F5),
        surface: Color(0x40FFFFFF), // Increased opacity for better visibility
        background: Color(0xFF0A0A0A),
        error: Colors.red,
        onPrimary: Colors.black,
        onSecondary: Colors.black,
        onSurface: Colors.white, // Full opacity for readability
        onBackground: Colors.white,
        onError: Colors.white,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white.withOpacity(0.18), // Increased from 0.05 to 0.18
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: Colors.white.withOpacity(0.25), // Increased border visibility
            width: 1.5, // Slightly thicker border
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white.withOpacity(0.2), // Increased from 0.1 to 0.2
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        titleTextStyle: const TextStyle(
          color: Colors.white, // Full opacity
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        contentTextStyle: const TextStyle(
          color: Colors.white, // Full opacity instead of 0.9
          fontSize: 14,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withOpacity(0.15), // Increased from 0.05 to 0.15
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: Colors.white.withOpacity(0.25), // Increased border visibility
            width: 1.5,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: Colors.white.withOpacity(0.25),
            width: 1.5,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: Colors.amber,
            width: 2,
          ),
        ),
        labelStyle: const TextStyle(color: Colors.white), // Full opacity
        hintStyle: TextStyle(color: Colors.white.withOpacity(0.7)), // Better visibility
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(color: Colors.white),
        displayMedium: TextStyle(color: Colors.white),
        displaySmall: TextStyle(color: Colors.white),
        headlineLarge: TextStyle(color: Colors.white),
        headlineMedium: TextStyle(color: Colors.white),
        headlineSmall: TextStyle(color: Colors.white),
        titleLarge: TextStyle(color: Colors.white),
        titleMedium: TextStyle(color: Colors.white),
        titleSmall: TextStyle(color: Colors.white),
        bodyLarge: TextStyle(color: Colors.white), // Full opacity
        bodyMedium: TextStyle(color: Colors.white), // Full opacity
        bodySmall: TextStyle(color: Colors.white), // Full opacity instead of 0.8
        labelLarge: TextStyle(color: Colors.white),
        labelMedium: TextStyle(color: Colors.white),
        labelSmall: TextStyle(color: Colors.white), // Full opacity instead of 0.8
      ),
      visualDensity: VisualDensity.adaptivePlatformDensity,
      extensions: [
        LiquidGlassTheme(
          blurIntensity: 15.0, // Reduced from 20.0 for lighter blur
          glassOpacity: 0.18, // Increased from 0.1 for better visibility
          borderOpacity: 0.25, // Increased from 0.2 for better definition
        ),
      ],
    );
  }

  // Get theme by type
  static ThemeData getThemeByType(AppThemeType type) {
    switch (type) {
      case AppThemeType.light:
        return lightTheme;
      case AppThemeType.dark:
        return darkTheme;
      case AppThemeType.liquidGlass:
        return liquidGlassTheme;
    }
  }
}

/// Liquid Glass Theme Extension
class LiquidGlassTheme extends ThemeExtension<LiquidGlassTheme> {
  final double blurIntensity;
  final double glassOpacity;
  final double borderOpacity;

  const LiquidGlassTheme({
    required this.blurIntensity,
    required this.glassOpacity,
    required this.borderOpacity,
  });

  @override
  ThemeExtension<LiquidGlassTheme> copyWith({
    double? blurIntensity,
    double? glassOpacity,
    double? borderOpacity,
  }) {
    return LiquidGlassTheme(
      blurIntensity: blurIntensity ?? this.blurIntensity,
      glassOpacity: glassOpacity ?? this.glassOpacity,
      borderOpacity: borderOpacity ?? this.borderOpacity,
    );
  }

  @override
  ThemeExtension<LiquidGlassTheme> lerp(
    ThemeExtension<LiquidGlassTheme>? other,
    double t,
  ) {
    if (other is! LiquidGlassTheme) {
      return this;
    }

    return LiquidGlassTheme(
      blurIntensity: blurIntensity + (other.blurIntensity - blurIntensity) * t,
      glassOpacity: glassOpacity + (other.glassOpacity - glassOpacity) * t,
      borderOpacity: borderOpacity + (other.borderOpacity - borderOpacity) * t,
    );
  }
}

/// Glassmorphism Widget Helper
class GlassContainer extends StatelessWidget {
  final Widget child;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final BorderRadius? borderRadius;
  final double? blurIntensity;
  final double? glassOpacity;
  final double? borderOpacity;

  const GlassContainer({
    super.key,
    required this.child,
    this.width,
    this.height,
    this.padding,
    this.margin,
    this.borderRadius,
    this.blurIntensity,
    this.glassOpacity,
    this.borderOpacity,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final liquidGlass = theme.extension<LiquidGlassTheme>();

    final blur = blurIntensity ?? liquidGlass?.blurIntensity ?? 15.0;
    final opacity = glassOpacity ?? liquidGlass?.glassOpacity ?? 0.18;
    final border = borderOpacity ?? liquidGlass?.borderOpacity ?? 0.25;

    return Container(
      width: width,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: borderRadius ?? BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(border),
          width: 1.5, // Slightly thicker for better visibility
        ),
      ),
      child: ClipRRect(
        borderRadius: borderRadius ?? BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(opacity),
              borderRadius: borderRadius ?? BorderRadius.circular(20),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

