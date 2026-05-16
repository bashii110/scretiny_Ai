import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_color.dart';

class AppTheme {
  AppTheme._();

  static const double _radiusSm = 8.0;
  static const double _radiusMd = 12.0;
  static const double _radiusLg = 16.0;
  static const double _radiusXl = 24.0;

  // ─── Light Theme ─────────────────────────────────────────────────────────
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: Brightness.light,
        primary: AppColors.primary,
        secondary: AppColors.secondary,
        surface: AppColors.surface,
        error: AppColors.danger,
      ),
      scaffoldBackgroundColor: AppColors.background,
      textTheme: _buildTextTheme(isDark: false),
      appBarTheme: _buildAppBarTheme(isDark: false),
      cardTheme: _buildCardTheme(isDark: false),
      elevatedButtonTheme: _buildElevatedButtonTheme(),
      outlinedButtonTheme: _buildOutlinedButtonTheme(),
      textButtonTheme: _buildTextButtonTheme(),
      inputDecorationTheme: _buildInputDecorationTheme(isDark: false),
      bottomNavigationBarTheme: _buildBottomNavTheme(isDark: false),
      chipTheme: _buildChipTheme(isDark: false),
      dividerTheme: const DividerThemeData(
        color: AppColors.divider,
        thickness: 1,
        space: 1,
      ),
      dialogTheme: DialogTheme(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_radiusLg),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_radiusMd),
        ),
      ),
      sliderTheme: _buildSliderTheme(),
      extensions: const [AppThemeExtension.light],
    );
  }

  // ─── Dark Theme ──────────────────────────────────────────────────────────
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: Brightness.dark,
        primary: AppColors.primaryLight,
        secondary: AppColors.secondary,
        surface: AppColors.darkSurface,
        error: AppColors.danger,
      ),
      scaffoldBackgroundColor: AppColors.darkBackground,
      textTheme: _buildTextTheme(isDark: true),
      appBarTheme: _buildAppBarTheme(isDark: true),
      cardTheme: _buildCardTheme(isDark: true),
      elevatedButtonTheme: _buildElevatedButtonTheme(),
      outlinedButtonTheme: _buildOutlinedButtonTheme(),
      textButtonTheme: _buildTextButtonTheme(),
      inputDecorationTheme: _buildInputDecorationTheme(isDark: true),
      bottomNavigationBarTheme: _buildBottomNavTheme(isDark: true),
      chipTheme: _buildChipTheme(isDark: true),
      extensions: const [AppThemeExtension.dark],
    );
  }

  // ─── Text Theme ──────────────────────────────────────────────────────────
  static TextTheme _buildTextTheme({required bool isDark}) {
    final baseColor = isDark ? Colors.white : AppColors.textDark;
    final secondaryColor = isDark ? Colors.white70 : AppColors.textMedium;
    final hintColor = isDark ? Colors.white38 : AppColors.textLight;

    return GoogleFonts.poppinsTextTheme().copyWith(
      displayLarge: GoogleFonts.poppins(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        color: baseColor,
        letterSpacing: -0.5,
      ),
      displayMedium: GoogleFonts.poppins(
        fontSize: 28,
        fontWeight: FontWeight.bold,
        color: baseColor,
      ),
      headlineLarge: GoogleFonts.poppins(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: baseColor,
      ),
      headlineMedium: GoogleFonts.poppins(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: baseColor,
      ),
      headlineSmall: GoogleFonts.poppins(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: baseColor,
      ),
      titleLarge: GoogleFonts.poppins(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: baseColor,
      ),
      titleMedium: GoogleFonts.poppins(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: baseColor,
      ),
      titleSmall: GoogleFonts.poppins(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: secondaryColor,
      ),
      bodyLarge: GoogleFonts.poppins(
        fontSize: 16,
        fontWeight: FontWeight.normal,
        color: baseColor,
      ),
      bodyMedium: GoogleFonts.poppins(
        fontSize: 14,
        fontWeight: FontWeight.normal,
        color: baseColor,
      ),
      bodySmall: GoogleFonts.poppins(
        fontSize: 12,
        fontWeight: FontWeight.normal,
        color: secondaryColor,
      ),
      labelLarge: GoogleFonts.poppins(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: baseColor,
      ),
      labelMedium: GoogleFonts.poppins(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: secondaryColor,
      ),
      labelSmall: GoogleFonts.poppins(
        fontSize: 11,
        fontWeight: FontWeight.normal,
        color: hintColor,
      ),
    );
  }

  // ─── AppBar ──────────────────────────────────────────────────────────────
  static AppBarTheme _buildAppBarTheme({required bool isDark}) {
    return AppBarTheme(
      elevation: 0,
      centerTitle: true,
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
      foregroundColor: isDark ? Colors.white : AppColors.textDark,
      titleTextStyle: GoogleFonts.poppins(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: isDark ? Colors.white : AppColors.textDark,
      ),
    );
  }

  // ─── Card ────────────────────────────────────────────────────────────────
  static CardTheme _buildCardTheme({required bool isDark}) {
    return CardTheme(
      elevation: 0,
      color: isDark ? AppColors.darkSurface : AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_radiusLg),
        side: BorderSide(
          color: isDark ? Colors.white12 : AppColors.border,
          width: 1,
        ),
      ),
      margin: EdgeInsets.zero,
    );
  }

  // ─── Elevated Button ─────────────────────────────────────────────────────
  static ElevatedButtonThemeData _buildElevatedButtonTheme() {
    return ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_radiusMd),
        ),
        textStyle: GoogleFonts.poppins(
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
        minimumSize: const Size(double.infinity, 52),
      ),
    );
  }

  // ─── Outlined Button ─────────────────────────────────────────────────────
  static OutlinedButtonThemeData _buildOutlinedButtonTheme() {
    return OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        side: const BorderSide(color: AppColors.primary, width: 1.5),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_radiusMd),
        ),
        textStyle: GoogleFonts.poppins(
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
        minimumSize: const Size(double.infinity, 52),
      ),
    );
  }

  // ─── Text Button ─────────────────────────────────────────────────────────
  static TextButtonThemeData _buildTextButtonTheme() {
    return TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primary,
        textStyle: GoogleFonts.poppins(
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  // ─── Input Decoration ────────────────────────────────────────────────────
  static InputDecorationTheme _buildInputDecorationTheme({required bool isDark}) {
    return InputDecorationTheme(
      filled: true,
      fillColor: isDark ? AppColors.darkSurfaceVariant : AppColors.surfaceVariant,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_radiusMd),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_radiusMd),
        borderSide: BorderSide(
          color: isDark ? Colors.white12 : AppColors.border,
          width: 1,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_radiusMd),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_radiusMd),
        borderSide: const BorderSide(color: AppColors.danger, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_radiusMd),
        borderSide: const BorderSide(color: AppColors.danger, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      hintStyle: GoogleFonts.poppins(
        fontSize: 14,
        color: isDark ? Colors.white38 : AppColors.textLight,
      ),
      labelStyle: GoogleFonts.poppins(
        fontSize: 14,
        color: isDark ? Colors.white60 : AppColors.textMedium,
      ),
    );
  }

  // ─── Bottom Nav Bar ──────────────────────────────────────────────────────
  static BottomNavigationBarThemeData _buildBottomNavTheme({required bool isDark}) {
    return BottomNavigationBarThemeData(
      type: BottomNavigationBarType.fixed,
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.surface,
      selectedItemColor: AppColors.primary,
      unselectedItemColor: isDark ? Colors.white38 : AppColors.textLight,
      showUnselectedLabels: true,
      selectedLabelStyle: GoogleFonts.poppins(
        fontSize: 11,
        fontWeight: FontWeight.w500,
      ),
      unselectedLabelStyle: GoogleFonts.poppins(fontSize: 11),
      elevation: 8,
    );
  }

  // ─── Chip Theme ──────────────────────────────────────────────────────────
  static ChipThemeData _buildChipTheme({required bool isDark}) {
    return ChipThemeData(
      backgroundColor: isDark ? AppColors.darkSurfaceVariant : AppColors.surfaceVariant,
      selectedColor: AppColors.primary.withOpacity(0.15),
      labelStyle: GoogleFonts.poppins(fontSize: 12),
      side: BorderSide(
        color: isDark ? Colors.white12 : AppColors.border,
        width: 1,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_radiusSm),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    );
  }

  // ─── Slider Theme ────────────────────────────────────────────────────────
  static SliderThemeData _buildSliderTheme() {
    return SliderThemeData(
      activeTrackColor: AppColors.primary,
      inactiveTrackColor: AppColors.primary.withOpacity(0.2),
      thumbColor: AppColors.primary,
      overlayColor: AppColors.primary.withOpacity(0.1),
      trackHeight: 4,
      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12),
    );
  }

  // ─── Border Radius Constants ─────────────────────────────────────────────
  static BorderRadius get radiusSm => BorderRadius.circular(_radiusSm);
  static BorderRadius get radiusMd => BorderRadius.circular(_radiusMd);
  static BorderRadius get radiusLg => BorderRadius.circular(_radiusLg);
  static BorderRadius get radiusXl => BorderRadius.circular(_radiusXl);
}

