import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTheme {
  AppTheme._();

  /// Bundled in assets/fonts — never fetched from the network.
  static const _font = 'PlusJakartaSans';

  static ThemeData get light {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: Brightness.light,
        surface: const Color(0xFFFFFFFF),
        onSurface: const Color(0xFF0F172A),
        onSurfaceVariant: const Color(0xFF64748B),
        outline: const Color(0xFFE2E8F0),
        surfaceContainerHighest: const Color(0xFFF1F5F9),
      ),
      scaffoldBackgroundColor: const Color(0xFFF8FAFC),
      hintColor: const Color(0xFF94A3B8),
      dividerColor: const Color(0xFFE2E8F0),
    );

    final textTheme = base.textTheme.apply(fontFamily: _font);

    return base.copyWith(
      textTheme: textTheme.copyWith(
        displayLarge: const TextStyle(fontFamily: _font,
          fontSize: 32,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
          height: 1.15,
          letterSpacing: -0.5,
        ),
        headlineLarge: const TextStyle(fontFamily: _font,
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
        headlineSmall: const TextStyle(fontFamily: _font,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        titleLarge: const TextStyle(fontFamily: _font,
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        titleMedium: const TextStyle(fontFamily: _font,
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: AppColors.textPrimary,
        ),
        bodyLarge: const TextStyle(fontFamily: _font,
          fontSize: 16,
          color: AppColors.textSecondary,
          height: 1.6,
        ),
        bodyMedium: const TextStyle(fontFamily: _font,
          fontSize: 14,
          color: AppColors.textSecondary,
          height: 1.5,
        ),
        labelLarge: const TextStyle(fontFamily: _font,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 1,
        shadowColor: AppColors.border,
        centerTitle: false,
        titleTextStyle: TextStyle(fontFamily: _font,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
        iconTheme: IconThemeData(color: AppColors.textPrimary),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.border),
        ),
        clipBehavior: Clip.antiAlias,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: const TextStyle(fontFamily: _font,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          side: const BorderSide(color: AppColors.border),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: const TextStyle(fontFamily: _font,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        hintStyle: const TextStyle(fontFamily: _font,
          color: AppColors.textHint,
          fontSize: 15,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shadowColor: AppColors.border,
        indicatorColor: AppColors.primary.withValues(alpha: 0.12),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: AppColors.primary, size: 22);
          }
          return const IconThemeData(color: AppColors.textSecondary, size: 22);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(fontFamily: _font,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            );
          }
          return const TextStyle(fontFamily: _font,
            fontSize: 11,
            color: AppColors.textSecondary,
          );
        }),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: AppColors.surface,
        selectedIconTheme: const IconThemeData(color: AppColors.primary),
        unselectedIconTheme: const IconThemeData(color: AppColors.textSecondary),
        indicatorColor: AppColors.primary.withValues(alpha: 0.12),
        labelType: NavigationRailLabelType.selected,
        selectedLabelTextStyle: const TextStyle(fontFamily: _font,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.primary,
        ),
        unselectedLabelTextStyle: const TextStyle(fontFamily: _font,
          fontSize: 12,
          color: AppColors.textSecondary,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 1,
      ),
    );
  }

  static ThemeData get dark {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: Brightness.dark,
        surface: const Color(0xFF1E293B),
        onSurface: const Color(0xFFF1F5F9),
        onSurfaceVariant: const Color(0xFF94A3B8),
        outline: const Color(0xFF334155),
        surfaceContainerHighest: const Color(0xFF253347),
      ),
      scaffoldBackgroundColor: const Color(0xFF0F172A),
      hintColor: const Color(0xFF64748B),
      dividerColor: const Color(0xFF334155),
    );

    final textTheme = base.textTheme.apply(fontFamily: _font);

    return base.copyWith(
      textTheme: textTheme.copyWith(
        displayLarge: const TextStyle(fontFamily: _font,
          fontSize: 32,
          fontWeight: FontWeight.w700,
          color: Color(0xFFF1F5F9),
          height: 1.15,
          letterSpacing: -0.5,
        ),
        headlineLarge: const TextStyle(fontFamily: _font,
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: Color(0xFFF1F5F9),
        ),
        headlineSmall: const TextStyle(fontFamily: _font,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Color(0xFFF1F5F9),
        ),
        titleLarge: const TextStyle(fontFamily: _font,
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Color(0xFFF1F5F9),
        ),
        titleMedium: const TextStyle(fontFamily: _font,
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: Color(0xFFF1F5F9),
        ),
        bodyLarge: const TextStyle(fontFamily: _font,
          fontSize: 16,
          color: Color(0xFF94A3B8),
          height: 1.6,
        ),
        bodyMedium: const TextStyle(fontFamily: _font,
          fontSize: 14,
          color: Color(0xFF94A3B8),
          height: 1.5,
        ),
        labelLarge: const TextStyle(fontFamily: _font,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF1E293B),
        elevation: 0,
        scrolledUnderElevation: 1,
        shadowColor: Color(0xFF334155),
        centerTitle: false,
        titleTextStyle: TextStyle(fontFamily: _font,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: Color(0xFFF1F5F9),
        ),
        iconTheme: IconThemeData(color: Color(0xFFF1F5F9)),
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF1E293B),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF334155)),
        ),
        clipBehavior: Clip.antiAlias,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: const TextStyle(fontFamily: _font,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFFF1F5F9),
          side: const BorderSide(color: Color(0xFF334155)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: const TextStyle(fontFamily: _font,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF1E293B),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF334155)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF334155)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        hintStyle: const TextStyle(fontFamily: _font,
          color: Color(0xFF64748B),
          fontSize: 15,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: const Color(0xFF1E293B),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shadowColor: const Color(0xFF334155),
        indicatorColor: AppColors.primary.withValues(alpha: 0.2),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: AppColors.primary, size: 22);
          }
          return const IconThemeData(color: Color(0xFF94A3B8), size: 22);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(fontFamily: _font,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            );
          }
          return const TextStyle(fontFamily: _font,
            fontSize: 11,
            color: Color(0xFF94A3B8),
          );
        }),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: const Color(0xFF1E293B),
        selectedIconTheme: const IconThemeData(color: AppColors.primary),
        unselectedIconTheme: const IconThemeData(color: Color(0xFF94A3B8)),
        indicatorColor: AppColors.primary.withValues(alpha: 0.2),
        labelType: NavigationRailLabelType.selected,
        selectedLabelTextStyle: const TextStyle(fontFamily: _font,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.primary,
        ),
        unselectedLabelTextStyle: const TextStyle(fontFamily: _font,
          fontSize: 12,
          color: Color(0xFF94A3B8),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFF334155),
        thickness: 1,
        space: 1,
      ),
    );
  }
}