// ─── Theme Extension for custom properties ───────────────────────────────────
class AppThemeExtension extends ThemeExtension<AppThemeExtension> {
  final Color cardShadow;
  final Color shimmerBase;
  final Color shimmerHighlight;

  const AppThemeExtension({
    required this.cardShadow,
    required this.shimmerBase,
    required this.shimmerHighlight,
  });

  static const light = AppThemeExtension(
    cardShadow: Color(0x1A6C63FF),
    shimmerBase: Color(0xFFE8E8F0),
    shimmerHighlight: Color(0xFFF8F9FE),
  );

  static const dark = AppThemeExtension(
    cardShadow: Color(0x336C63FF),
    shimmerBase: Color(0xFF374151),
    shimmerHighlight: Color(0xFF4B5563),
  );

  @override
  AppThemeExtension copyWith({
    Color? cardShadow,
    Color? shimmerBase,
    Color? shimmerHighlight,
  }) {
    return AppThemeExtension(
      cardShadow: cardShadow ?? this.cardShadow,
      shimmerBase: shimmerBase ?? this.shimmerBase,
      shimmerHighlight: shimmerHighlight ?? this.shimmerHighlight,
    );
  }

  @override
  AppThemeExtension lerp(AppThemeExtension? other, double t) {
    if (other is! AppThemeExtension) return this;
    return AppThemeExtension(
      cardShadow: Color.lerp(cardShadow, other.cardShadow, t)!,
      shimmerBase: Color.lerp(shimmerBase, other.shimmerBase, t)!,
      shimmerHighlight: Color.lerp(shimmerHighlight, other.shimmerHighlight, t)!,
    );
  }
}